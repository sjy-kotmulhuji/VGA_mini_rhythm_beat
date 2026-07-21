`timescale 1ns / 1ps

module top (
    input logic       clk,
    input logic       reset,
    input logic [2:0] btn,

    input  logic       vsync,
    output logic       xclk,
    input  logic       pclk,
    input  logic       href,
    input  logic [7:0] pdata,
    output logic       h_sync,
    output logic       v_sync,
    output logic [3:0] port_red,
    output logic [3:0] port_green,
    output logic [3:0] port_blue,
    output logic scl,
    inout  logic sda,

    output logic main_done,

    input  logic rx,
    output logic tx
);

    logic [3:0] region;
    logic [2:0] w_state;
    logic [23:0] w_score;
    // [원래 코드 백업]
    // logic [23:0] w_score;
    logic        w_perfect;
    logic        w_good;
    logic        w_miss;
    logic [9:0]  w_combo;
    logic        w_fever;

    logic w_vga_sync;
    assign v_sync = w_vga_sync;

    // [이전 원래 코드 백업]
    // logic w_v_sync;
    // assign vsync = w_v_sync;

    logic w_cam_vsync;
    assign w_cam_vsync = vsync; // 입력 vsync 값을 내부 와이어로 할당

    clk_wiz_0 instance_name (
        // Clock out ports
        .clk_out1(clk_100M),     // output clk_out1
        .clk_out2(clk_25M),     // output clk_out2
        // Status and control signals
        .reset(reset), // input reset
        // Clock in ports
        .clk_in1(clk)
    );  // input clk_in1

    MainController U_MainController (
        .clk         (clk),
        .reset       (reset),
        .rx          (rx),
        .btn_l_f     (btn[0]),
        .btn_r_f     (btn[1]),
        .btn_d_f     (btn[2]),
        .v_sync      (w_vga_sync), // 게임 프레임 처리는 VGA 60Hz 동기화 신호에 매핑 (이전 코드: .v_sync(w_v_sync))
        .region      (region),
        .capture_done(),
        .main_done   (main_done),
        .o_state     (w_state),
        .o_lane      (),
        .o_duration  (),
        .score       (w_score),
        // [원래 코드 백업]
        // .score    (w_score)
        // );
        .perfect     (w_perfect),
        .good        (w_good),
        .miss        (w_miss),
        .combo       (w_combo),
        .fever       (w_fever)
    );

    sender #(
        .CLK_FREQ (100_000_000),
        .BAUD_RATE(115_200)
    ) U_sender (
        .clk       (clk),
        .reset     (reset),
        .fifo_full (),             // full -> push 불가능
        .tx        (tx),
        .main_state(w_state),
        .btn       ({region[1], btn[2] | region[2], btn[1] | region[3], btn[0] | region[0]}),  // u, d, r, l (물리 버튼과 카메라 영역 결합, 이전 원래 코드 백업: .btn({1'b0, btn}))
        // .hit       (),
        .fever     (w_fever),
        .perfect   (w_perfect),
        .good      (w_good),
        .miss      (w_miss),
        .combo     (w_combo[7:0]),
        .score     (w_score)

        // input logic [11:0] capture_data[0:8799],
        // input logic        done_cap
    );

    VGAcam U_VGAcam (
        .clk_100M  (clk_100M),
        .clk_25M   (clk_25M),
        .reset     (reset),
        .xclk      (xclk),
        .pclk      (pclk),
        .href      (href),
        .vsync     (w_cam_vsync),  // 카메라 vsync 입력 전달 (이전 코드: .vsync(w_v_sync))
        .pdata     (pdata),
        .h_sync    (h_sync),
        .v_sync    (w_vga_sync),   // VGA v_sync 출력 (이전 코드: .v_sync(v_sync))
        .port_red  (port_red),
        .port_green(port_green),
        .port_blue (port_blue),
        .region    (region),
        .scl       (scl),
        .sda       (sda)
    );
endmodule
