`timescale 1ns / 1ps

module GameResult (
    input  logic       clk,
    input  logic       reset,
    // line_count에서 (슬롯 4개)
    input  logic [3:0] pos0,
    input  logic [3:0] pos1,
    input  logic [3:0] pos2,
    input  logic [3:0] pos3,        // 각 슬롯 노트의 영역 인덱스
    input  logic [9:0] lcnt0,
    input  logic [9:0] lcnt1,
    input  logic [9:0] lcnt2,
    input  logic [9:0] lcnt3,       // 각 슬롯 노트의 y좌표
    //input  logic [9:0] duration0,
    //input  logic [9:0] duration1,
    //input  logic [9:0] duration2,
    //input  logic [9:0] duration3,   // 미리 뚫어둠 (지금은 미사용)
    // camera에서
    input  logic [3:0] region,      // 영역별 빨강 검출 (level)
    // VGA 에서
    input  logic       v_sync,
    // GameScore로
    output logic       perfect,     // pulse
    output logic       good,        // pulse
    output logic       miss,        // pulse
    output logic       combo_done,  // pulse : 콤보가 끊긴 순간
    output logic [9:0] combo_data,  // 끊긴 시점의 콤보 수
    output logic       fever        // level : 7연속 perfect ~ miss까지 1
);

    /*
    게임 판정 로직

    노트 정보
    - pos[3:0]의 각 비트는 1~4번 레인의 노트 활성화 여부
    - 하나의 슬롯에 여러 비트가 1이면 동시 노트
    - lcnt는 해당 슬롯 노트의 현재 Y좌표

    위치 판정
    - lcnt 410~430 = Perfect
    - lcnt 400~409, 431~440 = Good
    - 입력 없이 lcnt 440 통과 = Miss

    동시 노트 판정
    - 모든 활성 레인이 Perfect이면 Perfect
    - 활성 레인 중 하나라도 Good이면 Good
    - 활성 레인 중 하나라도 입력하지 못하면 Miss
    - 최종 우선순위는 Miss > Good > Perfect

    잘못된 입력
    - 판정 가능한 노트가 없는 레인에 새 손 입력이 들어오면 Miss
    - 손을 계속 유지할 때는 Miss를 반복하지 않음

    콤보 및 Fever
    - Perfect 또는 Good이면 콤보 1 증가
    - Miss이면 combo_data에 끊어진 콤보 수 저장 후 콤보 초기화
    - combo_done은 combo_data 저장 다음 클럭에 1회 출력
    - Perfect 7연속이면 fever ON, Miss이면 fever OFF
    */

    // ===============================================================
    // 입력 슬롯 정리
    //
    // Line Count 모듈에서 최대 4개의 노트를 각각 별도 포트로 받음
    // 반복되는 판정 회로를 generate-for로 만들기 쉽도록 배열로 묶기 
    //
    // pos는 레인 번호가 아니라 레인 활성화 비트마스크
    // pos[0]=1 → 1번 레인, pos[1]=1 → 2번 레인
    // pos[2]=1 → 3번 레인, pos[3]=1 → 4번 레인
    //
    // 예) pos0=4'b0110, lcnt0=420
    //     → 슬롯 0은 2번과 3번 레인의 동시 노트 묶음
    //     → 두 노트의 공통 Y좌표는 420
    // ===============================================================
    logic [3:0] pos [0:3];
    logic [9:0] lcnt[0:3];

    assign pos[0]  = pos0;
    assign pos[1]  = pos1;
    assign pos[2]  = pos2;
    assign pos[3]  = pos3;
    assign lcnt[0] = lcnt0;
    assign lcnt[1] = lcnt1;
    assign lcnt[2] = lcnt2;
    assign lcnt[3] = lcnt3;

    // ===============================================================
    // 슬롯별 판정 결과 및 잘못된 손 입력 검출용 신호
    //
    // perfect_slot[i]: 슬롯 i에서 발생한 Perfect 1클럭 펄스
    // good_slot[i]   : 슬롯 i에서 발생한 Good 1클럭 펄스
    // miss_slot[i]   : 슬롯 i가 판정되지 않고 지나간 Miss 펄스
    // input_miss     : 노트가 없는 레인에 손을 넣었을 때의 Miss 펄스
    // region_d       : 이전 프레임의 region 값(새 손 입력 검출용)
    // ===============================================================
    logic [3:0] perfect_slot, good_slot, miss_slot;
    logic       input_miss;
    logic [3:0] region_d;

    // 전체 판정존의 중심은 Y=420이고 중심에서 위/아래 20까지 허용함
    // 따라서 전체 판정 가능 범위는 Y=400~440
    localparam int JUDGE_LINE = 420;
    localparam int JUDGE_GOOD_HALF = 20;

    // ===============================================================
    // 1단계: 각 슬롯의 노트가 전체 판정존에 있는지 확인
    //
    // slotN_in_zone = 1 : 슬롯 N의 lcnt가 400~440 안에 있음
    // slotN_in_zone = 0 : 아직 판정존 위이거나 이미 아래로 지나감
    // ===============================================================
    wire slot0_in_zone =
        (lcnt[0] >= JUDGE_LINE - JUDGE_GOOD_HALF) &&
        (lcnt[0] <= JUDGE_LINE + JUDGE_GOOD_HALF);
    wire slot1_in_zone =
        (lcnt[1] >= JUDGE_LINE - JUDGE_GOOD_HALF) &&
        (lcnt[1] <= JUDGE_LINE + JUDGE_GOOD_HALF);
    wire slot2_in_zone =
        (lcnt[2] >= JUDGE_LINE - JUDGE_GOOD_HALF) &&
        (lcnt[2] <= JUDGE_LINE + JUDGE_GOOD_HALF);
    wire slot3_in_zone =
        (lcnt[3] >= JUDGE_LINE - JUDGE_GOOD_HALF) &&
        (lcnt[3] <= JUDGE_LINE + JUDGE_GOOD_HALF);

    // ===============================================================
    // 2단계: 판정존 안의 노트가 어느 레인에 있는지 확인
    //
    // pos의 각 비트가 해당 레인의 노트 존재 여부를 표시함
    // pos=4'b0001 → 1번 레인 단일 노트
    // pos=4'b0110 → 2번과 3번 레인 동시 노트
    //
    // 예) 슬롯 0이 판정존 안이고 pos[0][1]=1이면 lane1_has_note=1
    //     즉, 현재 2번 레인에는 판정할 수 있는 노트가 있다는 의미
    // ===============================================================
    wire lane0_has_note =
        (slot0_in_zone && pos[0][0]) ||
        (slot1_in_zone && pos[1][0]) ||
        (slot2_in_zone && pos[2][0]) ||
        (slot3_in_zone && pos[3][0]);
    wire lane1_has_note =
        (slot0_in_zone && pos[0][1]) ||
        (slot1_in_zone && pos[1][1]) ||
        (slot2_in_zone && pos[2][1]) ||
        (slot3_in_zone && pos[3][1]);
    wire lane2_has_note =
        (slot0_in_zone && pos[0][2]) ||
        (slot1_in_zone && pos[1][2]) ||
        (slot2_in_zone && pos[2][2]) ||
        (slot3_in_zone && pos[3][2]);
    wire lane3_has_note =
        (slot0_in_zone && pos[0][3]) ||
        (slot1_in_zone && pos[1][3]) ||
        (slot2_in_zone && pos[2][3]) ||
        (slot3_in_zone && pos[3][3]);

    // ===============================================================
    // 3단계: 각 레인에서 손이 새로 들어온 순간만 검출
    //
    // region은 손이 머무는 동안 계속 1인 level 신호
    // 현재 region=1이고 이전 region_d=0일 때만 새 입력으로 판단함
    // 손을 여러 프레임 유지해도 Miss가 반복되지 않도록 처리함
    //
    // 현재:region[0]=1, 이전:region_d[0]=0 → 새 손 입력(1)
    // 현재:region[0]=1, 이전:region_d[0]=1 → 계속 유지 중(0)
    // ===============================================================
    wire lane0_hand_pressed = region[0] && !region_d[0];
    wire lane1_hand_pressed = region[1] && !region_d[1];
    wire lane2_hand_pressed = region[2] && !region_d[2];
    wire lane3_hand_pressed = region[3] && !region_d[3];

    // ===============================================================
    // 4단계: 손을 넣은 레인에 판정 가능한 노트가 있는지 비교
    //
    // 예) 2번 레인 노트만 판정존 안에 있을 때
    //     lane1_hand_pressed=1 → 올바른 레인 입력, 입력 Miss 없음
    //     lane3_hand_pressed=1 → 4번 레인에는 노트가 없으므로 Miss
    //
    // 판정존에 노트가 하나도 없다면 모든 laneN_has_note가 0이므로
    // 어느 레인에 손을 넣어도 wrong_hand_pressed가 1이 됨
    // ===============================================================
    wire wrong_hand_pressed =
        (lane0_hand_pressed && !lane0_has_note) ||
        (lane1_hand_pressed && !lane1_has_note) ||
        (lane2_hand_pressed && !lane2_has_note) ||
        (lane3_hand_pressed && !lane3_has_note);

    // ===============================================================
    // 프레임 판정 타이밍 생성
    //
    // v_sync_d에는 이전 clk의 v_sync를 저장함
    // 이전 값이 1이고 현재 값이 0이면 v_sync 하강 에지이므로
    // frame_tick을 시스템 clk 한 주기 동안만 1로 생성함
    // 모든 게임 판정은 이 frame_tick에서 프레임당 한 번 수행함
    // ===============================================================
    logic v_sync_d;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) v_sync_d <= 1'b1;  // active low라 idle은 1
        else v_sync_d <= v_sync;
    end

    wire frame_tick = !v_sync && v_sync_d;  // 1 -> 0 되는 그 클럭만 1

    // ===============================================================
    // 잘못된 레인 또는 잘못된 타이밍 입력 처리
    //
    // wrong_hand_pressed=1이면 input_miss를 한 번 발생시킴
    // 이 Miss는 사용자 입력에 대한 벌점이며 노트 FSM은 종료하지 않음
    // 따라서 조기/오입력 후에도 노트가 판정존에 왔을 때 다시 칠 수 있음
    // region_d에는 다음 프레임의 상승 에지 검출을 위해 현재 값을 저장함
    // ===============================================================
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            region_d   <= 4'b0000;
            input_miss <= 1'b0;
        end else begin
            input_miss <= 1'b0;

            if (frame_tick) begin
                if (wrong_hand_pressed) input_miss <= 1'b1;

                region_d <= region;
            end
        end
    end

    // ===============================================================
    // 4개 슬롯에 동일한 slot_fsm 생성
    //
    // pos_mask의 각 1비트가 해당 슬롯에서 눌러야 하는 레인을 의미함
    // 각 활성 레인의 판정을 기억한 뒤 슬롯 결과 하나로 합침
    // 최종 우선순위는 Miss > Good > Perfect
    // ===============================================================
    genvar i;
    generate
        for (i = 0; i < 4; i++) begin : gen_lane
            slot_fsm u_fsm (
                .clk       (clk),
                .reset     (reset),
                .frame_tick(frame_tick),
                .lcnt_y    (lcnt[i]),
                .pos_mask  (pos[i]),
                .region    (region),
                .perfect   (perfect_slot[i]),
                .good      (good_slot[i]),
                .miss      (miss_slot[i])
            );
        end
    endgenerate

    // ===============================================================
    // 슬롯별 결과를 GameResult의 단일 출력으로 합치기
    //
    // 4개 슬롯 중 하나라도 Perfect이면 perfect=1이 됨
    // miss에는 슬롯 통과 Miss뿐 아니라 잘못된 손 입력 Miss도 포함됨
    // 주의: 같은 프레임에 두 슬롯이 Perfect여도 출력은 1비트이므로
    //       perfect 펄스는 하나로 합쳐짐
    // ===============================================================
    assign perfect = perfect_slot[0] | perfect_slot[1] | perfect_slot[2] | perfect_slot[3];
    assign good = good_slot[0] | good_slot[1] | good_slot[2] | good_slot[3];
    assign miss = input_miss |
                  miss_slot[0] | miss_slot[1] |
                  miss_slot[2] | miss_slot[3];

    // ===============================================================
    // 콤보 계산
    //
    // Perfect 또는 Good 1회 → 현재 combo_cnt를 1 증가
    // Miss 1회            → 끊기기 직전 combo_cnt를 combo_data에 저장하고
    //                       현재 combo_cnt를 0으로 초기화
    //
    // 예) Perfect, Good, Perfect 후 Miss
    //     Miss 직전 combo_cnt=3 → combo_data=3, combo_cnt=0
    // combo_cnt는 10비트 최댓값인 1023에서 더 증가하지 않음
    // ===============================================================
    logic [9:0] combo_cnt;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            combo_cnt  <= 10'd0;
            combo_data <= 10'd0;
        end else begin
            if (miss) begin
                combo_data <= combo_cnt;  // 끊긴 콤보 수 전달
                combo_cnt  <= 10'd0;  // 콤보 리셋
            end else if (perfect || good) begin
                if (combo_cnt < 10'd1023)  // 오버플로 방지
                    combo_cnt <= combo_cnt + 10'd1;
            end
        end
    end

    // Miss 클럭에서 combo_data를 먼저 저장한 뒤 combo_done을 한 클럭 늦게 출력함
    // top_score는 combo_done=1인 클럭에 이미 안정된 combo_data를 읽을 수 있음
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            combo_done <= 1'b0;
        else
            combo_done <= miss;
    end

    // ===============================================================
    // Fever 계산
    //
    // Perfect가 연속 7번 나오면 fever를 1로 켬
    // Good이 나오면 연속 Perfect 횟수(perf_cnt)는 0으로 돌아가지만,
    // 이미 켜진 fever 값은 유지됨
    // Miss가 나오면 perf_cnt가 0이 되고 fever도 꺼짐
    // ===============================================================
    logic [3:0] perf_cnt;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            perf_cnt <= 4'd0;
            fever    <= 1'b0;
        end else begin
            // 연속 perfect 카운터 (good/miss면 연속 끊김 -> 리셋)
            if (miss || good) perf_cnt <= 4'd0;
            else if (perfect && perf_cnt < 4'd7) perf_cnt <= perf_cnt + 4'd1;

            // fever level
            if (miss) fever <= 1'b0;  // miss에서만 OFF
            else if (perfect && perf_cnt == 4'd6)
                fever <= 1'b1;  // 이번이 7번째 perfect
            // good이 와도 fever는 유지
        end
    end

endmodule


module slot_fsm #(
    parameter int LINE = 420,  // 판정선 중심
    parameter int PERFECT_HALF = 30,  // perfect 반폭 -> 410~430
    parameter int GOOD_HALF = 50  // 판정존 반폭 -> 400~440
) (
    input logic clk,
    input logic reset,
    input logic frame_tick,
    input logic [9:0] lcnt_y,  // 이 슬롯 노트의 y좌표 (lcnt)
    input logic [3:0] pos_mask, // 슬롯에서 활성화된 레인 비트마스크
    input logic [3:0] region,   // 카메라의 레인별 손 감지 신호
    output logic perfect,
    output logic good,
    output logic miss
);

    // ===============================================================
    // 슬롯 하나의 판정 상태
    //
    // COMPARE : 아직 판정되지 않은 노트의 위치와 손 입력을 계속 비교함
    // DONE    : 이미 Perfect/Good/Miss가 결정된 노트의 중복 판정 차단
    // ===============================================================
    typedef enum logic {
        COMPARE,
        DONE
    } result_e;

    result_e state;

    // hit_mask[n]=1이면 해당 슬롯의 n번 레인 노트를 이미 입력했음
    // has_good=1이면 먼저 입력된 레인 중 하나 이상이 Good이었음
    logic [3:0] hit_mask;
    logic       has_good;

    // ===============================================================
    // y=0    ─┐
    //         │  above = 1        (아직 위 / 새 노트)
    // y=400  ─┤ ─────────────────
    //         │  in_zone = 1      (판정 가능)
    // y=410  ─┤   ┐
    //         │   │ in_perfect=1  (정중앙)
    // y=430  ─┤   ┘
    //         │  in_zone = 1
    // y=440  ─┤ ─────────────────
    //         │  passed = 1       (놓침)
    // y=479  ─┘
    // ===============================================================

    wire above_zone = (lcnt_y < LINE - GOOD_HALF);  // zone 위, y = 400 보다 위 
    wire in_zone    = (lcnt_y >= LINE - GOOD_HALF) && (lcnt_y <= LINE + GOOD_HALF); // 판정존 안 y = 400 ~ 440
    wire in_perfect = (lcnt_y >= LINE - PERFECT_HALF) && (lcnt_y <= LINE + PERFECT_HALF); // 정중앙, y = 410 ~ 430 
    wire passed = (lcnt_y > LINE + GOOD_HALF);  // 존 아래로 통과

    // 판정존 안에서 현재 손이 들어온 활성 레인만 새 판정 대상으로 선택
    wire lane0_new_hit = in_zone && pos_mask[0] && !hit_mask[0] && region[0];
    wire lane1_new_hit = in_zone && pos_mask[1] && !hit_mask[1] && region[1];
    wire lane2_new_hit = in_zone && pos_mask[2] && !hit_mask[2] && region[2];
    wire lane3_new_hit = in_zone && pos_mask[3] && !hit_mask[3] && region[3];

    wire [3:0] new_hit_mask = {
        lane3_new_hit,
        lane2_new_hit,
        lane1_new_hit,
        lane0_new_hit
    };

    // 이전 프레임까지 입력한 레인과 이번 프레임 입력을 합친 값
    wire [3:0] next_hit_mask = hit_mask | new_hit_mask;

    // pos_mask의 모든 활성 레인이 입력되었는지 비트별로 확인
    wire lane0_complete = !pos_mask[0] || next_hit_mask[0];
    wire lane1_complete = !pos_mask[1] || next_hit_mask[1];
    wire lane2_complete = !pos_mask[2] || next_hit_mask[2];
    wire lane3_complete = !pos_mask[3] || next_hit_mask[3];

    wire all_lanes_complete =
        (pos_mask != 4'b0000) &&
        lane0_complete && lane1_complete &&
        lane2_complete && lane3_complete;

    wire any_new_hit =
        lane0_new_hit || lane1_new_hit ||
        lane2_new_hit || lane3_new_hit;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= COMPARE;
            hit_mask <= 4'b0000;
            has_good <= 1'b0;
            {perfect, good, miss} <= 3'b000;
        end else begin
            {perfect, good, miss} <= 3'b000;  // 기본 0

            // lcnt와 카메라 입력은 frame_tick에서만 판정함
            // 출력 펄스는 위에서 매 clk마다 0으로 지우므로 한 clk만 유지됨
            if (frame_tick) begin
                case (state)
                    COMPARE: begin
                        // 이번 프레임에 새로 입력된 활성 레인을 기억함
                        if (any_new_hit) begin
                            hit_mask <= next_hit_mask;

                            // Perfect 구간 밖의 입력이 하나라도 있으면 Good 기억
                            if (!in_perfect) has_good <= 1'b1;
                        end

                        // 모든 활성 레인의 입력이 끝나면 슬롯 결과 하나를 출력함
                        // 이전 또는 현재 입력 중 Good이 하나라도 있으면 Good
                        // 모든 입력이 Perfect였을 때만 Perfect
                        if (all_lanes_complete) begin
                            if (has_good || (any_new_hit && !in_perfect))
                                good <= 1'b1;
                            else
                                perfect <= 1'b1;

                            state <= DONE;

                        // 하나 이상의 활성 레인을 입력하지 못한 채 통과하면 Miss
                        end else if (passed) begin
                            miss  <= 1'b1;
                            state <= DONE;
                        end
                    end

                    DONE: begin
                        // 판정이 끝난 노트에서는 추가 입력을 무시함
                        // Line Count가 슬롯을 새 노트 위치(400 위)로 되돌리면
                        // COMPARE로 복귀하여 다음 노트의 판정을 준비함
                        if (above_zone) begin
                            state <= COMPARE;
                            hit_mask <= 4'b0000;
                            has_good <= 1'b0;
                        end
                    end

                    default: begin
                        state <= COMPARE;
                        hit_mask <= 4'b0000;
                        has_good <= 1'b0;
                    end
                endcase
            end
        end
    end

endmodule
