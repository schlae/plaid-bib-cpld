`timescale 1ns / 1ps
//
// Plaid Bib CPLD Version - Test bench for main module
// Copyright (c) 2020 Eric Schlaepfer
// This work is licensed under the Creative Commons Attribution-ShareAlike 4.0
// International License. To view a copy of this license, visit
// http://creativecommons.org/licenses/by-sa/4.0/ or send a letter to Creative
// Commons, PO Box 1866, Mountain View, CA 94042, USA.
//
module mcadlib_t;

    // Inputs
    reg cd_setup_l;
    reg chreset;
    reg adl_l;
    reg cmd;
    reg m_io;
    reg s0_w_l;
    reg s1_r_l;
    reg [15:0] a;

    // Outputs
    wire cd_sfdbk;
    wire cd_chrdy_l;
    wire ior_l;
    wire iow_l;
    wire ym_a0;
    wire ym_cs_l;
    wire cden;
    wire bufen_l;
    wire bufdir;

    // Bidirs
    wire [7:0] d;

    wire [7:0] d_in;
    reg [7:0] d_out;
    reg d_valid;

    // Instantiate simulated YM3812
    ym3812tst yamaha (
        .yd(d),
        .ym_cs_l(ym_cs_l),
        .ym_a0(ym_a0),
        .ym_rd_l(ior_l),
        .ym_wr_l(iow_l)
    );

    // Instantiate the Unit Under Test (UUT)
    mcadlib uut (
        .cd_setup_l(cd_setup_l),
        .cd_sfdbk(cd_sfdbk),
        .chreset(chreset),
        .cd_chrdy_l(cd_chrdy_l),
        .adl_l(adl_l),
        .cmd(cmd),
        .m_io(m_io),
        .s0_w_l(s0_w_l),
        .s1_r_l(s1_r_l),
        .a(a),
        .d(d),
        .ior_l(ior_l),
        .iow_l(iow_l),
        .ym_a0(ym_a0),
        .ym_cs_l(ym_cs_l),
        .cden(cden),
        .bufen_l(bufen_l),
        .bufdir(bufdir)
    );

    assign chck_l = 1'b1;
    assign refresh_l = 1'b1;

    assign d_in = d;
    assign d = (d_valid) ? d_out : 8'bZ;

    task read_cycle;
        input next_mio;
        input [15:0] next_addr;
        begin
            s1_r_l = 0;
            #16 d_valid = 0;
            #32 adl_l = 0;
            #48 cmd = 0;
            #8 adl_l = 1;
            #32
            #16 s1_r_l = 1;
            #16 m_io = next_mio;
            a = next_addr;
            #136 cmd = 1;
        end
    endtask

    task write_cycle;
        input next_mio;
        input [15:0] next_addr;
        input [7:0] din;
        begin
            s0_w_l = 0;
            #16 d_valid = 0;
            #32 adl_l = 0;
            #24 d_out = din;
            d_valid = 1;
            #24 cmd = 0;
            #8 adl_l = 1;
            #32
            #16 s0_w_l = 1;
            #16 m_io = next_mio;
            a = next_addr;
            #136 cmd = 1;
        end
    endtask

    task pos_write_cycle;
        input next_mio;
        input [15:0] next_addr;
        input [7:0] dout;
        begin
            #32 cd_setup_l = 0;
            #16 s0_w_l = 0;
            #48 adl_l = 0;
            #8 d_out = dout;
            d_valid = 1;
            #40 adl_l = 1;
            cmd = 0;
            #56 s0_w_l = 1;
            #8 a = next_addr;
            m_io = next_mio;
            #8 cd_setup_l = 1;
            #136 cmd = 1;
        end
    endtask

    // Cycles all start on rising edge of CMD
    // for this generator.
    task pos_read_cycle;
        input next_mio;
        input [15:0] next_addr;
        begin
            #16 d_valid = 0;
            #32 cd_setup_l = 0;
            #16 s1_r_l = 0;
            // Pulse ADL to latch address, CMD low
            #48 adl_l = 0;
            #48 cmd = 0;
            #8 adl_l = 1;
            // Done with status signals
            #48 s1_r_l = 1;
            #8 m_io = next_mio;
            a = next_addr;
            #8 cd_setup_l = 1;
            // Finish cycle
            #136 cmd = 1;
        end
    endtask

    initial begin
        $dumpfile("test.vcd");
        $dumpvars(0,mcadlib_t);
        // Initialize Inputs
        d_valid = 0;
        cd_setup_l = 1;
        chreset = 1;
        adl_l = 1;
        cmd = 1;
        m_io = 0;
        s0_w_l = 1;
        s1_r_l = 1;
        a = 0;

        // Wait 100 ns for global reset to finish
        #100;
        chreset = 0;
        #16;
        read_cycle(0, 16'h0000);
        pos_read_cycle(0, 16'h00aa);
        read_cycle(0, 16'h0001);
        pos_read_cycle(1, 16'h00bb);
        read_cycle(0, 16'h0003);
        pos_write_cycle(0, 16'h0002, 8'hC0);
        pos_write_cycle(0, 16'h0000, 8'h01);
        read_cycle(0, 16'h0388);
        read_cycle(0, 16'h0389);
        read_cycle(0, 16'h0388);
        write_cycle(0, 16'h0389, 8'hCC);
        write_cycle(0, 16'h0123, 8'hDD);
        write_cycle(0, 16'h0234, 8'hEE);

        #1 $finish ;
    end

endmodule

