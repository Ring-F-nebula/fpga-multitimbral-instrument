// Included by input decoder and renderer so drawn keys and hit regions agree.
function [4:0] music_key_at;
    input [1:0] instrument;
    input [10:0] px;
    input [9:0] py;
    integer white_key,string_number;
    begin
        music_key_at=31;
        if(px>=16 && px<1008 && py>=376 && py<592) begin
            if(instrument==0) begin
                white_key=(px-16)/124;
                case(white_key)
                    0:music_key_at=0;1:music_key_at=2;2:music_key_at=4;
                    3:music_key_at=5;4:music_key_at=7;5:music_key_at=9;
                    6:music_key_at=11;7:music_key_at=12;
                endcase
                if(py<500) begin
                    if(px>=104 && px<176) music_key_at=1;
                    else if(px>=228 && px<300) music_key_at=3;
                    else if(px>=476 && px<548) music_key_at=6;
                    else if(px>=600 && px<672) music_key_at=8;
                    else if(px>=724 && px<796) music_key_at=10;
                end
            end else if(instrument==1) begin
                string_number=(py-376)/36;
                music_key_at=string_number+(px>=512 ? 6:0);
            end else if(instrument==2) begin
                if(px<336) music_key_at=0;
                else if(px>=352 && px<672) music_key_at=1;
                else if(px>=688) music_key_at=2;
                if(py>=492 && music_key_at<6) music_key_at=music_key_at+3;
                if(py>=476 && py<492) music_key_at=31;
            end
        end
    end
endfunction
function [3:0] action_at;
    input [10:0] px;
    input [9:0] py;
    begin
        action_at=0;
        if(py>=8 && py<44 && px>=864 && px<1008) action_at=10;
        else if(py>=52 && py<100) begin
            if(px>=16 && px<208) action_at=1;
            else if(px>=224 && px<416) action_at=2;
            else if(px>=432 && px<624) action_at=3;
            else if(px>=640 && px<752) action_at=4;
            else if(px>=768 && px<880) action_at=5;
            else if(px>=896 && px<1008) action_at=6;
        end else if(py>=185 && py<225) begin
            if(px>=280 && px<352) action_at=7;
            else if(px>=368 && px<440) action_at=8;
        end else if(py>=104 && py<128 && px>=864) action_at=9;
    end
endfunction
function [3:0] game_action_at;
    input [10:0] px;
    input [9:0] py;
    begin
        game_action_at=0;
        if(py>=8 && py<44 && px>=864 && px<1008) game_action_at=10;
        else if(py>=52 && py<100) begin
            if(px>=16 && px<208) game_action_at=1;
            else if(px>=224 && px<416) game_action_at=4;
            else if(px>=432 && px<624) game_action_at=7;
            else if(px>=640 && px<832) game_action_at=8;
        end
    end
endfunction
