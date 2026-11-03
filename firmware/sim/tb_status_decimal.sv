`timescale 1ns/1ps
module tb_status_decimal;
    reg clk=0; always #5 clk=~clk;
    reg [15:0] value=0;
    wire [31:0] text;
    status_decimal dut(.clk(clk),.value(value),.text(text));
    reg [31:0] expected;
    initial begin
        for(integer n=0;n<65536;n=n+1) begin
            @(negedge clk); value=n;
            repeat(35) @(negedge clk);
            expected={8'(48+(n/1000)%10),8'(48+(n/100)%10),8'(48+(n/10)%10),8'(48+n%10)};
            if(text!==expected) $fatal(1,"decimal %0d got %h expected %h",n,text,expected);
        end
        $display("PASS pipelined status decimal: all 65536 input values, exact four-digit ASCII including wrap above 9999, bounded refresh latency");
        $finish;
    end
    initial begin #30000000; $fatal(1,"decimal timeout"); end
endmodule
