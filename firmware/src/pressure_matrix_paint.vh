if(page_q==6)begin
surface_hit=surface_cmp[210]&&surface_cmp[184];surface_color=24'hf7f8fc;
if(surface_cmp[211]&&surface_cmp[196]&&surface_cmp[210]&&surface_cmp[212])begin
surface_color=24'hffffff;matrix_edge=24'he0e5ef;
if(running_q&&!info_q[81]&&cue_q[0])begin surface_color=24'hfff0c2;matrix_edge=24'he9b34a;end
if(fsr_keys_q[0])begin surface_color=24'hdce9fd;matrix_edge=24'h7095d7;
if(running_q&&!info_q[81])begin surface_color=cue_q[0]?24'he0f1e7:24'hf9dede;matrix_edge=cue_q[0]?24'h4c9e7a:24'hd88083;end end
if(running_q&&!info_q[81]&&game_keys_q[0]&&!fsr_keys_q[0])begin
if(feedback_q==4)matrix_edge=24'hd88083;else if(cue_q[0]&&(feedback_q==1||feedback_q==2))matrix_edge=24'h4c9e7a;end
if(surface_cmp[213]||surface_cmp[214]||surface_cmp[215]||surface_cmp[216])surface_color=matrix_edge;
end
if(surface_cmp[217]&&surface_cmp[218]&&surface_cmp[210]&&surface_cmp[212])begin
surface_color=24'hffffff;matrix_edge=24'he0e5ef;
if(running_q&&!info_q[81]&&cue_q[1])begin surface_color=24'hfff0c2;matrix_edge=24'he9b34a;end
if(fsr_keys_q[1])begin surface_color=24'hdce9fd;matrix_edge=24'h7095d7;
if(running_q&&!info_q[81])begin surface_color=cue_q[1]?24'he0f1e7:24'hf9dede;matrix_edge=cue_q[1]?24'h4c9e7a:24'hd88083;end end
if(running_q&&!info_q[81]&&game_keys_q[1]&&!fsr_keys_q[1])begin
if(feedback_q==4)matrix_edge=24'hd88083;else if(cue_q[1]&&(feedback_q==1||feedback_q==2))matrix_edge=24'h4c9e7a;end
if(surface_cmp[219]||surface_cmp[220]||surface_cmp[215]||surface_cmp[216])surface_color=matrix_edge;
end
if(surface_cmp[221]&&surface_cmp[222]&&surface_cmp[210]&&surface_cmp[212])begin
surface_color=24'hffffff;matrix_edge=24'he0e5ef;
if(running_q&&!info_q[81]&&cue_q[2])begin surface_color=24'hfff0c2;matrix_edge=24'he9b34a;end
if(fsr_keys_q[2])begin surface_color=24'hdce9fd;matrix_edge=24'h7095d7;
if(running_q&&!info_q[81])begin surface_color=cue_q[2]?24'he0f1e7:24'hf9dede;matrix_edge=cue_q[2]?24'h4c9e7a:24'hd88083;end end
if(running_q&&!info_q[81]&&game_keys_q[2]&&!fsr_keys_q[2])begin
if(feedback_q==4)matrix_edge=24'hd88083;else if(cue_q[2]&&(feedback_q==1||feedback_q==2))matrix_edge=24'h4c9e7a;end
if(surface_cmp[223]||surface_cmp[224]||surface_cmp[215]||surface_cmp[216])surface_color=matrix_edge;
end
if(surface_cmp[225]&&surface_cmp[1]&&surface_cmp[210]&&surface_cmp[212])begin
surface_color=24'hffffff;matrix_edge=24'he0e5ef;
if(running_q&&!info_q[81]&&cue_q[3])begin surface_color=24'hfff0c2;matrix_edge=24'he9b34a;end
if(fsr_keys_q[3])begin surface_color=24'hdce9fd;matrix_edge=24'h7095d7;
if(running_q&&!info_q[81])begin surface_color=cue_q[3]?24'he0f1e7:24'hf9dede;matrix_edge=cue_q[3]?24'h4c9e7a:24'hd88083;end end
if(running_q&&!info_q[81]&&game_keys_q[3]&&!fsr_keys_q[3])begin
if(feedback_q==4)matrix_edge=24'hd88083;else if(cue_q[3]&&(feedback_q==1||feedback_q==2))matrix_edge=24'h4c9e7a;end
if(surface_cmp[145]||surface_cmp[226]||surface_cmp[215]||surface_cmp[216])surface_color=matrix_edge;
end
if(surface_cmp[211]&&surface_cmp[196]&&surface_cmp[227]&&surface_cmp[228])begin
surface_color=24'hffffff;matrix_edge=24'he0e5ef;
if(running_q&&!info_q[81]&&cue_q[4])begin surface_color=24'hfff0c2;matrix_edge=24'he9b34a;end
if(fsr_keys_q[4])begin surface_color=24'hdce9fd;matrix_edge=24'h7095d7;
if(running_q&&!info_q[81])begin surface_color=cue_q[4]?24'he0f1e7:24'hf9dede;matrix_edge=cue_q[4]?24'h4c9e7a:24'hd88083;end end
if(running_q&&!info_q[81]&&game_keys_q[4]&&!fsr_keys_q[4])begin
if(feedback_q==4)matrix_edge=24'hd88083;else if(cue_q[4]&&(feedback_q==1||feedback_q==2))matrix_edge=24'h4c9e7a;end
if(surface_cmp[213]||surface_cmp[214]||surface_cmp[229]||surface_cmp[230])surface_color=matrix_edge;
end
if(surface_cmp[217]&&surface_cmp[218]&&surface_cmp[227]&&surface_cmp[228])begin
surface_color=24'hffffff;matrix_edge=24'he0e5ef;
if(running_q&&!info_q[81]&&cue_q[5])begin surface_color=24'hfff0c2;matrix_edge=24'he9b34a;end
if(fsr_keys_q[5])begin surface_color=24'hdce9fd;matrix_edge=24'h7095d7;
if(running_q&&!info_q[81])begin surface_color=cue_q[5]?24'he0f1e7:24'hf9dede;matrix_edge=cue_q[5]?24'h4c9e7a:24'hd88083;end end
if(running_q&&!info_q[81]&&game_keys_q[5]&&!fsr_keys_q[5])begin
if(feedback_q==4)matrix_edge=24'hd88083;else if(cue_q[5]&&(feedback_q==1||feedback_q==2))matrix_edge=24'h4c9e7a;end
if(surface_cmp[219]||surface_cmp[220]||surface_cmp[229]||surface_cmp[230])surface_color=matrix_edge;
end
if(surface_cmp[221]&&surface_cmp[222]&&surface_cmp[227]&&surface_cmp[228])begin
surface_color=24'hffffff;matrix_edge=24'he0e5ef;
if(running_q&&!info_q[81]&&cue_q[6])begin surface_color=24'hfff0c2;matrix_edge=24'he9b34a;end
if(fsr_keys_q[6])begin surface_color=24'hdce9fd;matrix_edge=24'h7095d7;
if(running_q&&!info_q[81])begin surface_color=cue_q[6]?24'he0f1e7:24'hf9dede;matrix_edge=cue_q[6]?24'h4c9e7a:24'hd88083;end end
if(running_q&&!info_q[81]&&game_keys_q[6]&&!fsr_keys_q[6])begin
if(feedback_q==4)matrix_edge=24'hd88083;else if(cue_q[6]&&(feedback_q==1||feedback_q==2))matrix_edge=24'h4c9e7a;end
if(surface_cmp[223]||surface_cmp[224]||surface_cmp[229]||surface_cmp[230])surface_color=matrix_edge;
end
if(surface_cmp[225]&&surface_cmp[1]&&surface_cmp[227]&&surface_cmp[228])begin
surface_color=24'hffffff;matrix_edge=24'he0e5ef;
if(running_q&&!info_q[81]&&cue_q[7])begin surface_color=24'hfff0c2;matrix_edge=24'he9b34a;end
if(fsr_keys_q[7])begin surface_color=24'hdce9fd;matrix_edge=24'h7095d7;
if(running_q&&!info_q[81])begin surface_color=cue_q[7]?24'he0f1e7:24'hf9dede;matrix_edge=cue_q[7]?24'h4c9e7a:24'hd88083;end end
if(running_q&&!info_q[81]&&game_keys_q[7]&&!fsr_keys_q[7])begin
if(feedback_q==4)matrix_edge=24'hd88083;else if(cue_q[7]&&(feedback_q==1||feedback_q==2))matrix_edge=24'h4c9e7a;end
if(surface_cmp[145]||surface_cmp[226]||surface_cmp[229]||surface_cmp[230])surface_color=matrix_edge;
end
if(surface_cmp[211]&&surface_cmp[196]&&surface_cmp[231]&&surface_cmp[232])begin
surface_color=24'hffffff;matrix_edge=24'he0e5ef;
if(running_q&&!info_q[81]&&cue_q[8])begin surface_color=24'hfff0c2;matrix_edge=24'he9b34a;end
if(fsr_keys_q[8])begin surface_color=24'hdce9fd;matrix_edge=24'h7095d7;
if(running_q&&!info_q[81])begin surface_color=cue_q[8]?24'he0f1e7:24'hf9dede;matrix_edge=cue_q[8]?24'h4c9e7a:24'hd88083;end end
if(running_q&&!info_q[81]&&game_keys_q[8]&&!fsr_keys_q[8])begin
if(feedback_q==4)matrix_edge=24'hd88083;else if(cue_q[8]&&(feedback_q==1||feedback_q==2))matrix_edge=24'h4c9e7a;end
if(surface_cmp[213]||surface_cmp[214]||surface_cmp[233]||surface_cmp[234])surface_color=matrix_edge;
end
if(surface_cmp[217]&&surface_cmp[218]&&surface_cmp[231]&&surface_cmp[232])begin
surface_color=24'hffffff;matrix_edge=24'he0e5ef;
if(running_q&&!info_q[81]&&cue_q[9])begin surface_color=24'hfff0c2;matrix_edge=24'he9b34a;end
if(fsr_keys_q[9])begin surface_color=24'hdce9fd;matrix_edge=24'h7095d7;
if(running_q&&!info_q[81])begin surface_color=cue_q[9]?24'he0f1e7:24'hf9dede;matrix_edge=cue_q[9]?24'h4c9e7a:24'hd88083;end end
if(running_q&&!info_q[81]&&game_keys_q[9]&&!fsr_keys_q[9])begin
if(feedback_q==4)matrix_edge=24'hd88083;else if(cue_q[9]&&(feedback_q==1||feedback_q==2))matrix_edge=24'h4c9e7a;end
if(surface_cmp[219]||surface_cmp[220]||surface_cmp[233]||surface_cmp[234])surface_color=matrix_edge;
end
if(surface_cmp[221]&&surface_cmp[222]&&surface_cmp[231]&&surface_cmp[232])begin
surface_color=24'hffffff;matrix_edge=24'he0e5ef;
if(running_q&&!info_q[81]&&cue_q[10])begin surface_color=24'hfff0c2;matrix_edge=24'he9b34a;end
if(fsr_keys_q[10])begin surface_color=24'hdce9fd;matrix_edge=24'h7095d7;
if(running_q&&!info_q[81])begin surface_color=cue_q[10]?24'he0f1e7:24'hf9dede;matrix_edge=cue_q[10]?24'h4c9e7a:24'hd88083;end end
if(running_q&&!info_q[81]&&game_keys_q[10]&&!fsr_keys_q[10])begin
if(feedback_q==4)matrix_edge=24'hd88083;else if(cue_q[10]&&(feedback_q==1||feedback_q==2))matrix_edge=24'h4c9e7a;end
if(surface_cmp[223]||surface_cmp[224]||surface_cmp[233]||surface_cmp[234])surface_color=matrix_edge;
end
if(surface_cmp[225]&&surface_cmp[1]&&surface_cmp[231]&&surface_cmp[232])begin
surface_color=24'hffffff;matrix_edge=24'he0e5ef;
if(running_q&&!info_q[81]&&cue_q[11])begin surface_color=24'hfff0c2;matrix_edge=24'he9b34a;end
if(fsr_keys_q[11])begin surface_color=24'hdce9fd;matrix_edge=24'h7095d7;
if(running_q&&!info_q[81])begin surface_color=cue_q[11]?24'he0f1e7:24'hf9dede;matrix_edge=cue_q[11]?24'h4c9e7a:24'hd88083;end end
if(running_q&&!info_q[81]&&game_keys_q[11]&&!fsr_keys_q[11])begin
if(feedback_q==4)matrix_edge=24'hd88083;else if(cue_q[11]&&(feedback_q==1||feedback_q==2))matrix_edge=24'h4c9e7a;end
if(surface_cmp[145]||surface_cmp[226]||surface_cmp[233]||surface_cmp[234])surface_color=matrix_edge;
end
if(surface_cmp[211]&&surface_cmp[196]&&surface_cmp[235]&&surface_cmp[184])begin
surface_color=24'hffffff;matrix_edge=24'he0e5ef;
if(running_q&&!info_q[81]&&cue_q[12])begin surface_color=24'hfff0c2;matrix_edge=24'he9b34a;end
if(fsr_keys_q[12])begin surface_color=24'hdce9fd;matrix_edge=24'h7095d7;
if(running_q&&!info_q[81])begin surface_color=cue_q[12]?24'he0f1e7:24'hf9dede;matrix_edge=cue_q[12]?24'h4c9e7a:24'hd88083;end end
if(running_q&&!info_q[81]&&game_keys_q[12]&&!fsr_keys_q[12])begin
if(feedback_q==4)matrix_edge=24'hd88083;else if(cue_q[12]&&(feedback_q==1||feedback_q==2))matrix_edge=24'h4c9e7a;end
if(surface_cmp[213]||surface_cmp[214]||surface_cmp[160]||surface_cmp[236])surface_color=matrix_edge;
end
if(surface_cmp[217]&&surface_cmp[218]&&surface_cmp[235]&&surface_cmp[184])begin
surface_color=24'hffffff;matrix_edge=24'he0e5ef;
if(running_q&&!info_q[81]&&cue_q[13])begin surface_color=24'hfff0c2;matrix_edge=24'he9b34a;end
if(fsr_keys_q[13])begin surface_color=24'hdce9fd;matrix_edge=24'h7095d7;
if(running_q&&!info_q[81])begin surface_color=cue_q[13]?24'he0f1e7:24'hf9dede;matrix_edge=cue_q[13]?24'h4c9e7a:24'hd88083;end end
if(running_q&&!info_q[81]&&game_keys_q[13]&&!fsr_keys_q[13])begin
if(feedback_q==4)matrix_edge=24'hd88083;else if(cue_q[13]&&(feedback_q==1||feedback_q==2))matrix_edge=24'h4c9e7a;end
if(surface_cmp[219]||surface_cmp[220]||surface_cmp[160]||surface_cmp[236])surface_color=matrix_edge;
end
if(surface_cmp[221]&&surface_cmp[222]&&surface_cmp[235]&&surface_cmp[184])begin
surface_color=24'hffffff;matrix_edge=24'he0e5ef;
if(running_q&&!info_q[81]&&cue_q[14])begin surface_color=24'hfff0c2;matrix_edge=24'he9b34a;end
if(fsr_keys_q[14])begin surface_color=24'hdce9fd;matrix_edge=24'h7095d7;
if(running_q&&!info_q[81])begin surface_color=cue_q[14]?24'he0f1e7:24'hf9dede;matrix_edge=cue_q[14]?24'h4c9e7a:24'hd88083;end end
if(running_q&&!info_q[81]&&game_keys_q[14]&&!fsr_keys_q[14])begin
if(feedback_q==4)matrix_edge=24'hd88083;else if(cue_q[14]&&(feedback_q==1||feedback_q==2))matrix_edge=24'h4c9e7a;end
if(surface_cmp[223]||surface_cmp[224]||surface_cmp[160]||surface_cmp[236])surface_color=matrix_edge;
end
if(surface_cmp[225]&&surface_cmp[1]&&surface_cmp[235]&&surface_cmp[184])begin
surface_color=24'hffffff;matrix_edge=24'he0e5ef;
if(running_q&&!info_q[81]&&cue_q[15])begin surface_color=24'hfff0c2;matrix_edge=24'he9b34a;end
if(fsr_keys_q[15])begin surface_color=24'hdce9fd;matrix_edge=24'h7095d7;
if(running_q&&!info_q[81])begin surface_color=cue_q[15]?24'he0f1e7:24'hf9dede;matrix_edge=cue_q[15]?24'h4c9e7a:24'hd88083;end end
if(running_q&&!info_q[81]&&game_keys_q[15]&&!fsr_keys_q[15])begin
if(feedback_q==4)matrix_edge=24'hd88083;else if(cue_q[15]&&(feedback_q==1||feedback_q==2))matrix_edge=24'h4c9e7a;end
if(surface_cmp[145]||surface_cmp[226]||surface_cmp[160]||surface_cmp[236])surface_color=matrix_edge;
end
end
