`timescale 1ns / 1ps

module tb_MainController();

    // 1. 입력 신호 선언
    logic clk;
    logic reset;
    logic btn_l_f;
    logic btn_r_f;
    logic btn_d_f;
    logic v_sync;
    logic [3:0] region;
    logic capture_done;

    // 2. 출력 신호 선언
    logic        main_done;
    logic [2:0]  o_state;
    logic [3:0]  o_lane;
    logic [11:0] o_duration;
    logic [23:0] score;
    logic        perfect;
    logic        good;
    logic        miss;
    logic [9:0]  combo;
    logic        fever;

    // UUT 인스턴스화
    MainController UUT (
        .clk(clk),
        .reset(reset),
        .btn_l_f(btn_l_f),
        .btn_r_f(btn_r_f),
        .btn_d_f(btn_d_f),
        .v_sync(v_sync),
        .region(region),
        .capture_done(capture_done),
        .main_done(main_done),
        .o_state(o_state),
        .o_lane(o_lane),
        .o_duration(o_duration),
        .score(score),
        .perfect(perfect),
        .good(good),
        .miss(miss),
        .combo(combo),
        .fever(fever)
    );

    // 3. 클럭 생성 (25MHz -> 주기 40ns)
    initial begin
        clk = 0;
        forever #20 clk = ~clk; 
    end

    // 4. v_sync 신호 생성
    // top_game 모듈의 v_sync 글리치 필터(1000 클락 카운트)를 통과할 수 있도록
    // 충분한 시간 동안 유지되도록 설정합니다. (High 50us, Low 50us = 주기 100us)
    initial begin
        v_sync = 0;
        forever #50000 v_sync = ~v_sync; 
    end

    // -------------------------------------------------------------
    // 시뮬레이션 가속화 (Hierarchical Force)
    // 하드웨어 동작용 디바운서 및 카운터(CNT_MAX, TIME_3SEC)의 매우 긴 대기 시간을
    // 소스 코드 변경 없이 시뮬레이션 상에서 강제로 스킵하여 빠른 검증을 수행합니다.
    // -------------------------------------------------------------
    
    // READY 상태(3초 대기)가 되었을 때 s_cnt 카운터 값을 강제로 완료 상태로 채웁니다.
    initial begin
        #10;
        forever begin
            @(posedge clk);
            if (UUT.U_main_control.o_state == 3'b010) begin // READY
                force UUT.U_main_control.s_cnt = UUT.U_main_control.TIME_3SEC;
            end else begin
                release UUT.U_main_control.s_cnt;
            end
        end
    end

    // 버튼 디바운싱을 스킵하고 바로 내부 트리거 펄스(o_btn_*)를 발생시키는 가속 태스크
    task automatic press_button_d();
        $display("[INPUT] Pushing Down Button (btn_d)");
        force UUT.o_btn_d = 1'b1;
        repeat (5) @(posedge clk);
        force UUT.o_btn_d = 1'b0;
        repeat (5) @(posedge clk);
        release UUT.o_btn_d;
    endtask

    task automatic press_button_l();
        $display("[INPUT] Pushing Left Button (btn_l)");
        force UUT.o_btn_l = 1'b1;
        repeat (5) @(posedge clk);
        force UUT.o_btn_l = 1'b0;
        repeat (5) @(posedge clk);
        release UUT.o_btn_l;
    endtask

    task automatic press_button_r();
        $display("[INPUT] Pushing Right Button (btn_r)");
        force UUT.o_btn_r = 1'b1;
        repeat (5) @(posedge clk);
        force UUT.o_btn_r = 1'b0;
        repeat (5) @(posedge clk);
        release UUT.o_btn_r;
    endtask

    // 5. 테스트 시나리오
    initial begin
        // 초기 입력 설정
        reset = 1'b1;
        btn_l_f = 1'b0;
        btn_r_f = 1'b0;
        btn_d_f = 1'b0;
        region = 4'b0000;
        capture_done = 1'b0;
        
        #200;
        reset = 1'b0;
        #100;
        
        $display("==================================================");
        $display("=== 1. IDLE -> SELECT 상태 진입 ===");
        $display("==================================================");
        $display("Current State: %b (Expected: IDLE 000)", o_state);
        press_button_d();
        #100;
        $display("Current State: %b (Expected: SELECT 001)", o_state);
        $display("Current music_sel: %d", UUT.music_sel);
        
        #1000;
        $display("==================================================");
        $display("=== 2. SELECT 상태: 곡 선택 테스트 ===");
        $display("==================================================");
        // 다음 곡 선택 (music_sel: 0 -> 1)
        press_button_r();
        #100;
        $display("After Right click -> music_sel: %d (Expected: 1)", UUT.music_sel);
        
        // 다음 곡 선택 (music_sel: 1 -> 2)
        press_button_r();
        #100;
        $display("After Right click -> music_sel: %d (Expected: 2)", UUT.music_sel);

        // 이전 곡 선택 (music_sel: 2 -> 1)
        press_button_l();
        #100;
        $display("After Left click -> music_sel: %d (Expected: 1)", UUT.music_sel);

        // 곡 최종 선택 및 READY 진입
        #1000;
        $display("==================================================");
        $display("=== 3. SELECT -> READY -> GAME_CONT 상태 진입 ===");
        $display("==================================================");
        press_button_d();
        
        // s_cnt 가속 포스에 의해 READY(010)에서 곧바로 GAME_CONT(011)로 진입하게 됩니다.
        wait(o_state == 3'b011);
        $display("Current State: %b (Expected: GAME_CONT 011)", o_state);
        
        #1000;
        $display("==================================================");
        $display("=== 4. GAME_CONT 상태: 노트 생성 및 판정 테스트 ===");
        $display("==================================================");
        // 게임 루프가 실행되는 동안 v_sync 클린 동기에 맞춰 노트가 생성되는지 관찰
        // v_sync 엣지 검출을 통해 note_done이 뜨고 o_lane, o_duration 등이 바뀌는지 확인
        // 아래에서 약 15번의 v_sync 엣지를 대기합니다.
        repeat (15) begin
            @(posedge v_sync);
            #100;
            if (o_lane != 0) begin
                $display("[GAME] Note spawned on lane: %b, duration: %d", o_lane, o_duration);
                // 노트를 매칭시키기 위해 region 신호 타격 흉내
                region = o_lane;
                #500;
                region = 4'b0000;
                #100;
                $display("[GAME] Hit register check - Perfect: %b, Good: %b, Combo: %d, Score: %d", 
                         perfect, good, combo, score);
            end
        end

        #1000;
        $display("==================================================");
        $display("=== 5. GAME_CONT -> CAPTURE -> DONE 상태 자동 전환 ===");
        $display("==================================================");
        // little_star.mem 재생 완료(FFFF00A7 대기 완료)를 시뮬레이션하기 위해
        // game_done 출력이 발생할 때까지 대기
        $display("Waiting for game_done to complete remaining notes...");
        wait(UUT.game_done == 1'b1);
        
        // game_done이 감지되면 FSM은 CAPTURE(100) -> DONE(101)로 즉시 전환됩니다.
        wait(o_state == 3'b101);
        $display("Current State: %b (Expected: DONE 101)", o_state);
        $display("Final Score: %d, Max Combo: %d", score, combo);
        $display("main_done flag: %b (Expected: 1)", main_done);

        #1000;
        $display("==================================================");
        $display("=== 6. DONE -> IDLE 상태 복귀 ===");
        $display("==================================================");
        // DONE 상태에서 확인 버튼을 누르면 다시 IDLE로 돌아갑니다.
        press_button_d();
        #100;
        $display("Returned to State: %b (Expected: IDLE 000)", o_state);

        #1000;
        $display("==================================================");
        $display("=== 시뮬레이션 완료 ===");
        $display("==================================================");
        $finish;
    end

endmodule