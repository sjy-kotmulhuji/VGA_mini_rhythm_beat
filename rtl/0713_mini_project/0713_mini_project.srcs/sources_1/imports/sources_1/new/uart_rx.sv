`timescale 1ns / 1ps

module uart_rx #(
    parameter CLK_FREQ = 100_000_000,
    parameter BAUD_RATE = 115_200
)(
    input  logic       clk,
    input  logic       reset,
    input  logic       rx,
    output logic       rx_done,
    output logic [7:0] rx_data
);

    localparam int CLOCKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    typedef enum logic [1:0] {
        IDLE  = 2'b00,
        START = 2'b01,
        DATA  = 2'b10,
        STOP  = 2'b11
    } state_t;

    state_t state;
    logic [15:0] clk_cnt;
    logic [2:0]  bit_idx;
    logic [7:0]  rx_byte;
    logic        rx_sync_0, rx_sync_1;

    // Double registers to prevent metastability
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            rx_sync_0 <= 1'b1;
            rx_sync_1 <= 1'b1;
        end else begin
            rx_sync_0 <= rx;
            rx_sync_1 <= rx_sync_0;
        end
    end

    // UART Receiver State Machine
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state   <= IDLE;
            clk_cnt <= 0;
            bit_idx <= 0;
            rx_byte <= 8'h00;
            rx_done <= 1'b0;
            rx_data <= 8'h00;
        end else begin
            rx_done <= 1'b0;

            case (state)
                IDLE: begin
                    clk_cnt <= 0;
                    bit_idx <= 0;
                    if (rx_sync_1 == 1'b0) begin // Start bit detected (falling edge)
                        state <= START;
                    end
                end

                START: begin
                    // Sample at the middle of the start bit to confirm validity
                    if (clk_cnt == (CLOCKS_PER_BIT / 2) - 1) begin
                        if (rx_sync_1 == 1'b0) begin
                            clk_cnt <= 0;
                            state   <= DATA;
                        end else begin
                            state   <= IDLE; // False start
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end

                DATA: begin
                    // Sample at the middle of each data bit
                    if (clk_cnt == CLOCKS_PER_BIT - 1) begin
                        clk_cnt <= 0;
                        rx_byte[bit_idx] <= rx_sync_1;
                        if (bit_idx == 7) begin
                            state <= STOP;
                        end else begin
                            bit_idx <= bit_idx + 1;
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end

                STOP: begin
                    // Wait for the stop bit duration
                    if (clk_cnt == CLOCKS_PER_BIT - 1) begin
                        clk_cnt <= 0;
                        if (rx_sync_1 == 1'b1) begin // Valid stop bit
                            rx_done <= 1'b1;
                            rx_data <= rx_byte;
                        end
                        state <= IDLE;
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
