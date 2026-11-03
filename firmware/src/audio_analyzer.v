// Actual output PCM -> 1024-point Hann-windowed FFT and min/max waveform.
// All analysis/render memory is in the LCD clock domain. The audio mailbox
// holds PCM for an entire sample interval; a synchronized toggle marks it valid.
// One contiguous 1024-sample block is captured, transformed, and published at
// vertical blank. The next block starts after publication (no overlap).
module audio_analyzer(input clk,audio_clk,sample_tick,
    input signed [15:0] pcm,input frame_blank,
    input [7:0] wave_address,input [5:0] band_address,
    output reg [7:0] wave_low=60,wave_high=60,
    output reg [6:0] spectrum_height=0,output reg display_valid=0);
    `include "audio_analyzer_tables.vh"
    reg signed [15:0] audio_hold=0;
    reg audio_toggle=0;
    always @(posedge audio_clk) if(sample_tick) begin
        audio_hold<=pcm; audio_toggle<=~audio_toggle;
    end
    (* syn_preserve=1 *) reg [2:0] toggle_sync=0;
    always @(posedge clk) toggle_sync<={toggle_sync[1:0],audio_toggle};
    wire new_sample=toggle_sync[2]^toggle_sync[1];
    reg [4:0] state=0;
    reg [9:0] capture_index=0;
    reg signed [31:0] window_product=0;
    reg signed [15:0] group_min=0,group_max=0;
    reg signed [15:0] column_min=0,column_max=0;
    reg [15:0] peak=0;
    wire [15:0] absolute_pcm=audio_hold[15] ? -audio_hold:audio_hold;
    wire signed [15:0] minimum=(capture_index[1:0]==0 || audio_hold<group_min)?audio_hold:group_min;
    wire signed [15:0] maximum=(capture_index[1:0]==0 || audio_hold>group_max)?audio_hold:group_max;
    reg bank=0;
    reg [3:0] display_shift=0;
    function [3:0] gain_shift;
        input [15:0] value;
        begin
            if(value<32) gain_shift=0; else if(value<64) gain_shift=1;
            else if(value<128) gain_shift=2; else if(value<256) gain_shift=3;
            else if(value<512) gain_shift=4; else if(value<1024) gain_shift=5;
            else if(value<2048) gain_shift=6; else if(value<4096) gain_shift=7;
            else if(value<8192) gain_shift=8; else if(value<16384) gain_shift=9;
            else gain_shift=10;
        end
    endfunction
    function [7:0] wave_y;
        input signed [15:0] value;
        input [3:0] shift;
        reg signed [16:0] displacement;
        begin
            displacement=value>>>shift;
            if(displacement>39) displacement=39;
            else if(displacement< -39) displacement=-39;
            wave_y=17'sd60-displacement;
        end
    endfunction
    // Approximate log magnitude: 10 px per octave (about 6 dB), fractional
    // interpolation using three mantissa bits; fixed scale, no AGC. Suppress
    // magnitudes below 16 to hide the ten-stage integer rounding floor.
    function [7:0] magnitude_code;
        input [16:0] value;
        begin
            if(value[16]) magnitude_code={5'd16,value[15:13]};
            else if(value[15]) magnitude_code={5'd15,value[14:12]};
            else if(value[14]) magnitude_code={5'd14,value[13:11]};
            else if(value[13]) magnitude_code={5'd13,value[12:10]};
            else if(value[12]) magnitude_code={5'd12,value[11:9]};
            else if(value[11]) magnitude_code={5'd11,value[10:8]};
            else if(value[10]) magnitude_code={5'd10,value[9:7]};
            else if(value[9]) magnitude_code={5'd9,value[8:6]};
            else if(value[8]) magnitude_code={5'd8,value[7:5]};
            else if(value[7]) magnitude_code={5'd7,value[6:4]};
            else if(value[6]) magnitude_code={5'd6,value[5:3]};
            else if(value[5]) magnitude_code={5'd5,value[4:2]};
            else if(value[4]) magnitude_code={5'd4,value[3:1]};
            else magnitude_code=0;
        end
    endfunction
    function [6:0] code_height;
        input [7:0] code;
        reg [6:0] base;
        reg [3:0] fraction;
        begin
            case(code[7:3])
                4:base=0;5:base=10;6:base=20;7:base=30;8:base=40;
                9:base=50;10:base=60;11:base=70;12:base=80;default:base=0;
            endcase
            case(code[2:0])
                0:fraction=0;1:fraction=1;2:fraction=2;3:fraction=3;
                4:fraction=5;5:fraction=6;6:fraction=7;default:fraction=8;
            endcase
            if(code[7:3]<4) code_height=0;
            else if(code[7:3]>=13) code_height=88;
            else code_height=base+fraction;
        end
    endfunction
    function [9:0] reverse_bits;
        input [9:0] value;
        begin reverse_bits={value[0],value[1],value[2],value[3],value[4],
                            value[5],value[6],value[7],value[8],value[9]}; end
    endfunction
    (* ram_style="block" *) reg signed [15:0] fft_real[0:1023];
    (* ram_style="block" *) reg signed [15:0] fft_imag[0:1023];
    reg [3:0] stage=0;
    reg [10:0] half_size=1,span=2,group_base=0;
    reg [9:0] butterfly=0,frequency_bin=1;
    reg [8:0] twiddle_index=0;
    reg [9:0] twiddle_step=512;
    wire [9:0] address_a=group_base+butterfly;
    wire [9:0] address_b=group_base+butterfly+half_size;
    wire [9:0] fft_read_address=state==4 ? address_b : state>=11 ? frequency_bin:address_a;
    reg signed [15:0] read_real=0,read_imag=0;
    reg signed [15:0] ar=0,ai=0,br=0,bi=0,tw_cos=0,tw_sin=0;
    reg signed [31:0] rr=0,ii=0,ri=0,ir=0;
    reg signed [17:0] tr=0,ti=0;
    wire signed [32:0] product_real=$signed({rr[31],rr})-$signed({ii[31],ii});
    wire signed [32:0] product_imag=$signed({ri[31],ri})+$signed({ir[31],ir});
    reg signed [15:0] out_ar=0,out_ai=0,out_br=0,out_bi=0;
    always @(posedge clk) begin
        read_real<=fft_real[fft_read_address]; read_imag<=fft_imag[fft_read_address];
        if(state==1) begin
            fft_real[reverse_bits(capture_index)]<=window_product>>>15;
            fft_imag[reverse_bits(capture_index)]<=0;
        end else if(state==9) begin
            fft_real[address_a]<=out_ar; fft_imag[address_a]<=out_ai;
        end else if(state==10) begin
            fft_real[address_b]<=out_br; fft_imag[address_b]<=out_bi;
        end
    end
    reg [5:0] band=0;
    reg [16:0] magnitude=0,band_peak=0;
    reg [16:0] completed_magnitude=0;
    reg [7:0] completed_code=0;
    reg [6:0] completed_height=0;
    wire [15:0] abs_real=read_real[15] ? -read_real:read_real;
    wire [15:0] abs_imag=read_imag[15] ? -read_imag:read_imag;
    wire [16:0] next_band_peak=magnitude>band_peak?magnitude:band_peak;
    (* ram_style="block" *) reg [31:0] wave0[0:255],wave1[0:255];
    (* ram_style="block" *) reg [6:0] spectrum0[0:63],spectrum1[0:63];
    reg [31:0] wave_q0=0,wave_q1=0;
    reg [6:0] spectrum_q0=0,spectrum_q1=0;
    reg read_bank=0;
    always @(posedge clk) begin
        // bank is the displayed bank; only its opposite is written.
        if(state==1 && capture_index[1:0]==3) begin
            if(bank) wave0[capture_index[9:2]]<={column_min,column_max};
            else wave1[capture_index[9:2]]<={column_min,column_max};
        end
        if(state==17) begin
            if(bank) spectrum0[band]<=completed_height;
            else spectrum1[band]<=completed_height;
        end
        wave_q0<=wave0[wave_address]; wave_q1<=wave1[wave_address];
        spectrum_q0<=spectrum0[band_address]; spectrum_q1<=spectrum1[band_address];
        read_bank<=bank;
    end
    wire [31:0] displayed_wave=read_bank?wave_q1:wave_q0;
    // Keep gain/clipping out of the final pixel color path. Both plots have
    // two read cycles: block RAM output, then registered display coordinates.
    always @(posedge clk) begin
        wave_low<=display_valid ? wave_y($signed(displayed_wave[15:0]),display_shift):8'd60;
        wave_high<=display_valid ? wave_y($signed(displayed_wave[31:16]),display_shift):8'd60;
        spectrum_height<=display_valid ? (read_bank?spectrum_q1:spectrum_q0):7'd0;
    end
    always @(posedge clk) case(state)
        0: if(new_sample) begin
            window_product<=audio_hold*fft_window(capture_index);
            group_min<=minimum; group_max<=maximum;
            column_min<=minimum; column_max<=maximum;
            if(absolute_pcm>peak) peak<=absolute_pcm;
            state<=1;
        end
        1: if(capture_index==1023) state<=2;
           else begin capture_index<=capture_index+1'b1; state<=0; end
        2: begin
            stage<=0;half_size<=1;span<=2;group_base<=0;butterfly<=0;
            twiddle_index<=0;twiddle_step<=512;state<=3;
        end
        3: state<=4; // synchronous RAM read A
        4: begin ar<=read_real;ai<=read_imag;state<=5;end // read B
        5: begin br<=read_real;bi<=read_imag;
            tw_cos<=fft_cos(twiddle_index);tw_sin<=fft_sin(twiddle_index);state<=6;end
        6: begin rr<=br*tw_cos;ii<=bi*tw_sin;ri<=br*tw_sin;ir<=bi*tw_cos;state<=7;end
        7: begin tr<=product_real>>>15;ti<=product_imag>>>15;state<=8;end
        8: begin
            out_ar<=($signed(ar)+tr)>>>1;out_ai<=($signed(ai)+ti)>>>1;
            out_br<=($signed(ar)-tr)>>>1;out_bi<=($signed(ai)-ti)>>>1;state<=9;
        end
        9: state<=10;
        10: begin
            state<=3;
            if(butterfly+1<half_size) begin
                butterfly<=butterfly+1'b1;twiddle_index<=twiddle_index+twiddle_step;
            end else begin
                butterfly<=0;twiddle_index<=0;
                if(group_base+span<1024) group_base<=group_base+span;
                else begin
                    group_base<=0;
                    if(stage==9) begin frequency_bin<=1;band<=0;band_peak<=0;state<=11;end
                    else begin stage<=stage+1'b1;half_size<=span;span<=span<<1;
                        twiddle_step<=twiddle_step>>1;end
                end
            end
        end
        11: state<=12; // synchronous RAM read of a natural-order FFT bin
        12: begin magnitude<={1'b0,abs_real}+{1'b0,abs_imag};state<=13;end
        13: begin
            if(frequency_bin==band_end(band)) begin
                completed_magnitude<=next_band_peak;band_peak<=0;state<=14;
            end else begin
                band_peak<=next_band_peak;frequency_bin<=frequency_bin+1'b1;state<=11;
            end
        end
        // Peak selection, leading-bit encoding, height lookup and the large
        // display-bank write fanout each get their own 52.5 MHz cycle.
        14: begin completed_code<=magnitude_code(completed_magnitude);state<=16;end
        16: begin completed_height<=code_height(completed_code);state<=17;end
        17: begin
            band<=band+1'b1;
            if(frequency_bin==511) state<=15;
            else begin frequency_bin<=frequency_bin+1'b1;state<=11;end
        end
        15: if(frame_blank) begin
            bank<=~bank;display_valid<=1;display_shift<=gain_shift(peak);
            capture_index<=0;peak<=0;state<=0;
        end
        default: state<=0;
    endcase
endmodule
