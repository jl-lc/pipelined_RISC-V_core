module writeback #()
(
  input wire [31:0] pc,
  input wire        load,
  input wire        jal,
  input wire [2:0]  funct3,
  input wire [31:0] mdata,
  input wire [31:0] alu_res,
  output reg [31:0] data_rd
);
  parameter lb=3'h0, lh=3'h1, lw=3'h2, lbu=3'h4, lhu=3'h5;

  always @(*) begin
    if (load)
      case (funct3)
        lb:  data_rd = {{24{mdata[7]}}, mdata[7:0]}; // Sign-extend 8-bit to 32-bit
        lh:  data_rd = {{16{mdata[15]}}, mdata[15:0]}; // Sign-extend 16-bit to 32-bit
        lw:  data_rd = mdata;
        lbu: data_rd = {24'b0, mdata[7:0]};
        lhu: data_rd = {16'b0, mdata[15:0]};
        default: data_rd = mdata; // idk
      endcase
    else if (jal)
      data_rd = pc + 32'd4;
    else
      data_rd = alu_res;
  end
endmodule