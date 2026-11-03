// Included inside modules. F5 framing and IDs 1..6 remain unchanged.
function fx_valid;
    input [7:0] id, value;
    begin case(id)
        8'h10: fx_valid=(value<=127); // delay, chorus, reverb, glide, vibrato, bypass, remote bend
        8'h11: fx_valid=(value>=1 && value<=100); // delay, 10 ms units
        8'h12: fx_valid=(value<=230); // feedback / 256
        8'h13,8'h16,8'h19: fx_valid=1; // wet / 256
        8'h14: fx_valid=(value>=1 && value<=100); // chorus, 0.1 Hz
        8'h15,8'h17,8'h1c: fx_valid=(value<=100); // depth, space, cents
        8'h18,8'h1a: fx_valid=(value<=9); // decay / glide selector
        8'h1b: fx_valid=(value>=1 && value<=200); // vibrato, 0.1 Hz
        8'h1d: fx_valid=(value<=32); // 0..15 explicit, 16 latest note
        8'h1e: fx_valid=(value<=200); // (value - 100) * 2 cents
        8'h1f: fx_valid=(value<=1); // 1 latched STOP, 0 explicit resume
        8'h23:fx_valid=(value<=2);
        8'h24:fx_valid=(value<=200);
        8'h25:fx_valid=1;
        8'h26:fx_valid=(value<=100);
        8'h27:fx_valid=(value==0||value==4||value==8||value==16||value==32);
        8'h28,8'h30:fx_valid=(value<=31);
        8'h29,8'h2a:fx_valid=(value<=1);
        8'h2b,8'h32,8'h44,8'h53:fx_valid=(value==1);
        8'h2c:fx_valid=(value>=40&&value<=200);
        8'h2d,8'h2e,8'h50:fx_valid=(value<=3);
        8'h31:fx_valid=(value>=24&&value<=108);
        8'h40:fx_valid=(value>=1&&value<=128);
        8'h41:fx_valid=(value<128);
        8'h42:fx_valid=(value<32||value==255);
        8'h43:fx_valid=(value>=1&&value<=32);
        8'h45,8'h51:fx_valid=1;
        8'h52:fx_valid=(value<=1);
        8'h54:fx_valid=(value<=6); // Open, C, G, Am, F, Dm, Em
        8'h55:fx_valid=(value<=1); // Guitar strings / live analyzer
        8'h60:fx_valid=(value<=3);8'h61:fx_valid=1;
        8'h62:fx_valid=(value<=1);8'h63:fx_valid=(value<=3);
        8'h70:fx_valid=(value==1);
        8'h71,8'h72,8'h73,8'h74,8'h75,8'h76,8'h77:fx_valid=1;
        8'h78,8'h79:fx_valid=(value<=1);
        8'h7a:fx_valid=(value==1||value==2||value==3||value==7||value==8);
        default: fx_valid=0;
    endcase end
endfunction
