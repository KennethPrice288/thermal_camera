module framebuffer 
    #(parameter pixel_bytes_p = 2,
      parameter line_pixels_p = 5,
      parameter frame_lines_p = 5)
(
    input clk_i,
    input reset_i,
    input [(8 * pixel_bytes_p) - 1:0] pixel_i,
    input valid_i,
    output ready_o,
    output [(8 * pixel_bytes_p) - 1:0] pixel_o,
    input ready_i,
    output valid_o
);

    localparam frame_size_lp = line_pixels_p * frame_lines_p; // 25
    typedef enum logic [1:0] {
        FRAME_0 = 2'b00,
        FRAME_1 = 2'b01,
        FRAME_2 = 2'b10
    } frame_t;

    // Address and control registers
    reg [$clog2(frame_size_lp)-1:0] wr_addr_r, rd_addr_r;
    logic [$clog2(frame_size_lp)-1:0] wr_addr_n, rd_addr_n;

    reg wr_en_r;
    logic wr_en_n;
    
    reg [2:0] frame_done_r; // One bit per frame
    logic [2:0] frame_done_n;

    frame_t wr_frame_r, rd_frame_r;
    frame_t wr_frame_n, rd_frame_n;

    // Data wires for memory instances
    wire [(pixel_bytes_p * 8)-1:0] rd_data_w;
    wire [(pixel_bytes_p * 8)-1:0] rd_data_0_w;
    wire [(pixel_bytes_p * 8)-1:0] rd_data_1_w;
    wire [(pixel_bytes_p * 8)-1:0] rd_data_2_w;

    // Ready and valid signals
    reg ready_r;
    logic ready_n;
    reg valid_r;
    logic valid_n;

    // Memory instances for three frames
    ram_1r1w_sync
        #(.width_p(pixel_bytes_p * 8),
          .depth_p(frame_size_lp))
    framebuffer_0_mem_inst
        (.clk_i(clk_i),
         .reset_i(reset_i),
         .wr_valid_i(wr_en_n & (wr_frame_r == FRAME_0)),
         .wr_data_i(pixel_i),
         .wr_addr_i(wr_addr_r),
         .rd_valid_i(rd_frame_r == FRAME_0),
         .rd_addr_i(rd_addr_r),
         .rd_data_o(rd_data_0_w));

    ram_1r1w_sync
        #(.width_p(pixel_bytes_p * 8),
          .depth_p(frame_size_lp))
    framebuffer_1_mem_inst
        (.clk_i(clk_i),
         .reset_i(reset_i),
         .wr_valid_i(wr_en_n & (wr_frame_r == FRAME_1)),
         .wr_data_i(pixel_i),
         .wr_addr_i(wr_addr_r),
         .rd_valid_i(rd_frame_r == FRAME_1),
         .rd_addr_i(rd_addr_r),
         .rd_data_o(rd_data_1_w));

    ram_1r1w_sync
        #(.width_p(pixel_bytes_p * 8),
          .depth_p(frame_size_lp))
    framebuffer_2_mem_inst
        (.clk_i(clk_i),
         .reset_i(reset_i),
         .wr_valid_i(wr_en_n & (wr_frame_r == FRAME_2)),
         .wr_data_i(pixel_i),
         .wr_addr_i(wr_addr_r),
         .rd_valid_i(rd_frame_r == FRAME_2),
         .rd_addr_i(rd_addr_r),
         .rd_data_o(rd_data_2_w));
    
    // Write state registers
    always_ff @(posedge clk_i) begin
        if (reset_i) begin
            wr_addr_r <= 0;
            wr_frame_r <= FRAME_0;
            frame_done_r <= 3'b000;
            ready_r <= 1;
            wr_en_r <= 0;
        end else begin
            wr_addr_r <= wr_addr_n;
            wr_frame_r <= wr_frame_n;
            frame_done_r <= frame_done_n;
            ready_r <= ready_n;
            wr_en_r <= wr_en_n;
        end
    end

    // Read state registers
    always_ff @(posedge clk_i) begin
        if (reset_i) begin
            rd_addr_r <= 0;
            rd_frame_r <= FRAME_0; // Start from FRAME_0, corrected initialization
            valid_r <= 0;
        end else begin
            rd_addr_r <= rd_addr_n;
            rd_frame_r <= rd_frame_n;
            valid_r <= valid_n;
        end
    end

    // Write logic
    always_comb begin
        wr_addr_n = wr_addr_r;
        wr_frame_n = wr_frame_r;
        frame_done_n = frame_done_r;
        ready_n = ready_r;
        wr_en_n = 0;

        if (ready_o && valid_i) begin
            wr_en_n = 1;
            if (wr_addr_r == frame_size_lp - 1) begin
                wr_addr_n = 0;
                wr_frame_n = (wr_frame_r == FRAME_2) ? FRAME_0 : wr_frame_r + 1;
                if(wr_frame_n == rd_frame_r) begin
                    wr_frame_n = wr_frame_r;
                end
                else begin 
                    frame_done_n[wr_frame_r] = 1; 
                    frame_done_n[wr_frame_n] = 0; // Clear the next frame's done status
                end
            end else begin
                wr_addr_n = wr_addr_r + 1;
                ready_n = 1;
            end
        end
    end

    // Read logic
    always_comb begin
        rd_addr_n = rd_addr_r;
        rd_frame_n = rd_frame_r;
        valid_n = frame_done_r[rd_frame_r];

        if (ready_i & valid_o) begin
            if (rd_addr_r == frame_size_lp - 1) begin
                rd_addr_n = 0;
                rd_frame_n = (rd_frame_r == FRAME_2) ? FRAME_0 : rd_frame_r + 1;
                if(~frame_done_r[rd_frame_n]) rd_frame_n = rd_frame_r;
            end else begin
                rd_addr_n = rd_addr_r + 1;
            end
        end else begin
            valid_n = frame_done_r[rd_frame_r];
        end
    end

    // Select read data
    assign rd_data_w = (rd_frame_r == FRAME_0) ? rd_data_0_w :
                       (rd_frame_r == FRAME_1) ? rd_data_1_w :
                       (rd_frame_r == FRAME_2) ? rd_data_2_w :
                       {pixel_bytes_p*8{1'b0}};

    assign ready_o = ready_r;
    assign valid_o = valid_n;
    assign pixel_o = rd_data_w;

endmodule
