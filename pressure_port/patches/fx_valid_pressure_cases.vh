// INSERT these cases INSIDE the MAIN project's case(id) in fx_valid.
// Check command-ID conflicts first. Do not replace the entire fx_protocol.vh.
// This patch is NOT applied to frozen src/ or the delivered baseline .fs.
        8'h70: fx_valid=(value==1);
        8'h71,8'h72,8'h73,8'h74,8'h75,8'h76,8'h77: fx_valid=1;
        8'h78,8'h79: fx_valid=(value<=1);
        8'h7a: fx_valid=(value==1||value==2||value==3||value==7||value==8);
