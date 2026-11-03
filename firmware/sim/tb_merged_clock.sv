`timescale 1ns/1ps
module tb_merged_clock;
 reg clkin=0;always #10 clkin=~clkin;
 wire lcd,locked;
 reg audio=0;
 merged_clock dut(.clkin(clkin),.clkout(lcd),.locked(locked));
 always @(posedge lcd) audio<=~audio;
 realtime t0,t1;
 initial begin
  wait(locked);repeat(10)@(posedge lcd);
  t0=$realtime;repeat(1000)@(posedge lcd);t1=$realtime;
  if(t1-t0<19040 || t1-t0>19055)$fatal(1,"LCD PLL period: %f",(t1-t0)/1000);
  $display("PASS vendor PLL LCD clock period %f ns",(t1-t0)/1000);
  t0=$realtime;@(posedge audio);t0=$realtime;repeat(1000)@(posedge audio);t1=$realtime;
  if(t1-t0<38080 || t1-t0>38110)$fatal(1,"audio divider period: %f",(t1-t0)/1000);
  $display("PASS vendor PLL audio clock period %f ns",(t1-t0)/1000);
  $finish;
 end
 initial begin #1000000;$fatal(1,"PLL lock timeout");end
endmodule
