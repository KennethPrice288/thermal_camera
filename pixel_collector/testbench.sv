module testbench  (output logic error_o = 0
,output logic pass_o = 0);

    // Parameters
    localparam CLK_PERIOD = 25; // 40 MHz Clock for 640x480 @ 60Hz (25ns)
    

    // Parameters
    localparam pixel_bytes_p = 2;
    localparam pixel_width_p = pixel_bytes_p * 8;
    
    bit error = 0;

    // Clock and reset signals
    wire clk_i;
    reg reset_i;
    
    //inputs
    reg [7:0] data_i = 0;
    reg valid_i;
    reg ready_i;

    // Outputs
    wire valid_o;
    wire [15:0] pixel_o;

    logic sending_discards = 0;

    reg [pixel_width_p-1:0] input_image [input_height_p-1:0][input_width_p-1:0];
    reg [pixel_width_p-1:0] input_image_1d [(input_height_p * input_width_p)-1:0];
    reg [pixel_width_p-1:0] output_image [0:output_height_p-1][0:output_width_p-1];

    localparam string filename_p = "../../pattern_data.txt";
    localparam string fileout_p = "../../image_out.hex";
    localparam input_height_p = 60;
    localparam input_width_p = 80;
    localparam output_height_p = input_height_p;
    localparam output_width_p = input_width_p;
    integer file_id = 0;

    //instantiate pixel_collector dut
    pixel_collector
        #(.pixel_bytes_p(pixel_bytes_p))
    dut
        (.clk_i(clk_i)
        ,.reset_i(reset_i)
        ,.data_i(data_i)
        ,.valid_i(valid_i)
        ,.valid_o(valid_o)
        ,.ready_i(ready_i)
        ,.pixel_o(pixel_o));

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


        // Fill a test image
        $readmemh(filename_p, input_image_1d, 0, (input_height_p * input_width_p)-1);
        for (int y = 0; y < input_height_p; y++) begin
            for(int x = 0; x < input_width_p; x++) begin
                input_image[y][x] = input_image_1d[(y*input_width_p)+x];
            end
        end

        // Initialize Inputs
        reset_i = 1;
        valid_i = 0;
        ready_i = 0;
        // Wait 100 ns for global reset to finish
        #100;
        reset_i = 0;
        ready_i = 1;
        
        // Apply a test stimulus
        for(int y = 0; y < input_height_p; y++) begin
            for(int x = 0; x < input_width_p; x++) begin
                send_pixel(input_image[y][x]);
            end
        end

        #100;

        //capture output pixel values

        file_id = $fopen(fileout_p);
        if(file_id) begin
            for(int y = 0; y < output_height_p; y++) begin
                for(int x = 0; x < output_width_p; x++) begin
                    $fwrite(file_id, "%h ", output_image[y][x]);
                end
                $fwrite(file_id, "\n");
            end
        end


        #20;

        pass_o = 1; #1;
        $finish;
    end

    //Task to send a byte
    task send_byte(input [7:0] byte_i);
        begin
            @(negedge clk_i);
            data_i = byte_i;
            valid_i = 1;
            @(posedge clk_i); #1;
            valid_i = 0;
            data_i = 0;
        end
    endtask

    //Task to send a pixel
    task send_pixel(input [pixel_width_p-1:0] send_pixel_i);
        begin
            for(int i = pixel_bytes_p - 1; i >= 0 ; i--) begin
                send_byte(send_pixel_i[(i*8) +:8]);
            end
        end
    endtask

    int x_o = 0;
    int y_o = 0;

    always_ff @(posedge clk_i) begin
        if (reset_i) begin
            x_o <= 0;
            y_o <= 0;
        end else if (ready_i & valid_o) begin
            // Capture the pixel and store in the output image memory
            output_image[y_o][x_o] <= pixel_o;
    
            // Update the x and y coordinates
            if (x_o == output_width_p - 1) begin
                x_o <= 0;
                if (y_o == output_height_p - 1) begin
                    y_o <= 0;
                end else begin
                    y_o <= y_o + 1;
                end
            end else begin
                x_o <= x_o + 1;
            end
        end
    end

endmodule
