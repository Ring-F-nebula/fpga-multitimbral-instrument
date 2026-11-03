// Extracted unchanged from the frozen reference src/uart_link.v.
// Compile ONLY if the main project does not already define compatible uart_tx.
module uart_tx(input clk,input start,input [7:0] data,input [11:0] bit_clocks,
    output reg tx=1,output reg busy=0);
    reg [9:0] shift=10'h3ff;
    reg [3:0] bit_index=0;
    reg [11:0] count=0,period=228;
    always @(posedge clk) begin
        if(!busy) begin
            tx<=1;
            if(start) begin
                shift<={1'b1,data,1'b0}; tx<=0; busy<=1;
                bit_index<=0; period<=bit_clocks; count<=bit_clocks-1'b1;
            end
        end else if(count!=0) count<=count-1'b1;
        else if(bit_index==9) begin busy<=0; tx<=1; end
        else begin
            shift<={1'b1,shift[9:1]}; tx<=shift[1];
            bit_index<=bit_index+1'b1; count<=period-1'b1;
        end
    end
endmodule
