`timescale 1ns / 1ps

// top_game에 들어가는 VGA VSYNC 타이밍 전용 테스트벤치
//
// 실제 설계 기준:
//   system clock  = 100 MHz (10 ns)
//   pixel clock   = 25 MHz
//   VGA frame     = 800 * 525 pixel clocks = 16.8 ms
//   VSYNC low     = 2 lines * 800 pixel clocks = 64 us
//
// 확인할 핵심 파형:
//   v_sync                 : DUT에 넣는 원본 VGA VSYNC
//   v_sync_clean           : top_game의 10 us 필터 출력
//   note_vsync_edge        : Note_Controller가 만든 하강 에지 펄스
//   game_frame_tick        : GameResult가 만든 하강 에지 펄스
//   line_vsync_rise        : line_count가 만든 상승 에지 펄스
//   note_frame_cnt         : Note_Controller의 프레임 카운터
//   lcnt0                  : 첫 번째 노트의 낙하 위치 카운터

module tb_vsync_timing;

    localparam time CLK_PERIOD   = 10ns;
    localparam time FRAME_PERIOD = 16_800_000ns;
    localparam time VSYNC_LOW    = 64_000ns;
    localparam time VSYNC_HIGH   = FRAME_PERIOD - VSYNC_LOW;
    localparam time GLITCH_LOW   = 5_000ns;  // 10 us 필터보다 짧음

    logic        clk;
    logic        reset;
    logic [1:0]  music_sel;
    logic        v_sync;
    logic [3:0]  region;
    logic [2:0]  main_state;

    wire [3:0]   o_lane;
    wire [11:0]  o_duration;
    wire         game_done;
    wire [23:0]  score;
    wire         perfect;
    wire         good;
    wire         miss;
    wire [9:0]   combo;
    wire         fever;

    top_game DUT (
        .clk       (clk),
        .reset     (reset),
        .music_sel (music_sel),
        .v_sync    (v_sync),
        .region    (region),
        .main_state(main_state),
        .o_lane    (o_lane),
        .o_duration(o_duration),
        .game_done (game_done),
        .score     (score),
        .perfect   (perfect),
        .good      (good),
        .miss      (miss),
        .combo     (combo),
        .fever     (fever)
    );

    // Vivado 파형 창에 추가하기 쉬운 내부 관찰 신호
    wire        v_sync_clean    = DUT.v_sync_clean;
    wire        note_vsync_edge = DUT.U_NOTE_CTRL.v_sync_edge;
    wire        game_frame_tick = DUT.U_GAMERESULT.frame_tick;
    wire        line_vsync_rise = DUT.U_LINE_COUNT.w_vs_dly0_r;
    wire [15:0] note_frame_cnt  = DUT.U_NOTE_CTRL.frame_cnt;
    wire [5:0]  rom_addr        = DUT.U_ROM_SEL_READER.rom_addr;
    wire        note_done       = DUT.note_done;
    wire [9:0]  lcnt0           = DUT.lcnt0;
    wire [3:0]  pos0            = DUT.pos0;

    integer input_fall_count;
    integer clean_fall_count;
    integer note_edge_count;
    integer game_tick_count;
    integer line_rise_count;

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    always @(negedge v_sync)         input_fall_count = input_fall_count + 1;
    always @(negedge v_sync_clean)   clean_fall_count = clean_fall_count + 1;
    always @(posedge note_vsync_edge) note_edge_count = note_edge_count + 1;
    always @(posedge game_frame_tick) game_tick_count = game_tick_count + 1;
    always @(posedge line_vsync_rise) line_rise_count = line_rise_count + 1;

    // 정상적인 VGA 프레임 한 개 생성.
    // 호출 직전에 VSYNC가 high이고 첫 호출 전에 VSYNC_HIGH만큼 기다린다.
    // 각 호출은 low 64 us + high 16.736 ms이므로 하강 에지 간격은 정확히 16.8 ms이다.
    task automatic send_vga_frame;
        begin
            v_sync = 1'b0;
            #(VSYNC_LOW);
            v_sync = 1'b1;
            #(VSYNC_HIGH);
        end
    endtask

    initial begin
        reset            = 1'b1;
        music_sel        = 2'b00;
        v_sync           = 1'b1;
        region           = 4'b0000;
        main_state       = 3'b000;
        input_fall_count = 0;
        clean_fall_count = 0;
        note_edge_count  = 0;
        game_tick_count  = 0;
        line_rise_count  = 0;

        #(20 * CLK_PERIOD);
        reset      = 1'b0;
        main_state = 3'b011;  // GAME_CONT
        #(20 * CLK_PERIOD);

        // -------------------------------------------------------------
        // 1) 5 us짜리 가짜 VSYNC: 10 us 필터가 제거해야 함
        // -------------------------------------------------------------
        $display("[%0t] 5 us VSYNC glitch input", $time);
        v_sync = 1'b0;
        #(GLITCH_LOW);
        v_sync = 1'b1;
        #20_000ns;

        if (v_sync_clean !== 1'b1)
            $error("VSYNC glitch passed the filter: v_sync_clean=%b", v_sync_clean);
        if (note_edge_count != 0 || game_tick_count != 0)
            $error("A short glitch generated a frame event");

        // -------------------------------------------------------------
        // 2) 실제 VGA 60 Hz 타이밍으로 5프레임 생성
        // -------------------------------------------------------------
        #(VSYNC_HIGH);
        repeat (5) begin
            send_vga_frame();
            $display("[%0t] frame=%0d clean=%0d note=%0d game=%0d line=%0d frame_cnt=%0d rom=%0d lcnt0=%0d pos0=%b",
                     $time,
                     input_fall_count - 1, // 첫 입력 하강은 위의 글리치
                     clean_fall_count,
                     note_edge_count,
                     game_tick_count,
                     line_rise_count,
                     note_frame_cnt,
                     rom_addr,
                     lcnt0,
                     pos0);
        end

        // 정상 VSYNC 5개는 각 소비 모듈에서 정확히 5번 보여야 함
        if (clean_fall_count != 5)
            $error("Expected 5 clean VSYNC falling edges, got %0d", clean_fall_count);
        if (note_edge_count != 5)
            $error("Expected 5 Note_Controller frame edges, got %0d", note_edge_count);
        if (game_tick_count != 5)
            $error("Expected 5 GameResult frame ticks, got %0d", game_tick_count);
        if (line_rise_count != 5)
            $error("Expected 5 line_count rising edges, got %0d", line_rise_count);

        $display("VSYNC timing test completed");
        $finish;
    end

endmodule
