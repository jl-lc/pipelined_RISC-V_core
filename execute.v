module execute #()
(
  input  wire [31:0] pc,
  input  wire [6:0]  opcode,
  input  wire [2:0]  funct3,
  input  wire [6:0]  funct7,
  input  wire [31:0] data_rs1, data_rs2,
  input  wire [4:0]  shamt,
  input  wire [31:0] imm,
  output reg  [31:0] alu_res,
  output reg         br_taken
);
  /* instruction formats */
  parameter R_type=7'b0110011, I_type_ALU=7'b0010011, I_type_load=7'b0000011, 
            I_type_JALR=7'b1100111, S_type=7'b0100011, B_type=7'b1100011, 
            U_type_LUI=7'b0110111, U_type_AUIPC=7'b0010111, J_type=7'b1101111, ECALL=7'b1110011;
  /* instruction formats */
  
  /* funct3 specs */
  parameter add_f3=3'h0, sub_f3=3'h0, xor_f3=3'h4, or_f3=3'h6, and_f3=3'h7, sll_f3=3'h1, 
            srl_f3=3'h5, sra_f3=3'h5, slt_f3=3'h2, sltu_f3=3'h3;
  parameter addi_f3=3'h0, xori_f3=3'h4, ori_f3=3'h6, andi_f3=3'h7, slli_f3=3'h1, 
            srli_f3=3'h5, srai_f3=3'h5, slti_f3=3'h2, sltui_f3=3'h3;
  parameter beq_f3=3'h0, bne_f3=3'h1, blt_f3=3'h4, bge_f3=3'h5, bltu_f3=3'h6, bgeu_f3=3'h7;
  /* funct3 specs */
  
  /* funct7 specs */
  parameter add_f7=7'h00, sub_f7=7'h20, xor_f7=7'h00, or_f7=7'h00, and_f7=7'h00, sll_f7=7'h00, 
            srl_f7=7'h00, sra_f7=7'h20, slt_f7=7'h00, sltu_f7=7'h00;
  parameter slli_f7=7'h00, srli_f7=7'h00, srai_f7=7'h20;
  parameter ecall_f7=7'h00;
  /* funct7 specs */

  always @(*) begin
    alu_res  = 32'b0;
    br_taken = 1'b0;
    case (opcode)
      R_type:
        case (funct3)
          add_f3:
            alu_res = funct7 == add_f7  ? data_rs1 + data_rs2   : 
                      funct7 == sub_f7  ? data_rs1 - data_rs2   : 32'b0; // sub_f3
          xor_f3:
            alu_res = funct7 == xor_f7  ? data_rs1 ^ data_rs2   : 32'b0;
          or_f3:
            alu_res = funct7 == or_f7   ? data_rs1 | data_rs2   : 32'b0;
          and_f3:
            alu_res = funct7 == and_f7  ? data_rs1 & data_rs2   : 32'b0;
          sll_f3:
            alu_res = funct7 == sll_f7  ? data_rs1 << data_rs2[4:0]  : 32'b0;
          srl_f3:
            alu_res = funct7 == srl_f7  ? data_rs1 >>  data_rs2[4:0] :
                      funct7 == sra_f7  ? $signed($signed(data_rs1) >>> data_rs2[4:0] ): 32'b0; // sra_f3
          slt_f3:
            alu_res = funct7 == slt_f7  ? $signed(data_rs1) < $signed(data_rs2) ? 32'b1 : 32'b0 : 32'b0;
          sltu_f3:
            alu_res = funct7 == sltu_f7 ? data_rs1 < data_rs2                   ? 32'b1 : 32'b0 : 32'b0;
          default:
            alu_res  = 32'b0;
        endcase
      I_type_ALU:
        case (funct3)
          addi_f3:
            alu_res = data_rs1 + imm;
          xori_f3:
            alu_res = data_rs1 ^ imm;
          ori_f3:
            alu_res = data_rs1 | imm;
          andi_f3:
            alu_res = data_rs1 & imm;
          slli_f3:
            alu_res = funct7 == slli_f7 ? data_rs1 <<  shamt : 32'b0;
          srli_f3:
            alu_res = funct7 == srli_f7 ? (data_rs1 >>  shamt) :
                      funct7 == srai_f7 ? $signed($signed(data_rs1) >>> shamt) : 32'b0; // srai_f3
          slti_f3:
            alu_res = $signed(data_rs1) < $signed(imm) ? 32'b1 : 32'b0;
          sltui_f3:
            alu_res = data_rs1 < imm                   ? 32'b1 : 32'b0;
          default:
            alu_res  = 32'b0;
        endcase
      I_type_load:
        alu_res = data_rs1 + imm;
      S_type:
        alu_res = data_rs1 + imm;
      B_type: begin
        alu_res = pc + imm;
        case (funct3)
          beq_f3: 
            br_taken = data_rs1 == data_rs2;
          bne_f3: 
            br_taken = data_rs1 != data_rs2;
          blt_f3:
            br_taken = $signed(data_rs1) <  $signed(data_rs2);
          bge_f3: 
            br_taken = $signed(data_rs1) >= $signed(data_rs2);
          bltu_f3: 
            br_taken = data_rs1 < data_rs2;
          bgeu_f3: 
            br_taken = data_rs1 >= data_rs2;
          default: 
            br_taken = 1'b0;
        endcase
      end
      J_type:
        alu_res = pc + imm; // compute pc
      I_type_JALR:
        alu_res = data_rs1 + imm; // compute pc
      U_type_LUI:
        alu_res = imm; // imm << 12 in decode
      U_type_AUIPC:
        alu_res = pc + imm; // imm << 12 in decode
      default: begin // ecall
        alu_res  = 32'b0;
        br_taken = 1'b0;
      end
    endcase
  end
endmodule