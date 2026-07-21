`timescale 1ns / 1ps

module framePrinter(
    input  logic        clk,
    input  logic        reset,
    input  logic        vsync,
    input  logic [9:0]  x_pixel,
    input  logic [9:0]  y_pixel,
    input  logic [15:0] imgPxlData,
    output logic [$clog2(320*240)-1:0] imgPxlAddr,

    // frame print
    input  logic [3:0]  note_x0,
    input  logic [3:0]  note_x1,
    input  logic [3:0]  note_x2,
    input  logic [3:0]  note_x3,
    input  logic [9:0]  note_y0,
    input  logic [9:0]  note_y1,
    input  logic [9:0]  note_y2,
    input  logic [9:0]  note_y3,

    // region detector
    output logic [3:0]  region,

    output logic [11:0]  RGBport
);

    RegionDetector U_Region_Detector(
        .clk(clk),
        .reset(reset),
        .vsync(vsync),
        .x_pixel_VGA(x_pixel),
        .y_pixel_VGA(y_pixel),
        .frame_data(imgPxlData),
        .region(region)
    );

    frameController U_Frame_Controller(
        .note_x0(note_x0),
        .note_x1(note_x1),
        .note_x2(note_x2),
        .note_x3(note_x3),
        .note_y0(note_y0),
        .note_y1(note_y1),
        .note_y2(note_y2),
        .note_y3(note_y3),
        .x_pixel_VGA(x_pixel),
        .y_pixel_VGA(y_pixel),
        .region(region),
        .imgPxlData(imgPxlData),
        .imgPxlAddr(imgPxlAddr),
        .RGBport(RGBport)
    );
endmodule
