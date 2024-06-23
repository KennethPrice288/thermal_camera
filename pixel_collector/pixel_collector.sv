module pixel_collector
    #(parameter pixel_bytes_p = 2)
    (
        input clk_i,
        input reset_i,
        input [7:0] data_i,
        input valid_i, //from the vospi_master indicating a valid byte output
        output valid_o,
        input ready_i,
        output [(8 * pixel_bytes_p) - 1:0] pixel_o
    );

    reg [(8*pixel_bytes_p)-1:0] pixel_buff_r;
    logic [(8*pixel_bytes_p)-1:0] pixel_buff_n;
    reg [$clog2(pixel_bytes_p):0] byte_count_r;
    logic [$clog2(pixel_bytes_p):0] byte_count_n;

    logic valid_r;
    wire [(8*pixel_bytes_p)-1:0] fifo_data_li = pixel_buff_r;

    always_ff @(posedge clk_i) begin
        if(reset_i) begin
            byte_count_r <= 0;
            pixel_buff_r <= 0;
            valid_r <= 0;
        end else begin
            byte_count_r <= byte_count_n;
            pixel_buff_r <= pixel_buff_n;
            if(byte_count_r == pixel_bytes_p) begin
                valid_r <= 1;
            end else begin
                valid_r <= 0;
            end

            if (ready_i && valid_r)
                valid_r <= 0;
        end
    end

    always_comb begin
        byte_count_n = byte_count_r;
        pixel_buff_n = pixel_buff_r;
        if(valid_i) begin
            byte_count_n = byte_count_r + 1;
            pixel_buff_n = {pixel_buff_r[(8*pixel_bytes_p)-1 - 8:0], data_i};
        end
        if(byte_count_r == pixel_bytes_p) byte_count_n = 0;
    end

    assign valid_o = valid_r;
    assign pixel_o = pixel_buff_r;

endmodule
