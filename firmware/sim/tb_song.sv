`timescale 1ns/1ps
module tb_song;
    reg clk=0; always #5 clk=~clk;
    reg [2:0] count=0; always @(posedge clk) count<=count+1'b1;
    wire tick=(count==0);
    reg enable=0;
    wire gate;
    wire [23:0] step;
    song_player #(.TIME_SHIFT(10)) dut(clk,tick,enable,gate,step);
    integer samples=0,last_load=0,expected_period=0,events=0,loops=0;
    reg had_event=0;
    always @(posedge clk) begin
        if(tick) samples=samples+1;
        if(enable && tick && (dut.state==2 || dut.state==4)) begin
            if(had_event && samples-last_load!=expected_period)
                $fatal(1,"event length got %0d expected %0d",samples-last_load,expected_period);
            if(events>0 && dut.address==0) loops=loops+1;
            expected_period=dut.duration; last_load=samples; had_event=1; events=events+1;
            #1; if(step!=dut.rom_step) $fatal(1,"ROM pitch mismatch");
        end
    end
    initial begin
        repeat(10) @(negedge clk); enable=1;
        wait(loops==2);
        @(negedge clk); enable=0; had_event=0;
        repeat(10) @(negedge clk);
        if(gate || step!=0 || dut.address!=0) $fatal(1,"song disable");
        enable=1; wait(gate); @(negedge clk);
        if(dut.address!=1) $fatal(1,"restart pickup");
        $display("PASS full-score ROM, two loops, exact event durations, disable/restart; events=%0d",events);
        $finish;
    end
    initial begin #100000000; $fatal(1,"timeout"); end
endmodule
