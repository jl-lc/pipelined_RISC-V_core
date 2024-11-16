module dmemory #()
(
  input wire        clock,
  input wire [31:0] address,  
  input wire        rw,
  input wire [1:0]  access_size,
  input wire [31:0] data_in,  
  output reg [31:0] data_out
);
  reg [7:0] dmem [`MEM_DEPTH-1:0]; // byte addressable
  reg [31:0] temp_mem [`LINE_COUNT-1:0];
  reg [31:0] temp_word;
  integer i;
  parameter byte=2'b00, halfword=2'b01;

  initial
  begin
    $readmemh(`MEM_PATH, temp_mem);
    for (i = 0; i < `LINE_COUNT; i = i + 1)
    begin
      temp_word  = temp_mem[i]; // indices for bit slicing must be known at compile time, different from generate
      dmem[4*i]   = temp_word[7 :0 ];
      dmem[4*i+1] = temp_word[15:8 ];
      dmem[4*i+2] = temp_word[23:16];
      dmem[4*i+3] = temp_word[31:24];
    end
  end

  // write, clocked, access_size
  always @(posedge clock)
  begin
    if (rw) // write when rw is high
      // little endian
      case (access_size)
        byte: begin
          dmem[address]   = data_in[7  : 0 ];
        end
        halfword: begin
          dmem[address]   = data_in[7  : 0 ];
          dmem[address+1] = data_in[15 : 8 ];
        end
        default: begin // word
          dmem[address]   = data_in[7  : 0 ];
          dmem[address+1] = data_in[15 : 8 ];
          dmem[address+2] = data_in[23 : 16];
          dmem[address+3] = data_in[31 : 24];
        end
      endcase
  end

  // read, combinational
  always @(*)
  begin
    // little endian
    data_out[7  : 0 ] = dmem[address]  ;
    data_out[15 : 8 ] = dmem[address+1];
    data_out[23 : 16] = dmem[address+2];
    data_out[31 : 24] = dmem[address+3];
  end

endmodule
