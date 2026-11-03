`timescale 1ns/1ps
module tb_map_equivalence;
 reg [10:0] x=0;reg [9:0] y=0;reg [2:0] page_q=0;reg [1:0] instrument_q=0;
 reg [1:0] record_button_state=0;reg [2:0] event_label_state=0,audio_label_state=0,practice_label_state=0;
 reg [2:0] matrix_status=0,matrix_feedback=0;reg running_q=0,finished_q=0;reg [255:0] info_q=0;
 wire [13:0] actual;reg [13:0] map_address;
 panel_map_address dut(.*,.map_address(actual));
 reg [7:0] map_row_base;
 always_comb case(page_q)
 0:map_row_base=0;1:map_row_base=38;2:map_row_base=76;3:map_row_base=114;
 4:map_row_base=152;5:map_row_base=190;6:map_row_base=228;default:map_row_base=10;
 endcase

 always_comb begin
 map_address={map_row_base+y[9:4],x[9:4]};
 if(page_q==6)map_address=14'd16383;
 if(page_q==0&&instrument_q==1&&x>=128&&((y>=368&&y<424)||(y>=64&&y<96&&x<512)))map_address=14'd16383;
 `include "pressure_matrix_map.vh"
 `include "panel_dynamic.vh"
 end
 integer n,pg,ins,xx,yy,checks=0;
 task check;begin
 #1;
 if(actual!==map_address)$fatal(1,"map mismatch pg=%0d ins=%0d xy=%0d,%0d state=%0d actual=%0d expected=%0d",page_q,instrument_q,x,y,n,actual,map_address);
 if((dut.matrix_hit & (dut.matrix_hit-1'b1))!=0 || (dut.dynamic_hit & (dut.dynamic_hit-1'b1))!=0)$fatal(1,"overlapping regions inside parallel bank");
 checks=checks+1;
 end endtask
 initial begin
 // All coordinates are separated by boundaries aligned to 8 pixels; address
 // arithmetic depends only on tile bits. Cover every tile and every boundary
 // region over the entire port range, including blanking and invalid pages.
 for(n=0;n<8;n=n+1)begin
 record_button_state=n;event_label_state=n;audio_label_state=n;practice_label_state=n;
 matrix_status=n;matrix_feedback=n;running_q=n[0];finished_q=n[1];info_q[225]=n[0];info_q[81]=n[1];
 for(pg=0;pg<8;pg=pg+1)for(ins=0;ins<4;ins=ins+1)begin page_q=pg;instrument_q=ins;
 for(yy=0;yy<1024;yy=yy+8)for(xx=0;xx<2048;xx=xx+8)begin x=xx;y=yy;check();end
 end end
 for(n=0;n<20000;n=n+1)begin x=$random;y=$random;page_q=$random;instrument_q=$random;check();end
 $display("PASS map_equivalence: %0d reference address comparisons, all pages/instruments/status values and disjoint decoder banks",checks);$finish;
 end
endmodule

