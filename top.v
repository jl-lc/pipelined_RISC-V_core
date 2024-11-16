module pd (
  input clock,
  input reset
);
  /* instruction fetch */
  reg [31:0] f_pc;
  reg        f_read_write;
  reg [31:0] f_data_in;
  reg [31:0] f_insn;
  /* instruction fetch */

  /* instruction decode */
  reg [31:0] d_pc;
  reg [31:0] d_insn;
  reg [6:0]  d_opcode;
  reg [4:0]  d_rd;
  reg [4:0]  d_rs1, d_rs2;
  reg [2:0]  d_funct3;
  reg [6:0]  d_funct7;
  reg [31:0] d_imm;
  reg [4:0]  d_shamt;
  reg        d_store;
  reg        d_load;
  reg        d_rw;
  reg        d_jal;
  reg        d_write_enable;
  reg        d_rs1_only;
  /* instruction decode */

  /* register file */
  wire [4:0]  r_addr_rd;
  wire [4:0]  r_addr_rs1, r_addr_rs2;
  wire [31:0] r_data_rd;
  reg  [31:0] r_data_rs1, r_data_rs2;
  wire        r_write_enable;
  /* register file */
  
  /* execute */
  reg [31:0] e_pc;
  reg [6:0]  e_opcode;
  reg [2:0]  e_funct3;
  reg [6:0]  e_funct7;
  reg [31:0] e_data_rs1, e_data_rs2;
  reg [31:0] e_imm;
  reg [4:0]  e_shamt;
  reg [31:0] e_alu_res;
  reg        e_br_taken;
  reg        e_rw;
  reg        e_load;
  reg        e_jal;
  reg        e_write_enable;
  reg [4:0]  e_rd;
  reg [4:0]  e_addr_rs1;
  reg [4:0]  e_addr_rs2;
  reg [31:0] e_data_rs1_fwd;
  reg [31:0] e_data_rs2_fwd;
  /* execute */

  /* memory */
  reg  [31:0] m_pc;
  reg         m_rw;
  reg  [31:0] m_address;
  reg  [1:0]  m_size_encoded;
  reg  [31:0] m_data_in;  
  wire [31:0] m_data_in_fwd;  
  reg  [31:0] m_mdata;
  reg         m_load;
  reg         m_jal;
  reg  [2:0]  m_funct3;
  reg  [31:0] m_alu_res;
  reg         m_write_enable;
  reg  [4:0]  m_rd;
  reg  [4:0]  m_addr_rs2;
  /* memory */
  
  /* writeback */
  reg [31:0] w_pc;
  reg        w_load;
  reg        w_jal;
  reg [2:0]  w_funct3;
  reg [31:0] w_mdata;
  reg [31:0] w_alu_res;
  reg [31:0] w_data_rd;
  reg        w_write_enable;
  reg [4:0]  w_rd;
  /* writeback */

  /* control */
  reg stall;
  wire flush;
  /* control */

  always @(posedge clock)
    f_pc <= reset ? 32'h01000000 : 
            e_br_taken | e_jal ? e_alu_res : // higher priority
            stall ? f_pc : f_pc + 32'd4;

  imemory imemory (
    .clock(clock),
    .pc(f_pc), 
    .read_write(f_read_write), 
    .data_in(f_data_in), 
    .data_out(f_insn)
  );

  // IF -> ID
  always @(posedge clock) begin 
    if (reset | flush) begin
      d_pc    <= 0;
      d_insn  <= 0;
    end
    else if (stall) begin
      d_pc    <= d_pc;
      d_insn  <= d_insn;
    end
    else begin
      d_pc    <= f_pc;
      d_insn  <= f_insn;
    end
  end

  decode decode (
    .instruction(d_insn), 
    .opcode(d_opcode), 
    .rd(d_rd), 
    .rs1(d_rs1), 
    .rs2(d_rs2),
    .funct3(d_funct3), 
    .funct7(d_funct7), 
    .imm(d_imm), 
    .shamt(d_shamt),
    .store(d_store),
    .load(d_load),
    .rw(d_rw),
    .jal(d_jal),
    .write_enable(d_write_enable),
    .rs1_only(d_rs1_only)
  );

  always @(*) begin
    if (d_rs1_only) begin // filter out if rs2 are garbage values
      if (e_load && (e_rd == d_rs1)) // lw dependency stall
        stall = 1;
      else if (w_write_enable && (|w_rd) && (w_rd == r_addr_rs1)) begin // WB -> ID reg file stall
        if (((e_rd == r_addr_rs1) && (|e_rd) && e_write_enable) || 
            ((m_rd == r_addr_rs1) && (|m_rd) && m_write_enable)) // EX and ME can data forward, no stall
          stall = 0;
        else
          stall = 1;
      end 
      else
        stall = 0;
    end 
    else begin
      // maybe wrong
      if (e_load && (e_rd == d_rs1) && (e_rd != d_rs2)) begin // lw dependency stall
        // check rs1 only dependent
        stall = 1;
      end
      else if (e_load && (e_rd == d_rs2) && ~d_store) begin
        // check rs2 dependent
        stall = 1;
      end
      else if (w_write_enable && (|w_rd)) begin // WB -> ID reg file stall
        // check rs1 only dependent
        if ((w_rd == r_addr_rs1) && (w_rd != r_addr_rs2)) begin
          if (((e_rd == r_addr_rs1) && (|e_rd) && e_write_enable) || 
              ((m_rd == r_addr_rs1) && (|m_rd) && m_write_enable)) begin
            stall = 0;
          end
          else begin
            stall = 1;
          end
        end
        // check rs2 only dependent
        else if ((w_rd != r_addr_rs1) && (w_rd == r_addr_rs2)) begin
          if (((e_rd == r_addr_rs2) && (|e_rd) && e_write_enable) || 
              ((m_rd == r_addr_rs2) && (|m_rd) && m_write_enable)) begin
            stall = 0;
          end
          else begin
            stall = 1;
          end
        end
        // check both rs1 and rs2 dependent
        else if ((w_rd == r_addr_rs1) && (w_rd == r_addr_rs2)) begin
          // NOT STALL
          // if execute can support both, or memory can support both,
          // or (execute can support one, memory support other),
          // or no dependent at all
          if (((e_rd == r_addr_rs1) && (e_rd == r_addr_rs2) && (|e_rd) && e_write_enable) || 
              ((m_rd == r_addr_rs1) && (m_rd == r_addr_rs2) && (|m_rd) && m_write_enable) || 
              ((e_rd == r_addr_rs1) && (m_rd == r_addr_rs2) && (|m_rd) && m_write_enable) || 
              ((m_rd == r_addr_rs1) && (e_rd == r_addr_rs2) && (|m_rd) && m_write_enable)) begin
            stall = 0;
          end
          else begin
            stall = 1;
          end
        end
        // neither are dependent
        else begin
          stall = 0;
        end
      end
      else begin
        stall = 0;
      end
    end
  end

  assign r_addr_rs1     = d_rs1;
  assign r_addr_rs2     = d_rs2;
  assign r_write_enable = w_write_enable;
  assign r_addr_rd      = w_rd;
  assign r_data_rd      = w_data_rd;

  register_file register_file (
    .clock(clock), 
    .addr_rs1(r_addr_rs1), 
    .addr_rs2(r_addr_rs2),
    .addr_rd(r_addr_rd), 
    .data_rd(r_data_rd), 
    .write_enable(r_write_enable),
    .data_rs1(r_data_rs1), 
    .data_rs2(r_data_rs2)
  );

  // ID -> EX
  always @(posedge clock) begin
    if (reset | flush) begin
      e_pc            <= 0;
      e_opcode        <= 0;
      e_funct3        <= 0;
      e_funct7        <= 0;
      e_data_rs1      <= 0;
      e_data_rs2      <= 0;
      e_shamt         <= 0;
      e_imm           <= 0;
      e_rw            <= 0;
      e_load          <= 0;
      e_jal           <= 0;
      e_write_enable  <= 0;
      e_rd            <= 0;
    end
    else if (stall) begin
      e_pc            <= d_pc;
      e_opcode        <= 7'h13;
      e_funct3        <= 0;
      e_funct7        <= 0;
      e_data_rs1      <= 0;
      e_data_rs2      <= 0;
      e_shamt         <= 0;
      e_imm           <= 0;
      e_rw            <= 0;
      e_load          <= 0;
      e_jal           <= 0;
      e_write_enable  <= e_write_enable;
      e_rd            <= 0;
    end
    else begin
      e_pc            <= d_pc;            // PC
      e_opcode        <= d_opcode;        // EX
      e_funct3        <= d_funct3;        // EX
      e_funct7        <= d_funct7;        // EX  
      e_data_rs1      <= r_data_rs1;      // EX
      e_data_rs2      <= r_data_rs2;      // EX  
      e_shamt         <= d_shamt;         // EX  
      e_imm           <= d_imm;           // EX  
      e_addr_rs1      <= r_addr_rs1;      // EX <- WB
      e_addr_rs2      <= r_addr_rs2;      // EX <- WB, ME <- WB
      e_rw            <= d_rw;            // ME
      e_load          <= d_load;          // WB, stalling
      e_jal           <= d_jal;           // WB
      e_write_enable  <= d_write_enable;  // reg file
      e_rd            <= d_rd;            // reg file
    end
  end

  // EX <- ME, EX <- WB data forwarding, skip x0
  always @(*) begin
    /* rs1 */
    if (m_write_enable && (|m_rd) && (m_rd == e_addr_rs1)) begin // EX <- ME forwarding takes precedence
      if (m_jal) // jump and link
        e_data_rs1_fwd = m_pc + 4;
      else
        e_data_rs1_fwd = m_alu_res;
    end 
    else if (w_write_enable && (|w_rd) && (w_rd == e_addr_rs1)) // EX <- WB forwarding
      e_data_rs1_fwd = w_data_rd;
    else
      e_data_rs1_fwd = e_data_rs1; // no forwarding
    /* rs1 */

    /* rs2 */
    if (m_write_enable && (|m_rd) && (m_rd == e_addr_rs2)) begin // EX <- ME forwarding takes precedence
      if (m_jal) // jump and link
        e_data_rs2_fwd = m_pc + 4;
      else
        e_data_rs2_fwd = m_alu_res;
    end 
    else if (w_write_enable && (|w_rd) && (w_rd == e_addr_rs2)) // EX <- WB forwarding
      e_data_rs2_fwd = w_data_rd;
    else
      e_data_rs2_fwd = e_data_rs2; // no forwarding
    /* rs2 */
  end

  execute execute (
    .pc(e_pc), 
    .opcode(e_opcode), 
    .funct3(e_funct3), 
    .funct7(e_funct7), 
    .data_rs1(e_data_rs1_fwd), 
    .data_rs2(e_data_rs2_fwd), 
    .shamt(e_shamt),
    .imm(e_imm),
    .alu_res(e_alu_res), 
    .br_taken(e_br_taken)
  );

  // flushing
  assign flush = e_br_taken | e_jal;

  // EX -> ME
  always @(posedge clock) begin
    if (reset) begin
      m_pc            <= 0;
      m_address       <= 0;
      m_rw            <= 0;
      m_size_encoded  <= 0;
      m_data_in       <= 0;
      m_load          <= 0;
      m_jal           <= 0;
      m_funct3        <= 0;
      m_alu_res       <= 0;
      m_write_enable  <= 0;
      m_rd            <= 0;
    end
    else begin
      m_pc            <= e_pc;            // PC
      m_address       <= e_alu_res;       // ME
      m_rw            <= e_rw;            // ME
      m_size_encoded  <= e_funct3[1:0];   // ME
      m_data_in       <= e_data_rs2_fwd;  // ME forwarded
      m_addr_rs2      <= e_addr_rs2;      // ME <- WB
      m_load          <= e_load;          // WB
      m_jal           <= e_jal;           // WB
      m_funct3        <= e_funct3;        // WB
      m_alu_res       <= e_alu_res;       // WB
      m_write_enable  <= e_write_enable;  // reg file
      m_rd            <= e_rd;            // reg file, stalling
    end
  end

  // ME <- WB data forwarding, skip x0
  assign m_data_in_fwd = (w_write_enable && (|w_rd) && (w_rd == m_addr_rs2)) ? w_data_rd : m_data_in;

  dmemory dmemory (
    .clock(clock),
    .address(m_address),  
    .rw(m_rw),
    .access_size(m_size_encoded),
    .data_in(m_data_in_fwd),  
    .data_out(m_mdata)
  );

  // ME -> WB
  always @(posedge clock) begin
    if (reset) begin
      w_pc            <= 0;
      w_load          <= 0;
      w_jal           <= 0;
      w_funct3        <= 0;
      w_mdata         <= 0;
      w_alu_res       <= 0;
      w_write_enable  <= 0;
      w_rd            <= 0;
    end
    else begin
      w_pc            <= m_pc;            // PC
      w_load          <= m_load;          // WB
      w_jal           <= m_jal;           // WB
      w_funct3        <= m_funct3;        // WB
      w_mdata         <= m_mdata;         // WB
      w_alu_res       <= m_alu_res;       // WB
      w_write_enable  <= m_write_enable;  // reg file
      w_rd            <= m_rd;            // reg file
    end
  end

  writeback writeback (
    .pc(w_pc),
    .load(w_load),
    .jal(w_jal),
    .funct3(w_funct3),
    .mdata(w_mdata),
    .alu_res(w_alu_res),
    .data_rd(w_data_rd)
  );

endmodule