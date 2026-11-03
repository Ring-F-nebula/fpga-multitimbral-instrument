module fx_registers(input clk, reset_n,
    input usb_commit,bt_commit,input [7:0] usb_id,usb_value,bt_id,bt_value,
    input ui_commit,input [7:0] ui_id,ui_value,
    input stopped,output [127:0] snapshot,output reg [7:0] revision=0);
    `include "fx_protocol.vh"
    `include "fx_defaults.vh"
    // Byte 0 = ID 10; byte 14 = ID 1E. Byte 15 is actual STOP readback.
    localparam [119:0] DEFAULTS={fx_default_byte(4'd14),fx_default_byte(4'd13),fx_default_byte(4'd12),
        fx_default_byte(4'd11),fx_default_byte(4'd10),fx_default_byte(4'd9),fx_default_byte(4'd8),
        fx_default_byte(4'd7),fx_default_byte(4'd6),fx_default_byte(4'd5),fx_default_byte(4'd4),
        fx_default_byte(4'd3),fx_default_byte(4'd2),fx_default_byte(4'd1),fx_default_byte(4'd0)};
    reg [119:0] values=DEFAULTS;
    assign snapshot={7'd0,stopped,values};
    wire u=usb_commit && usb_id>=8'h10 && usb_id<=8'h1f && fx_valid(usb_id,usb_value);
    wire b=bt_commit && bt_id>=8'h10 && bt_id<=8'h1f && fx_valid(bt_id,bt_value);
    wire c=(ui_commit===1'b1) && ui_id>=8'h10 && ui_id<=8'h1f && fx_valid(ui_id,ui_value);
    always @(posedge clk) begin
        if(!reset_n) begin values<=DEFAULTS; revision<=0; end
        else begin
            if(u && usb_id!=8'h1f) values[(usb_id-8'h10)*8+:8]<=usb_value;
            if(b && bt_id!=8'h1f) values[(bt_id-8'h10)*8+:8]<=bt_value;
            if(c && ui_id!=8'h1f) values[(ui_id-8'h10)*8+:8]<=ui_value;
            if(u || b || c) revision<=revision+{7'd0,u}+{7'd0,b}+{7'd0,c};
        end
    end
endmodule
