module testbench  (output logic error_o = 0
,output logic pass_o = 0);

    bit error = 0;
    
    //parameters
    localparam pixel_bytes_p = 2;
    localparam pixel_width_p = 8*pixel_bytes_p;
    localparam line_pixels_p = 640;
    localparam frame_lines_p = 480;
    localparam frame_size_lp = line_pixels_p * frame_lines_p;

    //inputs
    wire clk_i;
    reg reset_i;
    reg [(8 * pixel_bytes_p)-1:0] pixel_i;
    reg valid_i;
    reg ready_i;

    //Outputs
    wire ready_o;
    wire [(8 * pixel_bytes_p) - 1:0] pixel_o;
    wire valid_o;

    //Instantiate DUT
    framebuffer 
        #(.pixel_bytes_p(pixel_bytes_p)
         ,.line_pixels_p(line_pixels_p)
         ,.frame_lines_p(frame_lines_p)
        ) dut (
            .clk_i(clk_i),
            .reset_i(reset_i),
            .pixel_i(pixel_i),
            .valid_i(valid_i),
            .ready_o(ready_o),
            .pixel_o(pixel_o),
            .ready_i(ready_i),
            .valid_o(valid_o)
        );

        logic [(8*pixel_bytes_p) - 1:0] pixel_expected [$];

        reg [pixel_width_p-1:0] input_image [frame_lines_p-1:0][line_pixels_p-1:0];
        reg [pixel_width_p-1:0] input_image_1d [(frame_lines_p * line_pixels_p)-1:0];
        reg [pixel_width_p-1:0] output_image [0:frame_lines_p-1][0:line_pixels_p-1];
    
        localparam string filename_p = "../../pattern_data.hex";
        localparam string fileout_p = "../../image_out.hex";
        integer file_id = 0;



    // Clock generator
    nonsynth_clock_gen #(.cycle_time_p(10)) clock_gen_inst(.clk_o(clk_i));
    // Testbench procedure
    initial begin
    `ifndef COCOTB
    `ifdef VERILATOR
        $dumpfile("verilator.vcd");
    `else
        $dumpfile("iverilog.vcd");
    `endif
        $dumpvars;
    `endif


        //Fill a test image
        $readmemh(filename_p, input_image_1d, 0, (frame_lines_p * line_pixels_p)-1);
        for (int y = 0; y < frame_lines_p; y++) begin
            for(int x = 0; x < line_pixels_p; x++) begin
                input_image[y][x] = input_image_1d[(y*line_pixels_p)+x];
            end
        end

        // Initialize Inputs
        reset_i = 1;
        valid_i = 0;
        ready_i = 0;
        // Wait 100 ns for global reset to finish
        #100;
        reset_i = 0;
        
        // Apply a test stimulus

        //Fill the framebuffer
        for(integer i = 0; i < 2; i++) begin
            write_frame();
        end
        @(negedge clk_i);
        //Read out the whole framebuffer
        for(integer i = 0; i < 2; i++) begin
            read_frame();
        end

        @(negedge clk_i);
        valid_i = 0;
        repeat(1000) @(negedge clk_i);

        // Write a frame from the input image
        for(int y = 0; y < frame_lines_p; y++) begin
            for(int x = 0; x < line_pixels_p; x++) begin
                @(negedge clk_i);
                valid_i = 1;
                pixel_i = input_image[y][x];
                wait(ready_o);
                @(posedge clk_i); #1;
            end    
        end
        valid_i = 0;

        // Read the frame to the output image
        read_frame(); //Ensure the framebuffer moves to the new frame
        for(int y = 0; y < frame_lines_p; y++) begin
            for(int x = 0; x < line_pixels_p; x++) begin
                @(negedge clk_i);
                ready_i = 1;
                wait(valid_o);
                @(posedge clk_i); #1;
                output_image[y][x] = pixel_o;
            end    
        end
        ready_i = 0;

        file_id = $fopen(fileout_p, "w");
        if(file_id) begin
            for(int y = 0; y < frame_lines_p; y++) begin
                for(int x = 0; x < line_pixels_p; x++) begin
                    $fwrite(file_id, "%h ", output_image[y][x]);
                end
                $fwrite(file_id, "\n");
            end
        end

        
        #20;
        if(error) error_o = 1;
        else pass_o = 1;
        #1;
        $finish;
    end

    //Task to write a frame
    task write_frame(); 
        begin
            for(int y = 0; y < frame_lines_p; y++) begin
                for(int x = 0; x < line_pixels_p; x++) begin
                @(negedge clk_i);
                pixel_i = x + y;
                pixel_expected.push_back(pixel_i);
                valid_i = 1;
                wait(ready_o);
                @(posedge clk_i) #1;
                end
            end
            //Signal end of valid data
            valid_i = 0;
        end
    endtask

    task read_frame();
        logic [(pixel_bytes_p * 8)-1:0] pixel_expected_l;
        begin
            for(int y = 0; y < frame_lines_p; y++) begin
                for(int x = 0; x < line_pixels_p; x++) begin
                    @(negedge clk_i);
                    ready_i = 1;
                    wait(valid_o);
                    @(posedge clk_i); #1;
                    pixel_expected_l = pixel_expected.pop_front();
                    if (pixel_o !== pixel_expected_l) begin
                        $display("ERROR: Mismatch time %t at pixel %0d %0d. Expected: %h, Got: %h", $time, x, y, pixel_expected_l, pixel_o);
                        error = 1;
                    end
                end
            end
           ready_i = 0; 
        end
    endtask

endmodule
