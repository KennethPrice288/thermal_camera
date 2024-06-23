module shift_register
    #(parameter width_p = 16)
(
    input clk_i,
    input reset_i,
    input data_i,
    input shift_i,
    output [width_p-1:0] data_o
);

    reg [width_p-1:0] shift_r;
    reg [width_p-1:0] shift_n;
    assign data_o = shift_r;

    always_ff @(posedge clk_i) begin
        if(reset_i) begin
            shift_r <= 0;
        end else begin
            shift_r <= shift_n;
        end
    end

    always_comb begin
        shift_n = shift_r;
        if(shift_i) begin
            shift_n = {shift_r[width_p-2:0], data_i};
        end
    end

endmodule
