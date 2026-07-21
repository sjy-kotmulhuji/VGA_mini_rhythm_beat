`timescale 1ns / 1ps

module tb_top_game();

    // ==============================
    // 클록 및 리셋
    // ==============================
    logic        clk;
    logic        reset;

    // ==============================
    // DUT 입력
    // ==============================
    logic [ 1:0] music_sel;
    logic        v_sync;
    logic [ 3:0] region;
    logic [ 2:0] main_state;

    // ==============================
    // DUT 출력
    // ==============================
    logic [ 3:0] o_lane;
    logic [11:0] o_duration;
    logic        game_done;
    logic [23:0] score;
    logic        perfect;
    logic        good;
    logic        miss;
    logic [ 9:0] combo;
    logic        fever;

    // ==============================
    // DUT 인스턴스
    // ==============================
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

    // ==============================
    // 100MHz 클록 생성 (주기 10ns)
    // ==============================
    initial clk = 0;
    always #5 clk = ~clk;

    // ==============================
    // 60Hz v_sync 생성
    // VGA 480p 기준: 전체 주기 = 16.667ms
    //   Active Low 구간(펄스) ≈ 64us (6400 클락)
    //   나머지는 High
    // ==============================
    localparam int VSYNC_PERIOD  = 1_666_700;  // 16.667ms = 1,666,700 ns
    localparam int VSYNC_PULSE   = 6_400;      // 64us = 6,400 ns (Active Low 구간)

    initial begin
        v_sync = 1;
        forever begin
            // High 구간 (대부분의 프레임 시간)
            #(VSYNC_PERIOD - VSYNC_PULSE);
            // Low 펄스 (v_sync active)
            v_sync = 0;
            #VSYNC_PULSE;
            v_sync = 1;
        end
    end

    // ==============================
    // 내부 관찰용 와이어 (파형 확인용)
    // ==============================
    // Note_Controller 내부
    wire [15:0] w_frame_cnt = DUT.U_NOTE_CTRL.frame_cnt;
    wire        w_note_done = DUT.U_NOTE_CTRL.note_done;
    wire        w_vs_edge   = DUT.U_NOTE_CTRL.v_sync_edge;

    // Rom_Sel_Reader 내부
    wire [5:0]  w_rom_addr  = DUT.U_ROM_SEL_READER.rom_addr;
    wire [31:0] w_note_data = DUT.U_ROM_SEL_READER.note_data;

    // line_count 내부
    wire [9:0]  w_lcnt0     = DUT.U_LINE_COUNT.o_lcnt0;
    wire [9:0]  w_lcnt1     = DUT.U_LINE_COUNT.o_lcnt1;
    wire [9:0]  w_lcnt2     = DUT.U_LINE_COUNT.o_lcnt2;
    wire [9:0]  w_lcnt3     = DUT.U_LINE_COUNT.o_lcnt3;
    wire [3:0]  w_pos0      = DUT.U_LINE_COUNT.o_pos0;
    wire [3:0]  w_pos1      = DUT.U_LINE_COUNT.o_pos1;

    // score 내부
    wire [22:0] w_basic_score = DUT.U_SCORE.basic_score;
    wire [22:0] w_combo_score = DUT.U_SCORE.combo_score;

    // ==============================
    // v_sync 엣지 대기 태스크
    // (falling edge = 1프레임 전진)
    // ==============================
    task wait_vsync_edges(input int n);
        repeat (n) begin
            @(negedge v_sync);
            @(posedge v_sync);
        end
    endtask

    // ==============================
    // region 입력 태스크
    // 특정 레인에 빨간색 감지를 시뮬레이션
    // ==============================
    task camera_input(input logic [3:0] lanes, input int hold_frames);
        region = lanes;
        wait_vsync_edges(hold_frames);
        region = 4'b0000;
    endtask

    // ==============================
    // 메인 시나리오
    // ==============================
    initial begin
        // --- 초기화 ---
        reset      = 1;
        music_sel  = 2'b00;    // 작은별 선택
        region     = 4'b0000;
        main_state = 3'b000;   // IDLE 상태

        #100;
        reset = 0;
        #100;

        // ============================================
        // [Phase 1] IDLE 상태에서 v_sync 몇 프레임 대기
        //   → 이 구간에서 노트가 생성되지 않아야 정상
        // ============================================
        $display("=== Phase 1: IDLE 상태 (노트 생성 없어야 함) ===");
        $display("  Time=%0t, main_state=%b, frame_cnt=%0d, rom_addr=%0d",
                 $time, main_state, w_frame_cnt, w_rom_addr);
        wait_vsync_edges(5);
        $display("  5프레임 후: frame_cnt=%0d, rom_addr=%0d, note_done=%b",
                 w_frame_cnt, w_rom_addr, w_note_done);

        // ============================================
        // [Phase 2] GAME_CONT(3'b011) 상태 진입
        //   → 노트가 rom에서 로딩되며 frame_cnt 증가 시작
        // ============================================
        $display("\n=== Phase 2: GAME_CONT 진입 ===");
        main_state = 3'b011;

        // 첫 번째 노트: frame=0x0000, lane=0x8 (4번 레인)
        // → 즉시 note_done이 발생해야 함
        wait_vsync_edges(3);
        $display("  3프레임 후: frame_cnt=%0d, rom_addr=%0d, note_data=%h",
                 w_frame_cnt, w_rom_addr, w_note_data);
        $display("  o_lane=%b, note_done=%b", o_lane, w_note_done);

        // ============================================
        // [Phase 3] 노트가 떨어지는 과정 관찰
        //   → lcnt 값이 매 프레임마다 증가해야 함
        //   → 15프레임(0x000F) 에서 두 번째 노트 발생
        // ============================================
        $display("\n=== Phase 3: 노트 낙하 관찰 (15프레임까지) ===");
        repeat (15) begin
            wait_vsync_edges(1);
            $display("  frame=%0d, rom_addr=%0d, note_data=%h, lcnt0=%0d, lcnt1=%0d, pos0=%b, pos1=%b",
                     w_frame_cnt, w_rom_addr, w_note_data, w_lcnt0, w_lcnt1, w_pos0, w_pos1);
        end

        // ============================================
        // [Phase 4] 판정 영역 도달 시뮬레이션
        //   → lcnt가 410~440 범위에 도달할 때 region 입력
        //   → Perfect/Good/Miss 판정 확인
        //
        //   첫 노트는 frame=0에서 발생, 4번 레인(region bit[3])
        //   linecounter의 LINE_VALUE = 640/179 ≈ 3 pixel/frame
        //   따라서 lcnt=420 도달까지 약 140프레임 필요
        // ============================================
        $display("\n=== Phase 4: 판정 영역 접근 (140프레임까지 전진) ===");
        // 현재 약 18프레임 진행됨 → 122프레임 더 전진
        wait_vsync_edges(122);
        $display("  frame=%0d, lcnt0=%0d, lcnt1=%0d, lcnt2=%0d, lcnt3=%0d",
                 w_frame_cnt, w_lcnt0, w_lcnt1, w_lcnt2, w_lcnt3);

        // 4번 레인(bit[3])에 카메라 입력 (Perfect 시도)
        $display("\n  → 4번 레인 카메라 입력 (region=4'b1000)");
        camera_input(4'b1000, 2);
        $display("  perfect=%b, good=%b, miss=%b, score=%0d, combo=%0d",
                 perfect, good, miss, score, combo);

        // ============================================
        // [Phase 5] 추가 노트들의 판정 관찰
        //   → 계속 진행하며 다양한 입력 테스트
        // ============================================
        $display("\n=== Phase 5: 추가 판정 테스트 ===");

        // 몇 프레임 더 진행 후 Miss 발생 관찰 (입력 안 함)
        wait_vsync_edges(30);
        $display("  30프레임 경과 (입력 없음): miss=%b, score=%0d", miss, score);

        // 1번 레인에 입력
        camera_input(4'b0001, 2);
        $display("  1번 레인 입력 후: perfect=%b, good=%b, miss=%b, score=%0d",
                 perfect, good, miss, score);

        // ============================================
        // [Phase 6] 곡 종료까지 진행
        //   → game_done 신호가 1이 되는지 확인
        //   → 마지막 ROM 데이터가 0xFFFF00A7
        //     (FFFF = 종료 마커, 00A7 = 딜레이 167프레임)
        // ============================================
        $display("\n=== Phase 6: 곡 종료 대기 ===");
        fork
            begin
                // game_done 감시
                @(posedge game_done);
                $display("  ★ game_done 발생! Time=%0t, frame=%0d, score=%0d",
                         $time, w_frame_cnt, score);
            end
            begin
                // 타임아웃 (최대 1000프레임 = 약 16.7초)
                wait_vsync_edges(1000);
                $display("  ✗ 타임아웃: 1000프레임 내에 game_done 미발생");
            end
        join_any
        disable fork;

        // ============================================
        // [Phase 7] 최종 결과 출력
        // ============================================
        $display("\n========================================");
        $display("  최종 결과");
        $display("========================================");
        $display("  Score       = %0d", score);
        $display("  basic_score = %0d", w_basic_score);
        $display("  combo_score = %0d", w_combo_score);
        $display("  game_done   = %b", game_done);
        $display("  fever       = %b", fever);
        $display("========================================");

        #1000;
        $finish;
    end

    // ==============================
    // 판정 이벤트 자동 모니터
    // ==============================
    always @(posedge clk) begin
        if (perfect)
            $display("[%0t] ★ PERFECT! score=%0d combo=%0d", $time, score, combo);
        if (good)
            $display("[%0t] ○ GOOD    score=%0d combo=%0d", $time, score, combo);
        if (miss)
            $display("[%0t] ✗ MISS    score=%0d combo=%0d", $time, score, combo);
        if (game_done)
            $display("[%0t] ■ GAME_DONE!", $time);
    end

endmodule

