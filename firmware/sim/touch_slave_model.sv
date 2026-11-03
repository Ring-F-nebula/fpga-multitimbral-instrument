`timescale 1ns/1ps
// Behavioral slave observes actual open-drain SCL/SDA edges, including master
// ACK/NACK and repeated START; it does not inspect controller internals.
module touch_slave_model #(parameter integer KIND=1,parameter [6:0] ADDRESS=7'h38,
    parameter integer CLOCKS_PER_MS=256)(
    input reset_n,enabled,input [2:0] fingers,input ready,
    input [59:0] xs,ys,inout scl,sda,output integer clears=0);
    reg pull_low=0,active=0,selected=0,reading=0;
    assign sda=pull_low?1'b0:1'bz;
    integer state=0,bits=0,pointer_bytes=0;
    reg [7:0] shift=0,outbyte=0;
    reg [15:0] pointer=0;
    reg ack=0,next_read=0;
    reg software_reset_seen=0,coordinate_mode=0;
    time software_reset_at=0;
    integer offset,p;
    reg [7:0] received;
    function [7:0] get_register(input [15:0] a);
        integer k,off;
        reg [11:0] xx,yy;
        begin
            get_register=0; k=0; off=0; xx=0; yy=0;
            if(KIND==1) begin
                if(a==16'ha8) get_register=8'h11;
                else if(a==2) get_register={5'd0,fingers};
                else if(a>=3 && a<33) begin
                    k=(a-3)/6; off=(a-3)%6; xx=xs[k*12+:12]; yy=ys[k*12+:12];
                    case(off)
                        0:get_register={4'b0000,xx[11:8]}; 1:get_register=xx[7:0];
                        2:get_register={k[3:0],yy[11:8]};3:get_register=yy[7:0];
                        default:get_register=0;
                    endcase
                end
            end else begin
                case(a)
                    16'h8140:get_register="9";16'h8141,16'h8142:get_register="1";
                    16'h8048:get_register=0;16'h8049:get_register=4;
                    16'h804a:get_register=8'h58;16'h804b:get_register=2;
                    // I2C product ID still responds without scanner init.
                    // This reproduces READY / no fingers with the old driver.
                    16'h814e:get_register=coordinate_mode?{ready,4'd0,fingers}:8'd0;
                    default: if(a>=16'h814f && a<16'h8177) begin
                        k=(a-16'h814f)/8;off=(a-16'h814f)%8;
                        xx=xs[k*12+:12]; yy=ys[k*12+:12];
                        case(off)
                            0:get_register=k;1:get_register=xx[7:0];2:get_register={4'd0,xx[11:8]};
                            3:get_register=yy[7:0];4:get_register={4'd0,yy[11:8]};
                            default:get_register=0;
                        endcase
                    end
                endcase
            end
        end
    endfunction
    always @(negedge sda) if(scl===1'b1 && reset_n) begin
        active=1;selected=0;state=0;bits=0;shift=0;pull_low=0;
    end
    always @(posedge sda) if(scl===1'b1) begin active=0; pull_low=0; end
    always @(negedge reset_n) begin
        active=0; pull_low=0; pointer=0; software_reset_seen=0; coordinate_mode=0;
    end
    always @(posedge scl) if(active && reset_n) begin
        if(state==0 && bits<8) begin
            received={shift[6:0],sda}; shift=received; bits=bits+1;
            if(bits==8) begin
                ack=0; next_read=0;
                if(!selected) begin
                    ack=enabled && received[7:1]==ADDRESS;
                    selected=ack; reading=received[0]; next_read=reading && ack;
                    pointer_bytes=reading?0:(KIND==1?1:2);
                end else begin
                    ack=enabled;
                    if(pointer_bytes==2) begin pointer={received,8'd0}; pointer_bytes=1; end
                    else if(pointer_bytes==1) begin
                        pointer[7:0]=received; pointer_bytes=0;
                    end else begin
                        if(KIND!=1 && pointer==16'h8040) begin
                            if(received==2) begin
                                software_reset_seen=1; coordinate_mode=0; software_reset_at=$time;
                            end else if(received==0) begin
                                if(!software_reset_seen || $time-software_reset_at<CLOCKS_PER_MS*100)
                                    $fatal(1,"GT coordinate mode without software reset / 10ms delay");
                                coordinate_mode=1;
                            end
                        end
                        if(pointer==16'h814e && received==0) clears=clears+1;
                        pointer=pointer+1;
                    end
                end
            end
        end else if(state==0 && bits==8) bits=9;
        else if(state==1) begin
            bits=bits+1;
            if(bits==8) state=2;
        end else if(state==2) begin
            if(sda===1'b0) begin pointer=pointer+1; outbyte=get_register(pointer); state=3; end
            else begin state=4; pull_low=0; end
        end
    end
    always @(negedge scl) if(active && reset_n) begin
        if(state==0 && bits==8) pull_low=ack;
        else if(state==0 && bits==9) begin
            pull_low=0; bits=0; shift=0;
            if(!ack) state=4;
            else if(next_read) begin outbyte=get_register(pointer); state=1; pull_low=!outbyte[7]; end
        end else if(state==1) pull_low=!outbyte[7-bits];
        else if(state==2) pull_low=0;
        else if(state==3) begin state=1; bits=0; pull_low=!outbyte[7]; end
    end
endmodule
