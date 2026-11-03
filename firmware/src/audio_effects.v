// 26.25 MHz / 576 = 45572.9167 samples/s. Shared AFTER the voice mixer.
// All memories have synchronous reads, including the fractional chorus taps.
// No sampled sound files. 36 processing clocks/sample, < 576 available.
module audio_effects(input clk,reset_n,sample_tick,enable,
    input signed [15:0] dry,input [127:0] params,
    output reg signed [15:0] wet=0,output reg valid=0,output reg ready=0);
    wire [7:0] flags=params[7:0];
    wire delay_on=enable||flags[0], chorus_on=flags[1],reverb_on=flags[2];
    wire [7:0] feedback=params[23:16];
    wire [7:0] target_d=(delay_on&&!flags[5])?params[31:24]:0;
    wire [7:0] target_c=(chorus_on&&!flags[5])?params[55:48]:0;
    wire [7:0] target_r=(reverb_on&&!flags[5])?params[79:72]:0;
    reg [7:0] mix_d=0,mix_c=0,mix_r=0;
    // round(45572.9167 * time_10ms / 100) using Q8 samples/unit
    wire [24:0] delay_product=params[15:8]*17'd116667;
    wire [15:0] requested_delay=(delay_product+25'd128)>>8;
    reg [15:0] delay_length=8203;
    reg signed [15:0] delay_mem[0:65535];
    reg signed [15:0] chorus_mem[0:2047];
    reg signed [15:0] comb0[0:4095],comb1[0:4095],comb2[0:4095],comb3[0:4095];
    reg signed [15:0] ap0[0:1023],ap1[0:1023];
    reg [15:0] clear_addr=0,dp=0;
    reg [10:0] cp=0;
    reg [11:0] rp=0;
    reg [9:0] ap=0;
    reg [5:0] state=0;
    reg signed [15:0] input_q=0,stage_d=0,stage_c=0;
    reg signed [15:0] dq=0,cq0=0,cq1=0,cq2=0,cq3=0;
    reg signed [15:0] rq0=0,rq1=0,rq2=0,rq3=0,aq0=0,aq1=0;
    reg signed [15:0] lp0=0,lp1=0,lp2=0,lp3=0,rv=0,av=0;
    reg signed [31:0] work=0;
    reg [23:0] lfo=0;
    wire [23:0] lfo_b=lfo+24'h400000;
    wire signed [8:0] tri_a=lfo[23]?$signed({1'b0,~lfo[22:15]})-9'sd128:$signed({1'b0,lfo[22:15]})-9'sd128;
    wire signed [8:0] tri_b=lfo_b[23]?$signed({1'b0,~lfo_b[22:15]})-9'sd128:$signed({1'b0,lfo_b[22:15]})-9'sd128;
    // +/- 200 samples at 100% depth, 16.85 ms centre. Q8 tap position.
    wire signed [23:0] offset_a=tri_a*$signed({1'b0,params[47:40]})*24'sd4;
    wire signed [23:0] offset_b=tri_b*$signed({1'b0,params[47:40]})*24'sd4;
    wire [18:0] tap_a=19'd196608+offset_a,tap_b=19'd196608+offset_b;
    reg [10:0] ca=0,cb=0;reg [7:0] fa=0,fb=0;
    wire [23:0] lfo_rate=(params[39:32]*24'd9424)>>8;
    wire [11:0] ra0=rp-12'd1493,ra1=rp-12'd1601,ra2=rp-12'd1867,ra3=rp-12'd2081;
    wire [9:0] aa0=ap-10'd225,aa1=ap-10'd556;
    wire [15:0] g0,g1,g2,g3;
    reverb_coeff coefficients(.selector(params[67:64]),.g0(g0),.g1(g1),.g2(g2),.g3(g3));
    // Space controls diffuser feedback, 0.25 .. 0.64; it is not a room-size measurement.
    wire [7:0] diffusion=8'd64+params[63:56];
    function signed [15:0] clip;
        input signed [31:0] x;
        begin clip=x>32767?16'sd32767:x< -32768?-16'sd32768:x[15:0]; end
    endfunction
    function signed [31:0] trunc8;
        input signed [31:0] x;
        begin trunc8=x<0?-((-x)>>>8):(x>>>8); end
    endfunction
    function signed [31:0] trunc15;
        input signed [31:0] x;
        begin trunc15=x<0?-((-x)>>>15):(x>>>15); end
    endfunction
    function signed [15:0] blend;
        input signed [15:0] x,y;input [7:0] m;
        reg signed [31:0] diff,prod;
        begin diff=$signed(y)-$signed(x);prod=diff*$signed({1'b0,m});blend=clip($signed(x)+trunc8(prod));end
    endfunction
    function [7:0] slew;
        input [7:0] a,b;begin slew=a<b?a+1'b1:a>b?a-1'b1:a;end
    endfunction
    function signed [15:0] damp;
        input signed [15:0] old,x;reg signed [31:0] sum;
        begin sum=$signed(old)*3+$signed(x);damp=sum<0?-((-sum)>>>2):(sum>>>2);end
    endfunction
    function signed [15:0] comb_write;
        input signed [15:0] x,y;input [15:0] gain;
        reg signed [31:0] p;
        begin p=y*$signed({1'b0,gain});comb_write=clip(($signed(x)>>>2)+trunc15(p));end
    endfunction
    always @(posedge clk) begin
        valid<=0;
        if(!reset_n) begin
            ready<=0;clear_addr<=0;state<=0;wet<=0;dp<=0;cp<=0;rp<=0;ap<=0;
            mix_d<=0;mix_c<=0;mix_r<=0;lfo<=0;lp0<=0;lp1<=0;lp2<=0;lp3<=0;
        end else if(!ready) begin
            delay_mem[clear_addr]<=0;
            if(clear_addr<2048)chorus_mem[clear_addr[10:0]]<=0;
            if(clear_addr<4096)begin comb0[clear_addr[11:0]]<=0;comb1[clear_addr[11:0]]<=0;comb2[clear_addr[11:0]]<=0;comb3[clear_addr[11:0]]<=0;end
            if(clear_addr<1024)begin ap0[clear_addr[9:0]]<=0;ap1[clear_addr[9:0]]<=0;end
            if(clear_addr==65535)begin ready<=1;delay_length<=requested_delay;end
            else clear_addr<=clear_addr+1'b1;
        end else case(state)
            0:if(sample_tick)begin
                input_q<=dry;state<=1;lfo<=lfo+lfo_rate;
                // A delay-time change fades the tap out before moving it.
                mix_d<=slew(mix_d,requested_delay!=delay_length?8'd0:target_d);
                if(mix_d==0)delay_length<=requested_delay;
                mix_c<=slew(mix_c,target_c);mix_r<=slew(mix_r,target_r);
                ca<=cp-tap_a[18:8];cb<=cp-tap_b[18:8];fa<=tap_a[7:0];fb<=tap_b[7:0];
            end
            1:begin dq<=delay_mem[dp-delay_length];state<=2;end
            2:begin
                work<=$signed(dq)*$signed({1'b0,delay_on?feedback:8'd0});
                stage_d<=blend(input_q,dq,mix_d);state<=3;
            end
            3:begin delay_mem[dp]<=clip($signed(input_q)+trunc8(work));dp<=dp+1'b1;state<=4;end
            4:begin cq0<=chorus_mem[ca];state<=5;end
            5:begin cq1<=chorus_mem[(ca-11'd1)&11'h7ff];state<=6;end
            6:begin cq2<=chorus_mem[cb];state<=7;end
            7:begin cq3<=chorus_mem[(cb-11'd1)&11'h7ff];state<=8;end
            8:begin work<=$signed(blend(cq0,cq1,fa))+$signed(blend(cq2,cq3,fb));state<=9;end
            9:begin stage_c<=blend(stage_d,clip(work>>>1),mix_c);chorus_mem[cp]<=stage_d;cp<=cp+1'b1;state<=10;end
            10:begin rq0<=comb0[ra0];rq1<=comb1[ra1];rq2<=comb2[ra2];rq3<=comb3[ra3];state<=11;end
            11:begin lp0<=damp(lp0,rq0);lp1<=damp(lp1,rq1);lp2<=damp(lp2,rq2);lp3<=damp(lp3,rq3);state<=12;end
            12:begin
                comb0[rp]<=comb_write(stage_c,lp0,g0);comb1[rp]<=comb_write(stage_c,lp1,g1);
                comb2[rp]<=comb_write(stage_c,lp2,g2);comb3[rp]<=comb_write(stage_c,lp3,g3);
                work<=$signed(rq0)+$signed(rq1)+$signed(rq2)+$signed(rq3);rp<=rp+1'b1;state<=13;
            end
            13:begin rv<=clip(work>>>1);aq0<=ap0[aa0];state<=14;end
            14:begin work<=$signed(rv)*$signed({1'b0,diffusion});state<=15;end
            15:begin av<=clip($signed(aq0)-trunc8(work));state<=16;end
            16:begin work<=$signed(av)*$signed({1'b0,diffusion});state<=17;end
            17:begin ap0[ap]<=clip($signed(rv)+trunc8(work));rv<=av;aq1<=ap1[aa1];state<=18;end
            18:begin work<=$signed(rv)*$signed({1'b0,diffusion});state<=19;end
            19:begin av<=clip($signed(aq1)-trunc8(work));state<=20;end
            20:begin work<=$signed(av)*$signed({1'b0,diffusion});state<=21;end
            21:begin ap1[ap]<=clip($signed(rv)+trunc8(work));ap<=ap+1'b1;wet<=blend(stage_c,av,mix_r);valid<=1;state<=0;end
            default:state<=0;
        endcase
    end
endmodule
