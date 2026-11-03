// Schroeder comb RT60 coefficients, Q15. Damping shortens high-frequency tails.
module reverb_coeff(input [3:0] selector, output reg [15:0] g0,g1,g2,g3);
always @* case(selector)
4'd0:begin g0=16'd15411;g1=16'd14593;g2=16'd12758;g3=16'd11450;end
4'd1:begin g0=16'd20839;g1=16'd20168;g2=16'd18606;g3=16'd17437;end
4'd2:begin g0=16'd24694;g1=16'd24194;g2=16'd23005;g3=16'd22091;end
4'd3:begin g0=16'd27136;g1=16'd26768;g2=16'd25884;g3=16'd25194;end
4'd4:begin g0=16'd28446;g1=16'd28157;g2=16'd27456;g3=16'd26905;end
4'd5:begin g0=16'd29819;g1=16'd29617;g2=16'd29123;g3=16'd28732;end
4'd6:begin g0=16'd30531;g1=16'd30375;g2=16'd29995;g3=16'd29692;end
4'd7:begin g0=16'd31259;g1=16'd31153;g2=16'd30892;g3=16'd30684;end
4'd8:begin g0=16'd31630;g1=16'd31549;g2=16'd31351;g3=16'd31192;end
4'd9:begin g0=16'd32035;g1=16'd31982;g2=16'd31854;g3=16'd31751;end
default:begin g0=0;g1=0;g2=0;g3=0;end
endcase
endmodule
