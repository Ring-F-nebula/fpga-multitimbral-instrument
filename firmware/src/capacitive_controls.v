`timescale 1ns/1ps
// Four passive RC capacitive pads. Each input connects to an electrode and to
// the shared charge_drive through its OWN 1 Mohm resistor. No touch-controller IC.
// Power on with hands away: 64 x 1 ms baseline measurements. Touch latency is
// bounded by one 1 ms scan plus the downstream digital stability filter.
module capacitive_controls #(
 parameter FRAME_CYCLES=6250, parameter DISCHARGE_CYCLES=1562,
 parameter CALIBRATION_FRAMES=64, parameter MIN_MARGIN=62
)(
 input wire clk,reset_n, input wire [3:0] pad_async,
 output wire charge_drive, output reg [3:0] touch,
 output reg calibrated
);
 localparam TIMER_BITS=$clog2(FRAME_CYCLES+1);
 localparam SUM_BITS=TIMER_BITS+$clog2(CALIBRATION_FRAMES+1);
 reg [TIMER_BITS-1:0] timer;
 reg [3:0] meta,sync,seen;
 reg [TIMER_BITS-1:0] measured [0:3];
 reg [TIMER_BITS-1:0] baseline [0:3];
 reg [SUM_BITS-1:0] accumulated [0:3];
 reg [6:0] calibration_count;
 integer k;
 wire [TIMER_BITS-1:0] charge_time=timer-DISCHARGE_CYCLES;
 assign charge_drive=(timer>=DISCHARGE_CYCLES) && reset_n;
 always @(posedge clk or negedge reset_n) begin
  if(!reset_n) begin
   timer<=0;meta<=0;sync<=0;seen<=0;touch<=0;
   calibration_count<=0;calibrated<=0;
   for(k=0;k<4;k=k+1) begin
    measured[k]<=FRAME_CYCLES-DISCHARGE_CYCLES;
    baseline[k]<=0;accumulated[k]<=0;
   end
  end else begin
   meta<=pad_async;sync<=meta;
   if(timer==FRAME_CYCLES-1) begin
    timer<=0;seen<=0;
    for(k=0;k<4;k=k+1) begin
     if(!calibrated) begin
      accumulated[k]<=accumulated[k]+measured[k];
      // The default 64-frame average is a compile-time constant divider.
      baseline[k]<=(accumulated[k]+measured[k])/CALIBRATION_FRAMES;
      touch[k]<=0;
     end else begin
      touch[k]<=({1'b0,measured[k]} >
       {1'b0,baseline[k]} +
       ((baseline[k]>>1)>MIN_MARGIN ? (baseline[k]>>1) : MIN_MARGIN));
     end
     measured[k]<=FRAME_CYCLES-DISCHARGE_CYCLES;
    end
    if(!calibrated) begin
     if(calibration_count==CALIBRATION_FRAMES-1) calibrated<=1;
     else calibration_count<=calibration_count+1'b1;
    end
   end else begin
    timer<=timer+1'b1;
    if(timer>=DISCHARGE_CYCLES) begin
     for(k=0;k<4;k=k+1) if(sync[k] && !seen[k]) begin
      measured[k]<=charge_time;seen[k]<=1;
     end
    end
   end
  end
 end
endmodule
