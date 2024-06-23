module testbench  (output logic error_o = 0
,output logic pass_o = 0);

    bit error = 0;
    
    //parameters
    localparam pixel_width_p = 16;
    localparam input_width_p = 80;
    localparam input_height_p = 60;
    localparam output_width_p = 640;
    localparam output_height_p = 480;


    //inputs
    wire clk_i;
    logic reset_i;
    logic [pixel_width_p-1:0] pixel_i;
    logic valid_i;
    logic ready_i;

    //Outputs
    wire ready_o;
    wire [pixel_width_p - 1:0] pixel_o;
    wire valid_o;

    integer out_y = 0;
    integer out_x = 0;
    reg [pixel_width_p-1:0] input_image [input_height_p-1:0][input_width_p-1:0];
    reg [pixel_width_p-1:0] input_image_1d [(input_height_p * input_width_p)-1:0];
    reg [pixel_width_p-1:0] output_image [0:output_height_p-1][0:output_width_p-1];

    localparam string filename_p = "../../pattern_data.hex";
    localparam string fileout_p = "../../image_out.hex"
    integer file_id = 0;

    //Instantiate DUT
    image_scaler
        #(.pixel_width_p(pixel_width_p)
         ,.input_width_p(input_width_p)
         ,.input_height_p(input_height_p)
         ,.output_width_p(output_width_p)
         ,.output_height_p(output_height_p)
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

        // Initialize Inputs
        reset_i = 1;
        valid_i = 0;
        ready_i = 0;
        // Wait 100 ns for global reset to finish
        #100;
        reset_i = 0;

        //Fill a test image
        $readmemh(filename_p, input_image_1d, 0, (input_height_p * input_width_p)-1);
        for (int y = 0; y < input_height_p; y++) begin
            for(int x = 0; x < input_width_p; x++) begin
                input_image[y][x] = input_image_1d[(y*input_width_p)+x];
            end
        end
        // Apply a test stimulus

        //input pixels
        for(int y = 0; y < input_height_p; y++) begin
            for(int x = 0; x < input_width_p; x++) begin
                @(negedge clk_i);
                valid_i = 1;
                ready_i = 0;
                pixel_i = input_image[y][x];
                @(posedge clk_i); #1;
            end
        end
        valid_i = 0;

        //capture output pixel values
        ready_i = 1;

        while(valid_o) begin
            @(negedge clk_i);
            output_image[out_y][out_x] = pixel_o;
            if(out_x == output_width_p-1) begin
                out_x = 0;
                out_y = out_y + 1;
            end else begin
                out_x = out_x + 1;
            end
            @(posedge clk_i); #1;
        end
        ready_i = 0;

        file_id = $fopen("/Users/kennethprice/Documents/Personal_Projects/AnCam/hdl_source/image_scaler/output_image.hex", "w");
        if(file_id) begin
            for(int y = 0; y < output_height_p; y++) begin
                for(int x = 0; x < output_width_p; x++) begin
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

endmodule
