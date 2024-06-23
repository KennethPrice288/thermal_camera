module testbench  (output logic error_o = 0
,output logic pass_o = 0);;

    // Parameters
    localparam CLK_PERIOD = 25; // 40 MHz Clock for 640x480 @ 60Hz (25ns)
    
    // Signals
    reg clk_i;
    reg reset_i;
    reg [11:0] data_i;
    wire ready_o;
    wire disp_en_o;
    wire hsync_o;
    wire vsync_o;
    wire [11:0] data_o;
    
    // Instantiate the VGA controller
    vga uut (
        .clk_i(clk_i),
        .reset_i(reset_i),
        .data_i(data_i),
        .ready_o(ready_o),
        .disp_en_o(disp_en_o),
        .hsync_o(hsync_o),
        .vsync_o(vsync_o),
        .data_o(data_o)
    );
    
    // Clock generator
    initial begin
        clk_i = 0;
        forever #(CLK_PERIOD / 2) clk_i = ~clk_i;
    end
    
    // Testbench procedure
    initial begin
        // Initialize signals
        reset_i = 1;
        data_i = 12'h0;
        
        // Hold reset for a few cycles
        #(10 * CLK_PERIOD);
        reset_i = 0;

        // Set some initial pixel data for testing
        #(10 * CLK_PERIOD);
        data_i = 12'hF00; // Red

        // Wait for some time to observe the output
        #(1000000);

        // End of simulation
        $finish;
    end
    
    // Monitor signals
    initial begin
        $monitor("Time: %0t | hsync_o: %0b, vsync_o: %0b, disp_en_o: %0b, data_o: %h, ready_o: %0b",
                 $time, hsync_o, vsync_o, disp_en_o, data_o, ready_o);
    end
    
    // Dump waves for viewing
    initial begin
        $dumpfile("testbench.vcd");
        $dumpvars(0, testbench);
    end
endmodule
