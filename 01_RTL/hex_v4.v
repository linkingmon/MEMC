`include "coordinate.v"
module hex(
    clk,
    rst_n,
    mv,
    mv_valid,
    mv_addr,

    cur_frame,
    block_addr, // 6 + 6
    block_size, // 4 + 4
    
    pixel_ready,
    pixel_valid,
    pixel,

    frame_done,
    block_done,

    block_ready,
    block_valid,
    block_pixel
);

/////////////////////////////////////////// IO port ////////////////////////////////////////////
// conenction of top module
input clk;
input rst_n;
output [7:0] mv;
output mv_valid;
output [5:0] mv_addr;

// conenction with sram_ctrl
output cur_frame;
output [11:0] block_addr; // 6 + 6
output [7:0] block_size; // 4 + 4
output pixel_ready;
input pixel_valid;
input [7:0] pixel;

// output pixel of padding frame
input block_ready;
output block_valid;
output [7:0] block_pixel;

// connection with process_ctrl
output reg frame_done;
output reg block_done;

//////////////////////////////////////// Reg & Wire ////////////////////////////////////////////
// state
reg [3:0] state_r, state_w;

//
reg cur_frame_r, cur_frame_w;

// center coordinate ; forms the motion vector
reg signed [3:0] row_offset_w, col_offset_w, row_offset_r, col_offset_r;

// current block coordinate ; forms the mv_addr
reg [2:0] mv_addr_row_w, mv_addr_col_w, mv_addr_row_r, mv_addr_col_r;

// block address and block size ; request rect from sram_ctrl
wire [5:0] block_addr_row_r, block_addr_col_r; 
wire [3:0] pixel_counter_row_max_r, pixel_counter_col_max_r; // also used as max of pixel counter in many state

// current & search block register
reg [7:0] cur_block_r [7:0][7:0], cur_block_w [7:0][7:0]; 
reg [7:0] search_block_r [11:0][11:0], search_block_w [11:0][11:0]; 
reg [7:0] search_block_pad_r [11:0][3:0], search_block_pad_w [11:0][3:0];

// specify if ready for getting pixel
reg pixel_ready_r, pixel_ready_w;

// pixel counter
reg [3:0] pixel_counter_row_r, pixel_counter_col_r, pixel_counter_row_w, pixel_counter_col_w;
reg [3:0] pixel_counter_row_r2, pixel_counter_col_r2, pixel_counter_row_w2, pixel_counter_col_w2;

// specify the coordinate to pad in search block register
wire [3:0] pad_offset_row_r, pad_offset_col_r;

// max value register
reg [13:0] center_max_r, point1_max_r, point2_max_r, point3_max_r, point4_max_r, point5_max_r, point6_max_r; 
reg [13:0] center_max_w, point1_max_w, point2_max_w, point3_max_w, point4_max_w, point5_max_w, point6_max_w; 
reg [13:0] center_max_half1_r, point1_max_half1_r, point2_max_half1_r, point3_max_half1_r, point4_max_half1_r, point5_max_half1_r, point6_max_half1_r; 
reg [13:0] center_max_half1_w, point1_max_half1_w, point2_max_half1_w, point3_max_half1_w, point4_max_half1_w, point5_max_half1_w, point6_max_half1_w; 
reg [13:0] center_max_half2_r, point1_max_half2_r, point2_max_half2_r, point3_max_half2_r, point4_max_half2_r, point5_max_half2_r, point6_max_half2_r; 
reg [13:0] center_max_half2_w, point1_max_half2_w, point2_max_half2_w, point3_max_half2_w, point4_max_half2_w, point5_max_half2_w, point6_max_half2_w; 

// calulate minimum
reg [13:0] current_min_value_r, current_min_value_w;
reg [2:0] current_min_idx_r, current_min_idx_w;
reg [2:0] counter_min_r, counter_min_w;

// output block pixel
reg block_valid_r, block_valid_w;

// iteration count
reg [1:0] iter_count_r, iter_count_w;

// reg [7:0] block_pixel_w, block_pixel_r;
reg [7:0] block_pixel_w;

integer i, j, k;

//////////////////////////////////////// Parameters ////////////////////////////////////////////
localparam INIT_READ_CUR = 4'd0;
localparam INIT_READ_PREV = 4'd1;
localparam CAL_HEX = 4'd2;
localparam FIND_MIN_AND_UPDATE = 4'd3;
localparam READ_NEW_BLOCK1 = 4'd4;
localparam READ_NEW_BLOCK2 = 4'd5;
localparam PAD_BLOCK = 4'd6;
localparam SMALL_HEX_FIND_MIN = 4'd7;
localparam OUTPUT = 4'd8;
localparam WRITE_DATA = 4'd9;
localparam UPDATE_BLOCK = 4'd10;
localparam CAL_HEX_CAL = 4'd11;


// wire no_up, no_right, no_left, no_down;

//////////////////////////////////////// Instances ////////////////////////////////////////////
coordinate coordinate_0(
    .clk(clk),
    .rst_n(rst_n),
    .state_r(state_r),
    .mv_addr_row_r(mv_addr_row_r),
    .mv_addr_col_r(mv_addr_col_r),
    .col_offset_r(col_offset_r),
    .row_offset_r(row_offset_r),
    .counter_min_r(current_min_idx_r),
    // output
    .block_addr_row_r(block_addr_row_r),
    .block_addr_col_r(block_addr_col_r),
    .pixel_counter_row_max_r(pixel_counter_row_max_r),
    .pixel_counter_col_max_r(pixel_counter_col_max_r),
    .pad_offset_row_r(pad_offset_row_r),
    .pad_offset_col_r(pad_offset_col_r)
);

//////////////////////////////////// Output Assignment ////////////////////////////////////////
assign block_valid = block_valid_r;
assign pixel_ready = pixel_ready_r;
assign mv_addr = {mv_addr_row_r, mv_addr_col_r};
assign block_size = {pixel_counter_row_max_r, pixel_counter_col_max_r};
assign block_addr = {block_addr_row_r, block_addr_col_r};
assign mv = {row_offset_r, col_offset_r};
assign mv_valid = (state_r == OUTPUT) ? 1'd1 : 1'd0;
assign cur_frame = cur_frame_r;
assign block_pixel = block_pixel_w;
// assign block_pixel = block_pixel_r;

// calculate abs
reg [7:0] pixel_abs_0_w [7:0], pixel_abs_1_w [7:0], pixel_abs_2_w [7:0], pixel_abs_3_w [7:0], pixel_abs_4_w [7:0], pixel_abs_5_w [7:0], pixel_abs_6_w [7:0];
reg [7:0] pixel_abs_0_r [7:0], pixel_abs_1_r [7:0], pixel_abs_2_r [7:0], pixel_abs_3_r [7:0], pixel_abs_4_r [7:0], pixel_abs_5_r [7:0], pixel_abs_6_r [7:0];
reg [7:0] pixel_cur_w [7:0];
reg [7:0] pixel_prev_0_w [7:0], pixel_prev_1_w [7:0], pixel_prev_2_w [7:0], pixel_prev_3_w [7:0], pixel_prev_4_w [7:0], pixel_prev_5_w [7:0], pixel_prev_6_w [7:0];
reg [7:0] pixel_cur_r [7:0];
reg [7:0] pixel_prev_0_r [7:0], pixel_prev_1_r [7:0], pixel_prev_2_r [7:0], pixel_prev_3_r [7:0], pixel_prev_4_r [7:0], pixel_prev_5_r [7:0], pixel_prev_6_r [7:0];

// for debuggind
// always@(posedge clk) begin
//     if(state_w != INIT_READ_CUR && state_r == INIT_READ_CUR) begin
//         ///////////////////////////////////////////////////////////////////////////////////////////////////
//         $display("#############################################");
//         $display("########### Value of current block ##########");
//         $display("block address: %4d %4d ; block size : %4d %4d", block_addr_row_r, block_addr_col_r, pixel_counter_row_max_r, pixel_counter_col_max_r);
//         for(i = 0 ; i < 8 ; i=i+1) begin
//             for(j = 0 ; j < 8 ; j=j+1)
//                 $write("%3d ", cur_block_w[i][j]);
//             $write("\n");
//         end
//         $display("#############################################");
//         ///////////////////////////////////////////////////////////////////////////////////////////////////
//     end
//     if(state_w != INIT_READ_PREV && state_r == INIT_READ_PREV) begin
//         ///////////////////////////////////////////////////////////////////////////////////////////////////
//         $display("#############################################");
//         $display("########### Value of previous block ##########");
//         $display("Adding block address %6d %6d", block_addr_row_r, block_addr_col_r);
//         $display("Adding block size %4d %4d", pixel_counter_row_max_r, pixel_counter_col_max_r);
//         for(i = 0 ; i < 12 ; i=i+1) begin
//             for(j = 0 ; j < 12 ; j=j+1)
//                 $write("%3d ", search_block_w[i][j]);
//             $write("\n");
//         end
//         $display("#############################################");
//         ///////////////////////////////////////////////////////////////////////////////////////////////////
//     end
//     if(state_w != CAL_HEX && state_r == CAL_HEX) begin
//         ///////////////////////////////////////////////////////////////////////////////////////////////////
//         $display("#############################################");
//         $display("########### Max of 7 points ##########");
//         $display("Max of center : %3d", center_max_w);
//         $display("Max of point 1 : %3d", point1_max_w);
//         $display("Max of point 2 : %3d", point2_max_w);
//         $display("Max of point 3 : %3d", point3_max_w);
//         $display("Max of point 4 : %3d", point4_max_w);
//         $display("Max of point 5 : %3d", point5_max_w);
//         $display("Max of point 6 : %3d", point6_max_w);
//         $display("#############################################");
//         ///////////////////////////////////////////////////////////////////////////////////////////////////
//     end
//     if(state_w != FIND_MIN_AND_UPDATE && state_r == FIND_MIN_AND_UPDATE) begin
//         ///////////////////////////////////////////////////////////////////////////////////////////////////
//         $display("#############################################");
//         $display("The minimax is in idx : %3d", counter_min_r);
//         $display("Moving direction is %4d %4d", row_offset_w, col_offset_w);
//         $display("########### PREV BLOCK AFTER MOVING ##########");
//         for(i = 0 ; i < 12 ; i=i+1) begin
//             for(j = 0 ; j < 12 ; j=j+1)
//                 $write("%3d ", search_block_w[i][j]);
//             $write("\n");
//         end
//         $display("#############################################");
//         ///////////////////////////////////////////////////////////////////////////////////////////////////
//     end
//     if(state_w != READ_NEW_BLOCK1 && state_r == READ_NEW_BLOCK1) begin
//         ///////////////////////////////////////////////////////////////////////////////////////////////////
//         $display("#############################################");
//         $display("########### adding block 1 ##########");
//         $display("init point coordinate : %4d %4d %4d %4d",coordinate_0.row_init_0,coordinate_0.col_init_0,coordinate_0.row_init_1,coordinate_0.col_init_1);
//         $display("point coordinate : %4d %4d %4d %4d",coordinate_0.row_0,coordinate_0.col_0,coordinate_0.row_1,coordinate_0.col_1);
//         $display("pad offset : %4d %4d",pad_offset_row_r, pad_offset_col_r);
//         $display("Adding block address %6d %6d", block_addr_row_r, block_addr_col_r);
//         $display("Adding block size %4d %4d", pixel_counter_row_max_r, pixel_counter_col_max_r);
//         for(i = 0 ; i < 12 ; i=i+1) begin
//             for(j = 0 ; j < 12 ; j=j+1)
//                 $write("%3d ", search_block_w[i][j]);
//             $write("\n");
//         end
//         $display("#############################################");
//         ///////////////////////////////////////////////////////////////////////////////////////////////////
//     end
//     if(state_w != READ_NEW_BLOCK2 && state_r == READ_NEW_BLOCK2) begin
//         ///////////////////////////////////////////////////////////////////////////////////////////////////
//         $display("#############################################");
//         $display("########### adding block 2 ##########");
//         for(i = 0 ; i < 12 ; i=i+1) begin
//             for(j = 0 ; j < 12 ; j=j+1)
//                 $write("%3d ", search_block_w[i][j]);
//             $write("\n");
//         end
//         $display("#############################################");
//         ///////////////////////////////////////////////////////////////////////////////////////////////////
//     end
//     if(state_w != CAL_SMALL_HEX && state_r == CAL_SMALL_HEX) begin
//         ///////////////////////////////////////////////////////////////////////////////////////////////////
//         $display("#############################################");
//         $display("########### CAL_SMALL_HEX ##########");
//         $display("########### Max of 5 points ##########");
//         $display("Max of center : %3d", center_max_r);
//         $display("Max of point 1 : %3d", point1_max_r);
//         $display("Max of point 2 : %3d", point2_max_r);
//         $display("Max of point 3 : %3d", point3_max_r);
//         $display("Max of point 4 : %3d", point4_max_r);
//         $display("#############################################");
//         ///////////////////////////////////////////////////////////////////////////////////////////////////
//     end
//     if(state_w != SMALL_HEX_FIND_MIN && state_r == SMALL_HEX_FIND_MIN) begin
//         ///////////////////////////////////////////////////////////////////////////////////////////////////
//         $display("#############################################");
//         $display("The minimax in small hex is in idx : %3d", counter_min_r);
//         $display("Moving direction in small hex is %4d %4d", row_offset_w, col_offset_w );
//         $display("#############################################");
//         ///////////////////////////////////////////////////////////////////////////////////////////////////
//     end
//     if(state_w != UPDATE_BLOCK && state_r == UPDATE_BLOCK) begin
//         ///////////////////////////////////////////////////////////////////////////////////////////////////
//         $display("#############################################");
//         $display("Motion address : %3d %3d", mv_addr_row_r, mv_addr_col_r);
//         $display("Motion vector : %4d %4d", row_offset_r, col_offset_r);
//         $display("#############################################\n");
//         $display("********************************************************************************************************\n");
//         ///////////////////////////////////////////////////////////////////////////////////////////////////
//     end
// end

always@(*) begin
    // default value
    state_w = state_r;
    mv_addr_col_w = mv_addr_col_r;
    mv_addr_row_w = mv_addr_row_r;
    cur_frame_w = cur_frame_r;
    pixel_counter_row_w = pixel_counter_row_r;
    pixel_counter_col_w = pixel_counter_col_r;
    pixel_counter_row_w2 = pixel_counter_row_r2;
    pixel_counter_col_w2 = pixel_counter_col_r2;
    pixel_ready_w = pixel_ready_r;
    center_max_w = center_max_r;
    point1_max_w = point1_max_r;
    point2_max_w = point2_max_r;
    point3_max_w = point3_max_r;
    point4_max_w = point4_max_r;
    point5_max_w = point5_max_r;
    point6_max_w = point6_max_r;
    center_max_half1_w = center_max_half1_r;
    point1_max_half1_w = point1_max_half1_r;
    point2_max_half1_w = point2_max_half1_r;
    point3_max_half1_w = point3_max_half1_r;
    point4_max_half1_w = point4_max_half1_r;
    point5_max_half1_w = point5_max_half1_r;
    point6_max_half1_w = point6_max_half1_r;
    center_max_half2_w = center_max_half2_r;
    point1_max_half2_w = point1_max_half2_r;
    point2_max_half2_w = point2_max_half2_r;
    point3_max_half2_w = point3_max_half2_r;
    point4_max_half2_w = point4_max_half2_r;
    point5_max_half2_w = point5_max_half2_r;
    point6_max_half2_w = point6_max_half2_r;
    row_offset_w = row_offset_r;
    col_offset_w = col_offset_r;
    block_done = 1'd0;
    frame_done = 1'd0;
    counter_min_w = counter_min_r;
    block_valid_w = block_valid_r;
    current_min_idx_w = current_min_idx_r;
    current_min_value_w = current_min_value_r;
    block_pixel_w = 0;
    // block_pixel_w = block_pixel_r;
    for(i=0;i<8;i=i+1) begin
        pixel_abs_0_w[i] = pixel_abs_0_r[i];
        pixel_abs_1_w[i] = pixel_abs_1_r[i];
        pixel_abs_2_w[i] = pixel_abs_2_r[i];
        pixel_abs_3_w[i] = pixel_abs_3_r[i];
        pixel_abs_4_w[i] = pixel_abs_4_r[i];
        pixel_abs_5_w[i] = pixel_abs_5_r[i];
        pixel_abs_6_w[i] = pixel_abs_6_r[i];
    end
    for(i=0;i<8;i=i+1) begin
        pixel_cur_w[i] = pixel_cur_r[i];
        pixel_prev_0_w[i] = pixel_prev_0_r[i];
        pixel_prev_1_w[i] = pixel_prev_1_r[i];
        pixel_prev_2_w[i] = pixel_prev_2_r[i];
        pixel_prev_3_w[i] = pixel_prev_3_r[i];
        pixel_prev_4_w[i] = pixel_prev_4_r[i];
        pixel_prev_5_w[i] = pixel_prev_5_r[i];
        pixel_prev_6_w[i] = pixel_prev_6_r[i];
    end
    iter_count_w = iter_count_r;
    for(i = 0; i < 8 ; i=i+1)
        for(j = 0; j < 8 ; j=j+1)
            cur_block_w[i][j] = cur_block_r[i][j];
    for(i = 0; i < 12 ; i=i+1)
        for(j = 0; j < 12 ; j=j+1)
            search_block_w[i][j] = search_block_r[i][j];
    for(i = 0; i < 12 ; i=i+1)
        for(j = 0; j < 4 ; j=j+1)
            search_block_pad_w[i][j] = search_block_pad_r[i][j];
    // FSM
    case (state_r)
        INIT_READ_CUR: // read cur block
        begin
            pixel_ready_w = 1;
            if(pixel_valid) begin
                // save pixel to current block register
                cur_block_w[pixel_counter_row_r][pixel_counter_col_r] = pixel;
                // update pixel counter
                if(pixel_counter_col_r == 4'd7) begin
                    pixel_counter_col_w = 4'd0;
                    if(pixel_counter_row_r == 4'd7) begin // if read 64 pixel, update state to "INIT_READ_PREV" & initialize value
                        state_w = INIT_READ_PREV;
                        cur_frame_w = 1'd0;
                        pixel_counter_row_w = 4'd0;
                        pixel_ready_w = 1'd0;
                    end
                    else
                        pixel_counter_row_w = pixel_counter_row_r + 1;
                end
                else
                    pixel_counter_col_w = pixel_counter_col_r + 1;
            end
        end
        INIT_READ_PREV: // read search block
        begin
            pixel_ready_w = 1'd1;
            if(pixel_valid & pixel_ready_r) begin
                // save pixel to search block register
                // 4 kinds of center coordinate offset
                if(mv_addr_row_r == 3'd0) begin // up
                    if(mv_addr_col_r == 3'd0) // left
                        search_block_w[pixel_counter_row_r+4'd2][pixel_counter_col_r+4'd2] = pixel;
                    else
                        search_block_w[pixel_counter_row_r+4'd2][pixel_counter_col_r+4'd4] = pixel;
                end
                else begin
                    if(mv_addr_col_r == 3'd0) // left
                        search_block_w[pixel_counter_row_r][pixel_counter_col_r+4'd2] = pixel;
                    else
                        search_block_w[pixel_counter_row_r][pixel_counter_col_r+4'd4] = pixel;
                end
                // update pixel counter
                if(pixel_counter_col_r == pixel_counter_col_max_r - 4'd1) begin
                    pixel_counter_col_w = 4'd0;
                    if(pixel_counter_row_r == pixel_counter_row_max_r - 4'd1) begin // if read max pixel, update state to "INIT_HEX" & initialize value
                        state_w = PAD_BLOCK;
                        pixel_counter_row_w = 4'd0;
                        pixel_ready_w = 1'd0;
                    end
                    else
                        pixel_counter_row_w = pixel_counter_row_r + 4'd1;
                end
                else
                    pixel_counter_col_w = pixel_counter_col_r + 4'd1;
            end
        end
        PAD_BLOCK:
        begin
            state_w = CAL_HEX;
            for(i=0;i<12;i=i+1)
                for(j=0;j<4;j=j+1)
                    search_block_pad_w[i][j] = search_block_r[i][j+8];
            if(mv_addr_col_r != 3'd0) // the leftest has no pad block  
                for(i=0;i<12;i=i+1)
                    for(j=0;j<4;j=j+1)
                        search_block_w[i][j] = search_block_pad_r[i][j];
        end
        CAL_HEX: // calculate the minimax of the seven point & update center coordinate
        begin
            state_w = CAL_HEX_CAL;
            center_max_w = 14'b0;
            point1_max_w = 14'b0;
            point2_max_w = 14'b0;
            point3_max_w = 14'b0;
            point4_max_w = 14'b0;
            point5_max_w = 14'b0;
            point6_max_w = 14'b0;
            for(i=0;i<8;i=i+1) begin
                pixel_cur_w[i] = 8'b0;
                pixel_prev_0_w[i] = 8'b0;
                pixel_prev_1_w[i] = 8'b0;
                pixel_prev_2_w[i] = 8'b0;
                pixel_prev_3_w[i] = 8'b0;
                pixel_prev_4_w[i] = 8'b0;
                pixel_prev_5_w[i] = 8'b0;
                pixel_prev_6_w[i] = 8'b0;
            end
            for(i=0;i<8;i=i+1) begin
                pixel_abs_0_w[i] = 8'b0;
                pixel_abs_1_w[i] = 8'b0;
                pixel_abs_2_w[i] = 8'b0;
                pixel_abs_3_w[i] = 8'b0;
                pixel_abs_4_w[i] = 8'b0;
                pixel_abs_5_w[i] = 8'b0;
                pixel_abs_6_w[i] = 8'b0;
            end
            center_max_half1_w = 0;
            point1_max_half1_w = 0;
            point2_max_half1_w = 0;
            point3_max_half1_w = 0;
            point4_max_half1_w = 0;
            point5_max_half1_w = 0;
            point6_max_half1_w = 0;

            center_max_half2_w = 0;
            point1_max_half2_w = 0;
            point2_max_half2_w = 0;
            point3_max_half2_w = 0;
            point4_max_half2_w = 0;
            point5_max_half2_w = 0;
            point6_max_half2_w = 0;

            center_max_w = 0;
            point1_max_w = 0;
            point2_max_w = 0;
            point3_max_w = 0;
            point4_max_w = 0;
            point5_max_w = 0;
            point6_max_w = 0;
        end
        CAL_HEX_CAL: // calculate the minimax of the seven point & update center coordinate
        begin
            // calculate minimax
            if(iter_count_r == 2'd2) begin
                state_w = OUTPUT;
            end
            if(pixel_counter_row_r < 4'd8)
            for(i=0;i<8;i=i+1) begin
                pixel_cur_w[i] = cur_block_r[pixel_counter_row_r][i];
                pixel_prev_0_w[i] = search_block_r[pixel_counter_row_r+4'd2][i+4'd2];
                pixel_prev_1_w[i] = search_block_r[pixel_counter_row_r+4'd2][i+4'd4];
                pixel_prev_2_w[i] = search_block_r[pixel_counter_row_r][i+4'd3];
                pixel_prev_3_w[i] = search_block_r[pixel_counter_row_r][i+4'd1];
                pixel_prev_4_w[i] = search_block_r[pixel_counter_row_r+4'd2][i];
                pixel_prev_5_w[i] = search_block_r[pixel_counter_row_r+4'd4][i+4'd1];
                pixel_prev_6_w[i] = search_block_r[pixel_counter_row_r+4'd4][i+4'd3];
            end
            
            for(i=0;i<8;i=i+1) begin
                pixel_abs_0_w[i] = (pixel_prev_0_r[i] > pixel_cur_r[i]) ? (pixel_prev_0_r[i] - pixel_cur_r[i]) : (pixel_cur_r[i] - pixel_prev_0_r[i]);
                pixel_abs_1_w[i] = (pixel_prev_1_r[i] > pixel_cur_r[i]) ? (pixel_prev_1_r[i] - pixel_cur_r[i]) : (pixel_cur_r[i] - pixel_prev_1_r[i]);
                pixel_abs_2_w[i] = (pixel_prev_2_r[i] > pixel_cur_r[i]) ? (pixel_prev_2_r[i] - pixel_cur_r[i]) : (pixel_cur_r[i] - pixel_prev_2_r[i]);
                pixel_abs_3_w[i] = (pixel_prev_3_r[i] > pixel_cur_r[i]) ? (pixel_prev_3_r[i] - pixel_cur_r[i]) : (pixel_cur_r[i] - pixel_prev_3_r[i]);
                pixel_abs_4_w[i] = (pixel_prev_4_r[i] > pixel_cur_r[i]) ? (pixel_prev_4_r[i] - pixel_cur_r[i]) : (pixel_cur_r[i] - pixel_prev_4_r[i]);
                pixel_abs_5_w[i] = (pixel_prev_5_r[i] > pixel_cur_r[i]) ? (pixel_prev_5_r[i] - pixel_cur_r[i]) : (pixel_cur_r[i] - pixel_prev_5_r[i]);
                pixel_abs_6_w[i] = (pixel_prev_6_r[i] > pixel_cur_r[i]) ? (pixel_prev_6_r[i] - pixel_cur_r[i]) : (pixel_cur_r[i] - pixel_prev_6_r[i]);
            end

            center_max_half1_w = pixel_abs_0_r[0] + pixel_abs_0_r[1] + pixel_abs_0_r[2] + pixel_abs_0_r[3];
            point1_max_half1_w = pixel_abs_1_r[0] + pixel_abs_1_r[1] + pixel_abs_1_r[2] + pixel_abs_1_r[3];
            point2_max_half1_w = pixel_abs_2_r[0] + pixel_abs_2_r[1] + pixel_abs_2_r[2] + pixel_abs_2_r[3];
            point3_max_half1_w = pixel_abs_3_r[0] + pixel_abs_3_r[1] + pixel_abs_3_r[2] + pixel_abs_3_r[3];
            point4_max_half1_w = pixel_abs_4_r[0] + pixel_abs_4_r[1] + pixel_abs_4_r[2] + pixel_abs_4_r[3];
            point5_max_half1_w = pixel_abs_5_r[0] + pixel_abs_5_r[1] + pixel_abs_5_r[2] + pixel_abs_5_r[3];
            point6_max_half1_w = pixel_abs_6_r[0] + pixel_abs_6_r[1] + pixel_abs_6_r[2] + pixel_abs_6_r[3];

            center_max_half2_w = pixel_abs_0_r[4] + pixel_abs_0_r[5] + pixel_abs_0_r[6] + pixel_abs_0_r[7];
            point1_max_half2_w = pixel_abs_1_r[4] + pixel_abs_1_r[5] + pixel_abs_1_r[6] + pixel_abs_1_r[7];
            point2_max_half2_w = pixel_abs_2_r[4] + pixel_abs_2_r[5] + pixel_abs_2_r[6] + pixel_abs_2_r[7];
            point3_max_half2_w = pixel_abs_3_r[4] + pixel_abs_3_r[5] + pixel_abs_3_r[6] + pixel_abs_3_r[7];
            point4_max_half2_w = pixel_abs_4_r[4] + pixel_abs_4_r[5] + pixel_abs_4_r[6] + pixel_abs_4_r[7];
            point5_max_half2_w = pixel_abs_5_r[4] + pixel_abs_5_r[5] + pixel_abs_5_r[6] + pixel_abs_5_r[7];
            point6_max_half2_w = pixel_abs_6_r[4] + pixel_abs_6_r[5] + pixel_abs_6_r[6] + pixel_abs_6_r[7];

            center_max_w = center_max_r + center_max_half1_r + center_max_half2_r;
            point1_max_w = point1_max_r + point1_max_half1_r + point1_max_half2_r;
            point2_max_w = point2_max_r + point2_max_half1_r + point2_max_half2_r;
            point3_max_w = point3_max_r + point3_max_half1_r + point3_max_half2_r;
            point4_max_w = point4_max_r + point4_max_half1_r + point4_max_half2_r;
            point5_max_w = point5_max_r + point5_max_half1_r + point5_max_half2_r;
            point6_max_w = point6_max_r + point6_max_half1_r + point6_max_half2_r;

            // update pixel counter
            if(pixel_counter_row_r == 4'd10) begin // if read all pixel, update state to "FIND_MIN_AND_UPDATE" & initialize value
                state_w = FIND_MIN_AND_UPDATE;
                current_min_value_w = 8'd255 << 6;
                counter_min_w = 3'd0;
                pixel_counter_row_w = 4'd0;
            end
            else
                pixel_counter_row_w = pixel_counter_row_r + 4'd1;
        end
        FIND_MIN_AND_UPDATE:
        begin
            counter_min_w = counter_min_r + 3'd1;
            case(counter_min_r)
                0:
                begin
                    if(center_max_r < current_min_value_r) begin
                        current_min_value_w = center_max_r;
                        current_min_idx_w = 3'd0;
                    end
                end
                1:
                begin
                    if(point1_max_r < current_min_value_r) begin
                        current_min_value_w = point1_max_r;
                        current_min_idx_w = 3'd1;
                    end
                end
                2:
                begin
                    if(point2_max_r < current_min_value_r) begin
                        current_min_value_w = point2_max_r;
                        current_min_idx_w = 3'd2;
                    end
                end
                3:
                begin
                    if(point3_max_r < current_min_value_r) begin
                        current_min_value_w = point3_max_r;
                        current_min_idx_w = 3'd3;
                    end
                end
                4:
                begin
                    if(point4_max_r < current_min_value_r ) begin
                        current_min_value_w = point4_max_r;
                        current_min_idx_w = 3'd4;
                    end
                end
                5:
                begin
                    if(point5_max_r < current_min_value_r) begin
                        current_min_value_w = point5_max_r;
                        current_min_idx_w = 3'd5;
                    end
                end
                6:
                begin
                    if(point6_max_r < current_min_value_r) begin
                        current_min_value_w = point6_max_r;
                        current_min_idx_w = 3'd6;
                    end
                end
            endcase
            // if out is true, update hex
            if(counter_min_r == 7) begin
                state_w = READ_NEW_BLOCK1;
                for(i = 0 ; i < 12 ; i=i+1)
                    for(j = 0 ; j < 12 ; j=j+1)
                        search_block_w[i][j] = 8'd0;
                case(current_min_idx_r)
                    3'd0:
                    begin
                        state_w = OUTPUT;
                        for(i = 0 ; i < 12 ; i=i+1)
                            for(j = 0 ; j < 12 ; j=j+1)
                                search_block_w[i][j] = search_block_r[i][j];
                    end
                    3'd1:
                    begin
                        col_offset_w = $signed(col_offset_r + 3'sd2);
                        for(i = 0 ; i < 12 ; i=i+1)
                            for(j = 0 ; j < 10 ; j=j+1)
                                search_block_w[i][j] = search_block_r[i][j+2];
                    end
                    3'd2:
                    begin
                        row_offset_w = $signed(row_offset_r - 3'sd2);
                        col_offset_w = $signed(col_offset_r + 3'sd1);
                        for(i = 2 ; i < 12 ; i=i+1)
                            for(j = 0 ; j < 11 ; j=j+1)
                                search_block_w[i][j] = search_block_r[i-2][j+1];
                    end
                    3'd3:
                    begin
                        row_offset_w = $signed(row_offset_r - 3'sd2);
                        col_offset_w = $signed(col_offset_r - 3'sd1);
                        for(i = 2 ; i < 12 ; i=i+1)
                            for(j = 1 ; j < 12 ; j=j+1)
                                search_block_w[i][j] = search_block_r[i-2][j-1];
                    end
                    3'd4:
                    begin
                        col_offset_w = $signed(col_offset_r - 3'sd2);
                        for(i = 0 ; i < 12 ; i=i+1)
                            for(j = 2 ; j < 12 ; j=j+1)
                                search_block_w[i][j] = search_block_r[i][j-2];
                    end
                    3'd5:
                    begin
                        state_w = READ_NEW_BLOCK1;
                        row_offset_w = $signed(row_offset_r + 3'sd2);
                        col_offset_w = $signed(col_offset_r - 3'sd1);
                        for(i = 0 ; i < 10 ; i=i+1)
                            for(j = 1 ; j < 12 ; j=j+1)
                                search_block_w[i][j] = search_block_r[i+2][j-1];
                    end
                    3'd6:
                    begin
                        row_offset_w = $signed(row_offset_r + 3'sd2);
                        col_offset_w = $signed(col_offset_r + 3'sd1);
                        for(i = 0 ; i < 10 ; i=i+1)
                            for(j = 0 ; j < 11 ; j=j+1)
                                search_block_w[i][j] = search_block_r[i+2][j+1];
                    end
                endcase
            end
        end
        READ_NEW_BLOCK1: // read the new blocks
        begin
            if(pixel_counter_col_max_r == 4'd0 || pixel_counter_row_max_r == 4'd0) begin
                state_w = CAL_HEX;
                pixel_ready_w = 1'b0;
            end
            else    
                pixel_ready_w = 1'b1;
            if(current_min_idx_r == 3'd0) begin
                state_w = OUTPUT;
                pixel_ready_w = 1'b0;
            end
            else begin
                if(pixel_valid) begin
                    // different kinds of center coordinate offset
                    case(current_min_idx_r) 
                        3'd1:
                            search_block_w[pad_offset_row_r + pixel_counter_row_r][pad_offset_col_r + pixel_counter_col_r+4'd10] = pixel;
                        3'd2:
                            search_block_w[pad_offset_row_r + pixel_counter_row_r+4'd2][pad_offset_col_r + pixel_counter_col_r+4'd11] = pixel;
                        3'd3:
                            search_block_w[pad_offset_row_r + pixel_counter_row_r+4'd2][pad_offset_col_r + pixel_counter_col_r] = pixel;
                        3'd4:
                            search_block_w[pad_offset_row_r + pixel_counter_row_r][pad_offset_col_r + pixel_counter_col_r] = pixel;
                        3'd5:
                            search_block_w[pad_offset_row_r + pixel_counter_row_r][pad_offset_col_r + pixel_counter_col_r] = pixel;
                        3'd6:
                            search_block_w[pad_offset_row_r + pixel_counter_row_r][pad_offset_col_r + pixel_counter_col_r+4'd11] = pixel;
                    endcase
                    // update pixel counter
                    if(pixel_counter_col_r == pixel_counter_col_max_r - 4'd1) begin
                        pixel_counter_col_w = 0;
                        if(pixel_counter_row_r == pixel_counter_row_max_r - 4'd1) begin // if read all pixel, update state *
                            pixel_counter_row_w = 0;
                            if(current_min_idx_r == 3'd1 || current_min_idx_r == 3'd4) begin
                                state_w = CAL_HEX;
                                iter_count_w = iter_count_r + 1;
                                pixel_ready_w = 1'd0;
                            end
                            else begin
                                state_w = READ_NEW_BLOCK2;
                                pixel_ready_w = 0;
                            end
                        end
                        else
                            pixel_counter_row_w = pixel_counter_row_r + 4'd1;
                    end
                    else
                        pixel_counter_col_w = pixel_counter_col_r + 4'd1;
                end
            end
        end
        READ_NEW_BLOCK2: // read the new blocks
        begin
            if(pixel_counter_col_max_r == 0 || pixel_counter_row_max_r == 0) begin
                state_w = CAL_HEX;
                pixel_ready_w = 0;
            end
            else
                pixel_ready_w = 1;
            if(pixel_valid) begin
                // different kinds of center coordinate offset
                case(current_min_idx_r) 
                    3'd2:
                        search_block_w[pad_offset_row_r + pixel_counter_row_r][pad_offset_col_r + pixel_counter_col_r] = pixel;
                    3'd3:
                        search_block_w[pad_offset_row_r + pixel_counter_row_r][pad_offset_col_r + pixel_counter_col_r] = pixel;
                    3'd5:
                        search_block_w[pad_offset_row_r + pixel_counter_row_r+4'd10][pad_offset_col_r + pixel_counter_col_r] = pixel;
                    3'd6:
                        search_block_w[pad_offset_row_r + pixel_counter_row_r+4'd10][pad_offset_col_r + pixel_counter_col_r] = pixel;
                endcase
                // update pixel counter
                if(pixel_counter_col_r == pixel_counter_col_max_r - 1) begin
                    pixel_counter_col_w = 0;
                    if(pixel_counter_row_r == pixel_counter_row_max_r - 1) begin // if read all pixel, update state *
                        pixel_counter_row_w = 0;
                        state_w = CAL_HEX;
                        iter_count_w = iter_count_r + 1;
                        pixel_ready_w = 0;
                    end
                    else
                        pixel_counter_row_w = pixel_counter_row_r + 1;
                end
                else
                    pixel_counter_col_w = pixel_counter_col_r + 1;
            end
        end
        OUTPUT: // output "mv", "mv_addr", "mv_valid"
        begin
            iter_count_w = 2'd0;
            block_valid_w = 1; // block valid
            block_done = 1; // block done
            state_w = WRITE_DATA;
            cur_frame_w = 1;
            pixel_ready_w = 0;
            row_offset_w = 0;
            col_offset_w = 0;
            if(mv_addr_col_r == 7) begin
                mv_addr_col_w = 0;
                if(mv_addr_row_r == 5) begin // frame done
                    mv_addr_row_w = 0;
                    frame_done = 1;
                end
                else
                    mv_addr_row_w = mv_addr_row_r + 1;
            end
            else
                mv_addr_col_w = mv_addr_col_r + 1;
        end
        WRITE_DATA: // output "mv", "mv_addr", "mv_valid"
        begin
            pixel_ready_w = 1; // check correctness of the last block in the last frame
            if(block_ready) begin
                case(current_min_idx_r)
                    0:
                        block_pixel_w = search_block_r[pixel_counter_row_r+2][pixel_counter_col_r+2];
                    1:
                        block_pixel_w = search_block_r[pixel_counter_row_r+2][pixel_counter_col_r+3];
                    2:
                        block_pixel_w = search_block_r[pixel_counter_row_r+1][pixel_counter_col_r+2];
                    3:
                        block_pixel_w = search_block_r[pixel_counter_row_r+2][pixel_counter_col_r+1];
                    4:
                        block_pixel_w = search_block_r[pixel_counter_row_r+3][pixel_counter_col_r+2];
                endcase
                // update pixel counter
                if(pixel_counter_col_r == 7) begin
                    pixel_counter_col_w = 0;
                    if(pixel_counter_row_r == 7) begin // if read 64 pixel, update state to "INIT_READ_PREV" & initialize value
                        block_valid_w = 0;
                    end
                    else
                        pixel_counter_row_w = pixel_counter_row_r + 1;
                end
                else
                    pixel_counter_col_w = pixel_counter_col_r + 1;
            end
            if(pixel_valid) begin
                // save pixel to current block register
                cur_block_w[pixel_counter_row_r2][pixel_counter_col_r2] = pixel;
                // update pixel counter
                if(pixel_counter_col_r2 == 4'd7) begin
                    pixel_counter_col_w2 = 4'd0;
                    if(pixel_counter_row_r2 == 4'd7) begin // if read 64 pixel, update state to "INIT_READ_PREV" & initialize value
                        state_w = INIT_READ_PREV;
                        cur_frame_w = 1'd0;
                        pixel_counter_row_w2 = 4'd0;
                        pixel_counter_row_w = 4'd0;
                        pixel_ready_w = 1'd0;
                        for(i = 0 ; i < 12 ; i=i+1)
                            for(j = 0 ; j < 12 ; j=j+1)
                                search_block_w[i][j] = 0;
                        // update mv addr
                    end
                    else
                        pixel_counter_row_w2 = pixel_counter_row_r2 + 1;
                end
                else
                    pixel_counter_col_w2 = pixel_counter_col_r2 + 1;
            end
        end
    endcase
end

always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        state_r <= 0;
        mv_addr_row_r <= 0;
        mv_addr_col_r <= 0;
        cur_frame_r <= 1;
        pixel_counter_row_r <= 0;
        pixel_counter_col_r <= 0;
        pixel_counter_row_r2 <= 0;
        pixel_counter_col_r2 <= 0;
        pixel_ready_r <= 1;
        center_max_r <= 0;
        point1_max_r <= 0;
        point2_max_r <= 0;
        point3_max_r <= 0;
        point4_max_r <= 0;
        point5_max_r <= 0;
        point6_max_r <= 0;
        center_max_half1_r <= 0;
        point1_max_half1_r <= 0;
        point2_max_half1_r <= 0;
        point3_max_half1_r <= 0;
        point4_max_half1_r <= 0;
        point5_max_half1_r <= 0;
        point6_max_half1_r <= 0;
        center_max_half2_r <= 0;
        point1_max_half2_r <= 0;
        point2_max_half2_r <= 0;
        point3_max_half2_r <= 0;
        point4_max_half2_r <= 0;
        point5_max_half2_r <= 0;
        point6_max_half2_r <= 0;
        counter_min_r <= 0;
        row_offset_r <= 0;
        col_offset_r <= 0;
        block_valid_r <= 0;
        current_min_value_r <= 0;
        current_min_idx_r <= 0;
        iter_count_r <= 0;
        // block_pixel_r <= 0;
        for(i = 0; i < 8 ; i=i+1)
            for(j = 0; j < 8 ; j=j+1)
                cur_block_r[i][j] <= 0;
        for(i = 0; i < 12 ; i=i+1)
            for(j = 0; j < 12 ; j=j+1)
                search_block_r[i][j] <= 0;
        for(i = 0; i < 12 ; i=i+1)
            for(j = 0; j < 4 ; j=j+1)
                search_block_pad_r[i][j] <= 0;
        for(i=0;i<8;i=i+1) begin
            pixel_abs_0_r[i] <= 0;
            pixel_abs_1_r[i] <= 0;
            pixel_abs_2_r[i] <= 0;
            pixel_abs_3_r[i] <= 0;
            pixel_abs_4_r[i] <= 0;
            pixel_abs_5_r[i] <= 0;
            pixel_abs_6_r[i] <= 0;
        end
        for(i=0;i<8;i=i+1) begin
            pixel_cur_r[i] <= 0;
            pixel_prev_0_r[i] <= 0;
            pixel_prev_1_r[i] <= 0;
            pixel_prev_2_r[i] <= 0;
            pixel_prev_3_r[i] <= 0;
            pixel_prev_4_r[i] <= 0;
            pixel_prev_5_r[i] <= 0;
            pixel_prev_6_r[i] <= 0;
        end
    end
    else begin
        state_r <= state_w;
        mv_addr_row_r <= mv_addr_row_w;
        mv_addr_col_r <= mv_addr_col_w;
        cur_frame_r <= cur_frame_w;
        pixel_counter_row_r <= pixel_counter_row_w;
        pixel_counter_col_r <= pixel_counter_col_w;
        pixel_counter_row_r2 <= pixel_counter_row_w2;
        pixel_counter_col_r2 <= pixel_counter_col_w2;
        pixel_ready_r <= pixel_ready_w;
        center_max_r <= center_max_w;
        point1_max_r <= point1_max_w;
        point2_max_r <= point2_max_w;
        point3_max_r <= point3_max_w;
        point4_max_r <= point4_max_w;
        point5_max_r <= point5_max_w;
        point6_max_r <= point6_max_w;
        center_max_half1_r <= center_max_half1_w;
        point1_max_half1_r <= point1_max_half1_w;
        point2_max_half1_r <= point2_max_half1_w;
        point3_max_half1_r <= point3_max_half1_w;
        point4_max_half1_r <= point4_max_half1_w;
        point5_max_half1_r <= point5_max_half1_w;
        point6_max_half1_r <= point6_max_half1_w;
        center_max_half2_r <= center_max_half2_w;
        point1_max_half2_r <= point1_max_half2_w;
        point2_max_half2_r <= point2_max_half2_w;
        point3_max_half2_r <= point3_max_half2_w;
        point4_max_half2_r <= point4_max_half2_w;
        point5_max_half2_r <= point5_max_half2_w;
        point6_max_half2_r <= point6_max_half2_w;
        counter_min_r <= counter_min_w;
        row_offset_r <= row_offset_w;
        col_offset_r <= col_offset_w;
        block_valid_r <= block_valid_w;
        current_min_value_r <= current_min_value_w;
        current_min_idx_r <= current_min_idx_w;
        iter_count_r <= iter_count_w;
        // block_pixel_r <= block_pixel_w;
        for(i = 0; i < 8 ; i=i+1)
            for(j = 0; j < 8 ; j=j+1)
                cur_block_r[i][j] <= cur_block_w[i][j];
        for(i = 0; i < 12 ; i=i+1)
            for(j = 0; j < 12 ; j=j+1)
                search_block_r[i][j] <= search_block_w[i][j];
        for(i = 0; i < 12 ; i=i+1)
            for(j = 0; j < 4 ; j=j+1)
                search_block_pad_r[i][j] <= search_block_pad_w[i][j];
        for(i=0;i<8;i=i+1) begin
            pixel_abs_0_r[i] <= pixel_abs_0_w[i];
            pixel_abs_1_r[i] <= pixel_abs_1_w[i];
            pixel_abs_2_r[i] <= pixel_abs_2_w[i];
            pixel_abs_3_r[i] <= pixel_abs_3_w[i];
            pixel_abs_4_r[i] <= pixel_abs_4_w[i];
            pixel_abs_5_r[i] <= pixel_abs_5_w[i];
            pixel_abs_6_r[i] <= pixel_abs_6_w[i];
        end
        for(i=0;i<8;i=i+1) begin
            pixel_cur_r[i] <= pixel_cur_w[i];
            pixel_prev_0_r[i] <= pixel_prev_0_w[i];
            pixel_prev_1_r[i] <= pixel_prev_1_w[i];
            pixel_prev_2_r[i] <= pixel_prev_2_w[i];
            pixel_prev_3_r[i] <= pixel_prev_3_w[i];
            pixel_prev_4_r[i] <= pixel_prev_4_w[i];
            pixel_prev_5_r[i] <= pixel_prev_5_w[i];
            pixel_prev_6_r[i] <= pixel_prev_6_w[i];
        end
    end
end
endmodule
