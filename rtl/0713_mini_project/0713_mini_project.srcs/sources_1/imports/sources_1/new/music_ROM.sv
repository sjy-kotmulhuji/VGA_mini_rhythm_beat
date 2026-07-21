`timescale 1ns / 1ps

module music_ROM #(
    parameter string FILE_NAME = "little_star.mem",
    parameter int ROM_DEPTH = 43,
    parameter int ADDR_WIDTH = $clog2(ROM_DEPTH)
    )(
    input  logic [ADDR_WIDTH-1:0] rom_addr,
    output logic [31:0] rom_data
);

    logic [31:0] mem[0:ROM_DEPTH-1];  

    initial begin
        $readmemh(FILE_NAME, mem);
    end

    assign rom_data = mem[rom_addr];

endmodule