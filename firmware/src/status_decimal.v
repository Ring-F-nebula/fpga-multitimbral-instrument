// Non-pixel-path decimal diagnostics. Double-dabble consumes one bit per
// clock, replacing a deep combinational 16-bit divide/modulo chain. The
// resulting ASCII settles in 17 clocks, well inside vertical blanking.
module status_decimal(input clk,input [15:0] value,output reg [31:0] text="0000");
    reg [15:0] binary=0,bcd=0;
    reg [4:0] count=0;
    reg [15:0] corrected;
    wire [15:0] shifted={corrected[14:0],binary[15]};
    integer i;
    always @* begin
        corrected=bcd;
        for(i=0;i<4;i=i+1)
            if(bcd[i*4 +: 4]>=5) corrected[i*4 +: 4]=bcd[i*4 +: 4]+4'd3;
    end
    always @(posedge clk) begin
        if(count==0) begin binary<=value; bcd<=0; count<=16; end
        else begin
            binary<={binary[14:0],1'b0}; bcd<=shifted; count<=count-1'b1;
            if(count==1) text<={4'h3,shifted[15:12],4'h3,shifted[11:8],4'h3,shifted[7:4],4'h3,shifted[3:0]};
        end
    end
endmodule
