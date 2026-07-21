`timescale 1ns / 1ps

module line_count(

    input           clk,
    input           reset,

    // ram output
    input           i_note,
    input   [03:00] i_lane,
    input           i_vs,
        
    // game output
    output  [03:00] o_pos0, 
    output  [09:00] o_lcnt0,
    output  [03:00] o_pos1,
    output  [09:00] o_lcnt1,
    output  [03:00] o_pos2,
    output  [09:00] o_lcnt2,
    output  [03:00] o_pos3,
    output  [09:00] o_lcnt3

);


    //parameter [07:00] FRAME_NUM = 179;
    //parameter [06:00] LINE_VALUE = 480 / FRAME_NUM;
    //parameter [06:00] LINE_VALUE = 63;
    parameter [1:0] LINE_VALUE = 3;

    reg [01:00] cnt;

    reg [03:00] r_pos0;
    reg [03:00] r_pos1;
    reg [03:00] r_pos2;
    reg [03:00] r_pos3;

    reg [09:00] r_lcnt0;
    reg [09:00] r_lcnt1;
    reg [09:00] r_lcnt2;
    reg [09:00] r_lcnt3;

    reg         r_en0;
    reg         r_en1;
    reg         r_en2;
    reg         r_en3;

    reg [09:00] r_frame_cnt0;
    reg [09:00] r_frame_cnt1;
    reg [09:00] r_frame_cnt2;
    reg [09:00] r_frame_cnt3;

    reg         r_vs_dly0;
    
    wire        w_vs_dly0_f;


    assign o_pos0   =   r_pos0 ;
    assign o_lcnt0  =   r_lcnt0;
    assign o_pos1   =   r_pos1 ;
    assign o_lcnt1  =   r_lcnt1;
    assign o_pos2   =   r_pos2 ;
    assign o_lcnt2  =   r_lcnt2;
    assign o_pos3   =   r_pos3 ;
    assign o_lcnt3  =   r_lcnt3;
    

    
    always @ (posedge clk or posedge reset) begin
        if(reset) begin
            r_vs_dly0 <= 0;
        end
        else begin
            r_vs_dly0 <= i_vs;
        end
    end


    assign w_vs_dly0_r =  i_vs && ~r_vs_dly0;
    assign w_vs_dly0_f = ~i_vs &&  r_vs_dly0; 


    always @ (posedge clk or posedge reset) begin
        if(reset) begin
            cnt <= 0;
        end
        else if(i_note) begin
            cnt <= cnt + 1'b1;
        end
        else begin
            cnt <= cnt;
        end
    end

    always @ (posedge clk or posedge reset) begin
        if(reset) begin
            r_pos0 <= 0;
        end
        else if(cnt == 0 && i_note) begin
            r_pos0 <= i_lane;
        end
        else begin
            r_pos0 <= r_pos0;
        end
    end

    always @ (posedge clk or posedge reset) begin
        if(reset) begin
            r_pos1 <= 0;
        end
        else if(cnt == 1 && i_note) begin
            r_pos1 <= i_lane;
        end
        else begin
            r_pos1 <= r_pos1;
        end
    end  

    always @ (posedge clk or posedge reset) begin
        if(reset) begin
            r_pos2 <= 0;
        end
        else if(cnt == 2 && i_note) begin
            r_pos2 <= i_lane;
        end
        else begin
            r_pos2 <= r_pos2;
        end
    end  

    always @ (posedge clk or posedge reset) begin
        if(reset) begin
            r_pos3 <= 0;
        end
        else if(cnt == 3 && i_note) begin
            r_pos3 <= i_lane;
        end
        else begin
            r_pos3 <= r_pos3;
        end
    end  
    
    always @ (posedge clk or posedge reset) begin
        if(reset) begin
            r_en0 <= 0;
        end
        else if(r_lcnt0 >= 480) begin
            r_en0 <= 0;
        end
        else if(cnt == 0 && i_note) begin
            r_en0 <= 1;
        end
        else begin
            r_en0 <= r_en0;
        end
    end

    always @ (posedge clk or posedge reset) begin
        if(reset) begin
            r_en1 <= 0;
        end
        else if(r_lcnt1 >= 480) begin
            r_en1 <= 0;
        end
        else if(cnt == 1 && i_note) begin
            r_en1 <= 1;
        end
        else begin
            r_en1 <= r_en1;
        end
    end

    always @ (posedge clk or posedge reset) begin
        if(reset) begin
            r_en2 <= 0;
        end
        else if(r_lcnt2 >= 480) begin
            r_en2 <= 0;
        end
        else if(cnt == 2 && i_note) begin
            r_en2 <= 1;
        end
        else begin
            r_en2 <= r_en2;
        end
    end

    always @ (posedge clk or posedge reset) begin
        if(reset) begin
            r_en3 <= 0;
        end
        else if(r_lcnt3 >= 480) begin
            r_en3 <= 0;
        end
        else if(cnt == 3 && i_note) begin
            r_en3 <= 1;
        end
        else begin
            r_en3 <= r_en3;
        end
    end
    
    always @ (posedge clk or posedge reset) begin
        if(reset) begin
            r_lcnt0 <= 0;
        end
        else if(!r_en0) begin           //  !r_en OR r_lcnt0 >= 480 
            r_lcnt0 <= 0;
        end
        else if(r_en0 && w_vs_dly0_f) begin
            r_lcnt0 <= r_lcnt0 + LINE_VALUE;
        end
        else begin
            r_lcnt0 <= r_lcnt0;
        end
    end

    always @ (posedge clk or posedge reset) begin
        if(reset) begin
            r_lcnt1 <= 0;
        end
        else if(!r_en1) begin           //  !r_en OR r_lcnt1 >= 480 
            r_lcnt1 <= 0;
        end
        else if(r_en1 && w_vs_dly0_f) begin
            r_lcnt1 <= r_lcnt1 + LINE_VALUE;
        end
        else begin
            r_lcnt1 <= r_lcnt1;
        end
    end

    always @ (posedge clk or posedge reset) begin
        if(reset) begin
            r_lcnt2 <= 0;
        end
        else if(!r_en2) begin           //  !r_en OR r_lcnt2 >= 480 
            r_lcnt2 <= 0;
        end
        else if(r_en2 && w_vs_dly0_f) begin
            r_lcnt2 <= r_lcnt2 + LINE_VALUE;
        end
        else begin
            r_lcnt2 <= r_lcnt2;
        end
    end

    always @ (posedge clk or posedge reset) begin
        if(reset) begin
            r_lcnt3 <= 0;
        end
        else if(!r_en3) begin           //  !r_en OR r_lcnt3 >= 480 
            r_lcnt3 <= 0;
        end
        else if(r_en3 && w_vs_dly0_f) begin
            r_lcnt3 <= r_lcnt3 + LINE_VALUE;
        end
        else begin
            r_lcnt3 <= r_lcnt3;
        end
    end




endmodule