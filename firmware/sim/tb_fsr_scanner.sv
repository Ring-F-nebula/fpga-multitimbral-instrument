`timescale 1ns/1ps
module tb_fsr_scanner;
    reg clk=0; always #5 clk=~clk;
    reg reset_n=0,adc_ready=0;
    reg [13:0] adc_value=0;
    wire request,adc_reset_n,enable_n,frame_toggle,online,fault;
    wire [3:0] select;
    wire [13:0] peak;
    wire [223:0] samples;
    fsr_scanner #(.SETTLE_CYCLES(20),.REQUEST_CYCLES(16),.TIMEOUT_CYCLES(150))
        dut(.clk(clk),.reset_n(reset_n),.adc_ready(adc_ready),.adc_value(adc_value),
        .adc_request(request),.adc_reset_n(adc_reset_n),.select(select),
        .enable_n(enable_n),.peak(peak),.samples(samples),.frame_toggle(frame_toggle),.online(online),.fault(fault));
    reg [13:0] codes[0:15];
    integer mode=0,remaining=0,requests=0,settled=0;
    reg previous_request=0,previous_enable=1;
    reg [3:0] previous_select=0,pending_select=0,expected_select=0;
    always @(posedge clk) begin
        if(!reset_n || !adc_reset_n) begin
            adc_ready<=0; previous_request<=0; remaining<=0;
            settled=0; previous_enable=1; expected_select=0;
        end else begin
            if(enable_n || previous_enable || select!=previous_select) settled=0;
            else settled=settled+1;
            previous_enable=enable_n; previous_select=select;
            previous_request<=request;
            if(mode==2) adc_ready<=1; // A stale high is not a new conversion.
            else if(request && !previous_request) begin
                if(enable_n || settled<20) $fatal(1,"mux not settled: %0d",settled);
                if(select!==expected_select) $fatal(1,"channel order %0d/%0d",select,expected_select);
                expected_select=expected_select+1'b1;
                pending_select<=select; requests=requests+1;
                adc_ready<=0; remaining<=40;
            end else if(remaining>0 && mode==0) begin
                remaining<=remaining-1;
                if(remaining==1) begin adc_ready<=1; adc_value<=codes[pending_select]; end
                if(select!==pending_select) $fatal(1,"mux changed before conversion completed");
            end
        end
    end
    task clocks(input integer n); repeat(n) @(negedge clk); endtask
    task next_frame;
        reg previous;
        previous=frame_toggle;
        while(frame_toggle===previous) @(negedge clk);
    endtask
    initial begin
        for(integer k=0;k<16;k=k+1) codes[k]=k*100;
        clocks(4); reset_n=1; clocks(100);
        if(peak!=0 || online) $fatal(1,"partial sweep leaked");
        next_frame();
        if(!online || fault || peak!=1500 || requests!=16) $fatal(1,"first complete peak");
        for(integer k=0;k<16;k=k+1)
            if(samples[k*14 +: 14]!=k*100) $fatal(1,"per-channel scan payload %0d",k);
        for(integer k=0;k<16;k=k+1) codes[k]=0;
        codes[5]=712; next_frame();
        if(peak!=712 || requests!=32) $fatal(1,"old peak retained or wrong channel max");
        mode=1; clocks(350);
        if(!fault || online || peak!=0) $fatal(1,"missing EOC did not mute");
        mode=0; next_frame();
        if(fault || !online || peak!=712) $fatal(1,"ADC retry recovery");
        mode=2; clocks(500);
        if(!fault || online || peak!=0) $fatal(1,"stale ready high accepted");
        mode=0; next_frame();
        if(fault || !online || peak!=712) $fatal(1,"stale-ready recovery");
        reset_n=0; clocks(2);
        if(!enable_n || request || adc_reset_n || peak!=0 || online) $fatal(1,"reset");
        $display("PASS FSR scanner: 16-channel order, mux settle, stable conversion channel, atomic max, peak release, missing/stale EOC rejection, mute, ADC reset/retry");
        $finish;
    end
    initial begin #1000000; $fatal(1,"scanner timeout"); end
endmodule
