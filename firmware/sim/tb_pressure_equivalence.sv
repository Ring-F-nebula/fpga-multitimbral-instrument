`timescale 1ns/1ps
module tb_pressure_equivalence;
 reg clk=0;always #5 clk=~clk;
 reg reset_n=0,tick=1,frame_valid=0,recalibrate=0,enabled=1,continuous=1;
 reg [383:0] samples=0;reg [7:0] model=1;
 reg [15:0] min_on=20,min_off=10;reg [23:0] full_scale=1000;
 wire [15:0] keys[0:1],cal[0:1];wire [143:0] gains[0:1];
 wire [383:0] raw[0:1],base[0:1],threshold[0:1];
 wire online[0:1],ready[0:1],calibrating[0:1],noisy[0:1];
 wire [23:0] peak[0:1],delta[0:1];
 wax_pressure #(.STALE_CYCLES(20000)) dut(clk,reset_n,tick,frame_valid,recalibrate,enabled,continuous,samples,model,min_on,min_off,full_scale,keys[0],gains[0],raw[0],base[0],cal[0],online[0],ready[0],calibrating[0],noisy[0],peak[0],delta[0],threshold[0]);
 wax_pressure_reference #(.STALE_CYCLES(20000)) golden(clk,reset_n,tick,frame_valid,recalibrate,enabled,continuous,samples,model,min_on,min_off,full_scale,keys[1],gains[1],raw[1],base[1],cal[1],online[1],ready[1],calibrating[1],noisy[1],peak[1],delta[1],threshold[1]);
 integer checks=0,n,j,k;reg [31:0] rng=32'h184532ab;
 function [31:0] next_random(input [31:0] v);reg [31:0] t;begin t=v^(v<<13);t=t^(t>>17);next_random=t^(t<<5);end endfunction
 task check;integer p;begin
 if({keys[0],gains[0],raw[0],base[0],cal[0],online[0],ready[0],calibrating[0],noisy[0],peak[0],delta[0],threshold[0]} !== {keys[1],gains[1],raw[1],base[1],cal[1],online[1],ready[1],calibrating[1],noisy[1],peak[1],delta[1],threshold[1]})
 $fatal(1,"reference mismatch check=%0d keys=%h/%h gains=%h/%h",checks,keys[0],keys[1],gains[0],gains[1]);
 for(p=0;p<16;p=p+1)if(dut.target[p]!==golden.target[p] || dut.count[p]!==golden.count[p] || dut.total[p]!==golden.total[p])$fatal(1,"cell state mismatch %0d check %0d",p,checks);
 if(dut.pending!==golden.pending)$fatal(1,"pending mismatch");
 checks=checks+1;
 end endtask
 task sweep;begin @(negedge clk);frame_valid=1;@(negedge clk);frame_valid=0;repeat(600)@(negedge clk);check();end endtask
 task idle_samples;integer p;begin for(p=0;p<16;p=p+1)samples[p*24+:24]=1000+p*17;end endtask
 task calibrate;begin idle_samples();repeat(10)sweep();end endtask
 initial begin
 repeat(4)@(negedge clk);reset_n=1;calibrate();
 for(j=0;j<16;j=j+1)begin
 idle_samples();samples[j*24+:24]=1500+j*17;sweep();sweep();
 samples[j*24+:24]=1800+j*17;sweep();idle_samples();sweep();
 end
 for(k=0;k<4;k=k+1)begin
 continuous=k[0];full_scale=k==2?0:(k==3?24'hffffff:1000);
 min_on=k==3?16'd65530:20;min_off=k==1?30:10;
 @(negedge clk);recalibrate=1;@(negedge clk);recalibrate=0;calibrate();
 for(n=0;n<200;n=n+1)begin
 for(j=0;j<16;j=j+1)begin rng=next_random(rng);
 case(rng[2:0])
 0:samples[j*24+:24]=1000+j*17;
 1:samples[j*24+:24]=1000+j*17+min_on-1;
 2:samples[j*24+:24]=1000+j*17+min_on;
 3:samples[j*24+:24]=1000+j*17+min_off;
 4:samples[j*24+:24]=24'hffffff;
 default:samples[j*24+:24]=1000+j*17+(rng[15:4]);
 endcase end
 sweep();if(n%3==0)sweep();
 end end
 idle_samples();sweep();enabled=0;repeat(10)@(negedge clk);check();enabled=1;calibrate();
 repeat(20500)@(negedge clk);check();calibrate();model=2;sweep();calibrate();
 // Abort in-flight processing, then compare recovered stable state.
 @(negedge clk);frame_valid=1;@(negedge clk);frame_valid=0;
 repeat(7)@(negedge clk);recalibrate=1;@(negedge clk);recalibrate=0;calibrate();
 $display("PASS pressure_equivalence: %0d settled-frame comparisons against standalone reference; 16 cells, randomized chords, thresholds, saturation, continuous mode, timeout and recovery",checks);$finish;
 end
 initial begin #20000000;$fatal(1,"equivalence timeout");end
endmodule
