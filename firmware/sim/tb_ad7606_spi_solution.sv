`timescale 1ns/1ps
module tb_ad7606_spi_solution;
 reg clk=0;always #10 clk=~clk;
 reg reset_n=0,disconnect=0,bad_first=0,no_busy=0,observed_busy=0;
 reg [127:0] codes={16'h8000,16'hffff,16'h0000,16'h5555,16'haaaa,16'h7fff,16'h0123,16'hfedc};
 wire [15:0] data;
 wire physical_busy,first,rst,convst,cs,sclk,toggle,online,fault,valid;
 wire [127:0] samples;
 ad7606_spi #(.RESET_CYCLES(10),.SETTLE_CYCLES(600)) dut(
  .clk(clk),.reset_n(reset_n),.busy_async(observed_busy),.first_async(first),.data_async(data),
  .adc_reset(rst),.convst(convst),.cs_n(cs),.rd_n(sclk),.samples(samples),
  .frame_toggle(toggle),.frame_valid(valid),.online(online),.fault(fault));
 ad7606_spi_model #(.FIRST_DELAY_NS(3000),.DATA_DELAY_NS(200)) chip(
  rst,convst,cs,sclk,codes,no_busy,1'b0,bad_first,disconnect,physical_busy,first,data);
 task frames(input integer n);begin repeat(n)begin @(toggle);repeat(8)@(negedge clk);end end endtask
 time triggered=0,last_cs=0;
 always @(posedge convst)if(!rst)triggered=$time;
 always @(negedge cs)begin
  if($time-triggered<400000)$fatal(1,"conversion wait below 400us");
  if(last_cs&&$time-last_cs<1000000)$fatal(1,"frame interval below 1ms");last_cs=$time;
 end
 reg [127:0] held;
 integer ch,pattern,published=0,before_count;
 always @(posedge clk)if(valid)published=published+1;
 initial begin
  repeat(8)@(negedge clk);reset_n=1;frames(3);
  if(samples!==codes||!online||fault)$fatal(1,"initial serial frame");
  for(pattern=0;pattern<3;pattern=pattern+1)begin
   for(ch=0;ch<8;ch=ch+1)codes[ch*16+:16]=$random;
   frames(2);if(samples!==codes)$fatal(1,"eight-channel bit/word order");
  end
  observed_busy=1;codes[15:0]=16'h1234;frames(2);
  if(samples!==codes||!online||fault)$fatal(1,"optional BUSY blocked reading");
  observed_busy=0;
  wait(dut.state==2);held=samples;no_busy=1;codes=~codes;frames(2);
  if(samples!==held)$fatal(1,"stale-register model boundary");
  no_busy=0;frames(2);if(samples!==codes)$fatal(1,"conversion recovery");
  held=samples;before_count=published;bad_first=1;wait(fault);repeat(8)@(negedge clk);
  if(samples!==held||published!=before_count||online||valid)$fatal(1,"invalid FRST accepted");
  bad_first=0;frames(2);
  wait(dut.state==2);held=samples;before_count=published;disconnect=1;wait(fault);repeat(8)@(negedge clk);
  if(samples!==held||published!=before_count||online||valid)$fatal(1,"missing module accepted");
  disconnect=0;frames(2);if(samples!==codes||!online||fault)$fatal(1,"module recovery");
  reset_n=0;repeat(8)@(negedge clk);
  if(online||samples||valid)$fatal(1,"reset publication");
  reset_n=1;frames(2);
  $display("PASS acquisition: 400us wait, 1ms frame period, 128-bit eight-channel order, BUSY optional, invalid/disconnected frames rejected, stale-register boundary and restart");$finish;
 end
 initial begin #60000000;$fatal(1,"serial acquisition timeout");end
endmodule
