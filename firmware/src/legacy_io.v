// Existing verified keyboard/encoder/UART input modules, unchanged protocol.

// PC protocol at 115200 8N1: 0x90..9F key down, 0x80..8F key up,
// 0xF0 all off, 0xF4 keepalive. If the app/cable stops, notes release.
module pc_key_receiver (
    input wire clk,
    input wire uart_rx,
    output reg [15:0] pressed = 16'b0
);
    wire [7:0] byte_data;
    wire byte_valid;
    uart_rx_8n1 receiver (.clk(clk), .rx(uart_rx),
                          .data(byte_data), .valid(byte_valid));
    reg [24:0] silence_count = 0;
    always @(posedge clk) begin
        if (byte_valid) begin
            silence_count <= 0;
            if (byte_data[7:4] == 4'h9)
                pressed[byte_data[3:0]] <= 1'b1;
            else if (byte_data[7:4] == 4'h8)
                pressed[byte_data[3:0]] <= 1'b0;
            else if (byte_data == 8'hf0)
                pressed <= 0;
        end else if (silence_count == 25'd26249999) begin
            pressed <= 0; // 1 s communication watchdog
        end else silence_count <= silence_count + 1'b1;
    end
endmodule

module uart_rx_8n1 (
    input wire clk,
    input wire rx,
    output reg [7:0] data = 0,
    output reg valid = 0
);
    // 26.25 MHz / 228 = 115131.58 baud, -0.0594% from 115200.
    reg [2:0] rx_sync = 3'b111;
    reg [1:0] state = 0;
    reg [7:0] count = 0;
    reg [2:0] bit_no = 0;
    reg [7:0] shift = 0;
    always @(posedge clk) begin
        rx_sync <= {rx_sync[1:0], rx};
        valid <= 0;
        case (state)
            0: if (!rx_sync[2]) begin
                count <= 8'd113; // middle of start bit
                state <= 1;
            end
            1: if (count == 0) begin
                if (!rx_sync[2]) begin
                    count <= 8'd227;
                    bit_no <= 0;
                    state <= 2;
                end else state <= 0;
            end else count <= count - 1'b1;
            2: if (count == 0) begin
                shift[bit_no] <= rx_sync[2];
                count <= 8'd227;
                if (bit_no == 7) state <= 3;
                else bit_no <= bit_no + 1'b1;
            end else count <= count - 1'b1;
            3: if (count == 0) begin
                if (rx_sync[2]) begin
                    data <= shift;
                    valid <= 1;
                end
                state <= 0;
            end else count <= count - 1'b1;
        endcase
    end
endmodule

module matrix4x4 (
    input wire clk,
    inout wire [3:0] row_n,
    input wire [3:0] col_n,
    output wire [15:0] pressed
);
    reg [3:0] col_ff1 = 4'hf;
    reg [3:0] col_ff2 = 4'hf;
    always @(posedge clk) begin
        col_ff1 <= col_n;
        col_ff2 <= col_ff1;
    end
    reg [1:0] row = 0;
    reg [11:0] dwell = 0;
    reg [15:0] frame_rows = 0;
    wire [15:0] full_frame = {~col_ff2, frame_rows[11:0]};
    // Non-selected rows must float: driving them high would short GPIO outputs
    // through multiple simultaneously pressed keys.
    genvar r;
    generate for (r=0; r<4; r=r+1) begin : row_drive
        assign row_n[r] = (row == r) ? 1'b0 : 1'bz;
    end endgenerate
    genvar j;
    generate for (j=0; j<16; j=j+1) begin : db
        reg stable = 0;
        reg [1:0] difference = 0;
        always @(posedge clk) if (dwell == 2699 && row == 3) begin
            if (full_frame[j] == stable) difference <= 0;
            else if (difference == 2) begin
                stable <= full_frame[j];
                difference <= 0;
            end else difference <= difference + 1'b1;
        end
        assign pressed[j] = stable;
    end endgenerate
    always @(posedge clk) begin
        if (dwell == 2699) begin
            dwell <= 0;
            frame_rows[row*4 +: 4] <= ~col_ff2;
            row <= row + 1'b1;
        end else dwell <= dwell + 1'b1;
    end
endmodule

module rotary_volume (
    input wire clk,
    input wire a_n,
    input wire b_n,
    output reg [3:0] level = 4'd8
);
    reg [1:0] q1 = 2'b11;
    reg [1:0] q2 = 2'b11;
    reg [1:0] qstable = 2'b11;
    reg [1:0] qprevious = 2'b11;
    reg [9:0] settle = 0;
    reg signed [3:0] steps = 0;
    always @(posedge clk) begin
        q1 <= {a_n,b_n};
        q2 <= q1;
        if (q2 == qstable) settle <= 0;
        else if (settle == 539) begin
            qstable <= q2; // 20 us digital filter
            settle <= 0;
        end else settle <= settle + 1'b1;

        if (qstable != qprevious) begin
            qprevious <= qstable;
            case ({qprevious,qstable})
                4'b1101,4'b0100,4'b0010,4'b1011: begin
                    if (qstable == 2'b11) begin
                        if (steps >= 2 && level != 15) level <= level + 1'b1;
                        steps <= 0;
                    end else steps <= steps + 1'b1;
                end
                4'b1110,4'b1000,4'b0001,4'b0111: begin
                    if (qstable == 2'b11) begin
                        if (steps <= -2 && level != 0) level <= level - 1'b1;
                        steps <= 0;
                    end else steps <= steps - 1'b1;
                end
                default: steps <= 0;
            endcase
        end
    end
endmodule
