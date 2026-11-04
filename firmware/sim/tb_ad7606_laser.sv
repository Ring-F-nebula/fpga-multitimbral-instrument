`timescale 1ns/1ps
module tb_ad7606_laser;
 reg clk=0;always #19.047619 clk=~clk;
 reg reset_n=0,toggle=0,online=1;reg [127:0] samples={8{16'd18000}};
 wire [6:0] notes,armed;wire [15:0] keys;wire valid;
 ad7606_laser_keys dut(clk,reset_n,samples,toggle,online,notes,armed,keys,valid);
 task frame;begin @(negedge clk);toggle=~toggle;wait(valid);repeat(20)@(negedge clk);end endtask
 initial begin
  #100;reset_n=1;repeat(12)frame();if(notes || armed)$fatal(1,"dark boot sounded");
  samples={8{16'd1000}};repeat(10)frame();if(armed!=127 || notes)$fatal(1,"bright arming");
  samples[15:0]=18000;frame();if(notes)$fatal(1,"single glitch triggered");
  samples[15:0]=1000;frame();samples[15:0]=18000;frame();frame();if(keys!=1)$fatal(1,"C trigger");
  samples[15:0]=9500;repeat(4)frame();if(keys!=1)$fatal(1,"hysteresis hold");
  samples[15:0]=1000;frame();if(keys!=1)$fatal(1,"early release");frame();if(keys)$fatal(1,"note release");
  samples={8{16'd18000}};repeat(2)frame();if(keys!=16'h0ab5)$fatal(1,"C major mapping/chord %h",keys);
  samples[31:16]=16'hffff;frame();if(notes[1] || armed[1])$fatal(1,"signed negative input accepted");
  online=0;repeat(8)@(negedge clk);if(keys || armed)$fatal(1,"offline did not release");
  online=1;repeat(12)frame();if(keys)$fatal(1,"dark reconnect sounded");
  samples={8{16'd1000}};repeat(10)frame();samples={8{16'd18000}};repeat(2)frame();if(!keys)$fatal(1,"rearm failed");
  repeat(52510)@(negedge clk);if(keys || armed)$fatal(1,"stale frame did not release");
  $display("PASS laser thresholds: silent dark boot, stable light arming, two-frame debounce, hysteresis, seven-note chord, signed input, offline/stale release and rearm");$finish;
 end
 initial begin #10000000;$fatal(1,"laser timeout");end
endmodule
