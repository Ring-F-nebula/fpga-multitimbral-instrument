`timescale 1ns/1ps
module tb_i2c_faults;
    reg clk=0;always #5 clk=~clk;
    tri1 scl,sda;
    reg hold_clock=0,hold_data=0,start=0;
    reg [6:0] address=7'h38;
    assign scl=hold_clock?1'b0:1'bz;
    assign sda=hold_data?1'b0:1'bz;
    wire busy,done,error;
    wire [327:0] result;
    i2c_register_master #(.QUARTER(3),.STRETCH_LIMIT(20)) dut(clk,start,address,16'ha8,1'b0,1'b0,8'd0,6'd1,scl,sda,busy,done,error,result);
    integer clears;
    touch_slave_model slave(1'b1,1'b1,3'd0,1'b1,60'd0,60'd0,scl,sda,clears);
    task launch;
        @(negedge clk);start=1;@(negedge clk);start=0;
    endtask
    task wait_done;
        integer n;
        begin
            n=0;while(!done && n<10000) begin @(negedge clk);n=n+1;end
            if(!done || busy) $fatal(1,"I2C transaction did not finish");
        end
    endtask
    integer rises=0;
    always @(posedge scl) if(hold_data) rises=rises+1;
    initial begin
        launch();@(negedge scl);hold_clock=1;repeat(24) @(negedge clk);hold_clock=0;
        wait_done();if(error || result[7:0]!=8'h11) $fatal(1,"clock stretching / read");
        address=7'h17;launch();wait_done();if(!error) $fatal(1,"NACK ignored");
        hold_data=1;launch();wait_done();
        if(!error || rises<9 || rises>10) $fatal(1,"SDA recovery clocks=%d",rises);
        hold_data=0;repeat(4) @(negedge clk);
        hold_clock=1;launch();wait_done();if(!error) $fatal(1,"SCL timeout");
        hold_clock=0;repeat(5) @(negedge clk);
        if(scl!==1 || sda!==1) $fatal(1,"bus not released on timeout");
        address=7'h38;launch();wait_done();if(error || result[7:0]!=8'h11) $fatal(1,"post-fault retry");
        $display("PASS I2C faults: finite clock stretch, NACK, nine-clock SDA recovery, held SCL timeout, open-drain release and retry");$finish;
    end
endmodule
