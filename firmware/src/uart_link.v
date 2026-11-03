// 0x55 training measures the physical bit time, including debugger scaling.
// Without training the legacy 115200 protocol still defaults to 228 clocks.
// Configuration: F5, id, value, XOR(F5,id,value). Only a complete valid
// packet updates a register. A stalled packet expires after 10 ms nominal.
module uart_link #(parameter integer CONFIG_TIMEOUT=262500, parameter integer DEFAULT_BIT_CLOCKS=228, parameter integer KEY_TIMEOUT=26250000, parameter integer ALLOW_LEGACY_KEYS=1)(input clk,input rx,
    output reg [15:0] upper_pressed=0,output reg [15:0] pressed=0,output reg [15:0] rx_count=0,
    output reg [7:0] last_byte=0,output reg [15:0] edges=0,
    output reg [11:0] bit_clocks=DEFAULT_BIT_CLOCKS,output reg trained=0,
    output reg [3:0] attack_sel=2,decay_sel=5,release_sel=5,volume=8,
    output reg [7:0] sustain_level=160,param_count=0,
    output reg volume_event=0,
    output reg config_commit=0, output reg [7:0] committed_id=0,committed_value=0,
    output reg mode_event=0,output reg mode_auto=0);
    `include "fx_protocol.vh"
    reg [2:0] sync=3'b111;
    reg previous=1;
    reg [12:0] width=0;
    reg [11:0] candidate=228;
    reg [5:0] match_count=0;
    reg [3:0] uniform_run=0;
    reg [18:0] width_sum=0;
    reg [17:0] idle_clocks=0;
    reg training_armed=1;
    reg baud_changed=0;
    wire edge_seen=(previous!=sync[2]);
    wire [12:0] interval=width+1'b1;
    wire close_match=interval>=candidate-2 && interval<=candidate+2;
    wire [18:0] full_sum=width_sum+interval;
    always @(posedge clk) begin
        sync<={sync[1:0],rx}; previous<=sync[2]; baud_changed<=0;
        if(!sync[2]) idle_clocks<=0;
        else if(idle_clocks!=18'h3ffff) idle_clocks<=idle_clocks+1'b1;
        // Reconnect after 32 idle bit periods. A 55 byte has nine equal
        // intervals, but real serial modules may pause between bytes.
        // Count 64 uniform intervals, allowing a long boundary only after
        // at least eight in-byte intervals; never average that idle gap.
        if(idle_clocks=={1'b0,bit_clocks,5'b0}) begin
            training_armed<=1; match_count<=0; width_sum<=0;uniform_run<=0;
        end
        if(edge_seen) begin
            edges<=edges+1'b1; width<=0;
            if(training_armed && match_count!=0 && uniform_run>=8 && interval>candidate+2)begin
                // Idle may exceed the measurable bit-period range. It is
                // excluded from the average, even if width has saturated.
                uniform_run<=0;
            end else if(training_armed && interval>=32 && interval<=4095) begin
                if(match_count!=0 && close_match) begin
                    if(match_count==63) begin
                        bit_clocks<=full_sum[17:6]; trained<=1;
                        baud_changed<=1; match_count<=0; width_sum<=0;
                        training_armed<=0;
                    end else begin match_count<=match_count+1'b1; width_sum<=full_sum; end
                    if(uniform_run!=15)uniform_run<=uniform_run+1'b1;
                end else begin candidate<=interval[11:0]; match_count<=1; width_sum<=interval;uniform_run<=1; end
            end else begin match_count<=0; width_sum<=0;uniform_run<=0; end
        end else if(width!=8191) width<=width+1'b1;
    end
    reg [1:0] state=0;
    reg [11:0] count=0;
    reg [2:0] bit_index=0;
    reg [7:0] shift=0;
    reg [31:0] watchdog=0;
    reg note_frame=0,wide_frame=0;reg [7:0] upper_lo=0,upper_hi=0;
    reg [2:0] config_state=0;
    reg [7:0] config_id=0,config_value=0;
    reg [31:0] config_timer=0;
    reg training_hold=0;
    always @(posedge clk) begin
        volume_event<=0; config_commit<=0; mode_event<=0;
        if(watchdog==KEY_TIMEOUT-1)begin pressed<=0;upper_pressed<=0;end
        else watchdog<=watchdog+1'b1;
        if(config_state!=0) begin
            if(config_timer==CONFIG_TIMEOUT-1) begin
                config_state<=0; config_timer<=0;
            end else config_timer<=config_timer+1'b1;
        end else config_timer<=0;
        if(baud_changed) begin
            state<=0; pressed<=0;upper_pressed<=0; config_state<=0; config_timer<=0;
            training_hold<=1;
        end else if(training_hold) begin
            // Do not decode the remainder of a training burst from its
            // middle: its last partial 55 byte could otherwise look like F5.
            // Host leaves at least two idle bit periods after training.
            state<=0; config_state<=0; config_timer<=0;
            if(idle_clocks>={5'd0,bit_clocks,1'b0}) training_hold<=0;
        end
        else case(state)
            0: if(!sync[2]) begin count<=(bit_clocks>>1)-1'b1; state<=1; end
            1: if(count!=0) count<=count-1'b1;
               else if(sync[2]) state<=0;
               else begin count<=bit_clocks-1'b1; bit_index<=0; state<=2; end
            2: if(count!=0) count<=count-1'b1;
               else begin
                   shift[bit_index]<=sync[2]; count<=bit_clocks-1'b1;
                   if(bit_index==7) state<=3; else bit_index<=bit_index+1'b1;
               end
            3: if(count!=0) count<=count-1'b1;
               else begin
                   state<=0;
                   if(sync[2]) begin
                       rx_count<=rx_count+1'b1; last_byte<=shift;
                       config_timer<=0;
                       case(config_state)
                           0: begin
                               if(shift==8'hf5 || shift==8'hf6 || shift==8'hf7) begin config_state<=1; note_frame<=(shift!=8'hf5);wide_frame<=(shift==8'hf7); end
                               else if(ALLOW_LEGACY_KEYS && shift[7:4]==9) begin pressed[shift[3:0]]<=1; watchdog<=0; end
                               else if(ALLOW_LEGACY_KEYS && shift[7:4]==8) begin pressed[shift[3:0]]<=0; watchdog<=0; end
                               else if(ALLOW_LEGACY_KEYS && shift==8'hf0) begin pressed<=0;upper_pressed<=0; watchdog<=0; end
                           end
                           1: begin config_id<=shift; config_state<=2; end
                           2: begin config_value<=shift; config_state<=3; end
                           3: if(wide_frame)begin upper_lo<=shift;config_state<=4;end else begin
                               config_state<=0;
                               if(shift==((note_frame ? 8'hf6 : 8'hf5)^config_id^config_value)) begin
                                   if(note_frame) begin pressed<={config_value,config_id};upper_pressed<=0; watchdog<=0; end
                                   else begin
                                   if((config_id==1 && config_value<=9) ||
                                      (config_id==2 && config_value<=9) || config_id==3 ||
                                      (config_id==4 && config_value<=9) ||
                                      (config_id==5 && config_value<=15) || fx_valid(config_id,config_value)) begin
                                       config_commit<=1; committed_id<=config_id; committed_value<=config_value;
                                   end
                                   case(config_id)
                                       1: if(config_value<=9) begin attack_sel<=config_value[3:0]; param_count<=param_count+1'b1; end
                                       2: if(config_value<=9) begin decay_sel<=config_value[3:0]; param_count<=param_count+1'b1; end
                                       3: begin sustain_level<=config_value; param_count<=param_count+1'b1; end
                                       4: if(config_value<=9) begin release_sel<=config_value[3:0]; param_count<=param_count+1'b1; end
                                       5: if(config_value<=15) begin volume<=config_value[3:0]; volume_event<=1; param_count<=param_count+1'b1; end
                                       6: if(config_value<=1) begin mode_event<=1; mode_auto<=config_value[0]; end
                                       default: if(fx_valid(config_id,config_value)) param_count<=param_count+1'b1;
                                   endcase
                                   end
                               end
                           end
                           4:begin upper_hi<=shift;config_state<=5;end
                           5:begin config_state<=0;if(shift==(8'hf7^config_id^config_value^upper_lo^upper_hi))begin
                               pressed<={config_value,config_id};upper_pressed<={upper_hi,upper_lo};watchdog<=0;
                           end end
                       endcase
                   end
               end
        endcase
    end
endmodule

module uart_tx(input clk,input start,input [7:0] data,input [11:0] bit_clocks,
    output reg tx=1,output reg busy=0);
    reg [9:0] shift=10'h3ff;
    reg [3:0] bit_index=0;
    reg [11:0] count=0,period=228;
    always @(posedge clk) begin
        if(!busy) begin
            tx<=1;
            if(start) begin
                shift<={1'b1,data,1'b0}; tx<=0; busy<=1;
                bit_index<=0; period<=bit_clocks; count<=bit_clocks-1'b1;
            end
        end else if(count!=0) count<=count-1'b1;
        else if(bit_index==9) begin busy<=0; tx<=1; end
        else begin
            shift<={1'b1,shift[9:1]}; tx<=shift[1];
            bit_index<=bit_index+1'b1; count<=period-1'b1;
        end
    end
endmodule

module uart_status #(parameter integer PERIOD=5250000,parameter [7:0] BUILD_ID=8'h41,parameter integer FX_STATUS=0)(
    input clk,input [7:0] flags,input [15:0] rx_count,input [7:0] last_byte,
    input [15:0] serial_keys,matrix_keys,live_keys,blocked_keys,
    input [3:0] volume,input [11:0] bit_clocks,input [15:0] edges,
    input [15:0] peak,input [8:0] gain,
    input [15:0] active_envelopes,phase0,input [7:0] envelope0,
    input [15:0] frame_count,
    input [3:0] attack_sel,decay_sel,release_sel,
    input [7:0] sustain_level,input [3:0] bend_target,
    input signed [8:0] bend_cents,input [7:0] param_count,output tx,
    input [127:0] fx_snapshot,input [7:0] fx_revision);
    reg [22:0] timer=0;
    reg [2:0] state=0;
    reg [319:0] packet=0;
    reg [5:0] index=0;
    reg extended=0;
    reg [7:0] data=0;
    reg start=0;
    wire busy;
    uart_tx transmitter(clk,start,data,bit_clocks,tx,busy);
    reg [7:0] checksum;
    integer i;
    always @* begin
        checksum=0;
        for(i=2;i<39;i=i+1) if(!extended || i<21)checksum=checksum^packet[i*8+:8];
    end
    always @(posedge clk) begin
        start<=0;
        case(state)
            0: if(timer==PERIOD-1) begin
                   timer<=0;
                   packet<={8'd0,param_count,{{7{bend_cents[8]}},bend_cents},
                       4'd0,bend_target,4'd0,release_sel,sustain_level,
                       4'd0,decay_sel,4'd0,attack_sel,BUILD_ID,frame_count,envelope0,phase0,active_envelopes,
                       gain[8:1],peak,edges,4'd0,bit_clocks,
                       4'd0,volume,blocked_keys,live_keys,matrix_keys,serial_keys,
                       last_byte,rx_count,flags,8'h04,8'h5a,8'ha5};
                   state<=1;
               end else timer<=timer+1'b1;
            1: begin
                if(extended)packet[175:168]<=checksum;else packet[319:312]<=checksum;
                index<=0; state<=2;
            end
            2: if(!busy) begin data<=packet[index*8+:8]; start<=1; state<=3; end
            3: if(busy) state<=4;
            4: if(!busy) begin
                   if(index==(extended?21:39)) begin
                       if(FX_STATUS && !extended)begin
                           // A5 5A 05 BUILD REV [ID10..1F values] XOR(bytes2..20)
                           packet<={144'd0,8'd0,fx_snapshot,fx_revision,BUILD_ID,8'h05,8'h5a,8'ha5};
                           extended<=1;state<=1;
                       end else begin extended<=0;state<=0;end
                   end
                   else begin index<=index+1'b1; state<=2; end
               end
            default:state<=0;
        endcase
    end
endmodule
