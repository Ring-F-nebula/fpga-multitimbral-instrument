// Shared power-on and LCD reset values. Rate: 0.1 Hz; wet/feedback: /256.
// Effects stay individually switchable. Remote bend stays at concert pitch.
function [7:0] fx_default_byte;
 input [3:0] index;
 begin case(index)
  0:fx_default_byte=0;
  1:fx_default_byte=24;  // delay 240 ms
  2:fx_default_byte=128; // feedback 50%
  3:fx_default_byte=102; // delay mix about 40%
  4:fx_default_byte=12;  // chorus 1.2 Hz
  5:fx_default_byte=70;  // chorus depth 70%
  6:fx_default_byte=115; // chorus mix about 45%
  7:fx_default_byte=70;  // reverb space 70%
  8:fx_default_byte=5;   // reverb decay 2400 ms
  9:fx_default_byte=115; // reverb mix about 45%
  10:fx_default_byte=5;  // glide 200 ms
  11:fx_default_byte=55; // vibrato 5.5 Hz
  12:fx_default_byte=35; // vibrato depth 35 cents
  13:fx_default_byte=32; // automatic pitch target
  default:fx_default_byte=100; // neutral remote bend
 endcase end
endfunction
