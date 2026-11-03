`timescale 1ns/1ps
module tb_rhythm_game;
    reg clk=0;always #5 clk=~clk;
    reg tick=1,enabled=1,start=0,stop=0;
    reg [15:0] keys=0;
    wire run,done,gate;
    wire [23:0] step;
    wire [15:0] cue,score;
    wire [3:0] target,next_note;
    wire [1:0] count;
    wire [5:0] combo,best,hits,misses,progress;
    wire [9:0] wrong;
    wire [2:0] feedback;
    rhythm_game #(.SAMPLE_RATE(1000),.BEAT_SAMPLES(500)) dut(clk,tick,enabled,start,stop,keys,
        run,done,gate,step,cue,target,next_note,count,score,combo,best,hits,misses,wrong,feedback,progress);
    integer expected[0:41];
    task restart;
        @(negedge clk);keys=0;tick=1;start=1;
        @(negedge clk);start=0;
        if(!run || done || score || hits || misses || wrong || count!=3) $fatal(1,"restart/countdown");
    endtask
    task tap(input [15:0] mask);
        @(negedge clk);keys=mask;
        @(negedge clk);keys=0;
        @(negedge clk);
    endtask
    initial begin
        expected[0]=0;expected[1]=0;expected[2]=7;expected[3]=7;expected[4]=9;expected[5]=9;expected[6]=7;
        expected[7]=5;expected[8]=5;expected[9]=4;expected[10]=4;expected[11]=2;expected[12]=2;expected[13]=0;
        expected[14]=7;expected[15]=7;expected[16]=5;expected[17]=5;expected[18]=4;expected[19]=4;expected[20]=2;
        for(integer i=21;i<28;i=i+1) expected[i]=expected[i-7];
        for(integer i=28;i<42;i=i+1) expected[i]=expected[i-28];
        restart();
        for(integer i=0;i<42;i=i+1) begin
            wait(dut.judge_index==i && dut.song_time==dut.judge_time);
            if(target!=expected[i] || cue!=(16'h1<<expected[i])) $fatal(1,"wrong melody/cue note %d",i);
            tap(16'h1<<expected[i]);
            if(score!=100*(i+1) || hits!=i+1 || combo!=i+1 || feedback!=1 || !gate)
                $fatal(1,"perfect note scoring/playback %d %d",i,score);
        end
        wait(done);#1;
        if(run || gate || score!=4200 || hits!=42 || best!=42 || misses || progress!=42) $fatal(1,"perfect result");
        restart();wait(done);#1;
        if(score || hits || misses!=42 || best || gate) $fatal(1,"all-miss result");
        restart();wait(dut.song_time==2900);tap(16'h1);
        if(score!=50 || feedback!=2) $fatal(1,"early GOOD window");
        @(negedge clk);keys=1;
        wait(dut.song_time==3653);@(negedge clk);
        if(score!=50 || hits!=1 || misses!=1) $fatal(1,"held repeated C must miss");
        restart();wait(dut.song_time==3000);tap(16'h3);
        if(score || wrong!=1 || combo) $fatal(1,"chord/mashing must not score");
        tap(16'h1);tap(16'h1);
        if(score!=100 || hits!=1 || combo!=1) $fatal(1,"duplicate tap scored twice");
        restart();wait(dut.song_time==3000);
        @(negedge clk);tick=0;keys=1;
        @(negedge clk);keys=0;
        if(score!=100) $fatal(1,"touch edge between sample ticks lost");
        stop=1;@(negedge clk);stop=0;
        if(run || gate) $fatal(1,"STOP must silence backing");
        restart();wait(gate);@(negedge clk);enabled=0;
        @(negedge clk);if(run || gate || cue) $fatal(1,"exit must silence/disable scoring");
        enabled=1;restart();wait(dut.song_time==3100);tap(16'h1);
        if(score!=50 || feedback!=2) $fatal(1,"late GOOD window");
        restart();wait(dut.song_time==3151);tap(16'h1);
        if(score || hits || misses!=1) $fatal(1,"late tap must not score");
        $display("PASS rhythm game: full 42-note melody/4200 perfect score, all misses, early/late GOOD and late MISS, held keys, chord anti-mash, duplicate taps, inter-tick edges, retry, stop and exit");
        $finish;
    end
    initial begin #2000000;$fatal(1,"game timeout");end
endmodule
