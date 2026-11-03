surface_hit=page_q==0 && surface_cmp[0] && surface_cmp[1] && surface_cmp[2] && ((instrument_q==0 && surface_cmp[3])||(instrument_q==1 && surface_cmp[4]));
surface_color=instrument_q==1?24'hf1e6d4:24'hcbd3df;
if(instrument_q==0 && bank_q==1'd0 && surface_cmp[0] && surface_cmp[5] && surface_cmp[3] && surface_cmp[2])begin
surface_color=info_q[(bank_q?16:0)+0]?24'hc5def7:24'hffffff;
if(surface_cmp[6] || surface_cmp[7] || surface_cmp[8])surface_color=info_q[(bank_q?16:0)+0]?24'h4f8fc0:24'hcbd3df;
end
if(instrument_q==0 && bank_q==1'd0 && surface_cmp[9] && surface_cmp[10] && surface_cmp[3] && surface_cmp[2])begin
surface_color=info_q[(bank_q?16:0)+2]?24'hc5def7:24'hffffff;
if(surface_cmp[11] || surface_cmp[12] || surface_cmp[8])surface_color=info_q[(bank_q?16:0)+2]?24'h4f8fc0:24'hcbd3df;
end
if(instrument_q==0 && bank_q==1'd0 && surface_cmp[13] && surface_cmp[14] && surface_cmp[3] && surface_cmp[2])begin
surface_color=info_q[(bank_q?16:0)+4]?24'hc5def7:24'hffffff;
if(surface_cmp[15] || surface_cmp[16] || surface_cmp[8])surface_color=info_q[(bank_q?16:0)+4]?24'h4f8fc0:24'hcbd3df;
end
if(instrument_q==0 && bank_q==1'd0 && surface_cmp[17] && surface_cmp[18] && surface_cmp[3] && surface_cmp[2])begin
surface_color=info_q[(bank_q?16:0)+5]?24'hc5def7:24'hffffff;
if(surface_cmp[19] || surface_cmp[20] || surface_cmp[8])surface_color=info_q[(bank_q?16:0)+5]?24'h4f8fc0:24'hcbd3df;
end
if(instrument_q==0 && bank_q==1'd0 && surface_cmp[21] && surface_cmp[22] && surface_cmp[3] && surface_cmp[2])begin
surface_color=info_q[(bank_q?16:0)+7]?24'hc5def7:24'hffffff;
if(surface_cmp[23] || surface_cmp[24] || surface_cmp[8])surface_color=info_q[(bank_q?16:0)+7]?24'h4f8fc0:24'hcbd3df;
end
if(instrument_q==0 && bank_q==1'd0 && surface_cmp[25] && surface_cmp[26] && surface_cmp[3] && surface_cmp[2])begin
surface_color=info_q[(bank_q?16:0)+9]?24'hc5def7:24'hffffff;
if(surface_cmp[27] || surface_cmp[28] || surface_cmp[8])surface_color=info_q[(bank_q?16:0)+9]?24'h4f8fc0:24'hcbd3df;
end
if(instrument_q==0 && bank_q==1'd0 && surface_cmp[29] && surface_cmp[30] && surface_cmp[3] && surface_cmp[2])begin
surface_color=info_q[(bank_q?16:0)+11]?24'hc5def7:24'hffffff;
if(surface_cmp[31] || surface_cmp[32] || surface_cmp[8])surface_color=info_q[(bank_q?16:0)+11]?24'h4f8fc0:24'hcbd3df;
end
if(instrument_q==0 && bank_q==1'd0 && surface_cmp[33] && surface_cmp[34] && surface_cmp[3] && surface_cmp[2])begin
surface_color=info_q[(bank_q?16:0)+12]?24'hc5def7:24'hffffff;
if(surface_cmp[35] || surface_cmp[36] || surface_cmp[8])surface_color=info_q[(bank_q?16:0)+12]?24'h4f8fc0:24'hcbd3df;
end
if(instrument_q==0 && bank_q==1'd0 && surface_cmp[37] && surface_cmp[1] && surface_cmp[3] && surface_cmp[2])begin
surface_color=info_q[(bank_q?16:0)+14]?24'hc5def7:24'hffffff;
if(surface_cmp[38] || surface_cmp[39] || surface_cmp[8])surface_color=info_q[(bank_q?16:0)+14]?24'h4f8fc0:24'hcbd3df;
end
if(instrument_q==0 && bank_q==1'd0 && surface_cmp[40] && surface_cmp[41] && surface_cmp[3] && surface_cmp[42])begin
surface_color=info_q[(bank_q?16:0)+1]?24'h497eaa:24'h293344;
if(surface_cmp[43] || surface_cmp[44] || surface_cmp[45])surface_color=info_q[(bank_q?16:0)+1]?24'h32668f:24'h182232;
if(surface_cmp[46] && surface_cmp[47] && surface_cmp[48] && surface_cmp[49])surface_color=info_q[(bank_q?16:0)+1]?24'h85bce4:24'h49566b;
end
if(instrument_q==0 && bank_q==1'd0 && surface_cmp[50] && surface_cmp[51] && surface_cmp[3] && surface_cmp[42])begin
surface_color=info_q[(bank_q?16:0)+3]?24'h497eaa:24'h293344;
if(surface_cmp[52] || surface_cmp[53] || surface_cmp[45])surface_color=info_q[(bank_q?16:0)+3]?24'h32668f:24'h182232;
if(surface_cmp[54] && surface_cmp[55] && surface_cmp[48] && surface_cmp[49])surface_color=info_q[(bank_q?16:0)+3]?24'h85bce4:24'h49566b;
end
if(instrument_q==0 && bank_q==1'd0 && surface_cmp[56] && surface_cmp[57] && surface_cmp[3] && surface_cmp[42])begin
surface_color=info_q[(bank_q?16:0)+6]?24'h497eaa:24'h293344;
if(surface_cmp[58] || surface_cmp[59] || surface_cmp[45])surface_color=info_q[(bank_q?16:0)+6]?24'h32668f:24'h182232;
if(surface_cmp[60] && surface_cmp[61] && surface_cmp[48] && surface_cmp[49])surface_color=info_q[(bank_q?16:0)+6]?24'h85bce4:24'h49566b;
end
if(instrument_q==0 && bank_q==1'd0 && surface_cmp[62] && surface_cmp[63] && surface_cmp[3] && surface_cmp[42])begin
surface_color=info_q[(bank_q?16:0)+8]?24'h497eaa:24'h293344;
if(surface_cmp[64] || surface_cmp[65] || surface_cmp[45])surface_color=info_q[(bank_q?16:0)+8]?24'h32668f:24'h182232;
if(surface_cmp[66] && surface_cmp[67] && surface_cmp[48] && surface_cmp[49])surface_color=info_q[(bank_q?16:0)+8]?24'h85bce4:24'h49566b;
end
if(instrument_q==0 && bank_q==1'd0 && surface_cmp[68] && surface_cmp[69] && surface_cmp[3] && surface_cmp[42])begin
surface_color=info_q[(bank_q?16:0)+10]?24'h497eaa:24'h293344;
if(surface_cmp[70] || surface_cmp[71] || surface_cmp[45])surface_color=info_q[(bank_q?16:0)+10]?24'h32668f:24'h182232;
if(surface_cmp[72] && surface_cmp[73] && surface_cmp[48] && surface_cmp[49])surface_color=info_q[(bank_q?16:0)+10]?24'h85bce4:24'h49566b;
end
if(instrument_q==0 && bank_q==1'd0 && surface_cmp[74] && surface_cmp[75] && surface_cmp[3] && surface_cmp[42])begin
surface_color=info_q[(bank_q?16:0)+13]?24'h497eaa:24'h293344;
if(surface_cmp[76] || surface_cmp[77] || surface_cmp[45])surface_color=info_q[(bank_q?16:0)+13]?24'h32668f:24'h182232;
if(surface_cmp[78] && surface_cmp[79] && surface_cmp[48] && surface_cmp[49])surface_color=info_q[(bank_q?16:0)+13]?24'h85bce4:24'h49566b;
end
if(instrument_q==0 && bank_q==1'd0 && surface_cmp[80] && surface_cmp[1] && surface_cmp[3] && surface_cmp[42])begin
surface_color=info_q[(bank_q?16:0)+15]?24'h497eaa:24'h293344;
if(surface_cmp[81] || surface_cmp[39] || surface_cmp[45])surface_color=info_q[(bank_q?16:0)+15]?24'h32668f:24'h182232;
if(surface_cmp[82] && surface_cmp[83] && surface_cmp[48] && surface_cmp[49])surface_color=info_q[(bank_q?16:0)+15]?24'h85bce4:24'h49566b;
end
if(instrument_q==0 && bank_q==1'd1 && surface_cmp[0] && surface_cmp[84] && surface_cmp[3] && surface_cmp[2])begin
surface_color=info_q[(bank_q?16:0)+0]?24'hc5def7:24'hffffff;
if(surface_cmp[6] || surface_cmp[85] || surface_cmp[8])surface_color=info_q[(bank_q?16:0)+0]?24'h4f8fc0:24'hcbd3df;
end
if(instrument_q==0 && bank_q==1'd1 && surface_cmp[86] && surface_cmp[87] && surface_cmp[3] && surface_cmp[2])begin
surface_color=info_q[(bank_q?16:0)+1]?24'hc5def7:24'hffffff;
if(surface_cmp[88] || surface_cmp[89] || surface_cmp[8])surface_color=info_q[(bank_q?16:0)+1]?24'h4f8fc0:24'hcbd3df;
end
if(instrument_q==0 && bank_q==1'd1 && surface_cmp[90] && surface_cmp[91] && surface_cmp[3] && surface_cmp[2])begin
surface_color=info_q[(bank_q?16:0)+3]?24'hc5def7:24'hffffff;
if(surface_cmp[92] || surface_cmp[93] || surface_cmp[8])surface_color=info_q[(bank_q?16:0)+3]?24'h4f8fc0:24'hcbd3df;
end
if(instrument_q==0 && bank_q==1'd1 && surface_cmp[94] && surface_cmp[95] && surface_cmp[3] && surface_cmp[2])begin
surface_color=info_q[(bank_q?16:0)+5]?24'hc5def7:24'hffffff;
if(surface_cmp[96] || surface_cmp[97] || surface_cmp[8])surface_color=info_q[(bank_q?16:0)+5]?24'h4f8fc0:24'hcbd3df;
end
if(instrument_q==0 && bank_q==1'd1 && surface_cmp[98] && surface_cmp[99] && surface_cmp[3] && surface_cmp[2])begin
surface_color=info_q[(bank_q?16:0)+7]?24'hc5def7:24'hffffff;
if(surface_cmp[100] || surface_cmp[101] || surface_cmp[8])surface_color=info_q[(bank_q?16:0)+7]?24'h4f8fc0:24'hcbd3df;
end
if(instrument_q==0 && bank_q==1'd1 && surface_cmp[102] && surface_cmp[103] && surface_cmp[3] && surface_cmp[2])begin
surface_color=info_q[(bank_q?16:0)+8]?24'hc5def7:24'hffffff;
if(surface_cmp[104] || surface_cmp[105] || surface_cmp[8])surface_color=info_q[(bank_q?16:0)+8]?24'h4f8fc0:24'hcbd3df;
end
if(instrument_q==0 && bank_q==1'd1 && surface_cmp[106] && surface_cmp[107] && surface_cmp[3] && surface_cmp[2])begin
surface_color=info_q[(bank_q?16:0)+10]?24'hc5def7:24'hffffff;
if(surface_cmp[108] || surface_cmp[109] || surface_cmp[8])surface_color=info_q[(bank_q?16:0)+10]?24'h4f8fc0:24'hcbd3df;
end
if(instrument_q==0 && bank_q==1'd1 && surface_cmp[110] && surface_cmp[111] && surface_cmp[3] && surface_cmp[2])begin
surface_color=info_q[(bank_q?16:0)+12]?24'hc5def7:24'hffffff;
if(surface_cmp[112] || surface_cmp[113] || surface_cmp[8])surface_color=info_q[(bank_q?16:0)+12]?24'h4f8fc0:24'hcbd3df;
end
if(instrument_q==0 && bank_q==1'd1 && surface_cmp[114] && surface_cmp[115] && surface_cmp[3] && surface_cmp[2])begin
surface_color=info_q[(bank_q?16:0)+13]?24'hc5def7:24'hffffff;
if(surface_cmp[116] || surface_cmp[117] || surface_cmp[8])surface_color=info_q[(bank_q?16:0)+13]?24'h4f8fc0:24'hcbd3df;
end
if(instrument_q==0 && bank_q==1'd1 && surface_cmp[118] && surface_cmp[1] && surface_cmp[3] && surface_cmp[2])begin
surface_color=info_q[(bank_q?16:0)+15]?24'hc5def7:24'hffffff;
if(surface_cmp[119] || surface_cmp[39] || surface_cmp[8])surface_color=info_q[(bank_q?16:0)+15]?24'h4f8fc0:24'hcbd3df;
end
if(instrument_q==0 && bank_q==1'd1 && surface_cmp[120] && surface_cmp[121] && surface_cmp[3] && surface_cmp[42])begin
surface_color=info_q[(bank_q?16:0)+2]?24'h497eaa:24'h293344;
if(surface_cmp[122] || surface_cmp[123] || surface_cmp[45])surface_color=info_q[(bank_q?16:0)+2]?24'h32668f:24'h182232;
if(surface_cmp[124] && surface_cmp[125] && surface_cmp[48] && surface_cmp[49])surface_color=info_q[(bank_q?16:0)+2]?24'h85bce4:24'h49566b;
end
if(instrument_q==0 && bank_q==1'd1 && surface_cmp[126] && surface_cmp[127] && surface_cmp[3] && surface_cmp[42])begin
surface_color=info_q[(bank_q?16:0)+4]?24'h497eaa:24'h293344;
if(surface_cmp[128] || surface_cmp[129] || surface_cmp[45])surface_color=info_q[(bank_q?16:0)+4]?24'h32668f:24'h182232;
if(surface_cmp[130] && surface_cmp[131] && surface_cmp[48] && surface_cmp[49])surface_color=info_q[(bank_q?16:0)+4]?24'h85bce4:24'h49566b;
end
if(instrument_q==0 && bank_q==1'd1 && surface_cmp[132] && surface_cmp[133] && surface_cmp[3] && surface_cmp[42])begin
surface_color=info_q[(bank_q?16:0)+6]?24'h497eaa:24'h293344;
if(surface_cmp[134] || surface_cmp[135] || surface_cmp[45])surface_color=info_q[(bank_q?16:0)+6]?24'h32668f:24'h182232;
if(surface_cmp[136] && surface_cmp[137] && surface_cmp[48] && surface_cmp[49])surface_color=info_q[(bank_q?16:0)+6]?24'h85bce4:24'h49566b;
end
if(instrument_q==0 && bank_q==1'd1 && surface_cmp[138] && surface_cmp[139] && surface_cmp[3] && surface_cmp[42])begin
surface_color=info_q[(bank_q?16:0)+9]?24'h497eaa:24'h293344;
if(surface_cmp[140] || surface_cmp[141] || surface_cmp[45])surface_color=info_q[(bank_q?16:0)+9]?24'h32668f:24'h182232;
if(surface_cmp[142] && surface_cmp[143] && surface_cmp[48] && surface_cmp[49])surface_color=info_q[(bank_q?16:0)+9]?24'h85bce4:24'h49566b;
end
if(instrument_q==0 && bank_q==1'd1 && surface_cmp[144] && surface_cmp[145] && surface_cmp[3] && surface_cmp[42])begin
surface_color=info_q[(bank_q?16:0)+11]?24'h497eaa:24'h293344;
if(surface_cmp[146] || surface_cmp[147] || surface_cmp[45])surface_color=info_q[(bank_q?16:0)+11]?24'h32668f:24'h182232;
if(surface_cmp[148] && surface_cmp[149] && surface_cmp[48] && surface_cmp[49])surface_color=info_q[(bank_q?16:0)+11]?24'h85bce4:24'h49566b;
end
if(instrument_q==0 && bank_q==1'd1 && surface_cmp[150] && surface_cmp[151] && surface_cmp[3] && surface_cmp[42])begin
surface_color=info_q[(bank_q?16:0)+14]?24'h497eaa:24'h293344;
if(surface_cmp[152] || surface_cmp[153] || surface_cmp[45])surface_color=info_q[(bank_q?16:0)+14]?24'h32668f:24'h182232;
if(surface_cmp[154] && surface_cmp[155] && surface_cmp[48] && surface_cmp[49])surface_color=info_q[(bank_q?16:0)+14]?24'h85bce4:24'h49566b;
end
if(instrument_q==1)begin
surface_color=24'hf1e6d4;
if(surface_cmp[156])surface_color=24'hf5e5cf;
if(surface_cmp[157] && surface_cmp[158] && surface_cmp[159] && surface_cmp[160])begin
if(guitar_string_active[0])surface_color=24'he4d6bd;
if(surface_cmp[161] && surface_cmp[162] && surface_cmp[163] && surface_cmp[164])surface_color=guitar_string_muted[0]?24'hc5b8a6:guitar_string_active[0]?24'h397f9e:24'h94846c;
if(guitar_string_active[0] && surface_cmp[161] && surface_cmp[162] && surface_cmp[165] && surface_cmp[166])surface_color=24'h397f9e;
end
if(surface_cmp[157] && surface_cmp[158] && surface_cmp[167] && surface_cmp[168])begin
if(guitar_string_active[1])surface_color=24'he4d6bd;
if(surface_cmp[161] && surface_cmp[162] && surface_cmp[169] && surface_cmp[170])surface_color=guitar_string_muted[1]?24'hc5b8a6:guitar_string_active[1]?24'h397f9e:24'h94846c;
if(guitar_string_active[1] && surface_cmp[161] && surface_cmp[162] && surface_cmp[171] && surface_cmp[172])surface_color=24'h397f9e;
end
if(surface_cmp[157] && surface_cmp[158] && surface_cmp[173] && surface_cmp[174])begin
if(guitar_string_active[2])surface_color=24'he4d6bd;
if(surface_cmp[161] && surface_cmp[162] && surface_cmp[175] && surface_cmp[176])surface_color=guitar_string_muted[2]?24'hc5b8a6:guitar_string_active[2]?24'h397f9e:24'h94846c;
if(guitar_string_active[2] && surface_cmp[161] && surface_cmp[162] && surface_cmp[177] && surface_cmp[178])surface_color=24'h397f9e;
end
if(surface_cmp[157] && surface_cmp[158] && surface_cmp[179] && surface_cmp[180])begin
if(guitar_string_active[3])surface_color=24'he4d6bd;
if(surface_cmp[161] && surface_cmp[162] && surface_cmp[45] && surface_cmp[181])surface_color=guitar_string_muted[3]?24'hc5b8a6:guitar_string_active[3]?24'h397f9e:24'h94846c;
if(guitar_string_active[3] && surface_cmp[161] && surface_cmp[162] && surface_cmp[182] && surface_cmp[42])surface_color=24'h397f9e;
end
if(surface_cmp[157] && surface_cmp[158] && surface_cmp[183] && surface_cmp[184])begin
if(guitar_string_active[4])surface_color=24'he4d6bd;
if(surface_cmp[161] && surface_cmp[162] && surface_cmp[185] && surface_cmp[186])surface_color=guitar_string_muted[4]?24'hc5b8a6:guitar_string_active[4]?24'h397f9e:24'h94846c;
if(guitar_string_active[4] && surface_cmp[161] && surface_cmp[162] && surface_cmp[187] && surface_cmp[188])surface_color=24'h397f9e;
end
if(surface_cmp[157] && surface_cmp[158] && surface_cmp[189] && surface_cmp[190])begin
if(guitar_string_active[5])surface_color=24'he4d6bd;
if(surface_cmp[161] && surface_cmp[162] && surface_cmp[191] && surface_cmp[192])surface_color=guitar_string_muted[5]?24'hc5b8a6:guitar_string_active[5]?24'h397f9e:24'h94846c;
if(guitar_string_active[5] && surface_cmp[161] && surface_cmp[162] && surface_cmp[193] && surface_cmp[194])surface_color=24'h397f9e;
end
if(surface_cmp[195] && surface_cmp[196] && surface_cmp[4] && surface_cmp[197])surface_color=info_q[228:226]==3'd0 ? 24'hd6e7ef : 24'hffffff;
if(surface_cmp[198] && surface_cmp[199] && surface_cmp[4] && surface_cmp[197])surface_color=info_q[228:226]==3'd1 ? 24'hd6e7ef : 24'hffffff;
if(surface_cmp[200] && surface_cmp[201] && surface_cmp[4] && surface_cmp[197])surface_color=info_q[228:226]==3'd2 ? 24'hd6e7ef : 24'hffffff;
if(surface_cmp[202] && surface_cmp[203] && surface_cmp[4] && surface_cmp[197])surface_color=info_q[228:226]==3'd3 ? 24'hd6e7ef : 24'hffffff;
if(surface_cmp[204] && surface_cmp[205] && surface_cmp[4] && surface_cmp[197])surface_color=info_q[228:226]==3'd4 ? 24'hd6e7ef : 24'hffffff;
if(surface_cmp[206] && surface_cmp[207] && surface_cmp[4] && surface_cmp[197])surface_color=info_q[228:226]==3'd5 ? 24'hd6e7ef : 24'hffffff;
if(surface_cmp[208] && surface_cmp[209] && surface_cmp[4] && surface_cmp[197])surface_color=info_q[228:226]==3'd6 ? 24'hd6e7ef : 24'hffffff;
end
