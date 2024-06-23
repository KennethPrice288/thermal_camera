`ifndef BINPATH
`define BINPATH ""
`endif

module testbench  (output logic error_o = 0
,output logic pass_o = 0);

    // Parameters
    localparam CLK_PERIOD = 25; // 40 MHz Clock for 640x480 @ 60Hz (25ns)
    

    // Parameters
    localparam packet_bytes_p = 164;
    localparam frame_packets_p = 60;
    localparam image_width_p = 80;
    localparam image_height_p = 60;
    logic [15:0] image_data [image_height_p-1:0][image_width_p-1:0];
    logic [15:0] image_data_1d [(image_width_p * image_height_p)-1:0];
    
    // Clock and reset signals
    wire clk_i;
    reg reset_i;
    
    // Inputs
    reg start_i;
    reg miso_i;
    reg ready_i;
    
    // Outputs
    wire sclk_o;
    wire cs_o;
    wire [15:0] data_o;

    logic sending_discards = 0;

    integer x = 0;
    integer y = 0;
    localparam output_width_p = 640;
    localparam output_height_p = 480;
    logic [15 :0] output_image [output_height_p-1:0][output_width_p-1:0];
    logic [15:0] sent_pixel;
    logic [15:0] received_pixel;

    localparam string filename_p = "../../pattern_data.hex";
    localparam string fileout_p = "../../image_out.hex";
    integer file_id = 0;

    //instantiate thermal camera dut
    thermal_camera
    thermal_camera_inst (
        .clk_i(clk_i)
       ,.reset_i(reset_i)
       ,.start_i(start_i)
       ,.miso_i(miso_i)
       ,.sclk_o(sclk_o)
       ,.cs_o(cs_o)
       ,.valid_o(valid_o)
       ,.ready_i(ready_i)
       ,.data_o(data_o)
    );

    // Clock generator
    nonsynth_clock_gen #(.cycle_time_p(10)) clock_gen_inst(.clk_o(clk_i));
    // Testbench procedure



    initial begin
        // Using readmemh to load pattern_data.txt
        $readmemh(filename_p, image_data_1d);
        for(int i = 0; i < image_height_p; i++) begin
            for(int j = 0; j < image_width_p; j++) begin
                image_data[i][j] = image_data_1d[(i*image_width_p) + j];
            end
        end
        #1;
    end
    

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
        start_i = 0;
        miso_i = 0;
        
        // Wait 100 ns for global reset to finish
        #100;
        reset_i = 0;
        // Apply a test stimulus
        @(negedge clk_i); start_i = 1;
        @(negedge clk_i); start_i = 0;
        ready_i = 1;
        send_frame();
        between_frames(5);
        @(posedge valid_o);
        repeat(350000) @(negedge clk_i);

        file_id = $fopen(fileout_p, "w"); // Open the file in write mode

        if (file_id) begin
            $display("Writing output image to file...");
            for (integer i = 0; i < output_height_p; i++) begin
                for (integer j = 0; j < output_width_p; j++) begin
                    $fwrite(file_id, "%h ", output_image[i][j]); // Write pixel data in hex
                    $display("wrote pixel %h", output_image[i][j]);
                end
                $fwrite(file_id, "\n"); // New line for each row
            end
            $fclose(file_id); // Close the file
            $display("Output image written to output_image.hex");
        end else begin
            $display("Error: Unable to open file for writing.");
        end


        pass_o = 1; #1;
        $finish;
    end

    // Task to send a byte via MISO
    task send_byte;
    input [7:0] byte_i;
    begin
        for (integer i = 0; i < 8; i++) begin
            @(negedge sclk_o);
            miso_i = byte_i[7-i];
            $display("Sending bit: %b of byte: %b", miso_i, byte_i);
            @(posedge sclk_o); #1;
        end
    end
    endtask

    // Task to send a packet
    task send_packet;
    input [15:0] id;
    logic [7:0] id_msb;
    logic [7:0] id_lsb;
    begin
        id_msb = id[15:8];
        id_lsb = id[7:0];
        // Send the ID
        send_byte(id_msb);
        send_byte(id_lsb);
    
        // Send CRC (dummy, not calculated here)
        send_byte(id_msb);
        send_byte(id_lsb);

        // Send pixel data
        for (integer i = 0; i < image_width_p; i++) begin
            sent_pixel = image_data[id][i];
            send_byte(image_data[id][i][15:8]); //MSB of pixel
            send_byte(image_data[id][i][7:0]); //LSB of pixel
        end
    
    end
endtask

task send_frame;
    begin
        for(logic [15:0] i = 0; i < image_height_p; i++) begin
            $display("Sending packet %d at time %t", i, $time);
            send_packet(i);
        end
    end
endtask

task between_frames;
    input integer x;
    begin
        integer random;
        sending_discards = 1;
        do begin
            random = $urandom_range(1, x);
            send_packet(16'h0F00);
        end while (random != 1);
        sending_discards = 0;
    end
endtask

// Capture valid data and store it in output_image
always @(posedge clk_i) begin
    if (valid_o && ready_i) begin
        if( (x < output_width_p) & (y < output_height_p)) begin
            output_image[y][x] = data_o;
            received_pixel = data_o;
            x = x + 1;
            if (x == output_width_p) begin
                x = 0;
                y = y + 1;
                if(y == output_height_p) begin
                    y = 0;
                end
            end
        end
    end
end

endmodule
