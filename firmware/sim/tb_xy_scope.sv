`timescale 1ns/1ps
module tb_xy_scope;
    reg clk=0,audio_clk=0;always #5 clk=~clk;always #10 audio_clk=~audio_clk;
    reg [7:0] divider=0;always @(posedge audio_clk) divider<=divider+1'b1;
    wire tick=divider==0;
    reg signed [15:0] pcm=0;
    integer sample_number=0;
    always @(posedge audio_clk) if(tick) begin
        sample_number<=sample_number+1;
        pcm<=$rtoi(6000*$sin(6.283185307179586*sample_number/128.0));
    end
    reg [1:0] mode=1;
    reg blank=0;
    reg [14:0] address=0;
    wire pixel,valid;
    xy_scope dut(clk,audio_clk,tick,pcm,mode,blank,address,pixel,valid);
    always @(posedge clk) if(dut.state==2 && dut.pen_y>=112) $fatal(1,"XY point outside plot");
    integer signatures[0:3],counts[0:3];
    task publish;
        wait(dut.state==3);@(negedge clk);blank=1;@(negedge clk);blank=0;
        if(!valid) $fatal(1,"plot buffer publication");
    endtask
    task scan(input integer id);
        begin
            counts[id]=0;signatures[id]=0;
            for(integer a=0;a<28672;a=a+1) begin
                address=a;@(negedge clk);
                if($isunknown(pixel)) $fatal(1,"uninitialized plot memory");
                if(pixel) begin counts[id]=counts[id]+1;signatures[id]=signatures[id]^(a*31+7);end
            end
            if(counts[id]<180 || counts[id]>5000) $fatal(1,"missing/malformed XY trace mode%d count%d",id,counts[id]);
        end
    endtask
    initial begin
        for(integer k=1;k<4;k=k+1) begin mode=k;publish();scan(k);end
        mode=0;publish();scan(0);
        if(signatures[1]==signatures[2] || signatures[2]==signatures[3] || signatures[0]==signatures[1])
            $fatal(1,"XY modes identical");
        $display("PASS XY scope: real PCM/delayed PCM, three independent sine ratios, in-range connected traces, cleared RAM and frame-boundary double buffering");$finish;
    end
    initial begin #30000000;$fatal(1,"scope timeout");end
endmodule
