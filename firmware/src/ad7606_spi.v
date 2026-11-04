`timescale 1ns/1ps
// Original AD7606, PAR/SER=1 and DB15/BYTE SEL=0. DOUTA is DB7.
// CS holds one 128-bit frame; V1 is the low 16-bit word in samples.
// SCLK idles high. Capture the settled bit immediately before falling SCLK;
// the ADC advances data on the intervening rising edges (datasheet Fig. 6).
module ad7606_spi #(
    parameter integer PERIOD_CYCLES=50000, HALF_SCLK_CYCLES=100,
    parameter integer CS_SETUP_CYCLES=500, RESET_LOW_CYCLES=50,
    parameter integer CONVST_LOW_CYCLES=50, RESET_CYCLES=2500,
    parameter integer SETTLE_CYCLES=2500000, BUSY_TIMEOUT=2500,
    // Fixed conversion wait by default; optional BUSY handshake for integration.
    parameter integer USE_BUSY=0, CONVERSION_WAIT_CYCLES=20000
)(
    input wire clk,reset_n,busy_async,first_async,input wire [15:0] data_async,
    output reg adc_reset=0,convst=0,cs_n=1,rd_n=1,
    output reg [127:0] samples=0,
    output reg frame_toggle=0,online=0,fault=0,
    output reg frame_valid=0
);
    reg [1:0] reset_sync=0,busy_sync=0,first_sync=0;
    reg [15:0] data_meta=0,data_sync=0;
    always @(posedge clk or negedge reset_n)
        if(!reset_n)reset_sync<=0;else reset_sync<={reset_sync[0],1'b1};
    always @(posedge clk)begin
        busy_sync<={busy_sync[0],busy_async};first_sync<={first_sync[0],first_async};
        data_meta<=data_async;data_sync<=data_meta;
    end
    localparam RST=0,SETTLE=1,IDLE=2,CONVERT=3,WAIT_RISE=4,
               WAIT_FALL=5,CS_SETUP=6,SHIFT_HIGH=7,SHIFT_LOW=8,
               RESET_LOW=9,CS_FINISH=10,TIMED_WAIT=11;
    reg [3:0] state=RESET_LOW;
    reg [21:0] timer=0;
    reg [15:0] period=0,shift_word=0;
    reg [6:0] bit_count=0;
    reg [127:0] pending=0;
    reg bad_frame=0;
    task fail_frame;
        begin
            state<=RESET_LOW;timer<=0;adc_reset<=0;convst<=0;cs_n<=1;rd_n<=1;
            online<=0;fault<=1;bad_frame<=0;
        end
    endtask
    always @(posedge clk)begin
        if(!reset_sync[1])begin
            state<=RESET_LOW;timer<=0;period<=0;adc_reset<=0;convst<=0;cs_n<=1;rd_n<=1;
            samples<=0;frame_toggle<=0;online<=0;fault<=0;bit_count<=0;shift_word<=0;
            pending<=0;bad_frame<=0;frame_valid<=0;
        end else begin
            frame_valid<=0;
            if(period<PERIOD_CYCLES-1)period<=period+1'b1;
            case(state)
                RESET_LOW:begin
                    adc_reset<=0;convst<=0;cs_n<=1;rd_n<=1;
                    if(timer==RESET_LOW_CYCLES-1)begin adc_reset<=1;timer<=0;state<=RST;end
                    else timer<=timer+1'b1;
                end
                RST:begin
                    adc_reset<=1;cs_n<=1;convst<=0;rd_n<=1;
                    if(timer==RESET_CYCLES-1)begin adc_reset<=0;timer<=0;state<=SETTLE;end
                    else timer<=timer+1'b1;
                end
                SETTLE:begin
                    // Retain reference-example startup; dummy conversion is
                    // never read or published. Subsequent frames either use BUSY
                    // or the explicitly selected fixed conversion wait.
                    if(timer==CONVST_LOW_CYCLES-1)convst<=1;
                    if(timer==SETTLE_CYCLES-1)begin timer<=0;state<=IDLE;end
                    else timer<=timer+1'b1;
                end
                IDLE:if(period==PERIOD_CYCLES-1)begin
                    if(USE_BUSY && busy_sync[1])fail_frame;
                    else begin period<=0;convst<=0;timer<=0;state<=CONVERT;end
                end
                CONVERT:if(timer==CONVST_LOW_CYCLES-1)begin
                    convst<=1;timer<=0;state<=USE_BUSY?WAIT_RISE:TIMED_WAIT;
                end else timer<=timer+1'b1;
                TIMED_WAIT:begin
                    // OS0/1/2 remain grounded. 400us at 50MHz is deliberately
                    // generous relative to the nominal ~4us conversion time.
                    // BUSY does not gate SPI in fixed-wait mode.
                    if(timer==CONVERSION_WAIT_CYCLES-1)begin
                        timer<=0;cs_n<=0;rd_n<=1;bit_count<=0;shift_word<=0;
                        bad_frame<=0;pending<=0;state<=CS_SETUP;
                    end else timer<=timer+1'b1;
                end
                WAIT_RISE:begin
                    if(busy_sync[1])begin timer<=0;state<=WAIT_FALL;end
                    else if(timer==BUSY_TIMEOUT-1)fail_frame;else timer<=timer+1'b1;
                end
                WAIT_FALL:begin
                    if(!busy_sync[1])begin
                        timer<=0;cs_n<=0;rd_n<=1;bit_count<=0;shift_word<=0;
                        bad_frame<=0;pending<=0;state<=CS_SETUP;
                    end else if(timer==BUSY_TIMEOUT-1)fail_frame;else timer<=timer+1'b1;
                end
                CS_SETUP:if(timer==CS_SETUP_CYCLES-1)begin
                    timer<=0;state<=SHIFT_HIGH;
                end else timer<=timer+1'b1;
                SHIFT_HIGH:if(timer==HALF_SCLK_CYCLES-1)begin
                    timer<=0;rd_n<=0;shift_word<={shift_word[14:0],data_sync[7]};
                    case ({first_sync[1],(bit_count<16)})
                        2'b00,2'b11:begin end
                        default:bad_frame<=1;
                    endcase
                    if(bit_count[3:0]==15)
                        pending[bit_count[6:4]*16+:16]<={shift_word[14:0],data_sync[7]};
                    state<=SHIFT_LOW;
                end else timer<=timer+1'b1;
                SHIFT_LOW:if(timer==HALF_SCLK_CYCLES-1)begin
                    timer<=0;
                    if(bit_count==127)begin cs_n<=1;state<=CS_FINISH;end
                    else begin rd_n<=1;bit_count<=bit_count+1'b1;state<=SHIFT_HIGH;end
                end else timer<=timer+1'b1;
                CS_FINISH:if(timer==HALF_SCLK_CYCLES-1)begin
                    timer<=0;rd_n<=1;
                    if(bad_frame)fail_frame;
                    else begin
                        frame_valid<=1;samples<=pending;frame_toggle<=~frame_toggle;
                        online<=1;fault<=0;state<=IDLE;
                    end
                end else timer<=timer+1'b1;
                default:fail_frame;
            endcase
        end
    end
endmodule
