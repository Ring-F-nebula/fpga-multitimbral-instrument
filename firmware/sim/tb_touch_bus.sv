`timescale 1ns/1ps
module tb_touch_bus;
    reg clk=0; always #5 clk=~clk;
    reg enabled=1,ready=1;
    reg [2:0] fingers=0;
    reg [59:0] xs=0,ys=0;
    wire [2:0] online,valid;
    wire [1:0] chip[0:2];
    wire [4:0] contacts[0:2];
    wire [59:0] xx[0:2],yy[0:2];
    wire [15:0] errors[0:2];
    wire [2:0] reset_n;
    integer clears[0:2];
    wire [7:0] raw_status[0:2];
    wire [3:0] raw_count[0:2];
    wire [15:0] report_count[0:2];
    wire [11:0] raw_x[0:2],raw_y[0:2],max_x[0:2],max_y[0:2];
    genvar g;
    generate for(g=0;g<3;g=g+1) begin: channels
        tri1 scl,sda,irq;
        capacitive_touch #(.CLOCKS_PER_MS(256),.I2C_QUARTER(2)) dut(
            .clk(clk),.scl(scl),.sda(sda),.interrupt(irq),.reset_n(reset_n[g]),
            .online(online[g]),.frame_valid(valid[g]),.chip(chip[g]),.contacts(contacts[g]),
            .point_x(xx[g]),.point_y(yy[g]),.error_count(errors[g]),
            .raw_status(raw_status[g]),.raw_count(raw_count[g]),.report_count(report_count[g]),
            .raw_x(raw_x[g]),.raw_y(raw_y[g]),.max_x(max_x[g]),.max_y(max_y[g]));
        touch_slave_model #(.KIND(g==0?1:2),.ADDRESS(g==0?7'h38:g==1?7'h5d:7'h14)) slave(
            .reset_n(reset_n[g]),.enabled(enabled),.fingers(fingers),.ready(ready),
            .xs(xs),.ys(ys),.scl(scl),.sda(sda),.clears(clears[g]));
    end endgenerate
    // Enforce the datasheet's >50ms INT-low settling interval after reset.
    generate for(g=1;g<3;g=g+1) begin: reset_timing
        initial begin
            wait(chip[g]!=0);
        end
        always @(posedge reset_n[g]) begin
            if(channels[g].irq===1'b0) begin
                repeat(256*51) begin
                    @(negedge clk);
                    if(channels[g].irq!==1'b0) $fatal(1,"GT INT released before 50ms");
                end
            end
        end
    end endgenerate
    task settle(input integer clocks); repeat(clocks) @(negedge clk); endtask
    initial begin
        settle(110000);
        if(online!==3'b111 || chip[0]!=1 || chip[1]!=2 || chip[2]!=3)
            $fatal(1,"touch discovery online=%b chips=%d %d %d",online,chip[0],chip[1],chip[2]);
        for(integer i=0;i<5;i=i+1) begin xs[i*12+:12]=100+i*200;ys[i*12+:12]=380+i*40; end
        fingers=5; settle(20000);
        for(integer j=0;j<3;j=j+1) begin
            if(contacts[j]!==5'b11111 || xx[j]!==xs || yy[j]!==ys)
                $fatal(1,"five-point decode channel %d contacts=%b x=%h expected=%h y=%h expected=%h",j,contacts[j],xx[j],xs,yy[j],ys);
            if(raw_count[j]!=5 || report_count[j]==0 || raw_x[j]!=100 || raw_y[j]!=380)
                $fatal(1,"raw touch diagnostics channel %d",j);
            if(j>0 && (max_x[j]!=1024 || max_y[j]!=600)) $fatal(1,"GT config dimensions");
        end
        if(clears[1]==0 || clears[2]==0) $fatal(1,"GT ready was not acknowledged");
        ready=0; settle(50000);
        if(contacts[1]!=0 || contacts[2]!=0 || online!=7) $fatal(1,"GT stale release");
        ready=1;fingers=0;settle(20000);
        if(contacts[0] || contacts[1] || contacts[2]) $fatal(1,"touch release");
        fingers=2;settle(20000);
        enabled=0;settle(60000);
        if(contacts[0] || contacts[1] || contacts[2] || online!=0) $fatal(1,"unplug release / offline");
        enabled=1;settle(240000);
        if(online!=7 || contacts[0]!=3 || contacts[1]!=3 || contacts[2]!=3) $fatal(1,"reconnect recovery");
        $display("PASS touch I2C V2: FT5446, GT911 5D/14, INT >50ms, software reset + coordinate mode, raw diagnostics, five points, clear/stale/NACK/reconnect");
        $finish;
    end
    initial begin #10000000; $fatal(1,"touch bus timeout"); end
endmodule
