`timescale 1ns / 1ps
//
// Plaid Bib CPLD Version - Main Module
// Copyright (c) 2020 Eric Schlaepfer
// This work is licensed under the Creative Commons Attribution-ShareAlike 4.0
// International License. To view a copy of this license, visit
// http://creativecommons.org/licenses/by-sa/4.0/ or send a letter to Creative
// Commons, PO Box 1866, Mountain View, CA 94042, USA.
//
module mcadlib(
// MCA signals
    input cd_setup_l,
    output cd_sfdbk,
    input chreset,
    output cd_chrdy_l,
    output cd_ds16,
    input adl_l,
    input cmd,
    input ext_clock,
    input m_io,
    input s0_w_l,
    input s1_r_l,
    input [15:0] a,
    inout [7:0] d,

// External buffer control
    output bufen_l,
    output bufdir,

// Yamaha control
    output ior_l,
    output iow_l,
    output ym_cs_l,
    output ym_a0,
    output ym_ic_l,
    output ym_clock,

// Miscellaneous
    output cden
    );

reg [2:0] addr_latched;
reg [7:0] pos_data_bus;
reg pos_reg0;
reg [7:0] pos_reg1;

wire [14:0] pos_address;
wire pos_read, pos_write;
reg cd_setup, cd_sel;
reg write, read, m_io_latched;
reg [1:0] clkdiv;

// Only ever 8-bit transfers
assign cd_ds16 = 1'b0;

// Address selection
// 0000 0011 1000 1000
// 0000 001A ABBB 100x
// AA comes from POS 103 [7:6]
// BBB comes from POS 103 [5:3]
// POS102 written to be 0000000X
// POS103 needs to be 11000000
assign pos_address = {7'b0000001, pos_reg1[7:3], 3'b100};

// Card selected feedback
// Inverted externally. Not qualified by any clock.
assign cd_sfdbk = (a[15:1] == pos_address) & ~m_io & cd_setup_l & cden;

// Address, m/IO#, s0, s1 are latched on falling edge of ADL.
always @ (negedge adl_l or posedge chreset)
begin
    if (chreset) begin
        addr_latched <= 3'b00;
        cd_sel <= 1'b0;
        m_io_latched <= 1'b0;
        cd_setup <= 1'b0;
        write <= 1'b0;
        read <= 1'b0;
    end else begin
        addr_latched <= a[2:0];
        cd_sel <= cd_sfdbk;
        m_io_latched <= m_io;
        cd_setup <= ~cd_setup_l;
        write <= ~s0_w_l;
        read <= ~s1_r_l;
    end
end

// Deasserting cd_chrdy during read cycle will enable MCA synchronous extended
// cycle. This helps meet the YM3812 timing spec. It must use the *unlatched*
// address decode and status signal. Technically this should be a reg that is
// set by this state and cleared on the falling edge of cmd.
// I'm not sure this is necessary for I/O cycles, which always seem to be about
// 300ns.
assign cd_chrdy_l = cd_sfdbk & ~s1_r_l & cmd;

// Clock divider takes 14.3MHz and divides it to 3.57MHz.
always @ (posedge ext_clock or posedge chreset)
begin
    if (chreset) begin
        clkdiv <= 2'b00;
    end else begin
        clkdiv <= clkdiv + 1;
    end
end
assign ym_clock = clkdiv[1];

// Control to external IO device
assign ior_l = ~(cd_sel & read);
assign iow_l = ~(cd_sel & write);
assign ym_a0 = addr_latched[0];
assign ym_cs_l = ~(cd_sel & ~cmd);
assign ym_ic_l = ~chreset;

// External level shift buffer control lines
assign bufdir = write;
assign bufen_l = ~(((cd_setup & ~m_io_latched) || cd_sel) & ~cmd);

// POS register operations
assign pos_read = cd_setup & read & ~m_io_latched & ~cmd;
assign pos_write = cd_setup & write & ~m_io_latched;
assign d = pos_read ? pos_data_bus : 8'bZ;

// MUX for POS read operations
always @ (addr_latched or pos_reg0 or pos_reg1) begin
    case (addr_latched)
        3'b000: pos_data_bus <= 8'hD7;
        3'b001: pos_data_bus <= 8'h70;
        3'b010: pos_data_bus <= {7'b0000000, pos_reg0}; // POS102
        3'b011: pos_data_bus <= pos_reg1;               // POS103
        3'b100: pos_data_bus <= 8'h00;
        3'b101: pos_data_bus <= 8'h00;
        3'b110: pos_data_bus <= 8'h00;
        3'b111: pos_data_bus <= 8'h00;
    endcase
end

// Latch POS registers on rising edge of cmd
always @ (posedge cmd or posedge chreset) begin
    if (chreset) begin
        pos_reg0 <= 1'b0;
        pos_reg1 <= 8'h00;
    end else if (pos_write) begin
        case (addr_latched)
            3'b010: pos_reg0 <= d[0]; // Bit 0 of POS register 102
            3'b011: pos_reg1 <= d;    // POS register 103
        endcase
    end
end

// Bit 0 of POS102 is the card enable signal
assign cden = pos_reg0;

endmodule
