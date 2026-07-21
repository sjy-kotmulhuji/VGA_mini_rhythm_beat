module frameController (
    input logic [3:0] note_x0,
    input logic [3:0] note_x1,
    input logic [3:0] note_x2,
    input logic [3:0] note_x3,
    input logic [9:0] note_y0,
    input logic [9:0] note_y1,
    input logic [9:0] note_y2,
    input logic [9:0] note_y3,
    input logic [9:0] x_pixel_VGA,
    input logic [9:0] y_pixel_VGA,
    input logic [3:0] region,
    input logic [15:0] imgPxlData,
    output logic [$clog2(320*240)-1:0] imgPxlAddr,
    output logic [11:0] RGBport
);

    logic [11:0] RGB_region;
    logic [11:0] RGB_note;
    logic [11:0] RGB_game;
    logic done_cap;

    // frame upscale -VGA: 640 * 320
    logic [9:0] x_pixel, y_pixel;
    assign x_pixel = x_pixel_VGA >> 1;
    assign y_pixel = y_pixel_VGA >> 1;
    assign imgPxlAddr = 320 * (y_pixel) + (319 - (x_pixel));


    Filter_Region U_Filter_REG (
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .region(region),
        .imgPxlData(imgPxlData),
        .imgPxlAddr(imgPxlAddr),
        .o_rgb(RGB_region)
    );
    Filter_NOTE U_Filter_NOTE (
        .note_x0(note_x0),
        .note_x1(note_x1),
        .note_x2(note_x2),
        .note_x3(note_x3),
        .note_y0(note_y0),
        .note_y1(note_y1),
        .note_y2(note_y2),
        .note_y3(note_y3),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .i_rgb  (RGB_region),
        .o_rgb  (RGB_note)
    );
    Filter_GAME U_Filter_GAME (
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .i_rgb  (RGB_note),
        .o_rgb  (RGBport)
    );
endmodule


module mux_2x1 #(
    parameter BIT_DEPTH = 16
) (
    input  logic                 sel,
    input  logic [BIT_DEPTH-1:0] in0,
    input  logic [BIT_DEPTH-1:0] in1,
    output logic [BIT_DEPTH-1:0] out
);
    assign out = sel ? in0 : in1;
endmodule


module Filter_Region (
    input logic [9:0] x_pixel,
    input logic [9:0] y_pixel,
    input logic [3:0] region,
    input logic [15:0] imgPxlData,
    output logic [$clog2(320*240)-1:0] imgPxlAddr,
    output logic [11:0] o_rgb
);
    // frame upscale -VGA: 640 * 320
    logic vgaArea;
    assign vgaArea = (x_pixel < 640) && (y_pixel < 480);

    always_comb begin
        if (vgaArea) begin
            case (region)
                4'b0001:
                if ((x_pixel >= 0) && (x_pixel < 80))
                    o_rgb = {
                        imgPxlData[15:12],
                        {1'b0, imgPxlData[10:8]},
                        {1'b0, imgPxlData[4:2]}
                    };
                else
                    o_rgb = {
                        imgPxlData[15:12], imgPxlData[10:7], imgPxlData[4:1]
                    };
                4'b0010:
                if ((x_pixel >= 80) && (x_pixel < 160))
                    o_rgb = {
                        imgPxlData[15:12],
                        {1'b0, imgPxlData[10:8]},
                        {1'b0, imgPxlData[4:2]}
                    };
                else
                    o_rgb = {
                        imgPxlData[15:12], imgPxlData[10:7], imgPxlData[4:1]
                    };
                4'b0100:
                if ((x_pixel >= 160) && (x_pixel < 240))
                    o_rgb = {
                        imgPxlData[15:12],
                        {1'b0, imgPxlData[10:8]},
                        {1'b0, imgPxlData[4:2]}
                    };
                else
                    o_rgb = {
                        imgPxlData[15:12], imgPxlData[10:7], imgPxlData[4:1]
                    };
                4'b1000:
                if ((x_pixel >= 240) && (x_pixel < 320))
                    o_rgb = {
                        imgPxlData[15:12],
                        {1'b0, imgPxlData[10:8]},
                        {1'b0, imgPxlData[4:2]}
                    };
                else
                    o_rgb = {
                        imgPxlData[15:12], imgPxlData[10:7], imgPxlData[4:1]
                    };
                4'b0011:
                if ((x_pixel >= 0) && (x_pixel < 80))
                    o_rgb = {
                        imgPxlData[15:12],
                        {1'b0, imgPxlData[10:8]},
                        {1'b0, imgPxlData[4:2]}
                    };
                else if ((x_pixel >= 80) && (x_pixel < 160))
                    o_rgb = {
                        imgPxlData[15:12],
                        {1'b0, imgPxlData[10:8]},
                        {1'b0, imgPxlData[4:2]}
                    };
                else
                    o_rgb = {
                        imgPxlData[15:12], imgPxlData[10:7], imgPxlData[4:1]
                    };
                4'b0101:
                if ((x_pixel >= 0) && (x_pixel < 80))
                    o_rgb = {
                        imgPxlData[15:12],
                        {1'b0, imgPxlData[10:8]},
                        {1'b0, imgPxlData[4:2]}
                    };
                else if ((x_pixel >= 160) && (x_pixel < 240))
                    o_rgb = {
                        imgPxlData[15:12],
                        {1'b0, imgPxlData[10:8]},
                        {1'b0, imgPxlData[4:2]}
                    };
                else
                    o_rgb = {
                        imgPxlData[15:12], imgPxlData[10:7], imgPxlData[4:1]
                    };
                4'b1001:
                if ((x_pixel >= 0) && (x_pixel < 80))
                    o_rgb = {
                        imgPxlData[15:12],
                        {1'b0, imgPxlData[10:8]},
                        {1'b0, imgPxlData[4:2]}
                    };
                else if ((x_pixel >= 240) && (x_pixel < 320))
                    o_rgb = {
                        imgPxlData[15:12],
                        {1'b0, imgPxlData[10:8]},
                        {1'b0, imgPxlData[4:2]}
                    };
                else
                    o_rgb = {
                        imgPxlData[15:12], imgPxlData[10:7], imgPxlData[4:1]
                    };
                4'b0110:
                if ((x_pixel >= 80) && (x_pixel < 160))
                    o_rgb = {
                        imgPxlData[15:12],
                        {1'b0, imgPxlData[10:8]},
                        {1'b0, imgPxlData[4:2]}
                    };
                else if ((x_pixel >= 160) && (x_pixel < 240))
                    o_rgb = {
                        imgPxlData[15:12],
                        {1'b0, imgPxlData[10:8]},
                        {1'b0, imgPxlData[4:2]}
                    };
                else
                    o_rgb = {
                        imgPxlData[15:12], imgPxlData[10:7], imgPxlData[4:1]
                    };
                4'b1010:
                if ((x_pixel >= 80) && (x_pixel < 160))
                    o_rgb = {
                        imgPxlData[15:12],
                        {1'b0, imgPxlData[10:8]},
                        {1'b0, imgPxlData[4:2]}
                    };
                else if ((x_pixel >= 240) && (x_pixel < 320))
                    o_rgb = {
                        imgPxlData[15:12],
                        {1'b0, imgPxlData[10:8]},
                        {1'b0, imgPxlData[4:2]}
                    };
                else
                    o_rgb = {
                        imgPxlData[15:12], imgPxlData[10:7], imgPxlData[4:1]
                    };
                4'b1100:
                if ((x_pixel >= 160) && (x_pixel < 240))
                    o_rgb = {
                        imgPxlData[15:12],
                        {1'b0, imgPxlData[10:8]},
                        {1'b0, imgPxlData[4:2]}
                    };
                else if ((x_pixel >= 240) && (x_pixel < 320))
                    o_rgb = {
                        imgPxlData[15:12],
                        {1'b0, imgPxlData[10:8]},
                        {1'b0, imgPxlData[4:2]}
                    };
                else
                    o_rgb = {
                        imgPxlData[15:12], imgPxlData[10:7], imgPxlData[4:1]
                    };
                4'b0111:
                if ((x_pixel >= 0) && (x_pixel < 80))
                    o_rgb = {
                        imgPxlData[15:12],
                        {1'b0, imgPxlData[10:8]},
                        {1'b0, imgPxlData[4:2]}
                    };
                else if ((x_pixel >= 80) && (x_pixel < 160))
                    o_rgb = {
                        imgPxlData[15:12],
                        {1'b0, imgPxlData[10:8]},
                        {1'b0, imgPxlData[4:2]}
                    };
                else if ((x_pixel >= 160) && (x_pixel < 240))
                    o_rgb = {
                        imgPxlData[15:12],
                        {1'b0, imgPxlData[10:8]},
                        {1'b0, imgPxlData[4:2]}
                    };
                else
                    o_rgb = {
                        imgPxlData[15:12], imgPxlData[10:7], imgPxlData[4:1]
                    };
                4'b1011:
                if ((x_pixel >= 0) && (x_pixel < 80))
                    o_rgb = {
                        imgPxlData[15:12],
                        {1'b0, imgPxlData[10:8]},
                        {1'b0, imgPxlData[4:2]}
                    };
                else if ((x_pixel >= 80) && (x_pixel < 160))
                    o_rgb = {
                        imgPxlData[15:12],
                        {1'b0, imgPxlData[10:8]},
                        {1'b0, imgPxlData[4:2]}
                    };
                else if ((x_pixel >= 240) && (x_pixel < 320))
                    o_rgb = {
                        imgPxlData[15:12],
                        {1'b0, imgPxlData[10:8]},
                        {1'b0, imgPxlData[4:2]}
                    };
                else
                    o_rgb = {
                        imgPxlData[15:12], imgPxlData[10:7], imgPxlData[4:1]
                    };
                4'b1101:
                if ((x_pixel >= 0) && (x_pixel < 80))
                    o_rgb = {
                        imgPxlData[15:12],
                        {1'b0, imgPxlData[10:8]},
                        {1'b0, imgPxlData[4:2]}
                    };
                else if ((x_pixel >= 160) && (x_pixel < 240))
                    o_rgb = {
                        imgPxlData[15:12],
                        {1'b0, imgPxlData[10:8]},
                        {1'b0, imgPxlData[4:2]}
                    };
                else if ((x_pixel >= 240) && (x_pixel < 320))
                    o_rgb = {
                        imgPxlData[15:12],
                        {1'b0, imgPxlData[10:8]},
                        {1'b0, imgPxlData[4:2]}
                    };
                else
                    o_rgb = {
                        imgPxlData[15:12], imgPxlData[10:7], imgPxlData[4:1]
                    };
                4'b1110:
                if ((x_pixel >= 80) && (x_pixel < 160))
                    o_rgb = {
                        imgPxlData[15:12],
                        {1'b0, imgPxlData[10:8]},
                        {1'b0, imgPxlData[4:2]}
                    };
                else if ((x_pixel >= 160) && (x_pixel < 240))
                    o_rgb = {
                        imgPxlData[15:12],
                        {1'b0, imgPxlData[10:8]},
                        {1'b0, imgPxlData[4:2]}
                    };
                else if ((x_pixel >= 240) && (x_pixel < 320))
                    o_rgb = {
                        imgPxlData[15:12],
                        {1'b0, imgPxlData[10:8]},
                        {1'b0, imgPxlData[4:2]}
                    };
                else
                    o_rgb = {
                        imgPxlData[15:12], imgPxlData[10:7], imgPxlData[4:1]
                    };
                4'b1111:
                o_rgb = {
                    imgPxlData[15:12],
                    {1'b0, imgPxlData[10:8]},
                    {1'b0, imgPxlData[4:2]}
                };
                4'b0000:
                o_rgb = {imgPxlData[15:12], imgPxlData[10:7], imgPxlData[4:1]};
            endcase
        end else begin
            o_rgb = 0;
        end
    end
endmodule


module Filter_NOTE (
    input  logic [ 3:0] note_x0,
    input  logic [ 3:0] note_x1,
    input  logic [ 3:0] note_x2,
    input  logic [ 3:0] note_x3,
    input  logic [ 9:0] note_y0,
    input  logic [ 9:0] note_y1,
    input  logic [ 9:0] note_y2,
    input  logic [ 9:0] note_y3,
    input  logic [ 9:0] x_pixel,
    input  logic [ 9:0] y_pixel,
    input  logic [11:0] i_rgb,
    output logic [11:0] o_rgb
);

    logic disp;
    logic y0_disp, y1_disp, y2_disp, y3_disp;

    assign y0_disp = (note_y0 > 1) ? ((y_pixel >= note_y0 - 2) && (y_pixel < note_y0 + 2)) : (note_y0 && (y_pixel < 2));
    assign y1_disp = (note_y1 > 1) ? ((y_pixel >= note_y1 - 2) && (y_pixel < note_y1 + 2)) : (note_y1 && (y_pixel < 2));
    assign y2_disp = (note_y2 > 1) ? ((y_pixel >= note_y2 - 2) && (y_pixel < note_y2 + 2)) : (note_y2 && (y_pixel < 2));
    assign y3_disp = (note_y3 > 1) ? ((y_pixel >= note_y3 - 2) && (y_pixel < note_y3 + 2)) : (note_y3 && (y_pixel < 2));

    always_comb begin
        disp = 1'b0;

        if (note_y0 && y0_disp) begin
            if (note_x0[0] && (x_pixel >= 20 && x_pixel < 60)) disp = 1'b1;
            if (note_x0[1] && (x_pixel >= 100 && x_pixel < 140)) disp = 1'b1;
            if (note_x0[2] && (x_pixel >= 180 && x_pixel < 220)) disp = 1'b1;
            if (note_x0[3] && (x_pixel >= 260 && x_pixel < 300)) disp = 1'b1;
        end
        if (note_y1 && y1_disp) begin
            if (note_x1[0] && (x_pixel >= 20 && x_pixel < 60)) disp = 1'b1;
            if (note_x1[1] && (x_pixel >= 100 && x_pixel < 140)) disp = 1'b1;
            if (note_x1[2] && (x_pixel >= 180 && x_pixel < 220)) disp = 1'b1;
            if (note_x1[3] && (x_pixel >= 260 && x_pixel < 300)) disp = 1'b1;
        end
        if (note_y2 && y2_disp) begin
            if (note_x2[0] && (x_pixel >= 20 && x_pixel < 60)) disp = 1'b1;
            if (note_x2[1] && (x_pixel >= 100 && x_pixel < 140)) disp = 1'b1;
            if (note_x2[2] && (x_pixel >= 180 && x_pixel < 220)) disp = 1'b1;
            if (note_x2[3] && (x_pixel >= 260 && x_pixel < 300)) disp = 1'b1;
        end
        if (note_y3 && y3_disp) begin
            if (note_x3[0] && (x_pixel >= 20 && x_pixel < 60)) disp = 1'b1;
            if (note_x3[1] && (x_pixel >= 100 && x_pixel < 140)) disp = 1'b1;
            if (note_x3[2] && (x_pixel >= 180 && x_pixel < 220)) disp = 1'b1;
            if (note_x3[3] && (x_pixel >= 260 && x_pixel < 300)) disp = 1'b1;
        end

        if (disp) o_rgb = 12'hfff;
        else o_rgb = i_rgb;
    end
endmodule


module Filter_GAME (
    input  logic [ 9:0] x_pixel,
    input  logic [ 9:0] y_pixel,
    input  logic [11:0] i_rgb,
    output logic [11:0] o_rgb
);
    always_comb begin
        // seperate region
        if ((x_pixel >= 79) && (x_pixel < 81)) o_rgb = 0;
        else if ((x_pixel >= 159) && (x_pixel < 161)) o_rgb = 0;
        else if ((x_pixel >= 239) && (x_pixel < 241)) o_rgb = 0;
        // detecting area
        else if ((y_pixel >= 200) && (y_pixel < 220))
            o_rgb = {2'b00, i_rgb[11:10], 2'b00, i_rgb[7:6], 2'b00, i_rgb[3:2]};
        else o_rgb = i_rgb;
    end
endmodule
