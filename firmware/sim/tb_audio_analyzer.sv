`timescale 1ns/1ps
module tb_audio_analyzer;
    reg clk=0,audio_clk=0;
    always #5 clk=~clk;
    always #10 audio_clk=~audio_clk;
    reg [9:0] divider=0;
    always @(posedge audio_clk) divider<=divider==575?0:divider+1'b1;
    wire tick=divider==0;
    reg signed [15:0] pcm=0;
    integer kind=0,number=0;
    real signal_value;
    always @(negedge audio_clk) if(divider==575) begin
        number=number+1;
        case(kind)
            0:signal_value=12000*$sin(6.283185307179586*2*number/1024.0);
            1:signal_value=12000*$sin(6.283185307179586*23*number/1024.0);
            2:signal_value=12000*$sin(6.283185307179586*200*number/1024.0);
            3:signal_value=8000*$sin(6.283185307179586*3*number/1024.0)+
                           6000*$sin(6.283185307179586*73*number/1024.0);
            4:signal_value=0;
            5:signal_value=-32768;
            6:signal_value=15000*$sin(6.283185307179586*23.4*number/1024.0);
            default:signal_value=0;
        endcase
        pcm=$rtoi(signal_value);
    end
    reg blank=0;
    reg [7:0] wave_address=0;
    reg [5:0] band_address=0;
    wire [7:0] low,high;
    wire [6:0] height;
    wire valid;
    audio_analyzer dut(clk,audio_clk,tick,pcm,blank,wave_address,band_address,low,high,height,valid);
    integer input_file,fft_file,case_id,peak_bin,peak_mag,mag;
    integer saved_bank;
    function integer absolute;
        input integer value;
        begin absolute=value<0?-value:value;end
    endfunction
    always @(posedge clk) if(dut.state==0 && dut.new_sample)
        $fdisplay(input_file,"%0d",$signed(dut.audio_hold));
    initial begin
        input_file=$fopen("analyzer_input_0.raw","w");
        for(case_id=0;case_id<7;case_id=case_id+1) begin
            wait(dut.state==15);@(negedge clk);
            $fclose(input_file);
            fft_file=$fopen($sformatf("analyzer_fft_%0d.raw",case_id),"w");
            peak_mag=0;peak_bin=0;
            for(integer k=0;k<1024;k=k+1) begin
                $fdisplay(fft_file,"%0d %0d",$signed(dut.fft_real[k]),$signed(dut.fft_imag[k]));
                if(k>0 && k<512) begin
                    mag=absolute($signed(dut.fft_real[k]))+absolute($signed(dut.fft_imag[k]));
                    if(mag>peak_mag) begin peak_mag=mag;peak_bin=k;end
                end
            end
            $fclose(fft_file);
            if(case_id==0 && peak_bin!=2) $fatal(1,"bass FFT peak %d",peak_bin);
            if(case_id==1 && peak_bin!=23) $fatal(1,"mid FFT peak %d",peak_bin);
            if(case_id==2 && peak_bin!=200) $fatal(1,"treble FFT peak %d",peak_bin);
            if(case_id==3 && peak_bin!=3) $fatal(1,"two-tone FFT peak %d",peak_bin);
            if(case_id==4 && peak_mag!=0) $fatal(1,"silence FFT nonzero");
            if(case_id==6 && peak_bin!=23) $fatal(1,"off-bin FFT peak %d",peak_bin);
            saved_bank=dut.bank;
            repeat(50) @(negedge clk);
            if(dut.bank!=saved_bank) $fatal(1,"bank swapped outside blanking");
            blank=1;@(negedge clk);blank=0;
            if(!valid || dut.bank==saved_bank) $fatal(1,"no publication at blanking");
            for(integer k=0;k<256;k=k+1) begin
                wave_address=k;band_address=k%64;repeat(2) @(negedge clk);
                if($isunknown({low,high,height}) || low<21 || high>99 || low>high || height>88)
                    $fatal(1,"invalid waveform/spectrum bounds");
                if(case_id==4 && (low!=60 || high!=60 || height!=0)) $fatal(1,"silence did not clear");
            end
            $display("PASS analyzer case %0d peak bin %0d, coherent publication and bounded waveform",case_id,peak_bin);
            // Current capture may have begun while scanning: let it finish,
            // change the stimulus, and discard one complete settling block.
            if(case_id<6) begin
                kind=case_id+1;
                input_file=$fopen("analyzer_discard.raw","w");
                wait(dut.state==15);@(negedge clk);
                blank=1;@(negedge clk);blank=0;
                $fclose(input_file);
                input_file=$fopen($sformatf("analyzer_input_%0d.raw",case_id+1),"w");
            end
        end
        $display("PASS actual PCM FFT: bass/mid/treble/two tones/silence/full-negative/off-bin; frame swap, AGC, all bars");
        $finish;
    end
    initial begin #400000000;$fatal(1,"analyzer timeout");end
endmodule
