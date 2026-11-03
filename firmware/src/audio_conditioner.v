// Q8 DC tracker (about 14Hz) and two one-pole low-pass stages (~5kHz each).
// Retain fractional bits to avoid negative-rounding hiss/limit cycles.
module audio_conditioner(input clk,reset_n,tick,active,input signed [15:0] pcm_in,
 output reg signed [15:0] pcm_out=0,output wire idle);
 reg signed [26:0] dc=0,low1=0,low2=0;
 reg [7:0] silence=255;
 assign idle=&silence;
 reg signed [26:0] x,high,n1,n2;
 always @(posedge clk or negedge reset_n) begin
  if(!reset_n) begin dc<=0;low1<=0;low2<=0;pcm_out<=0;silence<=255;end
  else if(tick) begin
   if(active || pcm_in!=0) silence<=0;
   else if(!(&silence)) silence<=silence+1'b1;
   x=$signed(pcm_in)*27'sd256;
   high=active || pcm_in!=0 ? x-dc:27'sd0;
   n1=low1+((high-low1)>>>1);
   n2=low2+((n1-low2)>>>1);
   if(active || pcm_in!=0) dc<=dc+((x-dc)>>>9);else dc<=0;
   if(!active && pcm_in==0 && low1<256 && low1> -256 && low2<256 && low2> -256) begin
    low1<=0;low2<=0;pcm_out<=0;
   end else begin
    low1<=n1;low2<=n2;
    if(n2>27'sd8388352) pcm_out<=16'sh7fff;
    else if(n2< -27'sd8388608) pcm_out<=16'sh8000;
    else pcm_out<=n2>>>8;
   end
  end
 end
endmodule
