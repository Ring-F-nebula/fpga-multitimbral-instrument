`timescale 1ns/1ps
module tb_i2s;
    reg clk=0;
    // Close to nominal; assertions count source cycles, not rounded times.
    always #19.047619 clk=~clk;
    reg signed [15:0] pcm_next=16'h6da3;
    wire bck,ws,din,sample_tick;
    i2s_tx dut(clk,pcm_next,bck,ws,din,sample_tick);

    integer cycle=0, ticks=0, last_tick=0;
    reg [15:0] expected[0:259];
    integer expected_count=0;
    integer last_bck_edge=0;
    reg [31:0] random_state=32'h76db4563;
    reg [15:0] captured;
    reg old_bck=0,old_ws=0,old_din=0;

    function [15:0] vector_value(input integer n);
        begin
            case(n)
                0:vector_value=0;
                1:vector_value=1;
                2:vector_value=16'hffff;
                3:vector_value=16'h8000;
                4:vector_value=16'h7fff;
                5:vector_value=16'haaaa;
                6:vector_value=16'h5555;
                7:vector_value=16'h0001;
                8:vector_value=16'h8000;
                default:vector_value=random_state[15:0];
            endcase
        end
    endfunction

    // The producer changes every source cycle, including all mid-word cycles.
    // Only a change held over sample_tick is expected to enter either channel.
    always @(negedge clk) begin
        random_state={random_state[30:0],random_state[31]^random_state[21]^random_state[1]^random_state[0]};
        if((cycle+1)>=18 && (((cycle+1)-18)%576)==0)
            pcm_next=(ticks==0) ? 16'h6da3 : vector_value(ticks-1);
        else pcm_next=random_state[15:0];
    end

    // Capture the accepted source word without using any internal DUT state.
    always @(posedge clk) begin
        cycle=cycle+1;
        if(sample_tick) begin
            if(ticks==0 && cycle!=18) $fatal(1,"First tick must match PT8211 edge at source cycle 18");
            if(ticks!=0 && cycle-last_tick!=576) $fatal(1,"Frame is not 576 source cycles");
            last_tick=cycle;
            captured=pcm_next;
            // The initial unframed I2S half-frame is deliberately all zero.
            if(ticks!=0) begin expected[expected_count]=captured; expected_count=expected_count+1; end
            ticks=ticks+1;
        end
        #1;
        if(bck!==old_bck) begin
            if(cycle-last_bck_edge!=9) $fatal(1,"BCK half period must be 9 source cycles");
            last_bck_edge=cycle;
        end
        if(ws!==old_ws || din!==old_din)
            if(!(old_bck===1'b1 && bck===1'b0))
                $fatal(1,"WS/DIN changed away from falling BCK");
        old_bck=bck; old_ws=ws; old_din=din;
    end

    // Independent receiver: recover word boundaries ONLY from WS changes.
    // At a WS change, DIN is still the previous word's LSB. MSB is next edge.
    reg rx_old_ws=0,rx_channel=0;
    reg receiving=0;
    reg [15:0] word_value=0,left_value=0;
    integer bit_count=0,frames_checked=0,words_checked=0;
    integer rising_count=0,last_ws_edge=0;
    reg got_ws=0,got_left=0;
    always @(posedge bck) begin
        rising_count=rising_count+1;
        if(receiving) begin
            word_value={word_value[14:0],din};
            bit_count=bit_count+1;
            if(bit_count==16) begin
                if(ws===rx_old_ws) $fatal(1,"16th bit must share next WS transition");
                receiving=0;
                words_checked=words_checked+1;
                if(!rx_channel) begin
                    if(frames_checked>=expected_count) $fatal(1,"Missing input scoreboard frame");
                    if(word_value!==expected[frames_checked])
                        $fatal(1,"Left frame %0d got %04h expected %04h",frames_checked,word_value,expected[frames_checked]);
                    left_value=word_value; got_left=1;
                end else if(got_left) begin
                    if(word_value!==left_value || word_value!==expected[frames_checked])
                        $fatal(1,"Right frame %0d mismatch %04h/%04h",frames_checked,word_value,left_value);
                    frames_checked=frames_checked+1; got_left=0;
                    if(frames_checked==256) begin
                        $display("PASS tb_i2s: 256 complete stereo frames, signed boundaries/random, left=right atomic sample, one-bit WS lead, LSB retained, 576-cycle frame, falling-edge-only changes");
                        $finish;
                    end
                end else if(word_value!==16'h0000)
                    $fatal(1,"Initial right half-frame must be zero");
            end
        end
        if(ws!==rx_old_ws) begin
            if(got_ws && rising_count-last_ws_edge!=16)
                $fatal(1,"WS must change every 16 BCK rising edges");
            if(receiving) $fatal(1,"WS changed before all 16 bits arrived");
            got_ws=1; last_ws_edge=rising_count;
            rx_channel=ws; word_value=0; bit_count=0; receiving=1;
        end
        rx_old_ws=ws;
    end
    initial begin
        #10000000;
        $fatal(1,"I2S timeout");
    end
endmodule
