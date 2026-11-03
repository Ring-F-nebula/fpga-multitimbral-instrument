// 16 spatial cells are already A0..A15 in the DIGITAL packet. No legacy
// 4067 permutation. Eight stable idle frames calibrate each cell independently.
// Two consecutive above-threshold frames qualify an onset. One below-off
// frame releases; gain is retained through the synth's release envelope.
module wax_pressure_reference #(parameter integer CAL_FRAMES=8,STALE_CYCLES=10500000)(
 input clk,reset_n,tick,frame_valid,recalibrate,enabled,continuous,
 input [383:0] samples,input [7:0] model,input [15:0] min_on,min_off,
 input [23:0] full_scale,
 output reg [15:0] keys=0,output [143:0] gains,
 output reg [383:0] raw_values=0,output [383:0] baselines,
 output reg [15:0] calibrated_mask=0,output reg online=0,
 output wire ready,calibrating,output reg noisy=0,
 output reg [23:0] peak=0,delta_peak=0,output [383:0] thresholds);
 reg [$clog2(STALE_CYCLES+1)-1:0] age=0;
 reg [23:0] baseline[0:15],low[0:15],high[0:15],threshold[0:15];
 reg [31:0] total[0:15];reg [7:0] count[0:15];
 reg [8:0] gain[0:15],target[0:15];reg [15:0] pending=0;
 reg [383:0] snapshot=0;reg [7:0] last_model=0;
 reg [3:0] pad=0;reg [2:0] state=0;reg [4:0] drift=0;
 reg [23:0] maximum=0,delta_max=0;
 reg [24:0] remainder=0;reg [7:0] quotient=0;reg [3:0] divide_bit=0;
 reg [23:0] denominator=1;reg onset=0;
 wire expired=age==STALE_CYCLES;
 assign ready=online&&(&calibrated_mask)&&enabled&&!expired;
 assign calibrating=online&&!(&calibrated_mask)&&enabled;
 genvar p;generate for(p=0;p<16;p=p+1)begin:packed_values
  assign gains[p*9+:9]=gain[p];assign baselines[p*24+:24]=baseline[p];assign thresholds[p*24+:24]=threshold[p];
 end endgenerate
 integer i;reg [23:0] code,diff,lo,hi,noise,off,allowance,effective;
 reg [31:0] sum;
 always @(posedge clk)begin
  if(!reset_n)begin
   age<=0;keys<=0;pending<=0;online<=0;calibrated_mask<=0;state<=0;last_model<=0;
   noisy<=0;peak<=0;delta_peak<=0;raw_values<=0;drift<=0;
   for(i=0;i<16;i=i+1)begin baseline[i]<=0;low[i]<=24'hffffff;high[i]<=0;total[i]<=0;count[i]<=0;gain[i]<=0;target[i]<=0;threshold[i]<=min_on;end
  end else begin
   if(age<STALE_CYCLES)age<=age+1'b1;
   // Slew aftertouch one gain unit/audio frame (full ramp ~5.6 ms).
   if(tick)for(i=0;i<16;i=i+1)if(keys[i])begin
    if(gain[i]<target[i])gain[i]<=gain[i]+1'b1;
    else if(gain[i]>target[i])gain[i]<=gain[i]-1'b1;
   end
   if(recalibrate||!enabled||(expired&&!frame_valid)||(frame_valid&&model!=last_model))begin
    keys<=0;pending<=0;calibrated_mask<=0;state<=0;noisy<=0;
    if(expired&&!frame_valid)online<=0;
    if(frame_valid)begin last_model<=model;age<=0;online<=1;end
    for(i=0;i<16;i=i+1)begin count[i]<=0;total[i]<=0;low[i]<=24'hffffff;high[i]<=0;threshold[i]<=min_on;end
   end else if(frame_valid)begin
    age<=0;online<=1;snapshot<=samples;raw_values<=samples;pad<=0;maximum<=0;delta_max<=0;state<=1;drift<=drift+1'b1;
   end else case(state)
    0:;
    1:begin
     code=snapshot[pad*24+:24];diff=code>baseline[pad]?code-baseline[pad]:0;
     if(code>maximum)maximum<=code;if(diff>delta_max)delta_max<=diff;
     state<=4;
     if(!calibrated_mask[pad])begin
      keys[pad]<=0;pending[pad]<=0;
      lo=count[pad]==0?code:(code<low[pad]?code:low[pad]);
      hi=count[pad]==0?code:(code>high[pad]?code:high[pad]);
      noise=hi-lo;sum=total[pad]+code;
      if(noise>120)begin count[pad]<=1;total[pad]<=code;low[pad]<=code;high[pad]<=code;noisy<=1;end
      else if(count[pad]==CAL_FRAMES-1)begin
       baseline[pad]<=sum/CAL_FRAMES;threshold[pad]<=min_on+2*noise;
       calibrated_mask[pad]<=1;count[pad]<=0;
      end else begin count[pad]<=count[pad]+1'b1;total[pad]<=sum;low[pad]<=lo;high[pad]<=hi;end
     end else begin
      allowance=threshold[pad]>min_on?threshold[pad]-min_on:0;
      off=allowance+(min_off<min_on?min_off:(min_on>>1));
      effective=diff>allowance?diff-allowance:0;
      if(!ready)begin keys[pad]<=0;pending[pad]<=0;end
      else if(keys[pad]&&diff<=off)begin keys[pad]<=0;pending[pad]<=0;end
      else if(!keys[pad]&&diff<threshold[pad])begin
       pending[pad]<=0;
       // Track slow unloaded drift only well inside the release band.
       if(drift==0&&diff<(min_off>>1))begin
        if(code>baseline[pad])baseline[pad]<=baseline[pad]+1'b1;
        else if(code<baseline[pad])baseline[pad]<=baseline[pad]-1'b1;
       end
      end else if(!keys[pad]&&!pending[pad])pending[pad]<=1;
      else if(!keys[pad]||continuous)begin
       if(!keys[pad])begin keys[pad]<=1;pending[pad]<=0;end
       if(effective>=full_scale||full_scale==0)begin
        target[pad]<=256;if(!keys[pad])gain[pad]<=256;
       end else begin
        // Shared 8-step fractional divider; no 16 parallel hardware dividers.
        remainder<={1'b0,effective};denominator<=full_scale;quotient<=0;divide_bit<=0;onset<=!keys[pad];state<=2;
       end
      end
     end
    end
    2:begin
     if((remainder<<1)>={1'b0,denominator})begin remainder<=(remainder<<1)-denominator;quotient<={quotient[6:0],1'b1};end
     else begin remainder<=remainder<<1;quotient<={quotient[6:0],1'b0};end
     if(divide_bit==7)state<=3;else divide_bit<=divide_bit+1'b1;
    end
    3:begin
     target[pad]<=quotient<32?9'd32:{1'b0,quotient};
     // First nonzero target also applies at onset; later aftertouch is slewed.
     if(onset)gain[pad]<=quotient<32?9'd32:{1'b0,quotient};state<=4;
    end
    4:if(pad==15)begin peak<=maximum;delta_peak<=delta_max;if(&calibrated_mask)noisy<=0;state<=0;end
      else begin pad<=pad+1'b1;state<=1;end
    default:state<=0;
   endcase
  end
 end
endmodule
