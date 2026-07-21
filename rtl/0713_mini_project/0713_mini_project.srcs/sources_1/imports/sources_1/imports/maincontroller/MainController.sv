`timescale 1ns / 1ps

module MainController (
    input logic clk,
    input logic reset,
    input logic rx,

    // UI 제어용 물리 버튼
    input logic btn_l_f,
    input logic btn_r_f,
    input logic btn_d_f,

    //top_game이 필요로 하는 외부 신호
    input logic v_sync,
    input logic [3:0] region,      // 리듬게임 4레인 타격 버튼

    // 카메라 완료 신호
    input logic capture_done,

    // FSM 상태 및 제어 출력
    output logic       main_done,
    output logic [2:0] o_state,

    //top_game에서 생성되어 렌더링(VGA) 모듈로 나갈 데이터
    output logic [ 3:0] o_lane,
    output logic [11:0] o_duration,
    output logic [23:0] score,
    // [원래 코드 백업]
    // output logic [23:0] score
    // );
    output logic        perfect,
    output logic        good,
    output logic        miss,
    output logic [ 9:0] combo,
    output logic        fever
);

    // 내부 와이어 선언
    logic o_btn_l;
    logic o_btn_r;
    logic o_btn_d;
    
    logic game_done; 
    logic [1:0] music_sel;

    logic w_rx_done;
    logic [7:0] w_rx_data;

    uart_rx #(
        .CLK_FREQ (100_000_000),
        .BAUD_RATE(115_200)
    ) U_uart_rx (
        .clk    (clk),
        .reset  (reset),
        .rx     (rx),
        .rx_done(w_rx_done),
        .rx_data(w_rx_data)
    );

    // 1. 버튼 디바운서
    BtnDebouncer U_debouncer_l (
        .clk  (clk),
        .reset(reset),
        .i_btn(btn_l_f),
        .o_btn(o_btn_l)
    );

    BtnDebouncer U_debouncer_r (
        .clk  (clk),
        .reset(reset),
        .i_btn(btn_r_f),
        .o_btn(o_btn_r)
    );

    BtnDebouncer U_debouncer_d (
        .clk  (clk),
        .reset(reset),
        .i_btn(btn_d_f),
        .o_btn(o_btn_d)
    );

    // 2. 메인 상태 컨트롤러
    MainControl U_main_control (
        .clk         (clk),
        .reset       (reset),
        .btn_l       (o_btn_l),
        .btn_r       (o_btn_r),
        .btn_d       (o_btn_d),
        .game_done   (game_done),    
        .capture_done(capture_done),
        .music_sel   (music_sel),
        .done        (main_done),
        .o_state     (o_state)
    );

    // 3. 게임 코어 로직 (top_game)
    top_game U_top_game (
        .clk         (clk),
        .reset       (reset),
        .music_sel   (music_sel),   
        .v_sync      (v_sync),      
        .region      (region),      
        .main_state  (o_state),     
        .rx_done     (w_rx_done),
        .rx_data     (w_rx_data),
        
        .o_lane      (o_lane),      
        .o_duration  (o_duration),  
        .game_done   (game_done),   
        .score       (score),
        // [원래 코드 백업]
        // .score    (score)
        .perfect     (perfect),
        .good        (good),
        .miss        (miss),
        .combo       (combo),
        .fever       (fever)        
    );

endmodule