`timescale 1ns / 1ps

module tb_top_game ();

    // ==============================
    // DUT 포트
    // ==============================
    logic       clk;
    logic       reset;
    logic [2:0] btn;

    // 카메라 (더미 입력)
    logic       vsync_cam;
    wire        xclk;
    logic       pclk;
    logic       href;
    logic [7:0] pdata;

    // VGA 출력
    wire h_sync, v_sync;
    wire [3:0] port_red, port_green, port_blue;

    // I2C
    wire scl;
    wire sda;

    // 기타
    wire main_done;
    wire tx;

    // ==============================
    // DUT 인스턴스 (top 모듈)
    // ==============================
    top DUT (
        .clk       (clk),
        .reset     (reset),
        .btn       (btn),
        .vsync     (vsync_cam),
        .xclk      (xclk),
        .pclk      (pclk),
        .href      (href),
        .pdata     (pdata),
        .h_sync    (h_sync),
        .v_sync    (v_sync),
        .port_red  (port_red),
        .port_green(port_green),
        .port_blue (port_blue),
        .scl       (scl),
        .sda       (sda),
        .main_done (main_done),
        .tx        (tx)
    );

    // I2C는 풀업 (open-drain)
    pullup (sda);

    // ==============================
    // 100MHz 입력 클록
    // ==============================
    initial clk = 0;
    always #5 clk = ~clk;

    // ==============================
    // 카메라 더미 신호
    // pclk = 25MHz, vsync/href/pdata = 안 씀
    // ==============================
    initial pclk = 0;
    always #20 pclk = ~pclk;

    initial begin
        vsync_cam = 1;
        href      = 0;
        pdata     = 8'd0;
    end

    // ==============================
    // 내부 관찰 와이어
    // ==============================
    wire [2:0] w_state = DUT.w_state;
    wire [23:0] w_score = DUT.w_score;
    wire w_perfect = DUT.w_perfect;
    wire w_good = DUT.w_good;
    wire w_miss = DUT.w_miss;
    wire w_fever = DUT.w_fever;

    // 디바운서 통과 후 실제 입력 확인용 모니터링 와이어
    wire w_debounced_btn = DUT.U_MainController.o_btn_d;

    // MainController 내부
    wire w_game_done = DUT.U_MainController.game_done;
    wire [15:0] w_frame_cnt = DUT.U_MainController.U_top_game.U_NOTE_CTRL.frame_cnt;
    wire [5:0]  w_rom_addr  = DUT.U_MainController.U_top_game.U_ROM_SEL_READER.rom_addr;
    wire w_note_done = DUT.U_MainController.U_top_game.U_NOTE_CTRL.note_done;
    wire [9:0] w_lcnt0 = DUT.U_MainController.U_top_game.U_LINE_COUNT.o_lcnt0;
    wire [3:0] w_pos0 = DUT.U_MainController.U_top_game.U_LINE_COUNT.o_pos0;

    // ==============================
    // 버튼 누르기 태스크 (실물 디바운서 기준 필터 타임 통과 버전)
    // ==============================
    task press_btn(input int idx);
        btn[idx] = 1;
        #3_000_000;  // 3ms 동안 누르기 (실물 디바운서 2.5ms 통과)
        btn[idx] = 0;
        #3_000_000;  // 3ms 동안 떼기 (실물 디바운서가 완전히 0으로 해제될 때까지 대기)
    endtask

    // v_sync 엣지 대기 (VGA 모듈이 자동 생성하는 v_sync 사용)
    task wait_vsync(input int n);
        repeat (n) begin
            @(negedge v_sync);
            @(posedge v_sync);
        end
    endtask

    // ==============================
    // 메인 시나리오
    // ==============================
    initial begin
        reset = 1;
        btn   = 3'b000;
        #500;
        reset = 0;
        #1000;

        $display("=== [%0t] 초기 상태: state=%b ===", $time, w_state);

        // ------------------------------------------
        // 버튼으로 상태 전환 (FSM에 맞게 btn[2] 사용)
        // IDLE(000) ➡️ SELECT(001) ➡️ READY(010) ➡️ GAME_CONT(011)
        // ------------------------------------------
        $display("\n=== 버튼으로 게임 시작 ===");

        // 1. IDLE ➡️ SELECT (btn_d를 3ms간 꾹 눌러 디바운서 통과)
        press_btn(2);  // btn[2] = btn_d
        $display("  [%0t] btn[2] 1회: state=%b (debounced=%b)", $time,
                 w_state, w_debounced_btn);

        // 2. SELECT ➡️ READY
        press_btn(2);
        $display("  [%0t] btn[2] 2회: state=%b (debounced=%b)", $time,
                 w_state, w_debounced_btn);

        // [추가] READY(3'b010) 진입 시 3초 카운트다운 강제 스킵
        wait (w_state == 3'b010);
        $display("  [%0t] READY 진입 확인! 3초 대기 카운터 즉시 스킵 수행", $time);
        
        // s_cnt 카운터 값을 강제로 완료 상태로 채움 (force)
        force DUT.U_MainController.U_main_control.s_cnt = 28'd150_000_000;
        #100; // FSM 상태 천이를 위해 약 10클럭 대기
        
        // FSM 상태가 전이된 후 제어권 원래대로 해제 (release)
        release DUT.U_MainController.U_main_control.s_cnt;

        // GAME_CONT(3'b011) 진입 확인
        wait (w_state == 3'b011);
        $display("  ★ GAME_CONT 정상 진입 완료! state=%b", w_state);

        // ------------------------------------------
        // 게임 진행: game_done 대기
        // ------------------------------------------
        $display("\n=== 게임 진행 중 (game_done 대기) ===");

        fork
            begin
                @(posedge w_game_done);
                $display("  ★ [%0t] game_done 발생! state=%b score=%0d",
                         $time, w_state, w_score);
            end
            begin
                // 타임아웃 (30ms = 실제 VGA 60Hz 기준 약 1800프레임)
                #30_000_000;
                $display("  ✗ 타임아웃: game_done 미발생");
            end
        join_any
        disable fork;

        // ------------------------------------------
        // 상태 자동 전환 확인
        // ------------------------------------------
        #500_000;  // 0.5ms 대기
        $display("\n=== game_done 이후 상태 ===");
        $display("  state=%b (CAPTURE=3'b100 이면 정상)", w_state);

        // ------------------------------------------
        // 최종 결과
        // ------------------------------------------
        #1_000_000;
        $display("\n========================================");
        $display("  최종 결과");
        $display("========================================");
        $display("  state = %b", w_state);
        $display("  score = %0d", w_score);
        $display("  fever = %b", w_fever);
        $display("========================================");

        $finish;
    end

    // ==============================
    // 상태 변화 자동 모니터
    // ==============================
    always @(w_state) $display("[%0t] ◆ STATE → %b", $time, w_state);

    // 판정 모니터
    always @(posedge clk) begin
        if (w_perfect) $display("[%0t] PERFECT score=%0d", $time, w_score);
        if (w_good) $display("[%0t] GOOD    score=%0d", $time, w_score);
        if (w_miss) $display("[%0t] MISS    score=%0d", $time, w_score);
        if (w_game_done) $display("[%0t] ■ GAME_DONE!", $time);
    end

endmodule
