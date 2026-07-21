`timescale 1ns / 1ps

module Rom_Sel_Reader (
    input logic clk,
    input logic reset,

    //rom 개수에 따라 bit 수 수정
    input  logic [ 1:0] music_sel,
    input  logic [ 2:0] main_state,
    //note controller에서 노트가 화면에 발생되면 나오는 신호. 이 신호 받으면 rom address 증가
    input  logic        note_done,
    output logic [31:0] note_data
);

    logic [31:0] song0_rom, song1_rom, song2_rom;
    logic [31:0] song_rom_sel;
    logic [5:0] rom_addr; //rom 주소 증가 변수. bit 수 rom 길이에 맞춰야 함

    //노래 별 ROM 모듈 인스턴스
    //작은별 ROM
    music_ROM #(
        .FILE_NAME ("little_star.mem"),
        .ROM_DEPTH (43),
        .ADDR_WIDTH($clog2(43))
    ) U_LITTLE_STAR_ROM (
        .rom_addr(rom_addr),
        .rom_data(song0_rom)
    );

    //음악별 rom 선택하기 위한 case문
    always_comb begin
        case (music_sel)
            2'b00:   song_rom_sel = song0_rom;
            2'b01:   song_rom_sel = song1_rom;
            2'b10:   song_rom_sel = song2_rom;
            default: song_rom_sel = song0_rom;
        endcase
    end

    //rom_addr 증가 순차 로직
    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            rom_addr <= 0;
        end else begin
            if (main_state == 3'b011) begin
                // [사용자 임시 시도 코드 백업 (주소 42 한계 조건 및 main_state 필터 누락으로 에러 발생)]
                // if (note_done) rom_addr <= rom_addr + 1;

                // [이전 원래 코드 백업]
                // if (rom_addr == 6'd42) rom_addr <= 6'd0;  // 반복 재생
                // else rom_addr <= rom_addr + 1'b1;

                if (note_done) begin     // 타이머에 맞춰 노트가 발생할 때만 ROM 주소 증가
                    if (rom_addr == 6'd42) rom_addr <= 6'd0;  // 반복 재생
                    else rom_addr <= rom_addr + 1'b1;
                end
            end else if(main_state == 3'b101) begin
                rom_addr <= 0;
            end
        end
    end

    //rom data 출력
    assign note_data = song_rom_sel;

endmodule
