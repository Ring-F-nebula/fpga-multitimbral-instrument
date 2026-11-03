// Open-drain I2C register transactions with repeated START, ACK checking,
// clock-stretch timeout and nine-clock recovery when SDA is stuck low.
module i2c_register_master #(parameter integer QUARTER=66, STRETCH_LIMIT=1023)(
    input wire clk,start,
    input wire [6:0] address,
    input wire [15:0] register_address,
    input wire register_16bit,write_command,
    input wire [7:0] write_data,
    input wire [5:0] read_length,
    inout wire scl,sda,
    output reg busy=0,done=0,error=0,
    output reg [327:0] read_data=0
);
    reg scl_low=0,sda_low=0;
    assign scl=scl_low ? 1'b0:1'bz;
    assign sda=sda_low ? 1'b0:1'bz;
    reg [1:0] scl_sync=3,sda_sync=3;
    always @(posedge clk) begin scl_sync<={scl_sync[0],scl}; sda_sync<={sda_sync[0],sda}; end
    reg [15:0] divider=0;
    wire quarter_tick=(divider==QUARTER-1);
    always @(posedge clk) if(!busy || quarter_tick) divider<=0; else divider<=divider+1'b1;
    localparam IDLE=0,START=1,START_HOLD=2,SETUP=3,RAISE=4,
        SAMPLE=5,FALL=6,RESTART_LOW=7,RESTART_HIGH=8,RESTART_WAIT=9,
        STOP_LOW=10,STOP_HIGH=11,STOP_WAIT=12,STOP_RELEASE=13,
        RECOVER_LOW=14,RECOVER_HIGH=15,RECOVER_WAIT=16,ABORT=17;
    reg [4:0] state=IDLE;
    reg [2:0] stage=0;
    reg [3:0] bit_number=0,recovery=0;
    reg [7:0] tx_byte=0,rx_byte=0,wr=0;
    reg reading=0,wide=0,is_write=0;
    reg [6:0] device=0;
    reg [15:0] regaddr=0,stretch=0;
    reg [5:0] length=0,read_index=0;
    task send_byte;
        input [7:0] value;
        input [2:0] next_stage;
        begin tx_byte<=value; stage<=next_stage; reading<=0;
            bit_number<=0; state<=SETUP; end
    endtask
    always @(posedge clk) begin
        done<=0;
        if(!busy) begin
            scl_low<=0; sda_low<=0;
            if(start) begin
                device<=address; regaddr<=register_address; wide<=register_16bit;
                is_write<=write_command; wr<=write_data; length<=read_length;
                read_index<=0; read_data<=0; error<=0; stretch<=0;
                busy<=1; state<=START;
                if(!write_command && (read_length==0 || read_length>41)) state<=ABORT;
            end
        end else if(quarter_tick) begin
            case(state)
                START: begin
                    if(!scl_sync[1]) begin
                        if(stretch==STRETCH_LIMIT) state<=ABORT;
                        else stretch<=stretch+1'b1;
                    end else if(!sda_sync[1]) begin
                        error<=1; recovery<=0; state<=RECOVER_LOW;
                    end else begin sda_low<=1; state<=START_HOLD; end
                end
                START_HOLD: send_byte({device,1'b0},0);
                SETUP: begin
                    scl_low<=1;
                    if(bit_number==8) sda_low<=reading && (read_index+1<length);
                    else sda_low<=!reading && !tx_byte[7-bit_number];
                    state<=RAISE;
                end
                RAISE: begin scl_low<=0; stretch<=0; state<=SAMPLE; end
                SAMPLE: begin
                    if(!scl_sync[1]) begin
                        if(stretch==STRETCH_LIMIT) state<=ABORT;
                        else stretch<=stretch+1'b1;
                    end else begin
                        if(reading && bit_number<8) rx_byte<={rx_byte[6:0],sda_sync[1]};
                        if(!reading && bit_number==8 && sda_sync[1]) error<=1;
                        state<=FALL;
                    end
                end
                FALL: begin
                    scl_low<=1;
                    if(bit_number<8) begin bit_number<=bit_number+1'b1; state<=SETUP; end
                    else if(error) state<=STOP_LOW;
                    else case(stage)
                        0: if(wide) send_byte(regaddr[15:8],1); else send_byte(regaddr[7:0],2);
                        1: send_byte(regaddr[7:0],2);
                        2: if(is_write) send_byte(wr,3); else state<=RESTART_LOW;
                        3: state<=STOP_LOW;
                        4: begin reading<=1; rx_byte<=0; bit_number<=0; stage<=5; state<=SETUP; end
                        5: begin
                            read_data[read_index*8 +: 8]<=rx_byte;
                            if(read_index+1==length) state<=STOP_LOW;
                            else begin read_index<=read_index+1'b1; rx_byte<=0; bit_number<=0; state<=SETUP; end
                        end
                        default: state<=ABORT;
                    endcase
                end
                RESTART_LOW: begin scl_low<=1; sda_low<=0; state<=RESTART_HIGH; end
                RESTART_HIGH: begin scl_low<=0; stretch<=0; state<=RESTART_WAIT; end
                RESTART_WAIT: begin
                    if(scl_sync[1]) begin sda_low<=1; state<=START_HOLD; stage<=4; end
                    else if(stretch==STRETCH_LIMIT) state<=ABORT;
                    else stretch<=stretch+1'b1;
                end
                STOP_LOW: begin scl_low<=1; sda_low<=1; state<=STOP_HIGH; end
                STOP_HIGH: begin scl_low<=0; stretch<=0; state<=STOP_WAIT; end
                STOP_WAIT: begin
                    if(scl_sync[1]) state<=STOP_RELEASE;
                    else if(stretch==STRETCH_LIMIT) state<=ABORT;
                    else stretch<=stretch+1'b1;
                end
                STOP_RELEASE: begin sda_low<=0; busy<=0; done<=1; state<=IDLE; end
                RECOVER_LOW: begin scl_low<=1; sda_low<=0; state<=RECOVER_HIGH; end
                RECOVER_HIGH: begin scl_low<=0; stretch<=0; state<=RECOVER_WAIT; end
                RECOVER_WAIT: begin
                    if(scl_sync[1]) begin
                        if(recovery==8) state<=STOP_LOW;
                        else begin recovery<=recovery+1'b1; state<=RECOVER_LOW; end
                    end else if(stretch==STRETCH_LIMIT) state<=ABORT;
                    else stretch<=stretch+1'b1;
                end
                default: begin scl_low<=0; sda_low<=0; busy<=0; error<=1; done<=1; state<=IDLE; end
            endcase
            // START_HOLD is also used after a repeated START.
            if(state==START_HOLD && stage==4) send_byte({device,1'b1},4);
        end
        if(!busy && start) stage<=0;
    end
endmodule
