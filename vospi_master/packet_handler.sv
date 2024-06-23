module packet_handler
    #(parameter packet_bytes_p = 164
     ,parameter id_width_p = 16
     ,parameter crc_width_p = 16)
(
    input clk_i,
    input reset_i,
    input start_i,
    input miso_i,
    output [7:0] payload_o,
    output valid_o
)

    localparam id_bytes_lp = id_width_p / 8;
    localparam crc_bytes_lp = crc_width_p / 8;

    reg [7:0] payload_sr;
    reg payload_valid_r, payload_valid_n;

    wire [id_with_p-1:0] id_w;
    wire [crc_width_p-1:0] crc_w;

    logic read_id_l;
    logic read_crc_l;
    logic read_payload_l;

    shift_register #(id_width_p) id_shift_reg_inst (
        .clk_i(clk_i),
        .reset_i(reset_i),
        .shift_i(read_id_l),
        .miso_i(miso_i),
        .data_o(id_w)
    );

    shift_register #(crc_width_p) crc_shift_reg_inst (
        .clk_i(clk_i),
        .reset_i(reset_i),
        .shift_i(read_crc_l),
        .miso_i(miso_i),
        .data_o(crc_w)
    )

    shift_register #()

endmodule
