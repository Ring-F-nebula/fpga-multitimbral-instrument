`timescale 1ns/1ps
module tb_wax_pressure;
reg clk=0;always #5 clk=~clk;reg rst=0,tick=1,frame=0,recal=0,enabled=1,continuous=1;
reg [383:0] samples=0;reg [7:0] model=1;wire [15:0] keys,cal;wire [143:0] gains;
wire [383:0] raw,base,threshold;wire online,ready,calibrating,noisy;wire [23:0] peak,delta;
wax_pressure #(.STALE_CYCLES(10000)) dut(clk,rst,tick,frame,recal,enabled,continuous,samples,model,16'd20,16'd10,24'd1000,keys,gains,raw,base,cal,online,ready,calibrating,noisy,peak,delta,threshold);
task sweep;begin @(negedge clk);frame=1;@(negedge clk);frame=0;repeat(500)@(negedge clk);end endtask
task idle_samples;integer n;begin for(n=0;n<16;n++)samples[n*24+:24]=100+n;end endtask
integer i;reg [8:0] release_gain;reg [15:0] expect_keys;
initial begin
 repeat(4)@(negedge clk);rst=1;idle_samples();repeat(10)sweep();
 if(!ready||keys||cal!=16'hffff)$fatal(1,"idle startup calibration");
 // Individual cell tests verify all 16 spatial identities, including cell15.
 for(i=0;i<16;i++)begin
  idle_samples();samples[i*24+:24]=600+i;sweep();if(keys)$fatal(1,"single-frame spike");
  sweep();expect_keys=16'b1<<i;if(keys!==expect_keys||gains[i*9+:9]<120||gains[i*9+:9]>130)$fatal(1,"cell/gain %d %h gain=%d",i,keys,gains[i*9+:9]);
  release_gain=gains[i*9+:9];idle_samples();sweep();if(keys||gains[i*9+:9]!=release_gain)$fatal(1,"release gain not retained");
 end
 idle_samples();samples[23:0]=200;samples[15*24+:24]=1100+15;sweep();sweep();
 if(keys!==16'h8001||gains[8:0]<32||gains[15*9+:9]!=256)$fatal(1,"independent light/heavy chord");
 samples[23:0]=900;sweep();if(gains[8:0]<190||gains[15*9+:9]!=256)$fatal(1,"aftertouch disturbed other voice");
 samples[23:0]=100;sweep();if(keys!==16'h8000)$fatal(1,"independent release");
 repeat(10500)@(negedge clk);if(keys||ready||online)$fatal(1,"disconnected source stuck note");
 idle_samples();repeat(10)sweep();if(!ready||keys)$fatal(1,"recovery must recalibrate");
 samples[23:0]=600;sweep();sweep();if(keys!=1)$fatal(1,"recovery press");
 @(negedge clk);recal=1;@(negedge clk);recal=0;if(keys||ready)$fatal(1,"recal did not mute");
 idle_samples();repeat(10)sweep();
 model=2;sweep();if(keys||ready)$fatal(1,"changed sensor range did not invalidate calibration");
 repeat(9)sweep();if(!ready)$fatal(1,"changed model calibration");
 enabled=0;repeat(3)@(negedge clk);if(keys||ready)$fatal(1,"disabled source");
 $display("PASS wax_pressure: all 16 cell identities, stable idle, spike rejection, calibrated hysteresis, per-key velocity/aftertouch, retained release gain, watchdog, reconnect/recalibration/model/disable guards");$finish;
end
initial begin #5000000;$fatal(1,"pressure timeout");end
endmodule
