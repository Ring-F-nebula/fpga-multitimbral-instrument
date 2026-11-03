// Master gain AFTER all effects: 0..15 is volume/8 below the peak knee.
// +6.02 dB versus the previous volume/16 curve; UI still boots at volume 8.
// Static 4:1 peak compression above 22528 prevents signed wrap or hard clipping.
// Full-scale input at volume 15 maps to at most 32256, with no extra DSP.
// One gain step per audio frame, maximum 5.27 ms across the entire range.
// Keep the amplifier powered during ordinary mute/parameter operations.
module audio_master(input clk,reset_n,tick,mute,input [3:0] volume,
 input signed [15:0] pcm_in,output reg signed [15:0] pcm_out=0);
 reg [8:0] gain=128;
 wire [8:0] target={1'b0,volume,4'b0};
 wire signed [25:0] product=pcm_in*$signed({1'b0,gain});
 wire signed [18:0] boosted=product>>>7;
 wire [18:0] magnitude=boosted[18]?-boosted:boosted;
 wire [18:0] peak=(magnitude <= 19'd22528) ? magnitude : 19'd22528+((magnitude-19'd22528)>>2);
 wire signed [19:0] protected_sample=boosted[18]?-$signed({1'b0,peak}):$signed({1'b0,peak});
 always @(posedge clk)begin
  if(!reset_n)begin gain<=0;pcm_out<=0;end
  else if(tick)begin
   if(mute)begin
    gain<=0;
    if(pcm_out>256)pcm_out<=pcm_out-16'sd256;
    else if(pcm_out< -256)pcm_out<=pcm_out+16'sd256;
    else pcm_out<=0;
   end else begin
    if(gain<target)gain<=gain+1'b1;else if(gain>target)gain<=gain-1'b1;
    pcm_out<=protected_sample[15:0];
   end
  end
 end
endmodule
