module register_file #()
(
  input wire        clock,
  input wire [4:0]  addr_rs1, addr_rs2,
  input wire [4:0]  addr_rd,
  input wire [31:0] data_rd,
  input wire        write_enable,
  output reg [31:0] data_rs1, data_rs2
);

  reg [31:0] registers [31:0];
  wire write;

  // synthesizable?
  integer i;
  initial
    for (i = 0; i < 32; i = i + 1)
      registers[i] = i == 2 ? 32'h01000000 + `MEM_DEPTH : 32'b0; // x2 stack ptr
  
  // write, clocked
  assign write = write_enable & (|addr_rd); // skip x0
  always @(posedge clock)
    if (write) 
      registers[addr_rd] <= data_rd;

  // read, combinational, data forwarding
  // assign data_rs1 = (write && (addr_rd == addr_rs1)) ? data_rd : registers[addr_rs1];
  // assign data_rs2 = (write && (addr_rd == addr_rs2)) ? data_rd : registers[addr_rs2];
  assign data_rs1 = registers[addr_rs1];
  assign data_rs2 = registers[addr_rs2];

endmodule
