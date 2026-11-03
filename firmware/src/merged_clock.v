`timescale 1ns / 1ps

// GW5AST PLL: external 50 MHz SOM oscillator -> 1050 MHz VCO -> 52.5 MHz.
// Fout = 50 * FBDIV(1) * MDIV(42) / IDIV(2) / ODIV(20).
module merged_clock (
    input  wire clkin,
    output wire clkout,
    output wire locked
);
    wire clkout1;
    wire clkout2;
    wire clkout3;
    wire clkout4;
    wire clkout5;
    wire clkout6;
    wire clkfbout;
    wire gw_vcc;
    wire gw_gnd;

    assign gw_vcc = 1'b1;
    assign gw_gnd = 1'b0;

    PLL pll_inst (
        .LOCK(locked),
        .CLKOUT0(clkout),
        .CLKOUT1(clkout1), .CLKOUT2(clkout2), .CLKOUT3(clkout3),
        .CLKOUT4(clkout4), .CLKOUT5(clkout5), .CLKOUT6(clkout6),
        .CLKFBOUT(clkfbout),
        .CLKIN(clkin), .CLKFB(gw_gnd), .RESET(gw_gnd),
        .PLLPWD(gw_gnd), .RESET_I(gw_gnd), .RESET_O(gw_gnd),
        .FBDSEL(6'b0), .IDSEL(6'b0), .MDSEL(7'b0), .MDSEL_FRAC(3'b0),
        .ODSEL0(7'b0), .ODSEL0_FRAC(3'b0), .ODSEL1(7'b0),
        .ODSEL2(7'b0), .ODSEL3(7'b0), .ODSEL4(7'b0),
        .ODSEL5(7'b0), .ODSEL6(7'b0),
        .DT0(4'b0), .DT1(4'b0), .DT2(4'b0), .DT3(4'b0),
        .ICPSEL(6'b0), .LPFRES(3'b0), .LPFCAP(2'b0),
        .PSSEL(3'b0), .PSDIR(gw_gnd), .PSPULSE(gw_gnd),
        .ENCLK0(gw_vcc), .ENCLK1(gw_vcc), .ENCLK2(gw_vcc),
        .ENCLK3(gw_vcc), .ENCLK4(gw_vcc), .ENCLK5(gw_vcc),
        .ENCLK6(gw_vcc), .SSCPOL(gw_gnd), .SSCON(gw_gnd),
        .SSCMDSEL(7'b0), .SSCMDSEL_FRAC(3'b0)
    );

    defparam pll_inst.FCLKIN = "50";
    defparam pll_inst.IDIV_SEL = 2;
    defparam pll_inst.FBDIV_SEL = 1;
    defparam pll_inst.MDIV_SEL = 42;
    defparam pll_inst.MDIV_FRAC_SEL = 0;
    defparam pll_inst.ODIV0_SEL = 20;
    defparam pll_inst.ODIV0_FRAC_SEL = 0;
    defparam pll_inst.ODIV1_SEL = 8;
    defparam pll_inst.ODIV2_SEL = 8;
    defparam pll_inst.ODIV3_SEL = 8;
    defparam pll_inst.ODIV4_SEL = 8;
    defparam pll_inst.ODIV5_SEL = 8;
    defparam pll_inst.ODIV6_SEL = 8;
    defparam pll_inst.CLKOUT0_EN = "TRUE";
    defparam pll_inst.CLKOUT1_EN = "FALSE";
    defparam pll_inst.CLKOUT2_EN = "FALSE";
    defparam pll_inst.CLKOUT3_EN = "FALSE";
    defparam pll_inst.CLKOUT4_EN = "FALSE";
    defparam pll_inst.CLKOUT5_EN = "FALSE";
    defparam pll_inst.CLKOUT6_EN = "FALSE";
    defparam pll_inst.CLKFB_SEL = "INTERNAL";
    defparam pll_inst.CLKOUT0_DT_DIR = 1'b1;
    defparam pll_inst.CLKOUT1_DT_DIR = 1'b1;
    defparam pll_inst.CLKOUT2_DT_DIR = 1'b1;
    defparam pll_inst.CLKOUT3_DT_DIR = 1'b1;
    defparam pll_inst.CLKOUT0_DT_STEP = 0;
    defparam pll_inst.CLKOUT1_DT_STEP = 0;
    defparam pll_inst.CLKOUT2_DT_STEP = 0;
    defparam pll_inst.CLKOUT3_DT_STEP = 0;
    defparam pll_inst.CLK0_IN_SEL = 1'b0;
    defparam pll_inst.CLK0_OUT_SEL = 1'b0;
    defparam pll_inst.CLK1_IN_SEL = 1'b0;
    defparam pll_inst.CLK1_OUT_SEL = 1'b0;
    defparam pll_inst.CLK2_IN_SEL = 1'b0;
    defparam pll_inst.CLK2_OUT_SEL = 1'b0;
    defparam pll_inst.CLK3_IN_SEL = 1'b0;
    defparam pll_inst.CLK3_OUT_SEL = 1'b0;
    defparam pll_inst.CLK4_IN_SEL = 2'b00;
    defparam pll_inst.CLK4_OUT_SEL = 1'b0;
    defparam pll_inst.CLK5_IN_SEL = 1'b0;
    defparam pll_inst.CLK5_OUT_SEL = 1'b0;
    defparam pll_inst.CLK6_IN_SEL = 1'b0;
    defparam pll_inst.CLK6_OUT_SEL = 1'b0;
    defparam pll_inst.DYN_DPA_EN = "FALSE";
    defparam pll_inst.CLKOUT0_PE_COARSE = 0;
    defparam pll_inst.CLKOUT0_PE_FINE = 0;
    defparam pll_inst.CLKOUT1_PE_COARSE = 0;
    defparam pll_inst.CLKOUT1_PE_FINE = 0;
    defparam pll_inst.CLKOUT2_PE_COARSE = 0;
    defparam pll_inst.CLKOUT2_PE_FINE = 0;
    defparam pll_inst.CLKOUT3_PE_COARSE = 0;
    defparam pll_inst.CLKOUT3_PE_FINE = 0;
    defparam pll_inst.CLKOUT4_PE_COARSE = 0;
    defparam pll_inst.CLKOUT4_PE_FINE = 0;
    defparam pll_inst.CLKOUT5_PE_COARSE = 0;
    defparam pll_inst.CLKOUT5_PE_FINE = 0;
    defparam pll_inst.CLKOUT6_PE_COARSE = 0;
    defparam pll_inst.CLKOUT6_PE_FINE = 0;
    defparam pll_inst.DYN_PE0_SEL = "FALSE";
    defparam pll_inst.DYN_PE1_SEL = "FALSE";
    defparam pll_inst.DYN_PE2_SEL = "FALSE";
    defparam pll_inst.DYN_PE3_SEL = "FALSE";
    defparam pll_inst.DYN_PE4_SEL = "FALSE";
    defparam pll_inst.DYN_PE5_SEL = "FALSE";
    defparam pll_inst.DYN_PE6_SEL = "FALSE";
    defparam pll_inst.DE0_EN = "FALSE";
    defparam pll_inst.DE1_EN = "FALSE";
    defparam pll_inst.DE2_EN = "FALSE";
    defparam pll_inst.DE3_EN = "FALSE";
    defparam pll_inst.DE4_EN = "FALSE";
    defparam pll_inst.DE5_EN = "FALSE";
    defparam pll_inst.DE6_EN = "FALSE";
    defparam pll_inst.RESET_I_EN = "FALSE";
    defparam pll_inst.RESET_O_EN = "FALSE";
    defparam pll_inst.ICP_SEL = 6'bXXXXXX;
    defparam pll_inst.LPF_RES = 3'bXXX;
    defparam pll_inst.LPF_CAP = 2'b00;
    defparam pll_inst.SSC_EN = "FALSE";
    defparam pll_inst.DYN_IDIV_SEL = "FALSE";
    defparam pll_inst.DYN_FBDIV_SEL = "FALSE";
    defparam pll_inst.DYN_MDIV_SEL = "FALSE";
    defparam pll_inst.DYN_ODIV0_SEL = "FALSE";
    defparam pll_inst.DYN_ODIV1_SEL = "FALSE";
    defparam pll_inst.DYN_ODIV2_SEL = "FALSE";
    defparam pll_inst.DYN_ODIV3_SEL = "FALSE";
    defparam pll_inst.DYN_ODIV4_SEL = "FALSE";
    defparam pll_inst.DYN_ODIV5_SEL = "FALSE";
    defparam pll_inst.DYN_ODIV6_SEL = "FALSE";
    defparam pll_inst.DYN_DT0_SEL = "FALSE";
    defparam pll_inst.DYN_DT1_SEL = "FALSE";
    defparam pll_inst.DYN_DT2_SEL = "FALSE";
    defparam pll_inst.DYN_DT3_SEL = "FALSE";
    defparam pll_inst.DYN_ICP_SEL = "FALSE";
    defparam pll_inst.DYN_LPF_SEL = "FALSE";
endmodule
