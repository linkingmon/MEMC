`include "sram_4096x8.vp"
`include "sram_512x8.vp"
module sram_ctrl(
    clk,
    rst_n,
    i_pixel_valid,
    i_pixel,
    busy,

    cur_frame,
    block_addr, // 6 + 6
    block_size, // 4 + 4
    pixel_ready,
    pixel_valid,
    pixel,
    // pixel_start,

    block_ready,
    block_valid,
    block_pixel,

    frame_inc,
    frame_id,
    block_id
);

input clk;
input rst_n;
input i_pixel_valid;
input [7:0] i_pixel;
output busy;

input cur_frame;
input [11:0] block_addr; // 6 + 6
input [7:0] block_size; // 4 + 4
input pixel_ready;
output pixel_valid;
output [7:0] pixel;
// output pixel_start;

output block_ready;
input block_valid;
input [7:0] block_pixel;

input frame_inc;
input [3:0] frame_id; //1~9
input [5:0] block_id; //0~47

wire sram1_cen, sram1_wen;
wire [7:0] sram1_Q, sram1_D;
wire [11:0] sram1_A;

wire sram2_cen, sram2_wen;
wire [7:0] sram2_Q, sram2_D;
wire [8:0] sram2_A;

wire sram3_cen, sram3_wen;
wire [7:0] sram3_Q, sram3_D;
wire [8:0] sram3_A;

reg [1:0]   state_r, state_w;
reg         frame_state_r, frame_state_w;
reg         write_state_r, write_state_w;
reg         busy_r, busy_w;
wire        need_frame, more_frame;
reg         more_frame_r, more_frame_w;
reg [3:0]   frame_read_r, frame_read_w; // number of frames read
reg [5:0]   block_read_r, block_read_w; // number of blocks read in the current frame
reg [11:0]  pixel_read_r, pixel_read_w; // number of pixels read in the current frame
reg [11:0]  sram_A_write_r, sram_A_write_w;
// reg [11:0]  sram_A_write_block_r, sram_A_write_block_w;
reg [5:0]   sram_row_A_write_block_r, sram_row_A_write_block_w;
reg [5:0]   sram_col_A_write_block_r, sram_col_A_write_block_w;
wire[11:0]  sram_A_write_block;
reg [11:0]  sram_A_read_r, sram_A_read_w;
reg [11:0]  sram_A_curFrame_r, sram_A_curFrame_w;
reg [11:0]  sram_A_preFrame_r, sram_A_preFrame_w;
reg [1:0]   sram_frame_offset;
reg [11:0]  sram_frame_addr;
reg [5:0]   sram_row_addr, sram_col_addr;
reg [3:0]   row_counter_r, row_counter_w;
reg [3:0]   col_counter_r, col_counter_w;
reg         pixel_valid_r, pixel_valid_w;
// reg         pixel_start_r, pixel_start_w;
reg         block_ready_r, block_ready_w;


localparam S_IDLE = 2'b00;
localparam S_READ = 2'b01;
localparam S_WRITE_BLK = 2'b10;
localparam S_F_IDLE = 1'b0;
localparam S_F_WRITE  = 1'b1;
localparam S_W_IDLE = 1'b0;
localparam S_W_BLK  = 1'b1;

sram_4096x8 sram_1(
   .Q(sram1_Q),          // [7:0]  output
   .CLK(clk),           //        input
   .CEN(sram1_cen),      //        input
   .WEN(sram1_wen),      //        input
   .A(sram1_A),          // [11:0] input
   .D(sram1_D)           // [7:0]  input
);

sram_512x8 sram_2(
   .Q(sram2_Q),         // [7:0]  output
   .CLK(clk),           //        input
   .CEN(sram2_cen),     //        input
   .WEN(sram2_wen),     //        input
   .A(sram2_A),         // [8:0] input
   .D(sram2_D)          // [7:0]  input
);

sram_512x8 sram_3(
   .Q(sram3_Q),         // [7:0]  output
   .CLK(clk),           //        input
   .CEN(sram3_cen),     //        input
   .WEN(sram3_wen),     //        input
   .A(sram3_A),         // [8:0] input
   .D(sram3_D)          // [7:0]  input
);


assign busy = busy_r;
assign need_frame = (frame_read_r < frame_id) || (frame_read_r==frame_id && block_read_r<=block_id);
assign more_frame = more_frame_r;
assign sram_A_write_block = {sram_row_A_write_block_r, sram_col_A_write_block_r};

assign sram1_cen = frame_state_r == S_F_IDLE && state_r==S_IDLE && write_state_r == S_W_IDLE ? 1'b1 : 1'b0;
assign sram1_wen = (frame_state_r == S_F_WRITE && i_pixel_valid  && frame_read_r==0) || (write_state_r == S_W_BLK) ? 1'b0 : 1'b1;
assign sram1_A = (frame_state_r == S_F_WRITE && frame_read_r==4'b0) ? sram_A_write_r :
                (write_state_r == S_W_BLK ? sram_A_write_block : sram_A_read_w);
assign sram1_D = frame_read_r==0 ? i_pixel : block_pixel;

assign sram2_cen = frame_state_r == S_F_IDLE && state_r==S_IDLE ? 1'b1 : 1'b0;
assign sram2_wen = (frame_state_r == S_F_WRITE && i_pixel_valid  && frame_read_r!=0 && block_read_r[3]==1'b0) ? 1'b0 : 1'b1;
assign sram2_A = (frame_state_r == S_F_WRITE && block_read_r[3]==1'b0) ? sram_A_write_r[8:0] : sram_A_read_w[8:0];
assign sram2_D = i_pixel;

assign sram3_cen = frame_state_r == S_F_IDLE && state_r==S_IDLE ? 1'b1 : 1'b0;
assign sram3_wen = (frame_state_r == S_F_WRITE && i_pixel_valid  && frame_read_r!=0 && block_read_r[3]==1'b1) ? 1'b0 : 1'b1;
assign sram3_A = (frame_state_r == S_F_WRITE && block_read_r[3]==1'b1) ? sram_A_write_r[8:0] : sram_A_read_w[8:0];
assign sram3_D = i_pixel;

assign pixel = cur_frame ? (block_id[3]==0 ? sram2_Q : sram3_Q ) : sram1_Q;
assign pixel_valid = pixel_valid_r;
// assign pixel_start = pixel_start_r;
assign block_ready = block_ready_r;

always@(*) begin
    frame_state_w = frame_state_r;
    busy_w = busy_r;
    frame_read_w = frame_read_r;
    block_read_w = block_read_r;
    pixel_read_w = pixel_read_r;
    sram_A_write_w = sram_A_write_r;
    case(frame_state_r)
        S_F_IDLE: begin
            if ( need_frame || more_frame ) begin
                frame_state_w = S_F_WRITE;
                busy_w = 1'b0;
            end else begin
                frame_state_w = S_F_IDLE;
                busy_w = 1'b1;
            end
        end
        S_F_WRITE: begin
            if (i_pixel_valid) begin
                if (pixel_read_r==12'd3071) begin
                    pixel_read_w = 12'd0;
                    frame_read_w = frame_read_r + 1;
                end else begin 
                    pixel_read_w = pixel_read_r + 1;
                    frame_read_w = frame_read_r;
                end

                if (pixel_read_r==12'd3071) block_read_w = 6'd0;
                else if (pixel_read_r[8:0]==9'b111111111) block_read_w = block_read_r + 8;
                else block_read_w = block_read_r;

                sram_A_write_w = sram_A_write_r + 1;

            end else begin
                pixel_read_w = pixel_read_r;
                block_read_w = block_read_r;
                frame_read_w = frame_read_r;
                sram_A_write_w = sram_A_write_r;
            end
            
            if (frame_read_r!=0 && pixel_read_r[8:0]==9'b111111111) begin
                frame_state_w = S_F_IDLE;
                busy_w = 1'b1;
            end else begin
                frame_state_w = S_F_WRITE;
                busy_w = 1'b0;
            end
        end
    endcase
end

always@(*) begin
    sram_frame_offset = sram_A_curFrame_r[11:10]-1;
    if (frame_inc) begin
        sram_A_curFrame_w = {sram_frame_offset, 10'b0};
        sram_A_preFrame_w = sram_A_curFrame_r;
    end else begin
        sram_A_curFrame_w = sram_A_curFrame_r;
        sram_A_preFrame_w = sram_A_preFrame_r;
    end
    sram_frame_addr = cur_frame ? 12'b0 : sram_A_preFrame_w;
    sram_row_addr = sram_frame_addr[11:6] + block_addr[11:6] + row_counter_r;
    sram_col_addr = sram_frame_addr[5:0] + block_addr[5:0] + col_counter_r;
    sram_A_read_w = {sram_row_addr, sram_col_addr};

    // if (state_r==S_READ && cur_frame && sram_A_read_w[8:0]==9'b111111111 && frame_read_r<4'd10) more_frame_w = 1'b1;
    // else if (frame_state_r==S_F_WRITE && pixel_read_r[8:0]==9'b111111111 ) more_frame_w = 1'b0;
    // else more_frame_w = more_frame_r;
    if (state_r==S_READ && cur_frame && sram_A_read_w[8:0]==9'b000000000 && frame_read_r<4'd10) more_frame_w = 1'b1;
    else if (frame_state_r==S_F_WRITE && pixel_read_r[8:0]==9'b111111111 ) more_frame_w = 1'b0;
    else more_frame_w = more_frame_r;
end

always@(*) begin
    state_w = state_r;
    pixel_valid_w = pixel_valid_r;
    row_counter_w = 4'b0;
    col_counter_w = 4'b0;
    case(state_r)
        S_IDLE: begin
            if (!need_frame && pixel_ready) begin
                state_w = S_READ;
            end else begin 
                state_w = S_IDLE;
            end
            pixel_valid_w = 1'b0;
        end
        S_READ: begin
            if (row_counter_r==block_size[7:4]) begin
                state_w = S_IDLE;
                pixel_valid_w = 1'b0;
            end else begin
                state_w = S_READ;
                pixel_valid_w = 1'b1;
            end

            if (col_counter_r==block_size[3:0]-1) begin
                col_counter_w = 0;
                row_counter_w = row_counter_r + 1;
            end else begin
                col_counter_w = col_counter_r + 1;
                row_counter_w = row_counter_r;
            end
        end
    endcase
end

always@(*) begin
    write_state_w = write_state_r;
    block_ready_w = block_ready_r;
    sram_row_A_write_block_w = sram_row_A_write_block_r;
    sram_col_A_write_block_w = sram_col_A_write_block_r;

    case(write_state_r)
        S_W_IDLE: begin
            if (!need_frame && block_valid) begin
                write_state_w = S_W_BLK;
                block_ready_w = 1'b1;
            end else begin 
                write_state_w = S_W_IDLE;
                block_ready_w = 1'b0;
            end
        end
        S_W_BLK: begin
            sram_col_A_write_block_w[2:0] = sram_col_A_write_block_r[2:0] + 3'b001;
            if (sram_col_A_write_block_r[2:0] == 3'b111 && sram_row_A_write_block_r[2:0] == 3'b111) begin
                sram_col_A_write_block_w[5:3] = sram_col_A_write_block_r[5:3] + 3'b001;
            end else begin
                sram_col_A_write_block_w[5:3] = sram_col_A_write_block_r[5:3];
            end

            if (sram_col_A_write_block_r[2:0] == 3'b111) begin
                sram_row_A_write_block_w[2:0] = sram_row_A_write_block_r[2:0] + 3'b001;
            end else begin
                sram_row_A_write_block_w[2:0] = sram_row_A_write_block_r[2:0];
            end

            if (sram_col_A_write_block_r == 6'b111111 && sram_row_A_write_block_r[2:0] == 3'b111) begin
                sram_row_A_write_block_w[5:3] = sram_row_A_write_block_r[5:3] + 3'b001;
            end else begin
                sram_row_A_write_block_w[5:3] = sram_row_A_write_block_r[5:3];
            end
                        
            if (sram_col_A_write_block_r[2:0] == 3'b111 && sram_row_A_write_block_r[2:0] == 3'b111) begin
                write_state_w = S_W_IDLE;
                block_ready_w = 1'b0;
            end else begin
                write_state_w = S_W_BLK;
                block_ready_w = 1'b1;
            end
        end
    endcase
end


always@(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state_r <= S_IDLE;
        frame_state_r <= S_F_IDLE;
        write_state_r <= S_W_IDLE;
        busy_r <= 1'b1;
        frame_read_r <= 4'b0;
        block_read_r <= 6'b0;
        pixel_read_r <= 12'b0;
        sram_A_write_r <= 12'b0;
        sram_row_A_write_block_r <= 6'b110000;
        sram_col_A_write_block_r <= 6'b000000;
        sram_A_read_r <= 12'b0;
        sram_A_curFrame_r <= 12'b110000_000000;
        sram_A_preFrame_r <= 12'b0;
        pixel_valid_r <= 1'b0;
        // pixel_start_r <= 1'b0;
        block_ready_r <= 1'b0;
        row_counter_r <= 4'b0;
        col_counter_r <= 4'b0;
        more_frame_r <= 1'b0;
    end else begin
        state_r <= state_w;
        frame_state_r <= frame_state_w;
        write_state_r <= write_state_w;
        busy_r <= busy_w;
        frame_read_r <= frame_read_w;
        block_read_r <= block_read_w;
        pixel_read_r <= pixel_read_w;
        sram_A_write_r <= sram_A_write_w;
        sram_row_A_write_block_r <= sram_row_A_write_block_w;
        sram_col_A_write_block_r <= sram_col_A_write_block_w;
        sram_A_read_r <= sram_A_read_w;
        sram_A_curFrame_r <= sram_A_curFrame_w;
        sram_A_preFrame_r <= sram_A_preFrame_w;
        pixel_valid_r <= pixel_valid_w;
        // pixel_start_r <= pixel_start_w;
        block_ready_r <= block_ready_w;
        row_counter_r <= row_counter_w;
        col_counter_r <= col_counter_w;
        more_frame_r <= more_frame_w;
    end
    
end

endmodule

