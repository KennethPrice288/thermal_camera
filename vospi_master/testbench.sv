module testbench  (output logic error_o = 0
,output logic pass_o = 0);

    // Parameters
    localparam CLK_PERIOD = 25; // 40 MHz Clock for 640x480 @ 60Hz (25ns)
    

    // Parameters
    localparam packet_bytes_p = 164;
    localparam frame_packets_p = 60;
    localparam pixel_bytes_p = 2;
    localparam pixel_width_p = pixel_bytes_p * 8;
    
    // Clock and reset signals
    wire clk_i;
    reg reset_i;
    
    // Inputs
    reg start_i;
    reg miso_i;
    
    // Outputs
    wire sclk_o;
    wire cs_o;
    wire [7:0] data_o;
    wire valid_o;

    logic sending_discards = 0;

    reg [pixel_width_p-1:0] input_image [input_height_p-1:0][input_width_p-1:0];
    reg [pixel_width_p-1:0] input_image_1d [(input_height_p * input_width_p)-1:0];
    reg [pixel_width_p-1:0] output_image [0:output_height_p-1][0:output_width_p-1];

    localparam string filename_p = "../../pattern_data.hex";
    localparam string fileout_p = "../../image_out.hex";
    localparam input_height_p = 60;
    localparam input_width_p = 80;
    localparam output_height_p = input_height_p;
    localparam output_width_p = input_width_p;
    integer file_id = 0;
    logic [pixel_width_p-1:0] sent_pixel;


    //instantiate vospi_master dut
    vospi_master #(
        .packet_bytes_p(packet_bytes_p),
        .frame_packets_p(frame_packets_p),
        .sync_idle_cycles_p(10) //extremely low sync idle for easy testing
    ) dut (
        .clk_i(clk_i)
        ,.reset_i(reset_i)
        ,.start_i(start_i)
        ,.miso_i(miso_i)
        ,.sclk_o(sclk_o)
        ,.cs_o(cs_o)
        ,.data_o(data_o)
        ,.valid_o(valid_o)
    );

    logic pixel_valid_o;
    logic [(8*pixel_bytes_p)-1:0] pixel_o;
    pixel_collector #(
        .pixel_bytes_p(pixel_bytes_p)
    ) pixel_collector_inst (
        .clk_i(clk_i)
       ,.reset_i(reset_i)
       ,.data_i(data_o)
       ,.valid_i(valid_o)
       ,.valid_o(pixel_valid_o)
       ,.ready_i(1'b1)
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
        $readmemh(filename_p, input_image_1d);
        for (int y = 0; y < input_height_p; y++) begin
            for(int x = 0; x < input_width_p; x++) begin
                input_image[y][x] = input_image_1d[(y*input_width_p)+x];
            end
        end

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

        @(negedge clk_i); 
        sending_discards = 1;
        send_packet(16'h0F00); // Simulate discard packet
        sending_discards = 0;

        send_frame();
        sending_discards = 1;
        send_packet(16'h0F00);
        sending_discards = 0;

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
        $display("Sending id byte %h", id_msb);
        send_byte(id_msb);
        $display("Sending id byte %h", id_lsb);
        send_byte(id_lsb);
    
        // Send CRC (dummy, not calculated here)
        $display("Sending crc byte %h", id_msb);
        send_byte(id_msb);
        $display("Sending crc byte %h", id_lsb);
        send_byte(id_lsb);

        // Send payload data
        for(integer x = 0; x < input_width_p; x++) begin
            if(id == 16'h0F00) begin
                send_byte(8'h00);
                send_byte(8'h00);
                sent_pixel = 16'hxxxx;
            end else begin
                sent_pixel = input_image[id][x];
                send_byte(input_image[id][x][15:8]);
                send_byte(input_image[id][x][7:0]);
            end

        end
    end
endtask

task send_frame;
    begin
        for(logic [15:0] i = 0; i < input_height_p; i++) begin
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

int x_o = 0;
int y_o = 0;

always_ff @(posedge clk_i) begin
    if (reset_i) begin
        x_o <= 0;
        y_o <= 0;
    end else if (pixel_valid_o) begin
        // Capture the pixel and store in the output image memory
        if((x_o < input_width_p & y_o < input_height_p)) begin
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
end

endmodule
