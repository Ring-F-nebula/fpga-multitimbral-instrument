`timescale 1ns/1ps
// Run with +define+FSR_ORIGINAL only against the unmodified uploaded source
// to demonstrate the failure. A normal run must remain silent throughout.
module tb_fsr_idle_regression;
    reg clk=0;always #5 clk=~clk;
    reg reset_n=0,toggle=0,online=0;
    reg [223:0] samples={16{14'd400}};
    wire [15:0] keys;
    fsr_keyboard #(.STALE_CYCLES(5000)) dut(.clk(clk),.reset_n(reset_n),.sample_tick(1'b0),
`ifndef FSR_ORIGINAL
        .recalibrate(1'b0),
`endif
        .samples_async(samples),.peak_async(14'd400),.frame_toggle_async(toggle),.online_async(online),.keys(keys));
    task publish;
        @(negedge clk);toggle=~toggle;repeat(30) @(negedge clk);
    endtask
    initial begin
        repeat(3) @(negedge clk);reset_n=1;online=1;
        repeat(5) @(negedge clk);
        repeat(34) publish();
        if(keys) $fatal(1,"idle before low outlier");
        samples[0 +:14]=100;publish();
        samples[0 +:14]=400;publish();publish();
`ifdef FSR_ORIGINAL
        if(keys!=1) $fatal(1,"old-source regression was not reproduced");
        $display("PASS reproduced ORIGINAL defect: idle 400 -> low outlier 100 -> idle 400 creates K=0001 without a press");
`else
        if(keys) $fatal(1,"idle recovery was misread as pressure");
        samples[0 +:14]=1200;publish();
        if(keys) $fatal(1,"isolated large ADC spike sounded");
        samples[0 +:14]=400;publish();
        if(keys) $fatal(1,"spike returned to idle but gate remains");
        $display("PASS fixed idle regression: low outlier + return to calibrated idle and isolated large spike cannot create notes");
`endif
        $finish;
    end
endmodule
