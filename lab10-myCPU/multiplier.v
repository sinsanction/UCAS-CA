module multiplier(
  input  [1:0]  mul_op,
  input  [31:0] mul_src1,
  input  [31:0] mul_src2,
  output [63:0] mul_result
);

wire op_mult;
wire op_multu;
wire [32:0] src1;
wire [32:0] src2;

assign op_mult  = mul_op[0];
assign op_multu = mul_op[1];

assign src1 = {33{op_mult}}  & {mul_src1[31],mul_src1[31:0]} | 
              {33{op_multu}} & {1'b0,mul_src1[31:0]};
assign src2 = {33{op_mult}}  & {mul_src2[31],mul_src2[31:0]} | 
              {33{op_multu}} & {1'b0,mul_src2[31:0]};

//assign mul_result = $signed(src1) * $signed(src2);
multiplier_33 umultiplier_33
(
  .X(src1      ),
  .Y(src2      ),
  .R(mul_result)
);

endmodule

//33bit multiplier (33bit input & 64bit output)
module multiplier_33(
    input  [32:0]    X,
    input  [32:0]    Y,
    output [63:0]    R
);

//17 booth encoder
wire [65:0] booth_p [16:0];
wire [16:0] booth_c;
wire [65:0] booth_X [16:0];

genvar i1;
generate for (i1=0; i1<66; i1=i1+1) begin : gen_for_ubooth_input
    assign booth_X[i1] = {{33{X[32]}},X[32:0]} << (i1 << 1);
end endgenerate

booth_66 ubooth_66_0(.y0(0), .y1(Y[0]), .y2(Y[1]), .x(booth_X[0]), .p(booth_p[0]), .c(booth_c[0]));
genvar i2;
generate for (i2=1; i2<=15; i2=i2+1) begin : gen_for_ubooth
	booth_66 ubooth_66(.y0(Y[2*i2-1]), .y1(Y[2*i2]), .y2(Y[2*i2+1]), .x(booth_X[i2]), .p(booth_p[i2]), .c(booth_c[i2]));
end endgenerate
booth_66 ubooth_66_16(.y0(Y[31]), .y1(Y[32]), .y2(Y[32]), .x(booth_X[16]), .p(booth_p[16]), .c(booth_c[16]));

//switch
wire [16:0] N [65:0];
genvar i3;
generate for (i3=0; i3<66; i3=i3+1) begin : gen_for_switch
    assign N[i3] = {booth_p[0][i3], booth_p[1][i3], booth_p[2][i3], booth_p[3][i3], 
                    booth_p[4][i3], booth_p[5][i3], booth_p[6][i3], booth_p[7][i3], 
                    booth_p[8][i3], booth_p[9][i3], booth_p[10][i3], booth_p[11][i3], 
                    booth_p[12][i3], booth_p[13][i3], booth_p[14][i3], booth_p[15][i3],
                    booth_p[16][i3]};
end endgenerate

//66 1bit wallace tree
wire [65:0] add_C;
wire [65:0] add_S;
wire [13:0] temp_C [66:0];

assign temp_C[0] = booth_c[13:0];
genvar i4;
generate for (i4=0; i4<66; i4=i4+1) begin : gen_for_uwallace
  wallace_1 uwallace_1(.Cin(temp_C[i4]), .N(N[i4]), .Cout(temp_C[i4+1]), .Cfinal(add_C[i4]), .Sfinal(add_S[i4]));
end endgenerate

//64bit adder
adder_64 uadder_64(.A({add_C[62:0], booth_c[14]}), .B(add_S[63:0]), .Cin(booth_c[15]), .S(R), .Cout());

endmodule

//66bit booth encoder
module booth_66(
    input           y0,
    input           y1,
    input           y2,
    input  [65:0]   x,
    output [65:0]   p,
    output          c
);

wire s_neg_1x;
wire s_neg_2x;
wire s_pos_1x;
wire s_pos_2x;

assign s_neg_1x = ~(~( y2 &  y1 & ~y0) & ~( y2 & ~y1 & y0));
assign s_pos_1x = ~(~(~y2 &  y1 & ~y0) & ~(~y2 & ~y1 & y0));
assign s_neg_2x = ~(~( y2 & ~y1 & ~y0));
assign s_pos_2x = ~(~(~y2 &  y1 &  y0));

assign p =  {66{s_neg_1x}} & {~x}        |
            {66{s_pos_1x}} & {x}         |
            {66{s_neg_2x}} & {~(x << 1)} |
            {66{s_pos_2x}} & {x << 1};

assign c = s_neg_2x | s_neg_1x;

endmodule

//1bit wallace tree (17 inputs)
module wallace_1(
    input  [13:0]    Cin,
    input  [16:0]    N,
    output [13:0]    Cout,
    output           Cfinal,
    output           Sfinal
);

//layer1: 5 1bit adder
wire [4:0] S1;
adder_1 uadder_1_1(.A(N[ 2]), .B(N[ 3]), .Cin(N[ 4]), .S(S1[0]), .Cout(Cout[0]));
adder_1 uadder_1_2(.A(N[ 5]), .B(N[ 6]), .Cin(N[ 7]), .S(S1[1]), .Cout(Cout[1]));
adder_1 uadder_1_3(.A(N[ 8]), .B(N[ 9]), .Cin(N[10]), .S(S1[2]), .Cout(Cout[2]));
adder_1 uadder_1_4(.A(N[11]), .B(N[12]), .Cin(N[13]), .S(S1[3]), .Cout(Cout[3]));
adder_1 uadder_1_5(.A(N[14]), .B(N[15]), .Cin(N[16]), .S(S1[4]), .Cout(Cout[4]));

//layer2: 4 1bit adder
wire [3:0] S2;
adder_1 uadder_1_6(.A(Cin[0]), .B(Cin[1]), .Cin(Cin[2]), .S(S2[0]), .Cout(Cout[5]));
adder_1 uadder_1_7(.A(Cin[3]), .B(Cin[4]), .Cin(  N[0]), .S(S2[1]), .Cout(Cout[6]));
adder_1 uadder_1_8(.A(  N[1]), .B( S1[0]), .Cin( S1[1]), .S(S2[2]), .Cout(Cout[7]));
adder_1 uadder_1_9(.A( S1[2]), .B( S1[3]), .Cin( S1[4]), .S(S2[3]), .Cout(Cout[8]));

//layer3: 2 1bit adder
wire [1:0] S3;
adder_1 uadder_1_10(.A(Cin[5]), .B(Cin[6]), .Cin(S2[0]), .S(S3[0]), .Cout(Cout[ 9]));
adder_1 audder_1_11(.A( S2[1]), .B( S2[2]), .Cin(S2[3]), .S(S3[1]), .Cout(Cout[10]));

//layer4: 2 1bit adder
wire [1:0] S4;
adder_1 uadder_1_12(.A( S3[0]), .B( S3[1]), .Cin(Cin[ 7]), .S(S4[0]), .Cout(Cout[11]));
adder_1 uadder_1_13(.A(Cin[8]), .B(Cin[9]), .Cin(Cin[10]), .S(S4[1]), .Cout(Cout[12]));

//layer5: 1 1bit adder
wire S5;
adder_1 uadder_1_14(.A(S4[0]), .B(S4[1]), .Cin(Cin[11]), .S(S5), .Cout(Cout[13]));

//layer6: 1 1bit adder
adder_1 uadder_1_15(.A(S5), .B(Cin[12]), .Cin(Cin[13]), .S(Sfinal), .Cout(Cfinal));

endmodule

//64bit adder
module adder_64(
    input  [63:0]    A,
    input  [63:0]    B,
    input            Cin,
    output [63:0]    S,
    output           Cout  
);

wire [64:0] c;
assign c[0] = Cin;

assign g = A & B;
assign p = A | B;
assign S = A ^ B ^ c;
assign Cout = c[64];

//layer1
wire [63:0] p;
wire [63:0] g;
adder_4 uadder_4_1 (.p(p[ 3: 0]), .g(g[ 3: 0]), .c0(c[ 0]), .P(pp[ 0]), .G(gg[ 0]), .c(c[ 3: 1]));
adder_4 uadder_4_2 (.p(p[ 7: 4]), .g(g[ 7: 4]), .c0(c[ 4]), .P(pp[ 1]), .G(gg[ 1]), .c(c[ 7: 5]));
adder_4 uadder_4_3 (.p(p[11: 8]), .g(g[11: 8]), .c0(c[ 8]), .P(pp[ 2]), .G(gg[ 2]), .c(c[11: 9]));
adder_4 uadder_4_4 (.p(p[15:12]), .g(g[15:12]), .c0(c[12]), .P(pp[ 3]), .G(gg[ 3]), .c(c[15:13]));
adder_4 uadder_4_5 (.p(p[19:16]), .g(g[19:16]), .c0(c[16]), .P(pp[ 4]), .G(gg[ 4]), .c(c[19:17]));
adder_4 uadder_4_6 (.p(p[23:20]), .g(g[23:20]), .c0(c[20]), .P(pp[ 5]), .G(gg[ 5]), .c(c[23:21]));
adder_4 uadder_4_7 (.p(p[27:24]), .g(g[27:24]), .c0(c[24]), .P(pp[ 6]), .G(gg[ 6]), .c(c[27:25]));
adder_4 uadder_4_8 (.p(p[31:28]), .g(g[31:28]), .c0(c[28]), .P(pp[ 7]), .G(gg[ 7]), .c(c[31:29]));
adder_4 uadder_4_9 (.p(p[35:32]), .g(g[35:32]), .c0(c[32]), .P(pp[ 8]), .G(gg[ 8]), .c(c[35:33]));
adder_4 uadder_4_10(.p(p[39:36]), .g(g[39:36]), .c0(c[36]), .P(pp[ 9]), .G(gg[ 9]), .c(c[39:37]));
adder_4 uadder_4_11(.p(p[43:40]), .g(g[43:40]), .c0(c[40]), .P(pp[10]), .G(gg[10]), .c(c[43:41]));
adder_4 uadder_4_12(.p(p[47:44]), .g(g[47:44]), .c0(c[44]), .P(pp[11]), .G(gg[11]), .c(c[47:45]));
adder_4 uadder_4_13(.p(p[51:48]), .g(g[51:48]), .c0(c[48]), .P(pp[12]), .G(gg[12]), .c(c[51:49]));
adder_4 uadder_4_14(.p(p[55:52]), .g(g[55:52]), .c0(c[52]), .P(pp[13]), .G(gg[13]), .c(c[55:53]));
adder_4 uadder_4_15(.p(p[59:56]), .g(g[59:56]), .c0(c[56]), .P(pp[14]), .G(gg[14]), .c(c[59:57]));
adder_4 uadder_4_16(.p(p[63:60]), .g(g[63:60]), .c0(c[60]), .P(pp[15]), .G(gg[15]), .c(c[63:61]));

//layer2
wire [15:0] pp;
wire [15:0] gg;
adder_4 uadder_4_17(.p(pp[ 3: 0]), .g(gg[ 3: 0]), .c0(c[ 0]), .P(ppp[0]), .G(ggg[0]), .c({c[12],c[ 8],c[ 4]}));
adder_4 uadder_4_18(.p(pp[ 7: 4]), .g(gg[ 7: 4]), .c0(c[16]), .P(ppp[1]), .G(ggg[1]), .c({c[28],c[24],c[20]}));
adder_4 uadder_4_19(.p(pp[11: 8]), .g(gg[11: 8]), .c0(c[32]), .P(ppp[2]), .G(ggg[2]), .c({c[44],c[40],c[36]}));
adder_4 uadder_4_20(.p(pp[15:12]), .g(gg[15:12]), .c0(c[48]), .P(ppp[3]), .G(ggg[3]), .c({c[60],c[56],c[52]}));

//layer3
wire [3:0]  ppp;
wire [3:0]  ggg;
wire        GGG;
wire        PPP;
adder_4 uadder_4_21(.p(ppp), .g(ggg), .c0(c[0]), .G(GGG), .P(PPP), .c({c[48],c[32],c[16]}));
assign c[64] = GGG | PPP & c[0];

endmodule

//1bit adder
module adder_1(
    input   A,
    input   B,
    input   Cin,
    output  S,
    output  Cout
);

assign S    = A ^ B ^ Cin;
assign Cout = A & B | A & Cin | B & Cin;

endmodule

//4bit adder (figure 8.21)
module adder_4(
    input [3:0]      p,
    input [3:0]      g,
    input            c0,
    output           P,
    output           G,
    output [3:1]     c
);

assign P    = p[3] & p[2] & p[1] & p[0];
assign G    = g[3] | p[3] & g[2] | p[3] & p[2] & g[1] | p[3] & p[2] & p[1] & g[0];
assign c[1] = g[0] | p[0] & c0;
assign c[2] = g[1] | p[1] & g[0] | p[1] & p[0] & c0;
assign c[3] = g[2] | p[2] & g[1] | p[2] & p[1] & g[0] | p[2] & p[1] & p[0] & c0;

endmodule