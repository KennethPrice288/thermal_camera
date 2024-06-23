module vga
  #(parameter pixel_bits_p = 4)
  (input [0:0] clk_i
  ,input [0:0] reset_i

  ,output [0:0] ready_o
  ,input [2:0][pixel_bits_p-1:0] data_i

  ,output [0:0] hsync_o
  ,output [0:0] vsync_o
  ,output [0:0] disp_en_o
  ,output [2:0][pixel_bits_p-1:0] data_o
  );

  logic hsync;
  logic vsync;
  logic de;
  reg [9:0] sx_r;
  reg [9:0] sx_n;
  reg [9:0] sy_r;
  reg [9:0] sy_n;

// horizontal timings
    parameter HA_END = 639;           // end of active pixels
    parameter HS_STA = HA_END + 16;   // sync starts after front porch
    parameter HS_END = HS_STA + 96;   // sync ends
    parameter LINE   = 799;           // last pixel on line (after back porch)

    // vertical timings
    parameter VA_END = 479;           // end of active pixels
    parameter VS_STA = VA_END + 10;   // sync starts after front porch
    parameter VS_END = VS_STA + 2;    // sync ends
    parameter SCREEN = 524;           // last line on screen (after back porch)

    always_comb begin
        sy_n = sy_r;
        sx_n = sx_r;
        hsync = (sx_r >= HS_STA && sx_r < HS_END);  // invert: negative polarity
        vsync = (sy_r >= VS_STA && sy_r < VS_END);  // invert: negative polarity
        de = (sx_r <= HA_END && sy_r <= VA_END);
        if(sx_r == LINE) begin
            sx_n = 0;
            sy_n = (sy_r == SCREEN) ? 0 : sy_r + 10'b1;
        end else begin
            sx_n = sx_r + 10'b1;
        end
    end

    // calculate horizontal and vertical screen position
    always_ff @(posedge clk_i) begin
        if (reset_i) begin
            sx_r <= 0;
            sy_r <= 0;
        end else begin
            sx_r <= sx_n;
            sy_r <= sy_n;
        end
    end

  assign hsync_o = ~hsync;
  assign vsync_o = ~vsync;
  assign disp_en_o = de;
  assign data_o = data_i;
  assign ready_o = de;

endmodule
