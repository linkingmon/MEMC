module process_ctrl(
    clk,
    rst_n,
    frame_id,
    block_id,
    frame_done,
    block_done,
    frame_inc
);

input clk;
input rst_n;

output reg [3:0] frame_id; // 1 ~ 9 ; is the current calculating frame
output reg [5:0] block_id; // 0 ~ 47 ; is the current calculating block
output reg frame_inc;
input frame_done;
input block_done;

always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        frame_id <= 1;
        block_id <= 0;
        frame_inc <= 0;
    end
    else begin
        frame_inc <= 0;
        frame_id <= frame_id;
        block_id <= block_id;
        if(block_done)
            block_id <= block_id + 1;
        if(frame_done) begin
            block_id <= 0;
            frame_id <= frame_id + 1;
            frame_inc <= 1;
        end
    end
end
endmodule