`timescale 1ns/1ps
module tb_note_step_cache;
reg clk=0;always #5 clk=~clk;reg [255:0] notes=0;wire [767:0] steps;
note_step_cache dut(.clk(clk),.notes(notes),.steps(steps));
function [23:0] expected(input integer note);real frequency,increment;
begin frequency=440.0*(2.0**((note-69)/12.0));increment=frequency*16777216.0/(26250000.0/576.0);expected=$rtoi(increment+0.5);end endfunction
integer batch,i;
initial begin
 for(batch=0;batch<4;batch++)begin
  for(i=0;i<32;i++)notes[i*8+:8]=batch*32+i;
  repeat(36)@(negedge clk);
  for(i=0;i<32;i++)if(steps[i*24+:24]!==expected(batch*32+i))$fatal(1,"MIDI conversion %0d got=%0d expected=%0d",batch*32+i,steps[i*24+:24],expected(batch*32+i));
 end
 notes[31*8+:8]=69;repeat(36)@(negedge clk);if(steps[31*24+:24]!==expected(69))$fatal(1,"live upper mapping refresh");
 notes[0+:8]=255;repeat(36)@(negedge clk);if(steps[0+:24]!==0)$fatal(1,"invalid MIDI");
 $display("PASS note_step_cache: all 128 MIDI notes against frequency formula, 32-slot refresh bound and live upper mapping");$finish;
end
initial begin #100000;$fatal(1,"cache timeout");end
endmodule
