`timescale 1ns/1ps
module tb_frequency_bank4;
reg clk=0;always #5 clk=~clk;reg clear=1,tick=0,enable=1,expression=1;reg [31:0] keys=0;
reg [255:0] notes;reg [3:0] time_sel=0;reg [16:0] coefficient=65536;reg [4:0] target_voice=31;
wire [767:0] result;wire done,overrun;
frequency_bank4 dut(.clk(clk),.clear(clear),.frame_tick(tick),.keys(keys),.notes(notes),.glide_enable(enable),.glide_time(time_sel),
 .coefficient(coefficient),.target_voice(target_voice),.expression_enable(expression),.phase_steps(result),.done(done),.overrun(overrun));
// Independent reference: the original 32 separate glide modules and smoothers.
reg [31:0] previous=0;reg [23:0] last_step=96315;wire [31:0] new_keys=keys&~previous;
wire legato=new_keys!=0&&((new_keys&(new_keys-32'd1))==0)&&(|(keys&previous));
wire [23:0] base[0:31],glided[0:31];wire [40:0] multiplied[0:31];reg [23:0] expected[0:31];
integer n,newest;always @*begin newest=0;for(n=0;n<32;n++)if(new_keys[n])newest=n;end
always @(posedge clk)if(clear)begin previous<=0;last_step<=96315;end else if(tick)begin previous<=keys;if(new_keys!=0)last_step<=base[newest];end
genvar v;generate for(v=0;v<32;v++)begin: reference_voice
 reg [16:0] smooth=65536;wire [16:0] desired=expression&&target_voice==v?coefficient:17'd65536;
 midi_step_rom rom(.note(notes[v*8+:8]),.step(base[v]));
 note_glide original(.clk(clk),.tick(tick),.clear(clear),.enable(enable),.attack(keys[v]&&!previous[v]),.legato(legato),
  .time_sel(time_sel),.base(base[v]),.from_step(last_step),.step(glided[v]));
 assign multiplied[v]=glided[v]*smooth+41'd32768;
 always @(posedge clk)if(clear)smooth<=65536;else if(tick)begin
  if(desired>smooth)smooth<=desired-smooth>32?smooth+17'd32:desired;
  else if(desired<smooth)smooth<=smooth-desired>32?smooth-17'd32:desired;
 end
end endgenerate
integer f,i,c,max_cycles=0;
task frame;
begin
 repeat(40)@(negedge clk);for(i=0;i<32;i++)expected[i]=multiplied[i][39:16];
 @(negedge clk);tick=1;@(negedge clk);tick=0;c=1;
 while(!done&&c<100)begin @(negedge clk);c++;end
 if(!done||overrun||c>64)$fatal(1,"bank deadline %0d",c);if(c>max_cycles)max_cycles=c;
 for(i=0;i<32;i++)if(result[i*24+:24]!==expected[i])$fatal(1,"frame=%0d voice=%0d got=%0d expected=%0d",f,i,result[i*24+:24],expected[i]);
 repeat(534-c)@(negedge clk);
end endtask
initial begin
 for(i=0;i<32;i++)notes[i*8+:8]=60+i;repeat(40)@(negedge clk);clear=0;
 for(f=0;f<1000;f++)begin
  case(f)
   2:keys=1;10:keys=32'h80000001;300:begin keys=32'h80000000;coefficient=73500;end
   400:notes[31*8+:8]=69;500:time_sel=1;600:keys=32'hffffffff;
   620:keys=0;640:begin coefficient=60000;target_voice=2;end
   650:keys=4;660:keys=32'h50000004;700:expression=0;750:expression=1;
   800:enable=0;820:enable=1;840:keys=32'h01000004;
   850:begin clear=1;repeat(3)@(negedge clk);clear=0;end
   900:time_sel=9;910:keys=32'h81000004;
  endcase
  frame();
 end
 $display("PASS frequency_bank4: 32000 voice-frame results match original independent glide/smoothing units; cache/mapping/chords/legato/bend/clear; max_cycles=%0d",max_cycles);$finish;
end
initial begin #12000000;$fatal(1,"bank timeout");end
endmodule
