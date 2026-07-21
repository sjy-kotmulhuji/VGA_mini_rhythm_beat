`timescale 1ns / 1ps

module Note_Controller (
    input  logic        clk,
    input  logic        reset,
    input  logic        v_sync,
    input  logic [31:0] note_data,
    input  logic [ 2:0] main_state,
    output logic [11:0] o_duration,
    output logic        game_done
);

    logic [15:0] frame_cnt;
    logic [15:0] delay_cnt;
    logic v_sync_1, v_sync_2, v_sync_edge;

    // [수정 이력 백업]
    // 이전에 적용했던 10us 단위 모듈 내부 글리치 필터는 top_module.sv의 공용 필터(v_sync_clean)로
    // 통합·이전되어 본 모듈 내부 필터 로직은 안전하게 원복되었습니다.

    //v_sync falling edge detection
    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            v_sync_1 <= 0;
            v_sync_2 <= 0;
        end else begin
            v_sync_1 <= v_sync;
            v_sync_2 <= v_sync_1;
        end
    end

    assign v_sync_edge = ((v_sync_2 == 1) && (v_sync_1 == 0)) ? 1 : 0;

    //frame counter(v_sync 신호 사용)
    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            frame_cnt  <= 0;
            delay_cnt  <= 0;
            o_lane     <= 0;
            o_duration <= 0;
            game_done  <= 0;
        end else begin
            game_done <= 0;  //game_done 한 클럭만 유지 이렇게 하면 되나??
            note_done <= 0;
            o_lane <= 0;
            o_duration <= 0;
            if (main_state == 3'b011) begin  //GAME_CONT 상태일 때만
                if (v_sync_edge) begin  //frame 단위 기준. v_sync edge detection 해야 함
                    if (note_data[31:16] == 16'hFFFF) begin
                        if (delay_cnt == note_data[15:0] - 1) begin
                            delay_cnt <= 0;
                            frame_cnt <= 0; //game 끝날 때 frame_cnt도 초기화
                            game_done <= 1; //이거는 언제 0으로 돌려야 하지??
                        end else begin
                            delay_cnt <= delay_cnt + 1;
                        end
                    end else begin
                        if(frame_cnt == note_data[31:16]) begin     //frame cnt와 rom time data가 같을 때 노트 발생
                            note_done  <= 1;
                            o_lane     <= note_data[3:0];
                            o_duration <= note_data[15:4];
                        end
                        frame_cnt <= frame_cnt + 1;
                    end
                end
            end
        end
    end

    //o_lane, o_duration 출력 로직
    //assign o_lane     = note_done ? note_data[3:0] : '0;
    //assign o_duration = note_done ? note_data[15:4] : '0;
    //단일 노트의 경우 duration이 동일하게 0인데 어떻게 처리? 어차피 lane data가 0이면 상관없나?

    //game_done 로직 설계, done 시 frame_cnt 멈추기 OK

    //frame counter 값과 rom time data가 같으면 lane, duration 데이터 출력 OK
    //동시에 note_done 신호 tick 발생시킴 OK



endmodule
