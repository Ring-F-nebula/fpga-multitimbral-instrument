3'd0:begin
if(paint_hits0[0]) card_hit=1;
if(paint_hits0[15]) begin button_hit=1;button_color=button_color | (!enabled_q[1]?24'hebedf2:(page_q==0?24'hdce7fc:24'hf1f3f8));end
if(paint_hits0[16]) begin button_hit=1;button_color=button_color | (!enabled_q[2]?24'hebedf2:(page_q==1?24'hdce7fc:24'hf1f3f8));end
if(paint_hits0[17]) begin button_hit=1;button_color=button_color | (!enabled_q[3]?24'hebedf2:(page_q==2?24'hdce7fc:24'hf1f3f8));end
if(paint_hits0[18]) begin button_hit=1;button_color=button_color | (!enabled_q[4]?24'hebedf2:(page_q==3?24'hdce7fc:24'hf1f3f8));end
if(paint_hits0[19]) begin button_hit=1;button_color=button_color | (!enabled_q[114]?24'hebedf2:(page_q==5?24'hdce7fc:24'hf1f3f8));end
if(paint_hits0[20]) begin button_hit=1;button_color=button_color | (!enabled_q[5]?24'hebedf2:(page_q==4?24'hdce7fc:24'hf1f3f8));end
if(paint_hits0[21]) begin button_hit=1;button_color=button_color | (!enabled_q[119]?24'hebedf2:(record_button_state!=0?24'hf5d9d8:24'hdce7fc));end
if(paint_hits0[22]) begin button_hit=1;button_color=button_color | (!enabled_q[8]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[23]) begin button_hit=1;button_color=button_color | (!enabled_q[9]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[24]) begin button_hit=1;button_color=button_color | (!enabled_q[6]?24'hebedf2:(!stopped_q && !auto_q && !game_q?24'hdce7fc:24'heff1f6));end
if(paint_hits0[25]) begin button_hit=1;button_color=button_color | (!enabled_q[7]?24'hebedf2:(stopped_q?24'hf4bfb8:24'hf9e6e2));end
if(paint_hits0[26]) begin button_hit=1;button_color=button_color | (!enabled_q[10]?24'hebedf2:(instrument_q==0?24'hdce7fc:24'hffffff));end
if(paint_hits0[27]) begin button_hit=1;button_color=button_color | (!enabled_q[11]?24'hebedf2:(instrument_q==1?24'hdce7fc:24'hffffff));end
if(paint_hits0[28]) begin button_hit=1;button_color=button_color | (!enabled_q[12]?24'hebedf2:(instrument_q==2?24'hdce7fc:24'hffffff));end
if(paint_hits0[29]) begin button_hit=1;button_color=button_color | (!enabled_q[16]?24'hebedf2:(bank_q?24'hc3d6fc:24'heff1f6));end
if(paint_hits0[30] && instrument_q!=1) begin button_hit=1;button_color=button_color | (!enabled_q[17]?24'hebedf2:(hold_q?24'hc3d6fc:24'heff1f6));end
if(paint_hits0[31]) begin button_hit=1;button_color=button_color | (!enabled_q[13]?24'hebedf2:(view_q==0?24'hdce7fc:24'heff1f6));end
if(paint_hits0[32]) begin button_hit=1;button_color=button_color | (!enabled_q[14]?24'hebedf2:(view_q==1?24'hdce7fc:24'heff1f6));end
if(paint_hits0[33]) begin button_hit=1;button_color=button_color | (!enabled_q[15]?24'hebedf2:(view_q==2?24'hdce7fc:24'heff1f6));end
if(paint_hits0[34]) begin button_hit=1;button_color=button_color | (!enabled_q[19]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[35] && instrument_q==2) begin button_hit=1;button_color=button_color | (!enabled_q[128]?24'hebedf2:(info_q[(bank_q?16:0)+0]?24'hc3d6fc:24'hffffff));end
if(paint_hits0[36] && instrument_q==2) begin button_hit=1;button_color=button_color | (!enabled_q[129]?24'hebedf2:(info_q[(bank_q?16:0)+1]?24'hc3d6fc:24'hffffff));end
if(paint_hits0[37] && instrument_q==2) begin button_hit=1;button_color=button_color | (!enabled_q[130]?24'hebedf2:(info_q[(bank_q?16:0)+2]?24'hc3d6fc:24'hffffff));end
if(paint_hits0[38] && instrument_q==2) begin button_hit=1;button_color=button_color | (!enabled_q[131]?24'hebedf2:(info_q[(bank_q?16:0)+3]?24'hc3d6fc:24'hffffff));end
if(paint_hits0[39] && instrument_q==2) begin button_hit=1;button_color=button_color | (!enabled_q[132]?24'hebedf2:(info_q[(bank_q?16:0)+4]?24'hc3d6fc:24'hffffff));end
if(paint_hits0[40] && instrument_q==2) begin button_hit=1;button_color=button_color | (!enabled_q[133]?24'hebedf2:(info_q[(bank_q?16:0)+5]?24'hc3d6fc:24'hffffff));end
if(paint_hits0[41] && instrument_q==2) begin button_hit=1;button_color=button_color | (!enabled_q[134]?24'hebedf2:(info_q[(bank_q?16:0)+6]?24'hc3d6fc:24'hffffff));end
if(paint_hits0[42] && instrument_q==2) begin button_hit=1;button_color=button_color | (!enabled_q[135]?24'hebedf2:(info_q[(bank_q?16:0)+7]?24'hc3d6fc:24'hffffff));end
if(paint_hits0[43] && instrument_q==2) begin button_hit=1;button_color=button_color | (!enabled_q[136]?24'hebedf2:(info_q[(bank_q?16:0)+8]?24'hc3d6fc:24'hffffff));end
if(paint_hits0[44] && instrument_q==2) begin button_hit=1;button_color=button_color | (!enabled_q[137]?24'hebedf2:(info_q[(bank_q?16:0)+9]?24'hc3d6fc:24'hffffff));end
if(paint_hits0[45] && instrument_q==2) begin button_hit=1;button_color=button_color | (!enabled_q[138]?24'hebedf2:(info_q[(bank_q?16:0)+10]?24'hc3d6fc:24'hffffff));end
if(paint_hits0[46] && instrument_q==2) begin button_hit=1;button_color=button_color | (!enabled_q[139]?24'hebedf2:(info_q[(bank_q?16:0)+11]?24'hc3d6fc:24'hffffff));end
if(paint_hits0[47] && instrument_q==2) begin button_hit=1;button_color=button_color | (!enabled_q[140]?24'hebedf2:(info_q[(bank_q?16:0)+12]?24'hc3d6fc:24'hffffff));end
if(paint_hits0[48] && instrument_q==2) begin button_hit=1;button_color=button_color | (!enabled_q[141]?24'hebedf2:(info_q[(bank_q?16:0)+13]?24'hc3d6fc:24'hffffff));end
if(paint_hits0[49] && instrument_q==2) begin button_hit=1;button_color=button_color | (!enabled_q[142]?24'hebedf2:(info_q[(bank_q?16:0)+14]?24'hc3d6fc:24'hffffff));end
if(paint_hits0[50] && instrument_q==2) begin button_hit=1;button_color=button_color | (!enabled_q[143]?24'hebedf2:(info_q[(bank_q?16:0)+15]?24'hc3d6fc:24'hffffff));end
end
3'd1:begin
if(paint_hits0[1]) card_hit=1;
if(paint_hits0[2]) card_hit=1;
if(paint_hits0[3]) card_hit=1;
if(paint_hits0[15]) begin button_hit=1;button_color=button_color | (!enabled_q[1]?24'hebedf2:(page_q==0?24'hdce7fc:24'hf1f3f8));end
if(paint_hits0[16]) begin button_hit=1;button_color=button_color | (!enabled_q[2]?24'hebedf2:(page_q==1?24'hdce7fc:24'hf1f3f8));end
if(paint_hits0[17]) begin button_hit=1;button_color=button_color | (!enabled_q[3]?24'hebedf2:(page_q==2?24'hdce7fc:24'hf1f3f8));end
if(paint_hits0[18]) begin button_hit=1;button_color=button_color | (!enabled_q[4]?24'hebedf2:(page_q==3?24'hdce7fc:24'hf1f3f8));end
if(paint_hits0[19]) begin button_hit=1;button_color=button_color | (!enabled_q[114]?24'hebedf2:(page_q==5?24'hdce7fc:24'hf1f3f8));end
if(paint_hits0[20]) begin button_hit=1;button_color=button_color | (!enabled_q[5]?24'hebedf2:(page_q==4?24'hdce7fc:24'hf1f3f8));end
if(paint_hits0[21]) begin button_hit=1;button_color=button_color | (!enabled_q[119]?24'hebedf2:(record_button_state!=0?24'hf5d9d8:24'hdce7fc));end
if(paint_hits0[22]) begin button_hit=1;button_color=button_color | (!enabled_q[8]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[23]) begin button_hit=1;button_color=button_color | (!enabled_q[9]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[24]) begin button_hit=1;button_color=button_color | (!enabled_q[6]?24'hebedf2:(!stopped_q && !auto_q && !game_q?24'hdce7fc:24'heff1f6));end
if(paint_hits0[25]) begin button_hit=1;button_color=button_color | (!enabled_q[7]?24'hebedf2:(stopped_q?24'hf4bfb8:24'hf9e6e2));end
if(paint_hits0[51]) begin button_hit=1;button_color=button_color | (!enabled_q[42]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[52]) begin button_hit=1;button_color=button_color | (!enabled_q[28]?24'hebedf2:(adsr_match_q[0]?24'hc3d6fc:24'heff1f6));end
if(paint_hits0[53]) begin button_hit=1;button_color=button_color | (!enabled_q[29]?24'hebedf2:(adsr_match_q[1]?24'hc3d6fc:24'heff1f6));end
if(paint_hits0[54]) begin button_hit=1;button_color=button_color | (!enabled_q[57]?24'hebedf2:(adsr_match_q[2]?24'hc3d6fc:24'heff1f6));end
if(paint_hits0[55]) begin button_hit=1;button_color=button_color | (!enabled_q[20]?24'hebedf2:(instrument_q!=2?24'he8eaf2:24'hf4f4f6));end
if(paint_hits0[56]) begin button_hit=1;button_color=button_color | (!enabled_q[21]?24'hebedf2:(instrument_q!=2?24'he8eaf2:24'hf4f4f6));end
if(paint_hits0[57]) begin button_hit=1;button_color=button_color | (!enabled_q[22]?24'hebedf2:(instrument_q!=2?24'he8eaf2:24'hf4f4f6));end
if(paint_hits0[58]) begin button_hit=1;button_color=button_color | (!enabled_q[23]?24'hebedf2:(instrument_q!=2?24'he8eaf2:24'hf4f4f6));end
if(paint_hits0[59]) begin button_hit=1;button_color=button_color | (!enabled_q[24]?24'hebedf2:(instrument_q!=2?24'he8eaf2:24'hf4f4f6));end
if(paint_hits0[60]) begin button_hit=1;button_color=button_color | (!enabled_q[25]?24'hebedf2:(instrument_q!=2?24'he8eaf2:24'hf4f4f6));end
if(paint_hits0[61]) begin button_hit=1;button_color=button_color | (!enabled_q[26]?24'hebedf2:(instrument_q!=2?24'he8eaf2:24'hf4f4f6));end
if(paint_hits0[62]) begin button_hit=1;button_color=button_color | (!enabled_q[27]?24'hebedf2:(instrument_q!=2?24'he8eaf2:24'hf4f4f6));end
if(paint_hits0[63]) begin button_hit=1;button_color=button_color | (!enabled_q[30]?24'hebedf2:(fx_q[3]?24'hc3d6fc:24'heff1f6));end
if(paint_hits0[64]) begin button_hit=1;button_color=button_color | (!enabled_q[31]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[65]) begin button_hit=1;button_color=button_color | (!enabled_q[32]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[66]) begin button_hit=1;button_color=button_color | (!enabled_q[33]?24'hebedf2:(fx_q[4]?24'hc3d6fc:24'heff1f6));end
if(paint_hits0[67]) begin button_hit=1;button_color=button_color | (!enabled_q[34]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[68]) begin button_hit=1;button_color=button_color | (!enabled_q[35]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[69]) begin button_hit=1;button_color=button_color | (!enabled_q[36]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[70]) begin button_hit=1;button_color=button_color | (!enabled_q[37]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[71]) begin button_hit=1;button_color=button_color | (!enabled_q[38]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[72]) begin button_hit=1;button_color=button_color | (!enabled_q[39]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[73]) begin button_hit=1;button_color=button_color | (!enabled_q[40]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[74]) begin button_hit=1;button_color=button_color | (!enabled_q[41]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[75]) begin button_hit=1;button_color=button_color | (!enabled_q[120]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[76]) begin button_hit=1;button_color=button_color | (!enabled_q[121]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[77]) begin button_hit=1;button_color=button_color | (!enabled_q[122]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[78]) begin button_hit=1;button_color=button_color | (!enabled_q[123]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[79]) begin button_hit=1;button_color=button_color | (!enabled_q[159]?24'hebedf2:(audition_active?24'hc3d6fc:24'heff1f6));end
if(paint_hits0[80]) begin button_hit=1;button_color=button_color | (!enabled_q[124]?24'hebedf2:(info_q[225]?24'hc3d6fc:24'he5ebfa));end
end
3'd2:begin
if(paint_hits0[4]) card_hit=1;
if(paint_hits0[5]) card_hit=1;
if(paint_hits0[6]) card_hit=1;
if(paint_hits0[15]) begin button_hit=1;button_color=button_color | (!enabled_q[1]?24'hebedf2:(page_q==0?24'hdce7fc:24'hf1f3f8));end
if(paint_hits0[16]) begin button_hit=1;button_color=button_color | (!enabled_q[2]?24'hebedf2:(page_q==1?24'hdce7fc:24'hf1f3f8));end
if(paint_hits0[17]) begin button_hit=1;button_color=button_color | (!enabled_q[3]?24'hebedf2:(page_q==2?24'hdce7fc:24'hf1f3f8));end
if(paint_hits0[18]) begin button_hit=1;button_color=button_color | (!enabled_q[4]?24'hebedf2:(page_q==3?24'hdce7fc:24'hf1f3f8));end
if(paint_hits0[19]) begin button_hit=1;button_color=button_color | (!enabled_q[114]?24'hebedf2:(page_q==5?24'hdce7fc:24'hf1f3f8));end
if(paint_hits0[20]) begin button_hit=1;button_color=button_color | (!enabled_q[5]?24'hebedf2:(page_q==4?24'hdce7fc:24'hf1f3f8));end
if(paint_hits0[21]) begin button_hit=1;button_color=button_color | (!enabled_q[119]?24'hebedf2:(record_button_state!=0?24'hf5d9d8:24'hdce7fc));end
if(paint_hits0[22]) begin button_hit=1;button_color=button_color | (!enabled_q[8]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[23]) begin button_hit=1;button_color=button_color | (!enabled_q[9]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[24]) begin button_hit=1;button_color=button_color | (!enabled_q[6]?24'hebedf2:(!stopped_q && !auto_q && !game_q?24'hdce7fc:24'heff1f6));end
if(paint_hits0[25]) begin button_hit=1;button_color=button_color | (!enabled_q[7]?24'hebedf2:(stopped_q?24'hf4bfb8:24'hf9e6e2));end
if(paint_hits0[81]) begin button_hit=1;button_color=button_color | (!enabled_q[50]?24'hebedf2:(fx_q[0]?24'hc3d6fc:24'heff1f6));end
if(paint_hits0[82]) begin button_hit=1;button_color=button_color | (!enabled_q[51]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[83]) begin button_hit=1;button_color=button_color | (!enabled_q[52]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[84]) begin button_hit=1;button_color=button_color | (!enabled_q[53]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[85]) begin button_hit=1;button_color=button_color | (!enabled_q[54]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[86]) begin button_hit=1;button_color=button_color | (!enabled_q[55]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[87]) begin button_hit=1;button_color=button_color | (!enabled_q[56]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[88]) begin button_hit=1;button_color=button_color | (!enabled_q[60]?24'hebedf2:(fx_q[1]?24'hc3d6fc:24'heff1f6));end
if(paint_hits0[89]) begin button_hit=1;button_color=button_color | (!enabled_q[61]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[90]) begin button_hit=1;button_color=button_color | (!enabled_q[62]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[91]) begin button_hit=1;button_color=button_color | (!enabled_q[63]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[92]) begin button_hit=1;button_color=button_color | (!enabled_q[64]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[93]) begin button_hit=1;button_color=button_color | (!enabled_q[65]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[94]) begin button_hit=1;button_color=button_color | (!enabled_q[66]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[95]) begin button_hit=1;button_color=button_color | (!enabled_q[70]?24'hebedf2:(fx_q[2]?24'hc3d6fc:24'heff1f6));end
if(paint_hits0[96]) begin button_hit=1;button_color=button_color | (!enabled_q[71]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[97]) begin button_hit=1;button_color=button_color | (!enabled_q[72]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[98]) begin button_hit=1;button_color=button_color | (!enabled_q[73]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[99]) begin button_hit=1;button_color=button_color | (!enabled_q[74]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[100]) begin button_hit=1;button_color=button_color | (!enabled_q[75]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[101]) begin button_hit=1;button_color=button_color | (!enabled_q[76]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[102]) begin button_hit=1;button_color=button_color | (!enabled_q[80]?24'hebedf2:(fx_q[5]?24'he0d7fa:24'hffffff));end
if(paint_hits0[103]) begin button_hit=1;button_color=button_color | (!enabled_q[159]?24'hebedf2:(audition_active?24'hc3d6fc:24'heff1f6));end
if(paint_hits0[104]) begin button_hit=1;button_color=button_color | (!enabled_q[81]?24'hebedf2:(24'heff1f6));end
end
3'd3:begin
if(paint_hits0[7]) card_hit=1;
if(paint_hits0[8]) card_hit=1;
if(paint_hits0[9]) card_hit=1;
if(paint_hits0[15]) begin button_hit=1;button_color=button_color | (!enabled_q[1]?24'hebedf2:(page_q==0?24'hdce7fc:24'hf1f3f8));end
if(paint_hits0[16]) begin button_hit=1;button_color=button_color | (!enabled_q[2]?24'hebedf2:(page_q==1?24'hdce7fc:24'hf1f3f8));end
if(paint_hits0[17]) begin button_hit=1;button_color=button_color | (!enabled_q[3]?24'hebedf2:(page_q==2?24'hdce7fc:24'hf1f3f8));end
if(paint_hits0[18]) begin button_hit=1;button_color=button_color | (!enabled_q[4]?24'hebedf2:(page_q==3?24'hdce7fc:24'hf1f3f8));end
if(paint_hits0[19]) begin button_hit=1;button_color=button_color | (!enabled_q[114]?24'hebedf2:(page_q==5?24'hdce7fc:24'hf1f3f8));end
if(paint_hits0[20]) begin button_hit=1;button_color=button_color | (!enabled_q[5]?24'hebedf2:(page_q==4?24'hdce7fc:24'hf1f3f8));end
if(paint_hits0[21]) begin button_hit=1;button_color=button_color | (!enabled_q[119]?24'hebedf2:(record_button_state!=0?24'hf5d9d8:24'hdce7fc));end
if(paint_hits0[22]) begin button_hit=1;button_color=button_color | (!enabled_q[8]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[23]) begin button_hit=1;button_color=button_color | (!enabled_q[9]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[24]) begin button_hit=1;button_color=button_color | (!enabled_q[6]?24'hebedf2:(!stopped_q && !auto_q && !game_q?24'hdce7fc:24'heff1f6));end
if(paint_hits0[25]) begin button_hit=1;button_color=button_color | (!enabled_q[7]?24'hebedf2:(stopped_q?24'hf4bfb8:24'hf9e6e2));end
if(paint_hits0[105]) begin button_hit=1;button_color=button_color | (!enabled_q[97]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[106]) begin button_hit=1;button_color=button_color | (!enabled_q[90]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[107]) begin button_hit=1;button_color=button_color | (!enabled_q[95]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[108]) begin button_hit=1;button_color=button_color | (!enabled_q[96]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[109]) begin button_hit=1;button_color=button_color | (!enabled_q[92]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[110]) begin button_hit=1;button_color=button_color | (!enabled_q[93]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[111]) begin button_hit=1;button_color=button_color | (!enabled_q[94]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[112]) begin button_hit=1;button_color=button_color | (!enabled_q[125]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[113]) begin button_hit=1;button_color=button_color | (!enabled_q[128]?24'hebedf2:(game_keys_q[0]?24'hc3d6fc:cue_q[0]?24'hf2d5bb:24'hffffff));end
if(paint_hits0[114]) begin button_hit=1;button_color=button_color | (!enabled_q[129]?24'hebedf2:(game_keys_q[1]?24'hc3d6fc:cue_q[1]?24'hf2d5bb:24'hffffff));end
if(paint_hits0[115]) begin button_hit=1;button_color=button_color | (!enabled_q[130]?24'hebedf2:(game_keys_q[2]?24'hc3d6fc:cue_q[2]?24'hf2d5bb:24'hffffff));end
if(paint_hits0[116]) begin button_hit=1;button_color=button_color | (!enabled_q[131]?24'hebedf2:(game_keys_q[3]?24'hc3d6fc:cue_q[3]?24'hf2d5bb:24'hffffff));end
if(paint_hits0[117]) begin button_hit=1;button_color=button_color | (!enabled_q[132]?24'hebedf2:(game_keys_q[4]?24'hc3d6fc:cue_q[4]?24'hf2d5bb:24'hffffff));end
if(paint_hits0[118]) begin button_hit=1;button_color=button_color | (!enabled_q[133]?24'hebedf2:(game_keys_q[5]?24'hc3d6fc:cue_q[5]?24'hf2d5bb:24'hffffff));end
if(paint_hits0[119]) begin button_hit=1;button_color=button_color | (!enabled_q[134]?24'hebedf2:(game_keys_q[6]?24'hc3d6fc:cue_q[6]?24'hf2d5bb:24'hffffff));end
if(paint_hits0[120]) begin button_hit=1;button_color=button_color | (!enabled_q[135]?24'hebedf2:(game_keys_q[7]?24'hc3d6fc:cue_q[7]?24'hf2d5bb:24'hffffff));end
if(paint_hits0[121]) begin button_hit=1;button_color=button_color | (!enabled_q[136]?24'hebedf2:(game_keys_q[8]?24'hc3d6fc:cue_q[8]?24'hf2d5bb:24'hffffff));end
if(paint_hits0[122]) begin button_hit=1;button_color=button_color | (!enabled_q[137]?24'hebedf2:(game_keys_q[9]?24'hc3d6fc:cue_q[9]?24'hf2d5bb:24'hffffff));end
if(paint_hits0[123]) begin button_hit=1;button_color=button_color | (!enabled_q[138]?24'hebedf2:(game_keys_q[10]?24'hc3d6fc:cue_q[10]?24'hf2d5bb:24'hffffff));end
if(paint_hits0[124]) begin button_hit=1;button_color=button_color | (!enabled_q[139]?24'hebedf2:(game_keys_q[11]?24'hc3d6fc:cue_q[11]?24'hf2d5bb:24'hffffff));end
if(paint_hits0[125]) begin button_hit=1;button_color=button_color | (!enabled_q[140]?24'hebedf2:(game_keys_q[12]?24'hc3d6fc:cue_q[12]?24'hf2d5bb:24'hffffff));end
if(paint_hits0[126]) begin button_hit=1;button_color=button_color | (!enabled_q[141]?24'hebedf2:(game_keys_q[13]?24'hc3d6fc:cue_q[13]?24'hf2d5bb:24'hffffff));end
if(paint_hits0[127]) begin button_hit=1;button_color=button_color | (!enabled_q[142]?24'hebedf2:(game_keys_q[14]?24'hc3d6fc:cue_q[14]?24'hf2d5bb:24'hffffff));end
if(paint_hits0[128]) begin button_hit=1;button_color=button_color | (!enabled_q[143]?24'hebedf2:(game_keys_q[15]?24'hc3d6fc:cue_q[15]?24'hf2d5bb:24'hffffff));end
end
3'd4:begin
if(paint_hits0[10]) card_hit=1;
if(paint_hits0[11]) card_hit=1;
if(paint_hits0[12]) card_hit=1;
if(paint_hits0[15]) begin button_hit=1;button_color=button_color | (!enabled_q[1]?24'hebedf2:(page_q==0?24'hdce7fc:24'hf1f3f8));end
if(paint_hits0[16]) begin button_hit=1;button_color=button_color | (!enabled_q[2]?24'hebedf2:(page_q==1?24'hdce7fc:24'hf1f3f8));end
if(paint_hits0[17]) begin button_hit=1;button_color=button_color | (!enabled_q[3]?24'hebedf2:(page_q==2?24'hdce7fc:24'hf1f3f8));end
if(paint_hits0[18]) begin button_hit=1;button_color=button_color | (!enabled_q[4]?24'hebedf2:(page_q==3?24'hdce7fc:24'hf1f3f8));end
if(paint_hits0[19]) begin button_hit=1;button_color=button_color | (!enabled_q[114]?24'hebedf2:(page_q==5?24'hdce7fc:24'hf1f3f8));end
if(paint_hits0[20]) begin button_hit=1;button_color=button_color | (!enabled_q[5]?24'hebedf2:(page_q==4?24'hdce7fc:24'hf1f3f8));end
if(paint_hits0[21]) begin button_hit=1;button_color=button_color | (!enabled_q[119]?24'hebedf2:(record_button_state!=0?24'hf5d9d8:24'hdce7fc));end
if(paint_hits0[22]) begin button_hit=1;button_color=button_color | (!enabled_q[8]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[23]) begin button_hit=1;button_color=button_color | (!enabled_q[9]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[24]) begin button_hit=1;button_color=button_color | (!enabled_q[6]?24'hebedf2:(!stopped_q && !auto_q && !game_q?24'hdce7fc:24'heff1f6));end
if(paint_hits0[25]) begin button_hit=1;button_color=button_color | (!enabled_q[7]?24'hebedf2:(stopped_q?24'hf4bfb8:24'hf9e6e2));end
if(paint_hits0[129]) begin button_hit=1;button_color=button_color | (!enabled_q[100]?24'hebedf2:(info_q[45:40]==4?24'hc3d6fc:24'heff1f6));end
if(paint_hits0[130]) begin button_hit=1;button_color=button_color | (!enabled_q[101]?24'hebedf2:(info_q[45:40]==8?24'hc3d6fc:24'heff1f6));end
if(paint_hits0[131]) begin button_hit=1;button_color=button_color | (!enabled_q[102]?24'hebedf2:(info_q[45:40]==16?24'hc3d6fc:24'heff1f6));end
if(paint_hits0[132]) begin button_hit=1;button_color=button_color | (!enabled_q[103]?24'hebedf2:(info_q[45:40]==32?24'hc3d6fc:24'heff1f6));end
if(paint_hits0[133]) begin button_hit=1;button_color=button_color | (!enabled_q[104]?24'hebedf2:(info_q[45:40]==0?24'hc3d6fc:24'heff1f6));end
if(paint_hits0[134]) begin button_hit=1;button_color=button_color | (!enabled_q[105]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[135]) begin button_hit=1;button_color=button_color | (!enabled_q[106]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[136]) begin button_hit=1;button_color=button_color | (!enabled_q[107]?24'hebedf2:(info_q[107]?24'hf5d9d8:24'heff1f6));end
if(paint_hits0[137]) begin button_hit=1;button_color=button_color | (!enabled_q[114]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[138]) begin button_hit=1;button_color=button_color | (!enabled_q[18]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[139]) begin button_hit=1;button_color=button_color | (!enabled_q[19]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[140]) begin button_hit=1;button_color=button_color | (!enabled_q[6]?24'hebedf2:(24'heff1f6));end
end
3'd5:begin
if(paint_hits0[13]) card_hit=1;
if(paint_hits0[14]) card_hit=1;
if(paint_hits0[15]) begin button_hit=1;button_color=button_color | (!enabled_q[1]?24'hebedf2:(page_q==0?24'hdce7fc:24'hf1f3f8));end
if(paint_hits0[16]) begin button_hit=1;button_color=button_color | (!enabled_q[2]?24'hebedf2:(page_q==1?24'hdce7fc:24'hf1f3f8));end
if(paint_hits0[17]) begin button_hit=1;button_color=button_color | (!enabled_q[3]?24'hebedf2:(page_q==2?24'hdce7fc:24'hf1f3f8));end
if(paint_hits0[18]) begin button_hit=1;button_color=button_color | (!enabled_q[4]?24'hebedf2:(page_q==3?24'hdce7fc:24'hf1f3f8));end
if(paint_hits0[19]) begin button_hit=1;button_color=button_color | (!enabled_q[114]?24'hebedf2:(page_q==5?24'hdce7fc:24'hf1f3f8));end
if(paint_hits0[20]) begin button_hit=1;button_color=button_color | (!enabled_q[5]?24'hebedf2:(page_q==4?24'hdce7fc:24'hf1f3f8));end
if(paint_hits0[21]) begin button_hit=1;button_color=button_color | (!enabled_q[119]?24'hebedf2:(record_button_state!=0?24'hf5d9d8:24'hdce7fc));end
if(paint_hits0[22]) begin button_hit=1;button_color=button_color | (!enabled_q[8]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[23]) begin button_hit=1;button_color=button_color | (!enabled_q[9]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[24]) begin button_hit=1;button_color=button_color | (!enabled_q[6]?24'hebedf2:(!stopped_q && !auto_q && !game_q?24'hdce7fc:24'heff1f6));end
if(paint_hits0[25]) begin button_hit=1;button_color=button_color | (!enabled_q[7]?24'hebedf2:(stopped_q?24'hf4bfb8:24'hf9e6e2));end
if(paint_hits0[141]) begin button_hit=1;button_color=button_color | (!enabled_q[115]?24'hebedf2:(24'hdce7fc));end
if(paint_hits0[142]) begin button_hit=1;button_color=button_color | (!enabled_q[116]?24'hebedf2:(24'hf5e5e2));end
if(paint_hits0[143]) begin button_hit=1;button_color=button_color | (!enabled_q[117]?24'hebedf2:(info_q[83]?24'hd9ece3:24'heff1f6));end
if(paint_hits0[144]) begin button_hit=1;button_color=button_color | (!enabled_q[118]?24'hebedf2:(24'hf6eeeb));end
end
3'd6:begin
if(paint_hits0[145]) begin button_hit=1;button_color=button_color | (!enabled_q[90]?24'hebedf2:(24'hdce7fc));end
if(paint_hits0[146]) begin button_hit=1;button_color=button_color | (!enabled_q[126]?24'hebedf2:(24'heff1f6));end
if(paint_hits0[147]) begin button_hit=1;button_color=button_color | (!enabled_q[127]?24'hebedf2:(24'heff1f6));end
end
