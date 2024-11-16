module decode #()
(
  input wire [31:0] instruction,
  output reg [6:0]  opcode,
  output reg [4:0]  rd,
  output reg [4:0]  rs1, rs2,
  output reg [2:0]  funct3,
  output reg [6:0]  funct7,
  output reg [31:0] imm,
  output reg [4:0]  shamt,
  output reg        write_enable,
  output reg        load,
  output reg        store,
  output reg        rw,
  output reg        jal,
  output reg        rs1_only
);
  parameter R_type=7'b0110011, I_type_ALU=7'b0010011, I_type_load=7'b0000011, 
            I_type_JALR=7'b1100111, S_type=7'b0100011, B_type=7'b1100011, 
            U_type_LUI=7'b0110111, U_type_AUIPC=7'b0010111, J_type=7'b1101111, ECALL=7'b1110011;
  reg [4:0] dummy_rs1; // for U-type

  assign opcode = instruction[6:0];
  assign shamt = rs2;

  always @(*) begin
    dummy_rs1 = 0;
    imm = 0;
    load = 0;
    rw = 0;
    jal = 0;
    write_enable = 1;
    rs1_only = 0;
    store = 0;
    case (opcode)
      R_type: begin
        {funct7, rs2, rs1, funct3, rd} = instruction[31:7];
      end
      I_type_ALU: begin
        {funct7, rs2, rs1, funct3, rd} = instruction[31:7];
        if (funct3[1:0] != 2'b01)
          imm[11:5] = funct7;
        imm[4:0] = rs2;
        imm[31:12] = {20{imm[11]}}; // immediate values are sign extended
        rs1_only = 1;
      end
      I_type_load: begin
        {imm[11:0], rs1, funct3, rd} = instruction[31:7];
        {funct7, rs2} = imm[11:0];
        imm[31:12] = {20{imm[11]}}; // immediate values are sign extended
        load = 1;
        rs1_only = 1;
      end
      I_type_JALR: begin
        {imm[11:0], rs1, funct3, rd} = instruction[31:7];
        {funct7, rs2} = imm[11:0];
        imm[31:12] = {20{imm[11]}}; // immediate values are sign extended
        jal = 1;
        rs1_only = 1;
      end
      S_type: begin
        {imm[11:5], rs2, rs1, funct3, imm[4:0]} = instruction[31:7];
        {funct7, rd} = imm[11:0];
        imm[31:12] = {20{imm[11]}}; // immediate values are sign extended
        rw = 1;
        write_enable = 0;
        store = 1;
      end
      B_type: begin
        {imm[12], imm[10:5], rs2, rs1, funct3, imm[4:1], imm[11]} = instruction[31:7];
        rd = {imm[4:1], imm[11]};
        funct7 = {imm[12], imm[10:5]};
        imm[31:13] = {19{imm[11]}}; // immediate values are sign extended
        write_enable = 0;
      end
      U_type_LUI: begin
        {imm[31:12], rd} = instruction[31:7];
        {funct7, rs2, dummy_rs1, funct3} = imm[31:12];
        rs1 = 0; // idk why it's inconsistent in the reference output
        rs1_only = 1;
      end
      U_type_AUIPC: begin
        {imm[31:12], rd} = instruction[31:7];
        {funct7, rs2, rs1, funct3} = imm[31:12];
      end
      J_type: begin
        {imm[20], imm[10:1], imm[11], imm[19:12], rd} = instruction[31:7];
        {funct7, rs2, rs1, funct3} = {imm[20], imm[10:1], imm[11], imm[19:12]};
        imm[31:21] = {11{imm[20]}}; // immediate values are sign extended
        jal = 1;
      end
      ECALL: begin
        rd = 0;
        rs1 = 0;
        rs2 = 0;
        funct3 = 0;
        funct7 = 0;
        write_enable = 0;
      end
      default: begin
        rd = 0;
        rs1 = 0;
        rs2 = {5{1'b1}};
        funct3 = 0;
        funct7 = 7'h7;
      end
    endcase
  end

endmodule