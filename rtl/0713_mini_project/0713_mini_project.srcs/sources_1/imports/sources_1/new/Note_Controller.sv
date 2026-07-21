`timescale 1ns / 1ps

module Note_Controller (
    input  logic        clk,
    input  logic        reset,
    input  logic        v_sync,
    input  logic        rx_done,
    input  logic [ 7:0] rx_data,
    input  logic [ 2:0] main_state,
    output logic [ 3:0] o_lane,
    output logic [11:0] o_duration,
    output logic        note_done,
    output logic        game_done
);

    // Note trigger and game over decoding logic from PC UART
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            o_lane     <= 4'b0000;
            o_duration <= 12'd0;
            note_done  <= 1'b0;
            game_done  <= 1'b0;
        end else begin
            note_done  <= 1'b0;
            game_done  <= 1'b0;
            o_lane     <= 4'b0000;
            o_duration <= 12'd0;

            if (main_state == 3'b011) begin // PLAYING state (GAME_CONT)
                if (rx_done) begin
                    if (rx_data[7:4] == 4'h8) begin // Note spawn command (e.g. 0x81, 0x82, 0x84, 0x88)
                        note_done  <= 1'b1;
                        o_lane     <= rx_data[3:0];
                        o_duration <= 12'd0; // Default single hit note duration
                    end else if (rx_data == 8'h90) begin // Game over command from PC
                        game_done  <= 1'b1;
                    end
                end
            end
        end
    end

endmodule
