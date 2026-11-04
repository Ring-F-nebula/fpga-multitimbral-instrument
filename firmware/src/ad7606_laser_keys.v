`timescale 1ns/1ps
// Signed ADC codes, +/-5V range. 3.3V--10k--ADC--LDR--GND:
// illuminated -> low; blocked -> high. Two thresholds provide hysteresis.
// Each string must first see stable light; booting in darkness is silent.
module ad7606_laser_keys #(
    parameter signed [15:0] ON_CODE=16'sd11796,  // 1.8V
    parameter signed [15:0] OFF_CODE=16'sd7864,  // 1.2V
    parameter integer ARM_FRAMES=8,
    parameter integer STABLE_FRAMES=2,
    parameter integer STALE_CYCLES=52500         // 2ms at 26.25MHz
)(
    input wire clk,reset_n,input wire [127:0] samples_async,
    input wire toggle_async,online_async,
    output reg [6:0] notes=0,armed=0,
    output wire [15:0] keys,output reg frame_valid=0
);
    reg [1:0] toggle_sync=0,online_sync=0;
    reg seen=0,capture=0;
    reg [15:0] age=0;
    reg [7:0] light_count[0:6],change_count[0:6];
    integer i;
    wire usable=online_sync[1] && age<STALE_CYCLES-1;
    always @(posedge clk)begin
        toggle_sync<={toggle_sync[0],toggle_async};online_sync<={online_sync[0],online_async};
        frame_valid<=0;
        if(!reset_n)begin
            toggle_sync<=0;online_sync<=0;seen<=0;capture<=0;age<=0;notes<=0;armed<=0;
            for(i=0;i<7;i=i+1)begin light_count[i]<=0;change_count[i]<=0;end
        end else begin
            if(age<STALE_CYCLES-1)age<=age+1'b1;
            capture<=0;
            if(toggle_sync[1]!=seen)begin seen<=toggle_sync[1];capture<=1;end
            if(!usable)begin
                notes<=0;armed<=0;
                for(i=0;i<7;i=i+1)begin light_count[i]<=0;change_count[i]<=0;end
            end
            if(capture && online_sync[1])begin
                age<=0;frame_valid<=1;
                for(i=0;i<7;i=i+1)begin
                    // Negative voltages are outside the specified light-divider wiring.
                    if(samples_async[i*16+15])begin
                        armed[i]<=0;notes[i]<=0;light_count[i]<=0;change_count[i]<=0;
                    end else if(!usable || !armed[i])begin
                        notes[i]<=0;change_count[i]<=0;
                        if($signed(samples_async[i*16+:16])<=OFF_CODE)begin
                            if(light_count[i]==ARM_FRAMES-1)begin armed[i]<=1;light_count[i]<=0;end
                            else light_count[i]<=light_count[i]+1'b1;
                        end else light_count[i]<=0;
                    end else if((!notes[i] && $signed(samples_async[i*16+:16])>=ON_CODE) ||
                                (notes[i] && $signed(samples_async[i*16+:16])<=OFF_CODE))begin
                        if(change_count[i]==STABLE_FRAMES-1)begin notes[i]<=~notes[i];change_count[i]<=0;end
                        else change_count[i]<=change_count[i]+1'b1;
                    end else change_count[i]<=0;
                end
            end
        end
    end
    assign keys=(notes[0]?16'h0001:16'h0000)|(notes[1]?16'h0004:16'h0000)|
                (notes[2]?16'h0010:16'h0000)|(notes[3]?16'h0020:16'h0000)|
                (notes[4]?16'h0080:16'h0000)|(notes[5]?16'h0200:16'h0000)|
                (notes[6]?16'h0800:16'h0000);
endmodule
