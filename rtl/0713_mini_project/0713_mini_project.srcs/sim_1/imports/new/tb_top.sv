`timescale 1ns / 1ps

module tb_top();

    // 1. 입력 및 입출력 신호 선언
    logic       clk;
    logic       reset;
    logic [2:0] btn;

    logic       vsync;     // 카메라 vsync
    logic       pclk;      // 카메라 pclk
    logic       href;      // 카메라 href
    logic [7:0] pdata;     // 카메라 pdata

    // 2. 출력 신호 선언
    logic       xclk;      // 카메라 master clock
    logic       h_sync;    // VGA h_sync
    logic       v_sync;    // VGA v_sync
    logic [3:0] port_red;  // VGA R
    logic [3:0] port_green;// VGA G
    logic [3:0] port_blue; // VGA B
    logic       scl;       // I2C SCL
    wire        sda;       // I2C SDA (inout)

    logic       main_done;
    logic       tx;        // UART TX

    // I2C 풀업 저항 모사
    assign sda = 1'bz;

    // 3. UUT (top) 인스턴스화
    top UUT (
        .clk(clk),
        .reset(reset),
        .btn(btn),
        .vsync(vsync),
        .xclk(xclk),
        .pclk(pclk),
        .href(href),
        .pdata(pdata),
        .h_sync(h_sync),
        .v_sync(v_sync),
        .port_red(port_red),
        .port_green(port_green),
        .port_blue(port_blue),
        .scl(scl),
        .sda(sda),
        .main_done(main_done),
        .tx(tx)
    );

    // 4. 입력 시스템 클럭 생성 (100MHz -> 주기 10ns)
    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end

    // 5. 카메라 클럭 및 신호 생성 에뮬레이션
    initial begin
        pclk = 0;
        forever #20 pclk = ~pclk; // 약 25MHz 카메라 픽셀 클럭
    end

    initial begin
        vsync = 0;
        href = 0;
        pdata = 8'h00;
        
        // 프레임 전송 에뮬레이션
        forever begin
            #500;
            vsync = 1;           // 프레임 시작 (vsync active high)
            #200;
            vsync = 0;
            #100;
            
            // 시뮬레이션 속도를 위해 480라인 중 5라인만 단순 모사
            repeat (5) begin
                href = 1;
                repeat (640) begin
                    @(posedge pclk);
                    pdata = $urandom_range(8'h00, 8'hFF); // 가상의 픽셀 데이터
                end
                href = 0;
                #5000;           // 수평 블랭킹 구간
            end
        end
    end

    // -------------------------------------------------------------
    // 시뮬레이션 가속화 (Hierarchical Force)
    // READY 상태(3초 대기)만 강제로 값을 주입해 스킵하여 
    // 검증이 오랜 대기 시간 없이 원활하게 돌 수 있도록 가속합니다.
    // -------------------------------------------------------------
    initial begin
        #10;
        forever begin
            @(posedge clk);
            if (UUT.U_MainController.U_main_control.o_state == 3'b010) begin 
                force UUT.U_MainController.U_main_control.s_cnt = UUT.U_MainController.U_main_control.TIME_3SEC;
            end else begin
                release UUT.U_MainController.U_main_control.s_cnt;
            end
        end
    end

    // 물리 버튼 입력을 가하는 태스크 (디바운서 CNT_MAX = 250,000 클락을 통과해야 하므로 3ms 이상 유지)
    task automatic press_button_d();
        $display("[INPUT] Pushing Down Button (btn[2]) - Natural Debouncing");
        btn[2] = 1'b1;
        #3000000;  // 3ms 유지 (100MHz 기준 300,000 사이클)
        btn[2] = 1'b0;
        #3000000;  // 뗀 후 3ms 대기
    endtask

    task automatic press_button_l();
        $display("[INPUT] Pushing Left Button (btn[0]) - Natural Debouncing");
        btn[0] = 1'b1;
        #3000000;
        btn[0] = 1'b0;
        #3000000;
    endtask

    task automatic press_button_r();
        $display("[INPUT] Pushing Right Button (btn[1]) - Natural Debouncing");
        btn[1] = 1'b1;
        #3000000;
        btn[1] = 1'b0;
        #3000000;
    endtask

    // 6. 메인 테스트 시나리오
    initial begin
        // 초기화
        reset = 1'b1;
        btn = 3'b000;
        
        #200;
        reset = 1'b0; // 리셋 해제
        #1000;

        $display("==================================================");
        $display("=== 1. IDLE -> SELECT 상태 진입 ===");
        $display("==================================================");
        press_button_d();
        #10000;
        
        $display("==================================================");
        $display("=== 2. SELECT 상태: 곡 선택 및 변경 ===");
        $display("==================================================");
        // 오른쪽 버튼 입력 (music_sel: 0 -> 1)
        press_button_r();
        #10000;
        
        // 왼쪽 버튼 입력 (music_sel: 1 -> 0)
        press_button_l();
        #10000;

        $display("==================================================");
        $display("=== 3. SELECT -> READY -> GAME_CONT 상태 진입 ===");
        $display("==================================================");
        // 확인 버튼 누름 -> READY 진입 -> s_cnt 가속으로 인해 바로 GAME_CONT 진입
        press_button_d();
        
        // GAME_CONT(011) 상태가 될 때까지 대기
        wait(UUT.U_MainController.o_state == 3'b011);
        $display("Entered GAME_CONT state successfully.");
        
        $display("==================================================");
        $display("=== 4. GAME_CONT 상태: 자연스러운 동작 관찰 ===");
        $display("==================================================");
        // 하드웨어 타이밍(VGA v_sync 16.67ms 주기)에 맞춰서 게임이 자연스럽게 흐릅니다.
        // 식사시간 동안 시뮬레이션이 넉넉히 돌아갈 수 있도록 200ms 동안 관찰합니다.
        #200000000; 

        $display("==================================================");
        $display("=== 5. 시뮬레이션 완료 ===");
        $display("==================================================");
        $finish;
    end

endmodule
