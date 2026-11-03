`timescale 1ns/1ps
module tb_fx_stop_top;
reg clk=0;always #5 clk=~clk;
reg tick=0;reg [15:0] keys=0;
reg commit=0;reg [7:0] id=0,value=0;
dualmode_top #(.PANEL_UI(0)) dut(.clk_50m(clk),.key0_n(1'b1),.key1_n(1'b1),.UART_RX(1'b1),.BT_RX(1'b1),
 .enc_a_n(5'h1f),.enc_b_n(5'h1f),.enc_sw_n(1'b1),.beam_broken(7'd0),.soft_touch(1'b0),.bend_touch(1'b0),.timbre_touch(1'b0),.fx_touch(1'b0));
initial begin
 force dut.clk=clk;force dut.harp_reset_n=1'b1;force dut.sample_tick=tick;
 force dut.touch_keys=keys;force dut.fsr_keys=16'd0;
 force dut.usb_commit=commit;force dut.usb_id=id;force dut.usb_value=value;
end
task sample;
begin @(negedge clk);tick=1;@(negedge clk);tick=0;repeat(127)@(negedge clk);end endtask
task write_param(input [7:0] a,b);
begin @(negedge clk);id=a;value=b;commit=1;@(negedge clk);commit=0;end endtask
integer heard,i;
initial begin
 wait(dut.fx_ready);write_param(8'h10,7);write_param(8'h11,1);write_param(8'h13,128);
 keys=1;heard=0;repeat(1200)begin sample();if(dut.pcm!=0)heard++;end
 if(heard<900)$fatal(1,"effects muted ordinary touch source");
 write_param(8'h1f,1);repeat(5)sample();
 if(!dut.performance_stopped || dut.pcm!==0 || dut.fx_ready)$fatal(1,"remote STOP did not reset audio pipeline");
 keys=16'hffff;repeat(300)sample();if(dut.pcm!==0)$fatal(1,"input restarted stopped audio");
 keys=0;write_param(8'h1f,0);wait(dut.fx_ready);repeat(1000)begin sample();if(dut.pcm!==0)$fatal(1,"old tail after resume");end
 if(dut.fx_params[23:0]!={8'd90,8'd1,8'd7})$fatal(1,"STOP lost stored effects parameters");
 keys=16'h10;heard=0;repeat(500)begin sample();if(dut.pcm!=0)heard++;end
 if(heard<400)$fatal(1,"resume did not allow a fresh touch note");
 $display("PASS fx_stop_top: effects on actual mixer, UART commit STOP/resume, persistent parameters, exact silence and no stale tails");$finish;
end
initial begin #30000000;$fatal(1,"timeout");end
endmodule
