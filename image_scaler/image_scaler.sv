module image_scaler
    #(parameter pixel_width_p = 16
     ,parameter input_width_p = 80
     ,parameter input_height_p = 60
     ,parameter output_width_p = 640
     ,parameter output_height_p = 480)

(
    input clk_i,
    input reset_i,
    input [pixel_width_p-1:0] pixel_i,
    output logic ready_o,
    input valid_i,  // Valid signal for the input pixel
    output [pixel_width_p-1:0] pixel_o,  // Scaled 8-bit pixel value for 640x480 framebuffer
    output logic valid_o, // Valid signal for the output pixel
    input ready_i
);

    // Scaling factors
    parameter int scale_x_p = output_width_p / input_width_p;
    parameter int scale_y_p = output_height_p / input_height_p;

    // Internal registers
    reg [$clog2(input_width_p)-1:0] in_x_r;  // X-coordinate for input image
    logic [$clog2(input_width_p)-1:0] in_x_n;
    reg [$clog2(input_height_p)-1:0] in_y_r;  // Y-coordinate for input image
    logic [$clog2(input_height_p)-1:0] in_y_n;
    reg [$clog2(output_width_p)-1:0] out_x_r;  // X-coordinate for output image
    logic [$clog2(output_width_p)-1:0] out_x_n;
    reg [$clog2(output_height_p)-1:0] out_y_r;  // Y-coordinate for output image
    logic [$clog2(output_height_p)-1:0] out_y_n;

    logic [$clog2(input_width_p)-1:0] mem_x_idx;
    logic [$clog2(input_height_p)-1:0] mem_y_idx;

    // Pixel memory to store the input image (80 x 60)
    logic [pixel_width_p-1:0] pixel_mem [0:input_height_p-1][0:input_width_p-1];

    // State_r machine state_rs
    typedef enum logic [0:0] {
        READ_PIXELS,
        SCALE_PIXELS
    } state_r_t;

    state_r_t state_r, state_n;

    // State_r transition logic (combinational)
    always_comb begin
        state_n = state_r;
        case (state_r)
            READ_PIXELS: begin
                if (in_x_r == input_width_p-1 && in_y_r == input_height_p-1)
                    state_n = SCALE_PIXELS;
            end
            SCALE_PIXELS: begin
                if (out_x_r == output_width_p-1 && out_y_r == output_height_p-1)
                    state_n = READ_PIXELS;
            end
        endcase
    end



    //flops
    always_ff @(posedge clk_i) begin
        if (reset_i) begin
            state_r <= READ_PIXELS;
            in_x_r <= 0;
            in_y_r <= 0;
            out_x_r <= 0;
            out_y_r <= 0;
        end else begin
            state_r <= state_n;
            in_x_r <= in_x_n;
            in_y_r <= in_y_n;
            out_x_r <= out_x_n;
            out_y_r <= out_y_n;
            if(state_r == READ_PIXELS & valid_i)
                pixel_mem[in_y_r][in_x_r] <= pixel_i;
        end
    end

    always_comb begin
        in_x_n = in_x_r;
        in_y_n = in_y_r;
        out_x_n = out_x_r;
        out_y_n = out_y_r;
        valid_o = 0;
        ready_o = 0;
        mem_y_idx = (out_y_r >> $clog2(scale_y_p));
        mem_x_idx = (out_x_r >> $clog2(scale_x_p));

        case(state_r)
            READ_PIXELS: begin
                ready_o = 1;
                if (valid_i) begin
                    if(in_x_r == input_width_p-1) begin
                        in_x_n = 0;
                        in_y_n = in_y_r + 1;
                    end else begin
                        in_x_n = in_x_r + 1;
                    end
                end
            end
            SCALE_PIXELS: begin
                valid_o = 1;
                if(ready_i) begin
                    if(out_x_r == output_width_p-1) begin
                        out_x_n = 0;
                        if(out_y_r == output_height_p) begin
                            out_y_n = 0;
                        end else begin
                            out_y_n = out_y_r + 1;
                        end
                    end else begin
                        out_x_n = out_x_r + 1;
                    end
                end
        end

            default:;

            endcase
    end

    assign pixel_o = pixel_mem[mem_y_idx][mem_x_idx];


endmodule
