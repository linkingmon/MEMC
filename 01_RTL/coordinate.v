// pure combinational logic
// for caculating block address & block size & pad_offset
module coordinate(
    clk,
    rst_n,
    state_r,
    mv_addr_row_r,
    mv_addr_col_r,
    col_offset_r,
    row_offset_r,
    counter_min_r,
    block_addr_row_r,
    block_addr_col_r,
    pixel_counter_row_max_r,
    pixel_counter_col_max_r,
    pad_offset_row_r,
    pad_offset_col_r
);

input clk, rst_n;
input [3:0] state_r;
input [2:0] mv_addr_row_r, mv_addr_col_r;
input signed [3:0] col_offset_r, row_offset_r;                      // mv
input [2:0] counter_min_r;                                          // movind direction
reg [5:0] block_addr_row_w, block_addr_col_w;                // block address
output reg [5:0] block_addr_row_r, block_addr_col_r;                // block address
reg [3:0] pixel_counter_row_max_w, pixel_counter_col_max_w;  // block size
output reg [3:0] pixel_counter_row_max_r, pixel_counter_col_max_r;  // block size
reg [3:0] pad_offset_row_w, pad_offset_col_w;                // pad_offset
output reg [3:0] pad_offset_row_r, pad_offset_col_r;                // pad_offset
// output reg no_up, no_down, no_left, no_right;                       

reg signed [7:0] row_init_0, col_init_0, row_init_1, col_init_1;
reg signed [7:0] row_0, col_0, row_1, col_1;

wire [7:0] mv_addr_row_sign_extend_r, mv_addr_col_sign_extend_r;
wire [7:0] row_offset_sign_extend_r, col_offset_sign_extend_r;

assign mv_addr_row_sign_extend_r = {5'b0,mv_addr_row_r};
assign mv_addr_col_sign_extend_r = {5'b0,mv_addr_col_r};
assign row_offset_sign_extend_r = {{4{row_offset_r[3]}},row_offset_r};
assign col_offset_sign_extend_r = {{4{col_offset_r[3]}},col_offset_r};

localparam INIT_READ_CUR = 4'd0;
localparam INIT_READ_PREV = 4'd1;
localparam CAL_HEX = 4'd2;
localparam FIND_MIN_AND_UPDATE = 4'd3;
localparam READ_NEW_BLOCK1 = 4'd4;
localparam READ_NEW_BLOCK2 = 4'd5;
localparam CAL_SMALL_HEX = 4'd6;
localparam SMALL_HEX_FIND_MIN = 4'd7;
localparam OUTPUT = 4'd8;
localparam WRITE_DATA = 4'd9;
localparam UPDATE_BLOCK = 4'd10;

always@(*) begin
    // default
    block_addr_row_w = block_addr_row_r;
    block_addr_col_w = block_addr_col_r;
    pixel_counter_row_max_w = pixel_counter_row_max_r;
    pixel_counter_col_max_w = pixel_counter_col_max_r;
    row_0 = 0;
    row_1 = 0;
    col_0 = 0;
    col_1 = 0;
    row_init_0 = 0;
    col_init_0 = 0;
    row_init_1 = 0;
    col_init_1 = 0;
    pad_offset_row_w = pad_offset_row_r;
    pad_offset_col_w = pad_offset_col_r; 
    // calculate initial coordinate
    case(state_r)
        INIT_READ_PREV: // read search block
        begin
            if(mv_addr_col_r == 0) begin
                row_init_0 = $signed((mv_addr_row_sign_extend_r << 3) - 8'sd2);
                col_init_0 = $signed((mv_addr_col_sign_extend_r << 3) - 8'sd2);
                row_init_1 = $signed((mv_addr_row_sign_extend_r << 3) + 8'sd10);
                col_init_1 = $signed((mv_addr_col_sign_extend_r << 3) + 8'sd10);
            end 
            else begin
                row_init_0 = $signed((mv_addr_row_sign_extend_r << 3) - 8'sd2);
                col_init_0 = $signed((mv_addr_col_sign_extend_r << 3) + 8'sd2);
                row_init_1 = $signed((mv_addr_row_sign_extend_r << 3) + 8'sd10);
                col_init_1 = $signed((mv_addr_col_sign_extend_r << 3) + 8'sd10);
            end
        end
        READ_NEW_BLOCK1: // read new search block (component 1 of L size block)
        begin
            // block size
            // 1, 4: 12x2
            // other : block1 : 10x1 ; block2 : 2x12
            case(counter_min_r)
                1:  
                begin
                    row_init_0 = $signed($signed((mv_addr_row_sign_extend_r << 3) - 8'sd2) + row_offset_sign_extend_r);
                    col_init_0 = $signed($signed((mv_addr_col_sign_extend_r << 3) + 8'sd8) + col_offset_sign_extend_r);
                    row_init_1 = $signed($signed((mv_addr_row_sign_extend_r << 3) + 8'sd10) + row_offset_sign_extend_r);
                    col_init_1 = $signed($signed((mv_addr_col_sign_extend_r << 3) + 8'sd10) + col_offset_sign_extend_r);
                end
                2:
                begin
                    row_init_0 = $signed($signed((mv_addr_row_sign_extend_r << 3)) + row_offset_sign_extend_r);
                    col_init_0 = $signed($signed((mv_addr_col_sign_extend_r << 3) + 8'sd9) + col_offset_sign_extend_r);
                    row_init_1 = $signed($signed((mv_addr_row_sign_extend_r << 3) + 8'sd10) + row_offset_sign_extend_r);
                    col_init_1 = $signed($signed((mv_addr_col_sign_extend_r << 3) + 8'sd10) + col_offset_sign_extend_r);
                end
                3:
                begin
                    row_init_0 = $signed($signed((mv_addr_row_sign_extend_r << 3)) + row_offset_sign_extend_r);
                    col_init_0 = $signed($signed((mv_addr_col_sign_extend_r << 3) - 8'sd2) + col_offset_sign_extend_r);
                    row_init_1 = $signed($signed((mv_addr_row_sign_extend_r << 3) + 8'sd10) + row_offset_sign_extend_r);
                    col_init_1 = $signed($signed((mv_addr_col_sign_extend_r << 3) - 8'sd1) + col_offset_sign_extend_r);
                end
                4:
                begin
                    row_init_0 = $signed($signed((mv_addr_row_sign_extend_r << 3) - 8'sd2) + row_offset_sign_extend_r);
                    col_init_0 = $signed($signed((mv_addr_col_sign_extend_r << 3) - 8'sd2) + col_offset_sign_extend_r);
                    row_init_1 = $signed($signed((mv_addr_row_sign_extend_r << 3) + 8'sd10) + row_offset_sign_extend_r);
                    col_init_1 = $signed($signed((mv_addr_col_sign_extend_r << 3)) + col_offset_sign_extend_r);
                end
                5:
                begin
                    row_init_0 = $signed($signed((mv_addr_row_sign_extend_r << 3) - 8'sd2) + row_offset_sign_extend_r);
                    col_init_0 = $signed($signed((mv_addr_col_sign_extend_r << 3) - 8'sd2) + col_offset_sign_extend_r);
                    row_init_1 = $signed($signed((mv_addr_row_sign_extend_r << 3) + 8'sd8) + row_offset_sign_extend_r);
                    col_init_1 = $signed($signed((mv_addr_col_sign_extend_r << 3) - 8'sd1) + col_offset_sign_extend_r);
                end
                6:
                begin
                    row_init_0 = $signed($signed((mv_addr_row_sign_extend_r << 3) - 8'sd2) + row_offset_sign_extend_r);
                    col_init_0 = $signed($signed((mv_addr_col_sign_extend_r << 3) + 8'sd9) + col_offset_sign_extend_r);
                    row_init_1 = $signed($signed((mv_addr_row_sign_extend_r << 3) + 8'sd8) + row_offset_sign_extend_r);
                    col_init_1 = $signed($signed((mv_addr_col_sign_extend_r << 3) + 8'sd10) + col_offset_sign_extend_r);
                end
            endcase
        end
        READ_NEW_BLOCK2: // read new search block (component 2 of L size block)
        begin
            case(counter_min_r)
                2:
                begin
                    row_init_0 = $signed($signed((mv_addr_row_sign_extend_r << 3) - 8'sd2) + row_offset_sign_extend_r);
                    col_init_0 = $signed($signed((mv_addr_col_sign_extend_r << 3) - 8'sd2) + col_offset_sign_extend_r);
                    row_init_1 = $signed($signed((mv_addr_row_sign_extend_r << 3)) + row_offset_sign_extend_r);
                    col_init_1 = $signed($signed((mv_addr_col_sign_extend_r << 3) + 8'sd10) + col_offset_sign_extend_r);
                end
                3:
                begin
                    row_init_0 = $signed($signed((mv_addr_row_sign_extend_r << 3) - 8'sd2) + row_offset_sign_extend_r);
                    col_init_0 = $signed($signed((mv_addr_col_sign_extend_r << 3) - 8'sd2) + col_offset_sign_extend_r);
                    row_init_1 = $signed($signed((mv_addr_row_sign_extend_r << 3))  + row_offset_sign_extend_r);
                    col_init_1 = $signed($signed((mv_addr_col_sign_extend_r << 3) + 8'sd10) + col_offset_sign_extend_r);
                end
                5:
                begin
                    row_init_0 = $signed($signed((mv_addr_row_sign_extend_r << 3) + 8'sd8) + row_offset_sign_extend_r);
                    col_init_0 = $signed($signed((mv_addr_col_sign_extend_r << 3) - 8'sd2) + col_offset_sign_extend_r);
                    row_init_1 = $signed($signed((mv_addr_row_sign_extend_r << 3) + 8'sd10) + row_offset_sign_extend_r);
                    col_init_1 = $signed($signed((mv_addr_col_sign_extend_r << 3) + 8'sd10) + col_offset_sign_extend_r);
                end
                6:
                begin
                    row_init_0 = $signed($signed((mv_addr_row_sign_extend_r << 3) + 8'sd8) + row_offset_sign_extend_r);
                    col_init_0 = $signed($signed((mv_addr_col_sign_extend_r << 3) - 8'sd2) + col_offset_sign_extend_r);
                    row_init_1 = $signed($signed((mv_addr_row_sign_extend_r << 3) + 8'sd10) + row_offset_sign_extend_r);
                    col_init_1 = $signed($signed((mv_addr_col_sign_extend_r << 3) + 8'sd10) + col_offset_sign_extend_r);
                end
            endcase
        end
    endcase
    // caculate output
    if(state_r == INIT_READ_CUR || state_r == WRITE_DATA) begin
        // block size is 8x8 (fixed)
        pixel_counter_row_max_w = 8;
        pixel_counter_col_max_w = 8;
        // block address
        block_addr_row_w = (mv_addr_row_sign_extend_r << 3);
        block_addr_col_w = (mv_addr_col_sign_extend_r << 3);
    end
    else begin
        // default 
        row_0 = row_init_0;
        col_0 = col_init_0;
        row_1 = row_init_1;
        col_1 = col_init_1;
        pad_offset_row_w = 0;
        pad_offset_col_w = 0;
        // fixed p0 & p1 into frame range, also calculate p0 offset & block size
        if($signed(row_init_0) < 8'sd0) begin
            row_0 = 8'sd0;
            pad_offset_row_w = $signed(-row_init_0);
        end
        if($signed(col_init_0) < 8'sd0) begin
            col_0 = 8'sd0;
            pad_offset_col_w = $signed(-col_init_0);
        end
        if($signed(row_init_1) < 8'sd0) begin
            row_1 = 8'sd0;
        end
        if($signed(col_init_1) < 8'sd0) begin
            col_1 = 8'sd0;
        end
        if($signed(row_init_0) > 8'sd48) begin
            row_0 = 8'sd48;
        end
        if($signed(col_init_0) > 8'sd64) begin
            col_0 = 8'sd64;
        end
        if($signed(row_init_1) > 8'sd48) begin
            row_1 = 8'sd48;
        end
        if($signed(col_init_1) > 8'sd64) begin
            col_1 = 8'sd64;
        end
        pixel_counter_row_max_w = row_1 - row_0;
        pixel_counter_col_max_w = col_1 - col_0;
        block_addr_row_w = row_0;
        block_addr_col_w = col_0;
    end
end

always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        block_addr_row_r <= 0;
        block_addr_col_r <= 0;
        pixel_counter_row_max_r <= 0;
        pixel_counter_col_max_r <= 0;
        pad_offset_row_r <= 0;
        pad_offset_col_r <= 0; 
    end
    else begin
        block_addr_row_r <= block_addr_row_w;
        block_addr_col_r <= block_addr_col_w;
        pixel_counter_row_max_r <= pixel_counter_row_max_w;
        pixel_counter_col_max_r <= pixel_counter_col_max_w;
        pad_offset_row_r <= pad_offset_row_w;
        pad_offset_col_r <= pad_offset_col_w; 
    end
end

endmodule
