module vospi_master 
    #(parameter packet_bytes_p = 164 //bytes in a line
     ,parameter frame_packets_p = 60 //packets in a frame
     ,parameter sync_idle_cycles_p = 5000000
     )
(
  input clk_i,
  input reset_i,
  input start_i,
  input miso_i,
  output sclk_o,
  output cs_o,
  output [7:0] data_o, // Output frame data 1 byte at a time
  //ready valid & interface on the consuming side
  output valid_o
);

  localparam id_byte_count_lp = 2;
  localparam crc_byte_count_lp = 2;

  reg [$clog2(frame_packets_p)-1:0] frame_packets_r;
  reg [$clog2(frame_packets_p)-1:0] frame_packets_n;
  reg [$clog2(packet_bytes_p)-1:0] packet_byte_count_r; // Counter for bytes in a packet
  reg [$clog2(packet_bytes_p)-1:0] packet_byte_count_n;
  reg [$clog2(sync_idle_cycles_p)-1:0] sync_count_r; // counter for number of cycles sleeping for sync
  reg [$clog2(sync_idle_cycles_p)-1:0] sync_count_n;
  reg [3:0] byte_count_r; //counter for location in byte while reading MISO
  reg [3:0] byte_count_n;

  reg cs_r;
  reg cs_n;
  logic sclk_l;
  reg valid_r;
  reg valid_n;

  reg [7:0] payload_sr;
  reg [7:0] payload_sn;
  reg [7:0] payload_r;
  reg [7:0] payload_n;
  reg [15:0] id_r;
  reg [15:0] id_n;
  reg [15:0] id_sr; //packet id shift register
  reg [15:0] id_sn; //packet id shift next
  reg [15:0] crc_r;
  reg [15:0] crc_n;
  reg [15:0] crc_sr; //packet crc shift register
  reg [15:0] crc_sn; //packet crc shift next
  logic read_id_l;
  logic read_crc_l;
  logic read_payload_l;

  assign cs_o = cs_r;
  assign sclk_o = sclk_l;
  assign data_o = payload_r;
  assign valid_o = valid_r;

  //state encoding
  typedef enum logic [2:0] {
    IDLE = 3'b000,
    SYNC_IDLE = 3'b001,
    SYNC_SETUP = 3'b010,
    SYNC_RECV = 3'b011,
    FRAME_RECV = 3'b100
  } state_t;

  state_t state_r, state_n;

  always_ff @(posedge clk_i) begin
    if(reset_i) begin
        state_r <= IDLE;
        packet_byte_count_r <= 0;
        frame_packets_r <= 0;
        sync_count_r <= 0;
        byte_count_r <= 0;
        cs_r <= 1;
        payload_sr <= 0;
        payload_r <= 0;
        id_r <= 16'h0F00; //simulate discard packet on reset
        crc_r <= 16'h0000;
        id_sr <= 16'h0000;
        crc_sr <= 16'h0000;
        valid_r <= 1'b0;
    end else begin
        state_r <= state_n;
        packet_byte_count_r <= packet_byte_count_n;
        frame_packets_r <= frame_packets_n;
        sync_count_r <= sync_count_n;
        byte_count_r <= byte_count_n;
        cs_r <= cs_n;
        payload_sr <= payload_sn;
        payload_r <= payload_n;
        id_r <= id_n;
        crc_r <= crc_n;
        id_sr <= id_sn;
        crc_sr <= crc_sn;
        valid_r <= valid_n;
    end
  end

  always_comb begin
    state_n = state_r;
    packet_byte_count_n = packet_byte_count_r;
    frame_packets_n = frame_packets_r;
    sync_count_n = sync_count_r;
    byte_count_n = byte_count_r;
    cs_n = cs_r;
    payload_sn = payload_sr;
    payload_n = payload_r;
    id_n = id_r;
    crc_n = crc_r;
    id_sn = id_sr;
    crc_sn = crc_sr;
    valid_n = valid_r;
    read_id_l = 0;
    read_crc_l = 0;
    read_payload_l = 0;
    sclk_l = 1'b1; //default to sclk_l idle
    
    case (state_r)
        IDLE: begin
            if(start_i) begin
                packet_byte_count_n = 0;
                sync_count_n = 0;
                state_n = SYNC_IDLE;
            end
        end

        SYNC_IDLE: begin
            cs_n = 1'b1; //deassert CS
            sclk_l = 1'b1; //idle sclk
            sync_count_n = sync_count_r + 1;
            if(sync_count_r > sync_idle_cycles_p) begin
                sync_count_n = 0;
                state_n = SYNC_SETUP;
            end
        end

        SYNC_SETUP: begin
            cs_n = 1'b0; //assert cs_o
            sclk_l = 1'b1; //leave sclk idle
            state_n = SYNC_RECV;
        end

        SYNC_RECV: begin
            // SPI reception logic
            // Perform synchronization data reception here
            // Once synchronization complete, move to FRAME_RECV
            cs_n = 1'b0; //assert cs_o
            sclk_l = clk_i; //enable sclk
            read_id_l = packet_byte_count_r < id_byte_count_lp;
            read_crc_l = (packet_byte_count_r >= id_byte_count_lp) & (packet_byte_count_r < (id_byte_count_lp + crc_byte_count_lp));
            read_payload_l = packet_byte_count_r >= (id_byte_count_lp + crc_byte_count_lp);
            valid_n = 0; //no valid data during sync_recv
            
            if(read_id_l) begin //reading ID
                id_sn = {id_sr[14:0], miso_i};
            end else begin
                id_n = id_sr;
                //Once the ID can be read, check if its a discard packet (ID 4'hxFxx)
                //If it is not a discard packet, move to FRAME_RECV
                //Otherwise, stay in SYNC_RECV and discard the rest of the discard packet
                if(id_sr[11:8] != 4'hF) state_n = FRAME_RECV;
                else state_n = SYNC_RECV;
            end

            //reading CRC field
            if(read_crc_l) begin
                crc_sn = {crc_sr[14:0], miso_i};
            end else if(read_payload_l) begin //set CRC after reading the ID and CRC
                crc_n = crc_sr;
            end

            //Reset the packet byte counter when all bytes in the packet have been read
            if(packet_byte_count_r == packet_bytes_p) begin
                packet_byte_count_n = 0;
            end

            //Increment byte counter
            //If a byte has been read, set byte counter to 0 and increment packet byte counter
            if(byte_count_r < 7) begin
                byte_count_n = byte_count_r + 1;
            end else begin
                byte_count_n = 0;
                packet_byte_count_n = packet_byte_count_r + 1;
                if(packet_byte_count_n == packet_bytes_p) packet_byte_count_n = 0;
            end
        end

        FRAME_RECV: begin
            cs_n = 1'b0; //assert cs_o
            sclk_l = clk_i; //enable sclk
            //Check which field is being read currently
            read_id_l = packet_byte_count_r < id_byte_count_lp;
            read_crc_l = (packet_byte_count_r >= id_byte_count_lp) & (packet_byte_count_r < (id_byte_count_lp + crc_byte_count_lp));
            read_payload_l = packet_byte_count_r >= (id_byte_count_lp + crc_byte_count_lp);
            valid_n = 0;

            //reading ID field
            if(read_id_l) begin
                id_sn = {id_sr[14:0], miso_i};
            end else begin
                id_n = id_sr;
            end

            //reading CRC field
            if(read_crc_l) begin
                crc_sn = {crc_sr[14:0], miso_i};
            end else if(read_payload_l) begin //set CRC after reading the ID and CRC
                crc_n = crc_sr;
            end

            //reading Payload field
            if(read_payload_l) begin
                payload_sn = {payload_sr[6:0], miso_i};
            end

            //Reset the packet byte counter when all bytes in the packet have been read
            //Also increment frame packet counter, since a full packet has been read
            if(packet_byte_count_r == packet_bytes_p) begin
                packet_byte_count_n = 0;
                frame_packets_n = frame_packets_r + 1;
            end

            //Increment byte counter
            //If a byte has been read, set byte counter to 0 and increment packet byte counter
            //If currently reading the payload, and the packet is not discard
            //send that payload byte to the payload_byte_r register and set the valid bit
            if(byte_count_r < 7) begin
                byte_count_n = byte_count_r + 1;
            end else begin
                byte_count_n = 0;
                packet_byte_count_n = packet_byte_count_r + 1;
                if(read_payload_l & (id_r[11:8] != 4'hF)) begin
                    payload_n = payload_sn;
                    valid_n = 1'b1;
                end
            end

            if(packet_byte_count_n >= packet_bytes_p) begin
                state_n = SYNC_RECV; //Discard packets until we receive another valid one
                packet_byte_count_n = 0; //Reset the counter because this packet has been fully read
            end

        end

        default: begin
            state_n = SYNC_IDLE; //If something has gone wrong and we aren't in a valid state, attempt to resync
        end

    endcase
  end

endmodule
