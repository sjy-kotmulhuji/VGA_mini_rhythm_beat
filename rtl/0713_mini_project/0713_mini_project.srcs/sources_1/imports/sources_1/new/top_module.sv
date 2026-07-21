`timescale 1ns / 1ps

module top_game (
    input  logic        clk,
    input  logic        reset,
    input  logic [ 1:0] music_sel,
    input  logic        v_sync,
    input  logic [ 3:0] region,
    input  logic [ 2:0] main_state,
    output logic [ 3:0] o_lane,
    output logic [11:0] o_duration,
    output logic        game_done,
    output logic [23:0] score,
    // [사용자 임시 시도 코드 백업 (perfect, good, miss, combo, fever 포트 출력을 누락시켜 빌드 에러 및 판정 차단 유발)]
    // );
    output logic        perfect,
    output logic        good,
    output logic        miss,
    output logic [ 9:0] combo,
    output logic        fever,

    input  logic        rx_done,
    input  logic [ 7:0] rx_data
);

    logic [31:0] note_data;
    logic note_done;
    logic [3:0] pos0, pos1, pos2, pos3;
    logic [9:0] lcnt0, lcnt1, lcnt2, lcnt3;
    logic combo_done;
    logic [9:0] combo_data;

    assign combo = combo_data;

    //game reset
    logic game_reset;
    assign game_reset = reset || (main_state != 3'b011);    //GAME_CONT 상태가 아닐 때 rom 초기화

    // v_sync 공용 글리치 필터 (100MHz 기준 10us = 1000클락 동안 유지될 때만 신호 인정)
    logic [9:0] vs_filter_cnt;
    logic       v_sync_clean;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            vs_filter_cnt <= '0;
            v_sync_clean  <= 1'b1; // Active-Low idle
        end else begin
            if (v_sync == v_sync_clean) begin
                vs_filter_cnt <= '0;
            end else begin
                if (vs_filter_cnt == 10'd1000) begin
                    v_sync_clean  <= v_sync;
                    vs_filter_cnt <= '0;
                end else begin
                    vs_filter_cnt <= vs_filter_cnt + 1'b1;
                end
            end
        end
    end

    Rom_Sel_Reader U_ROM_SEL_READER (
        .clk       (clk),
        .reset     (game_reset),
        .music_sel (music_sel),
        .main_state(main_state),
        .note_done (note_done),
        .note_data (note_data)
    );


    Note_Controller U_NOTE_CTRL (
        .clk       (clk),
        .reset     (game_reset),
        .v_sync    (v_sync_clean), // 필터링된 동기 신호 연결 (이전 원래 코드 백업: .v_sync(v_sync))
        .rx_done   (rx_done),
        .rx_data   (rx_data),
        .main_state(main_state),
        .o_lane    (o_lane),
        .o_duration(o_duration),
        .note_done (note_done),
        .game_done (game_done)
    );

    line_count U_LINE_COUNT (
        .clk    (clk),
        .reset  (reset),
        .i_note (note_done),
        .i_lane (o_lane),
        .i_vs   (v_sync_clean), // 필터링된 동기 신호 연결 (이전 원래 코드 백업: .i_vs(v_sync))
        .i_done (game_done),
        .o_pos0 (pos0),
        .o_lcnt0(lcnt0),
        .o_pos1 (pos1),
        .o_lcnt1(lcnt1),
        .o_pos2 (pos2),
        .o_lcnt2(lcnt2),
        .o_pos3 (pos3),
        .o_lcnt3(lcnt3)
    );

    GameResult U_GAMERESULT (
        .clk       (clk),
        .reset     (game_reset),  // 게임 중이 아닐 때 판정기 리셋 (이전 원래 코드 백업: .reset(reset))
        .pos0      (pos0),
        .pos1      (pos1),
        .pos2      (pos2),
        .pos3      (pos3),
        .lcnt0     (lcnt0),
        .lcnt1     (lcnt1),
        .lcnt2     (lcnt2),
        .lcnt3     (lcnt3),
        .region    (region),
        .v_sync    (v_sync_clean), // 필터링된 동기 신호 연결 (이전 원래 코드 백업: .v_sync(v_sync))
        .perfect   (perfect),
        .good      (good),
        .miss      (miss),
        .combo_done(combo_done),
        .combo_data(combo_data), // [사용자 임시 시도 코드 백업 (오타로 빌드 에러 유발: .combo_data(combd_data))]
        .fever     (fever)
    );

    Game_Score U_SCORE (
        .clk       (clk),
        .reset     (reset),
        .main_state(main_state),
        .good      (good),
        .perfect   (perfect),
        .miss      (miss),
        .combo_done(combo_done),
        .combo_data(combo_data),
        .fever     (fever),
        .score     (score)
    );

endmodule
