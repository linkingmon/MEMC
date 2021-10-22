`include "hex_v4.v"
`include "process_ctrl.v"
`include "sram_ctrl_v5.v"
module MEMC(
    clk,
    rst_n,
    pixel_valid,
    pixel,
    busy,
    mv_valid,
    mv,
    mv_addr
);

input clk;
input rst_n;
input pixel_valid;
input [7:0] pixel;
output busy;
output mv_valid;
output [7:0] mv;
output [5:0] mv_addr;

wire [3:0] frame_id;
wire [5:0] block_id;
wire frame_done, block_done, frame_inc;

wire cur_frame;
wire [11:0] block_addr; // 6 + 6
wire [7:0] block_size; // 4 + 4
wire pixel_ready;
wire inter_pixel_valid;
wire [7:0] inter_pixel;
// wire pixel_start;
wire block_ready;
wire block_valid;
wire [7:0] block_pixel;

sram_ctrl sram_ctrl_0(
    .clk(clk),
    .rst_n(rst_n),
    .i_pixel_valid(pixel_valid),
    .i_pixel(pixel),
    .busy(busy),

    .cur_frame(cur_frame),
    .block_addr(block_addr), // 6 + 6
    .block_size(block_size), // 4 + 4
    .pixel_ready(pixel_ready),
    .pixel_valid(inter_pixel_valid),
    .pixel(inter_pixel),
    // .pixel_start(pixel_start),

    .frame_inc(frame_inc),
    .frame_id(frame_id),
    .block_id(block_id),

    .block_ready(block_ready),
    .block_valid(block_valid),
    .block_pixel(block_pixel)
);

hex hex_0(
    .clk(clk),
    .rst_n(rst_n),
    .mv(mv),
    .mv_valid(mv_valid),
    .mv_addr(mv_addr),

    .cur_frame(cur_frame),
    .block_addr(block_addr), // 6 + 6
    .block_size(block_size), // 4 + 4
    .pixel_ready(pixel_ready),
    .pixel_valid(inter_pixel_valid),
    .pixel(inter_pixel),
    // .pixel_start(pixel_start),

    .frame_done(frame_done),
    .block_done(block_done),

    .block_ready(block_ready),
    .block_valid(block_valid),
    .block_pixel(block_pixel)
);

process_ctrl process_ctrl_0(
    .clk(clk),
    .rst_n(rst_n),
    .frame_id(frame_id),
    .block_id(block_id),
    .frame_done(frame_done),
    .block_done(block_done),
    .frame_inc(frame_inc)
);

endmodule