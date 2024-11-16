module imemory #() 
(
  input wire        clock,
  input wire [31:0] pc,  
  input wire        read_write,
  input wire [31:0] data_in,  
  output reg [31:0] data_out
);
  reg [7:0] imem [`MEM_DEPTH-1:0]; // byte addressable
  reg [31:0] temp_mem [`LINE_COUNT-1:0];
  reg [31:0] temp_word;
  wire [31:0] address;
  integer i;

  assign address = pc - 32'h01000000;

  initial
  begin
    $readmemh(`MEM_PATH, temp_mem);
    for (i = 0; i < `LINE_COUNT; i = i + 1)
    begin
      temp_word  = temp_mem[i]; // indices for bit slicing must be known at compile time, different from generate
      imem[4*i]   = temp_word[7 :0 ];
      imem[4*i+1] = temp_word[15:8 ];
      imem[4*i+2] = temp_word[23:16];
      imem[4*i+3] = temp_word[31:24];
    end
  end

  // write, clocked
  always @(posedge clock)
  begin
    if (read_write) // write when read_write is high
    begin
      // little endian
      imem[address]   = data_in[7  : 0 ];
      imem[address+1] = data_in[15 : 8 ];
      imem[address+2] = data_in[23 : 16];
      imem[address+3] = data_in[31 : 24];
    end
  end

  // read, combinational
  always @(*)
  begin
    if (read_write) // data forwarding to read on write
      data_out = data_in;
    else // normal reading
    begin
      // little endian
      data_out[7  : 0 ] = imem[address]  ;
      data_out[15 : 8 ] = imem[address+1];
      data_out[23 : 16] = imem[address+2];
      data_out[31 : 24] = imem[address+3];
    end
  end

endmodule