// Captures actual DAC input PCM. This memory is never connected to synthesis.
// 131072 samples at 45572.9167 Hz: 2.876 seconds. Command 3 arms capture
// until the first nonzero DAC sample; sample storage never feeds the DAC.
module audio_capture(input clk,reset_n,tick,input signed [15:0] pcm,input command_valid,input [1:0] command,
 input [16:0] read_address,output reg [15:0] read_data=0,output reg recording=0,full=0,armed=0,
 output reg [17:0] count=0,output reg [4:0] tenths=0);
 reg [15:0] memory[0:131071];reg [12:0] tenth_samples=0;
 wire capture_sample=reset_n&&!command_valid&&tick&&(recording||(armed&&pcm!=0))&&count<131072;
 always @(posedge clk)if(capture_sample)memory[count[16:0]]<=pcm;
 always @(posedge clk)read_data<=memory[read_address];
 always @(posedge clk)begin
  if(!reset_n)begin recording<=0;full<=0;armed<=0;count<=0;tenths<=0;tenth_samples<=0;end
  else if(command_valid)case(command)
   0:begin recording<=0;armed<=0;end
   1,3:begin recording<=command==1;armed<=command==3;full<=0;count<=0;tenths<=0;tenth_samples<=0;end
   2:begin recording<=0;armed<=0;full<=0;count<=0;tenths<=0;tenth_samples<=0;end
  endcase
  else if(capture_sample)begin
   armed<=0;recording<=1;
   if(tenth_samples==4556)begin tenth_samples<=0;tenths<=tenths+1'b1;end else tenth_samples<=tenth_samples+1'b1;
   if(count==131071)begin count<=131072;recording<=0;full<=1;end else count<=count+1'b1;
  end
 end
endmodule
