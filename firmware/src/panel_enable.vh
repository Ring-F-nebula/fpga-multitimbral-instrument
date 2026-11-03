// The controller and renderer use the same availability rules.
function panel_enabled;
 input [7:0] a;input [1:0] inst;input [3:0] vol,at,dc,rl;
 input [7:0] su;input [127:0] fx;input [255:0] inf;input [2:0] pg;
 reg recording_now,mapping_ok,has_audio;
 begin
  recording_now=inf[82]||inf[217]||inf[239];has_audio=inf[219]||(|inf[216:200]);
  mapping_ok=!recording_now&&!inf[83]&&!inf[221]&&inf[45:40]==0&&inst==0;
  panel_enabled=1;
  case(a)
   16:panel_enabled=inst!=1;
   17:panel_enabled=inst!=1; // Guitar uses a permanent analyzer, no hide button.
   8:panel_enabled=vol>0;9:panel_enabled=vol<15;
   20:panel_enabled=inst!=2&&at>0;21:panel_enabled=inst!=2&&at<9;
   22:panel_enabled=inst!=2&&dc>0;23:panel_enabled=inst!=2&&dc<9;
   24:panel_enabled=inst!=2&&su>0;25:panel_enabled=inst!=2&&su<255;
   26:panel_enabled=inst!=2&&rl>0;27:panel_enabled=inst!=2&&rl<9;
   30,33,40,41:panel_enabled=inst!=2;
   38:panel_enabled=inst!=2&&fx[119:112]>0;39:panel_enabled=inst!=2&&fx[119:112]<200;
   31:panel_enabled=inst!=2&&fx[87:80]>0;32:panel_enabled=inst!=2&&fx[87:80]<9;
   34:panel_enabled=inst!=2&&fx[95:88]>1;35:panel_enabled=inst!=2&&fx[95:88]<200;
   36:panel_enabled=inst!=2&&fx[103:96]>0;37:panel_enabled=inst!=2&&fx[103:96]<100;
   28,29,42,57:panel_enabled=inst!=2;
   51:panel_enabled=fx[0]&&!fx[5]&&fx[15:8]>1;52:panel_enabled=fx[0]&&!fx[5]&&fx[15:8]<100;
   53:panel_enabled=fx[0]&&!fx[5]&&fx[23:16]>0;54:panel_enabled=fx[0]&&!fx[5]&&fx[23:16]<230;
   55:panel_enabled=fx[0]&&!fx[5]&&fx[31:24]>0;56:panel_enabled=fx[0]&&!fx[5]&&fx[31:24]<255;
   61:panel_enabled=fx[1]&&!fx[5]&&fx[39:32]>1;62:panel_enabled=fx[1]&&!fx[5]&&fx[39:32]<100;
   63:panel_enabled=fx[1]&&!fx[5]&&fx[47:40]>0;64:panel_enabled=fx[1]&&!fx[5]&&fx[47:40]<100;
   65:panel_enabled=fx[1]&&!fx[5]&&fx[55:48]>0;66:panel_enabled=fx[1]&&!fx[5]&&fx[55:48]<255;
   71:panel_enabled=fx[2]&&!fx[5]&&fx[63:56]>0;72:panel_enabled=fx[2]&&!fx[5]&&fx[63:56]<100;
   73:panel_enabled=fx[2]&&!fx[5]&&fx[71:64]>0;74:panel_enabled=fx[2]&&!fx[5]&&fx[71:64]<9;
   75:panel_enabled=fx[2]&&!fx[5]&&fx[79:72]>0;76:panel_enabled=fx[2]&&!fx[5]&&fx[79:72]<255;
   90:panel_enabled=(inf[80:79]!=3||inf[108])&&(pg!=6||(inf[230]&&(inf[80:79]!=3||inf[231])));
   91:panel_enabled=inf[80:79]!=3||inf[108];
   126:panel_enabled=inf[221];
   92:panel_enabled=inf[221]&&!inf[81];93:panel_enabled=inf[221]&&inf[81];
   94:panel_enabled=inf[221];95:panel_enabled=inf[78:71]>40;96:panel_enabled=inf[78:71]<200;
   104,105,106,107:panel_enabled=inf[45:40]!=0;
   108:panel_enabled=!recording_now&&!inf[83];109:panel_enabled=recording_now;
   110,117:panel_enabled=inf[238]&&!recording_now&&!inf[221];
   111,118:panel_enabled=!recording_now&&!inf[83]&&(inf[93:84]!=0||has_audio);
   112:panel_enabled=!inf[217]&&!inf[239];113:panel_enabled=inf[217]||inf[239];
   115:panel_enabled=!recording_now&&!inf[83];116:panel_enabled=recording_now||inf[83];
   120,121,124:panel_enabled=mapping_ok;
   122:panel_enabled=mapping_ok&&inf[135:128]>24;123:panel_enabled=mapping_ok&&inf[135:128]<108;
   159:panel_enabled=!inf[127]&&inf[45:40]==0&&!inf[83];
   default:panel_enabled=1;
  endcase
 end
endfunction
