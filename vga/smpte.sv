module smpte
  #(parameter pixel_bits_p = 4)
  (input [0:0] clk_i
  ,input [0:0] reset_i
  ,input [0:0] ready_i
  ,output logic [2:0][pixel_bits_p-1:0] data_o);

  localparam LINE = 639;
  localparam SCREEN = 479;

  logic [9:0] horizontal_pos;
  logic [9:0] vertical_pos;
  typedef logic [pixel_bits_p-1:0] color_t;
  typedef struct packed {
    color_t red;
    color_t green;
    color_t blue;
  } RGB;
  localparam RGB WHITE = {4'hF, 4'hF, 4'hF};
  localparam RGB YELLOW = {4'hF, 4'hF, 4'h0};
  localparam RGB CYAN = {4'h0, 4'hF, 4'hF};
  localparam RGB GREEN = {4'h0, 4'hF, 4'h0};
  localparam RGB MAGENTA = {4'hF, 4'h0, 4'hF}; 
  localparam RGB RED = {4'hF,4'h0,4'h0};
  localparam RGB BLUE = {4'h0, 4'h0, 4'hF};
  localparam RGB BLACK = {4'h0, 4'h0, 4'h0};

  always_ff @(posedge clk_i) begin
    if(reset_i) begin
      horizontal_pos <= 0;
      vertical_pos <= 0;
    end
    else if(horizontal_pos == LINE && ready_i) begin
      horizontal_pos <= 0;
      vertical_pos <= (vertical_pos == SCREEN) ? 0 : vertical_pos + 1;
    end else if(ready_i) begin
      horizontal_pos <= horizontal_pos + 1;
    end
  end

  RGB current_color;

  //else if block is like the worst possible way to do this
  always_comb begin
      current_color = BLACK;

      if (ready_i) begin
        if (vertical_pos <= 440) begin
          if (horizontal_pos <= 91) begin
            current_color = WHITE;
          end else if (horizontal_pos <= 183) begin
            current_color = YELLOW;
          end else if (horizontal_pos <= 275) begin
            current_color = CYAN;
          end else if (horizontal_pos <= 367) begin
            current_color = GREEN;
          end else if (horizontal_pos <= 469) begin
            current_color = MAGENTA;
          end else if (horizontal_pos <= 561) begin
            current_color = RED;
          end else if (horizontal_pos <= 640) begin
            current_color = BLUE;
          end
        end else if (vertical_pos > 440) begin
          if (horizontal_pos <= 80) begin
            current_color = BLACK;
          end else if (horizontal_pos <= 140) begin
            current_color = WHITE;
          end else begin
            current_color = BLACK;
          end
        end
      end

      data_o[0] = current_color.red;
      data_o[1] = current_color.green;
      data_o[2] = current_color.blue;
  end




endmodule
