module thermal_camera
  (input clk_i //Clock in. Master clock into sensor (48 MHz maximum)
  ,input reset_i
  ,input start_i
  ,input miso_i
  ,output sclk_o
  ,output cs_o
  ,output valid_o
  ,input ready_i
  ,output [15:0] data_o
  );

  localparam pixel_bytes_p = 2;
  localparam camera_width_p = 80;
  localparam camera_height_p = 60;
  localparam output_width_p = 640;
  localparam output_height_p = 480;

  //vospi signals
  wire [7:0] vospi_lo;
  wire vospi_valid_lo;

  //pixel collector signals
  wire pixel_collector_valid_lo;
  wire [(pixel_bytes_p * 8)-1:0] pixel_collector_data_lo;

  //image scaler signals
  wire image_scaler_ready_lo;
  wire [(8*pixel_bytes_p)-1:0] image_scaler_data_lo;
  wire image_scaler_valid_lo;

  //framebuffer signals
  wire framebuffer_ready_lo;
  wire [(8 * pixel_bytes_p)-1:0] framebuffer_data_lo;
  wire framebuffer_valid_lo;

  vospi_master
    #(.packet_bytes_p(164)
     ,.frame_packets_p(60)
    ) vospi_master_inst (
      .clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.start_i(start_i)
     ,.miso_i(miso_i)
     ,.sclk_o(sclk_o)
     ,.cs_o(cs_o)
     ,.data_o(vospi_lo)
     ,.valid_o(vospi_valid_lo)
    );

  pixel_collector
    #(.pixel_bytes_p(pixel_bytes_p)
    ) pixel_collector_inst (
      .clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.data_i(vospi_lo)
     ,.valid_i(vospi_valid_lo)
     ,.valid_o(pixel_collector_valid_lo)
     ,.ready_i(image_scaler_ready_lo)
     ,.pixel_o(pixel_collector_data_lo)
    );

    framebuffer
      #(.pixel_bytes_p(pixel_bytes_p)
      ,.line_pixels_p(camera_width_p)
      ,.frame_lines_p(camera_height_p))
      framebuffer_inst (
        .clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.pixel_i(pixel_collector_data_lo)
      ,.valid_i(pixel_collector_valid_lo)
      ,.ready_o(framebuffer_ready_lo)
      ,.pixel_o(framebuffer_data_lo)
      ,.ready_i(ready_i)
      ,.valid_o(framebuffer_valid_lo)
      );

    image_scaler
    #(.pixel_width_p(8 * pixel_bytes_p)
     ,.input_width_p(camera_width_p)
     ,.input_height_p(camera_height_p)
     ,.output_width_p(output_width_p)
     ,.output_height_p(output_height_p))
     image_scaler_inst (
      .clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.pixel_i(framebuffer_data_lo)
     ,.ready_o(image_scaler_ready_lo)
     ,.valid_i(framebuffer_valid_lo)
     ,.pixel_o(image_scaler_data_lo)
     ,.valid_o(valid_o)
     ,.ready_i(ready_i)
     );

    assign data_o = framebuffer_data_lo;

  
endmodule

