// ATK-MD0700R V1.6: FT5446 (0x38), or GT911 (0x5d / 0x14).
// Coordinates publish atomically. A failed/disconnected bus cannot hold notes.
module capacitive_touch #(parameter integer CLOCKS_PER_MS=26250,I2C_QUARTER=66,POLL_MS=1)(
    input wire clk,
    inout wire scl,sda,interrupt,
    output reg reset_n=0,
    output reg online=0,frame_valid=0,
    output reg [1:0] chip=0,
    output reg [4:0] contacts=0,
    output reg [59:0] point_x=0,point_y=0,
    output reg [15:0] error_count=0,
    // Independent of UI clipping/orientation: retain raw controller evidence.
    output reg [7:0] raw_status=0,
    output reg [3:0] raw_count=0,
    output reg [15:0] report_count=0,
    output reg [11:0] raw_x=0,raw_y=0,max_x=0,max_y=0
);
    reg int_low=0;
    assign interrupt=int_low ? 1'b0:1'bz;
    reg start=0,wide=0,write_command=0;
    reg [6:0] address=7'h38;
    reg [15:0] regaddr=0;
    reg [7:0] wr=0;
    reg [5:0] length=1;
    wire done,error,busy;
    wire [327:0] data;
    i2c_register_master #(.QUARTER(I2C_QUARTER)) bus(.clk(clk),.start(start),
        .address(address),.register_address(regaddr),.register_16bit(wide),
        .write_command(write_command),.write_data(wr),.read_length(length),
        .scl(scl),.sda(sda),.busy(busy),.done(done),.error(error),.read_data(data));
    localparam BOOT_RESET=0,BOOT_WAIT=1,FT_ID=2,FT_INIT=3,
        GT_RESET=4,GT_SELECT=5,GT_WAIT=6,GT_ID5D=7,GT_ID14=8,GT_CONFIG=9,
        POLL_WAIT=10,FT_FRAME=11,GT_FRAME=12,GT_CLEAR=13,RETRY=14,
        GT_SOFT_RESET=15,GT_SOFT_WAIT=16,GT_NORMAL=17,GT_NORMAL_WAIT=18,
        GT_INITIAL_CLEAR=19;
    reg [4:0] state=BOOT_RESET;
    reg [25:0] timer=0,stale=0;
    reg [1:0] failures=0;
    reg swap_gt=0;
    integer i;
    reg [4:0] mask;
    task read_register;
        input [6:0] addr;
        input [15:0] regnum;
        input is_wide;
        input [5:0] bytes;
        input [4:0] next_state;
        begin address<=addr; regaddr<=regnum; wide<=is_wide;
            length<=bytes; write_command<=0; start<=1; state<=next_state; end
    endtask
    task write_register;
        input [6:0] addr;
        input [15:0] regnum;
        input is_wide;
        input [7:0] value;
        input [4:0] next_state;
        begin address<=addr; regaddr<=regnum; wide<=is_wide; wr<=value;
            write_command<=1; start<=1; state<=next_state; end
    endtask
    task failed_frame;
        begin
            contacts<=0; frame_valid<=1; error_count<=error_count+1'b1;
            if(failures==2) begin online<=0; chip<=0; state<=RETRY; timer<=0; end
            else begin failures<=failures+1'b1; state<=POLL_WAIT; timer<=0; end
        end
    endtask
    always @(posedge clk) begin
        start<=0; frame_valid<=0;
        if(stale<CLOCKS_PER_MS*150) stale<=stale+1'b1;
        else if(contacts!=0) begin contacts<=0; frame_valid<=1; end
        case(state)
            BOOT_RESET: begin
                reset_n<=0; int_low<=0; online<=0; contacts<=0;
                if(timer==CLOCKS_PER_MS*20-1) begin reset_n<=1; timer<=0; state<=BOOT_WAIT; end
                else timer<=timer+1'b1;
            end
            BOOT_WAIT: if(timer==CLOCKS_PER_MS*100-1) begin
                timer<=0; read_register(7'h38,16'h00a8,0,1,FT_ID);
            end else timer<=timer+1'b1;
            FT_ID: if(done) begin
                if(!error && data[7:0]!=8'hff) begin
                    chip<=1; online<=1; failures<=0;
                    write_register(7'h38,16'h00a4,0,0,FT_INIT);
                end else begin reset_n<=0; int_low<=1; timer<=0; state<=GT_RESET; end
            end
            FT_INIT: if(done) begin
                if(error) failed_frame(); else begin timer<=0; state<=POLL_WAIT; end
            end
            GT_RESET: if(timer==CLOCKS_PER_MS*20-1) begin
                reset_n<=1; timer<=0; state<=GT_SELECT;
            end else timer<=timer+1'b1;
            // Hold INT LOW for >50 ms after RESET rises, then float it.
            // Reading the product ID alone does not prove the scanner started.
            GT_SELECT: if(timer==CLOCKS_PER_MS*60-1) begin
                int_low<=0; timer<=0; state<=GT_WAIT;
            end else timer<=timer+1'b1;
            GT_WAIT: if(timer==CLOCKS_PER_MS*60-1) begin
                timer<=0; read_register(7'h5d,16'h8140,1,3,GT_ID5D);
            end else timer<=timer+1'b1;
            GT_ID5D: if(done) begin
                if(!error && data[7:0]==8'h39) begin
                    chip<=2; failures<=0;
                    write_register(7'h5d,16'h8040,1,8'h02,GT_SOFT_RESET);
                end else read_register(7'h14,16'h8140,1,3,GT_ID14);
            end
            GT_ID14: if(done) begin
                if(!error && data[7:0]==8'h39) begin
                    chip<=3; failures<=0;
                    write_register(7'h14,16'h8040,1,8'h02,GT_SOFT_RESET);
                end else begin chip<=0; online<=0; state<=RETRY; timer<=0; end
            end
            // Match ALIENTEK's supplied GTxx driver: 8040=02, wait 10 ms,
            // then 8040=00 (coordinate mode). Do not overwrite panel config.
            GT_SOFT_RESET: if(done) begin
                if(error) begin error_count<=error_count+1'b1; state<=RETRY; timer<=0; end
                else begin timer<=0; state<=GT_SOFT_WAIT; end
            end
            GT_SOFT_WAIT: if(timer==CLOCKS_PER_MS*10-1) begin
                timer<=0; write_register(chip==2?7'h5d:7'h14,16'h8040,1,0,GT_NORMAL);
            end else timer<=timer+1'b1;
            GT_NORMAL: if(done) begin
                if(error) begin error_count<=error_count+1'b1; state<=RETRY; timer<=0; end
                else begin timer<=0; state<=GT_NORMAL_WAIT; end
            end
            GT_NORMAL_WAIT: if(timer==CLOCKS_PER_MS*100-1) begin
                timer<=0; read_register(chip==2?7'h5d:7'h14,16'h8048,1,4,GT_CONFIG);
            end else timer<=timer+1'b1;
            GT_CONFIG: if(done) begin
                // Some panel firmware reports portrait coordinates.
                if(error) begin error_count<=error_count+1'b1; state<=RETRY; timer<=0; end
                else begin
                    swap_gt<=data[15:0]==600 && data[31:16]==1024;
                    max_x<=data[11:0]; max_y<=data[27:16];
                    write_register(chip==2?7'h5d:7'h14,16'h814e,1,0,GT_INITIAL_CLEAR);
                end
            end
            GT_INITIAL_CLEAR: if(done) begin
                if(error) begin error_count<=error_count+1'b1; state<=RETRY; timer<=0; end
                else begin online<=1; timer<=0; state<=POLL_WAIT; end
            end
            POLL_WAIT: if(timer==CLOCKS_PER_MS*POLL_MS-1) begin
                timer<=0;
                if(chip==1) read_register(7'h38,16'h0002,0,31,FT_FRAME);
                else read_register(chip==2?7'h5d:7'h14,16'h814e,1,41,GT_FRAME);
            end else timer<=timer+1'b1;
            FT_FRAME: if(done) begin
                if(error) failed_frame();
                else begin
                    raw_status<=data[7:0]; raw_count<=data[3:0];
                    report_count<=report_count+1'b1;
                    if(data[3:0]>0 && data[3:0]<=5) begin
                        raw_x<={data[11:8],data[23:16]};
                        raw_y<={data[27:24],data[39:32]};
                    end
                    mask=0;
                    for(i=0;i<5;i=i+1) begin
                        point_x[i*12 +:12]<={data[(1+i*6)*8 +:4],data[(2+i*6)*8 +:8]};
                        point_y[i*12 +:12]<={data[(3+i*6)*8 +:4],data[(4+i*6)*8 +:8]};
                        if(i<data[3:0] && data[3:0]<=5 && data[(1+i*6)*8+6 +:2]!=1)
                            mask[i]=1;
                    end
                    contacts<=mask; frame_valid<=1; stale<=0; failures<=0;
                    state<=POLL_WAIT; timer<=0;
                end
            end
            GT_FRAME: if(done) begin
                if(!error) raw_status<=data[7:0];
                if(error) failed_frame();
                else if(data[7]) begin
                    raw_count<=data[3:0]; report_count<=report_count+1'b1;
                    if(data[3:0]>0 && data[3:0]<=5) begin
                        raw_x<=data[27:16]; raw_y<=data[43:32];
                    end
                    for(i=0;i<5;i=i+1) begin
                        point_x[i*12 +:12]<=swap_gt ? data[(4+i*8)*8 +:12]:data[(2+i*8)*8 +:12];
                        point_y[i*12 +:12]<=swap_gt ? data[(2+i*8)*8 +:12]:data[(4+i*8)*8 +:12];
                        contacts[i]<=i<data[3:0] && data[3:0]<=5;
                    end
                    frame_valid<=1; stale<=0; failures<=0;
                    write_register(chip==2?7'h5d:7'h14,16'h814e,1,0,GT_CLEAR);
                end else begin failures<=0; state<=POLL_WAIT; timer<=0; end
            end
            GT_CLEAR: if(done) begin
                if(error) failed_frame(); else begin state<=POLL_WAIT; timer<=0; end
            end
            RETRY: if(timer==CLOCKS_PER_MS*250-1) begin
                timer<=0; failures<=0; state<=BOOT_RESET;
            end else timer<=timer+1'b1;
            default: begin state<=RETRY; timer<=0; end
        endcase
    end
endmodule
