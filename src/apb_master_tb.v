`timescale 1ns/1ps

module apb_master_tb;

parameter SIZE = 8;

reg         PCLK, PRESETn;
reg         READ_WRITE, PREADY, TRANSFER, PSLVERR;
reg  [SIZE:0] APB_READ_PADDR, APB_WRITE_DATA, APB_WRITE_PADDR;
reg  [SIZE:0] PRDATA;

wire        PWRITE, PENABLE, PSEL1;
wire [SIZE-1:0] PWDATA, PADDR, APB_READ_DATA_OUT;

integer pass_count, fail_count;

apb_master #(.size(SIZE)) dut (
    .PCLK            (PCLK),
    .PRESETn         (PRESETn),
    .READ_WRITE      (READ_WRITE),
    .PADDR           (PADDR),
    .PSEL1           (PSEL1),
    .TRANSFER        (TRANSFER),
    .PENABLE         (PENABLE),
    .PWRITE          (PWRITE),
    .PREADY          (PREADY),
    .APB_READ_DATA_OUT(APB_READ_DATA_OUT),
    .APB_READ_PADDR  (APB_READ_PADDR),
    .APB_WRITE_DATA  (APB_WRITE_DATA),
    .APB_WRITE_PADDR (APB_WRITE_PADDR),
    .PSLVERR         (PSLVERR),
    .PRDATA          (PRDATA)
);

always #5 PCLK = ~PCLK;

task check;
    input [63:0] tc_num;
    input        exp_psel1, exp_penable, exp_pwrite;
    input [SIZE-1:0] exp_paddr, exp_pwdata;
    input [SIZE-1:0] exp_read_data;
    input        check_read;
    begin
        if (PSEL1    !== exp_psel1   ||
            PENABLE  !== exp_penable ||
            PWRITE   !== exp_pwrite  ||
            PADDR    !== exp_paddr   ||
            PWDATA   !== exp_pwdata  ||
            (check_read && APB_READ_DATA_OUT !== exp_read_data)) begin
            $display("FAIL TC%0d | psel=%b(exp %b) pen=%b(exp %b) pw=%b(exp %b) addr=%h(exp %h) wdata=%h(exp %h)%s",
                tc_num,
                PSEL1, exp_psel1,
                PENABLE, exp_penable,
                PWRITE, exp_pwrite,
                PADDR, exp_paddr,
                PWDATA, exp_pwdata,
                check_read ? $sformatf(" rdata=%h(exp %h)", APB_READ_DATA_OUT, exp_read_data) : "");
            fail_count = fail_count + 1;
        end else begin
            $display("PASS TC%0d", tc_num);
            pass_count = pass_count + 1;
        end
    end
endtask

task apply_reset;
    begin
        PRESETn  = 0;
        TRANSFER = 0;
        READ_WRITE = 0;
        PREADY   = 0;
        PSLVERR  = 0;
        APB_READ_PADDR  = 0;
        APB_WRITE_DATA  = 0;
        APB_WRITE_PADDR = 0;
        PRDATA   = 0;
        @(negedge PCLK);
        @(negedge PCLK);
        PRESETn = 1;
    end
endtask

initial begin
    PCLK       = 0;
    pass_count = 0;
    fail_count = 0;
    apply_reset;

    // -------------------------------------------------------
    // TC1: After reset, FSM in IDLE, all outputs deasserted
    // -------------------------------------------------------
    @(negedge PCLK);
    #1;
    check(1, 0, 0, 0, 0, 0, 0, 0);

    // -------------------------------------------------------
    // TC2: TRANSFER=0, FSM stays in IDLE for multiple cycles
    // -------------------------------------------------------
    TRANSFER = 0;
    repeat(3) @(negedge PCLK);
    #1;
    check(2, 0, 0, 0, 0, 0, 0, 0);

    // -------------------------------------------------------
    // TC3: WRITE transfer – SETUP phase check
    //      PSEL1 = APB_WRITE_PADDR[SIZE], PADDR = lower bits
    //      PENABLE = 0
    // -------------------------------------------------------
    APB_WRITE_PADDR = 9'b1_1010_0011; // PSEL1=1, addr=8'hA3
    APB_WRITE_DATA  = 9'h055;         // lower 8 bits = 0x55
    READ_WRITE = 1;
    TRANSFER   = 1;
    @(negedge PCLK);   // IDLE -> SETUP
    #1;
    check(3, 1, 0, 1, 8'hA3, 8'h55, 0, 0);

    // -------------------------------------------------------
    // TC4: WRITE transfer – ACCESS phase, PENABLE asserted
    //      outputs latched from SETUP (by the implicit latch)
    // -------------------------------------------------------
    PREADY = 0;
    @(negedge PCLK);   // SETUP -> ACCESS
    #1;
    check(4, 1, 1, 1, 8'hA3, 8'h55, 0, 0);

    // -------------------------------------------------------
    // TC5: ACCESS stalls while PREADY=0 (another cycle)
    // -------------------------------------------------------
    @(negedge PCLK);
    #1;
    check(5, 1, 1, 1, 8'hA3, 8'h55, 0, 0);

    // -------------------------------------------------------
    // TC6: WRITE completes (PREADY=1), next transfer queued
    //      (TRANSFER still 1) -> should go back to SETUP
    // -------------------------------------------------------
    PREADY = 1;
    APB_WRITE_PADDR = 9'b1_0101_1100; // addr=8'h5C
    APB_WRITE_DATA  = 9'hAB;
    @(negedge PCLK);   // ACCESS -> SETUP (PREADY && TRANSFER)
    #1;
    check(6, 1, 0, 1, 8'h5C, 8'hAB, 0, 0);

    // -------------------------------------------------------
    // TC7: Second WRITE ACCESS phase
    // -------------------------------------------------------
    PREADY = 0;
    @(negedge PCLK);   // SETUP -> ACCESS
    #1;
    check(7, 1, 1, 1, 8'h5C, 8'hAB, 0, 0);

    // -------------------------------------------------------
    // TC8: PREADY=1, TRANSFER=0 -> go to IDLE
    // -------------------------------------------------------
    PREADY   = 1;
    TRANSFER = 0;
    @(negedge PCLK);   // ACCESS -> IDLE
    #1;
    PREADY = 0;
    #1;
    check(8, 0, 0, 0, 0, 0, 0, 0);

    // -------------------------------------------------------
    // TC9: READ transfer – SETUP phase
    //      PSEL1 = APB_READ_PADDR[SIZE], PADDR = lower bits
    //      PWRITE = 0
    // -------------------------------------------------------
    APB_READ_PADDR = 9'b1_1100_0001; // PSEL1=1, addr=8'hC1
    READ_WRITE = 0;
    TRANSFER   = 1;
    @(negedge PCLK);   // IDLE -> SETUP
    #1;
    check(9, 1, 0, 0, 8'hC1, 0, 0, 0);

    // -------------------------------------------------------
    // TC10: READ – ACCESS phase
    // -------------------------------------------------------
    PREADY = 0;
    @(negedge PCLK);   // SETUP -> ACCESS
    #1;
    check(10, 1, 1, 0, 8'hC1, 0, 0, 0);

    // -------------------------------------------------------
    // TC11: READ completes, PRDATA captured, PSLVERR=0
    // -------------------------------------------------------
    PRDATA   = 9'hBE;
    PSLVERR  = 0;
    TRANSFER = 0;
    PREADY   = 1;
    @(posedge PCLK); #1; // capture happens on posedge
    @(negedge PCLK); PREADY = 0; #1;
    check(11, 0, 0, 0, 0, 0, 8'hBE, 1);

    // -------------------------------------------------------
    // TC12: PSLVERR=1, APB_READ_DATA_OUT must NOT update
    //       (holds previous value 8'hBE)
    // -------------------------------------------------------
    APB_READ_PADDR = 9'b1_0010_0000; // addr=8'h20
    READ_WRITE = 0;
    TRANSFER   = 1;
    @(negedge PCLK);   // IDLE -> SETUP
    @(negedge PCLK);   // SETUP -> ACCESS
    PRDATA   = 9'hFF;
    PSLVERR  = 1;
    TRANSFER = 0;
    PREADY   = 1;
    @(posedge PCLK); #1;
    @(negedge PCLK); PREADY = 0; PSLVERR = 0; #1;
    check(12, 0, 0, 0, 0, 0, 8'hBE, 1);  // data held, not 0xFF

    // -------------------------------------------------------
    // TC13: PSEL1=0 (MSB of WRITE_PADDR=0), WRITE transfer
    // -------------------------------------------------------
    APB_WRITE_PADDR = 9'b0_0111_0001; // PSEL1=0, addr=8'h71
    APB_WRITE_DATA  = 9'h3C;
    READ_WRITE = 1;
    TRANSFER   = 1;
    @(negedge PCLK);   // IDLE -> SETUP
    #1;
    check(13, 0, 0, 1, 8'h71, 8'h3C, 0, 0);

    @(negedge PCLK);   // SETUP -> ACCESS
    PREADY = 0; #1;
    check(13, 0, 1, 1, 8'h71, 8'h3C, 0, 0);

    PREADY   = 1;
    TRANSFER = 0;
    @(negedge PCLK); #1; PREADY = 0;

    // -------------------------------------------------------
    // TC14: Mid-transfer reset
    // -------------------------------------------------------
    APB_WRITE_PADDR = 9'b1_0000_1111;
    APB_WRITE_DATA  = 9'hAA;
    READ_WRITE = 1;
    TRANSFER   = 1;
    @(negedge PCLK);   // IDLE -> SETUP
    @(negedge PCLK);   // SETUP -> ACCESS
    PRESETn = 0;       // async reset mid-transfer
    #3;
    check(14, 0, 0, 0, 0, 0, 0, 0);
    PRESETn = 1;
    TRANSFER = 0;

    // -------------------------------------------------------
    // TC15: ACCESS holds for multiple PREADY=0 cycles (N=4)
    // -------------------------------------------------------
    APB_WRITE_PADDR = 9'b1_0101_0101;
    APB_WRITE_DATA  = 9'h77;
    READ_WRITE = 1;
    TRANSFER   = 1;
    PREADY     = 0;
    @(negedge PCLK);   // IDLE -> SETUP
    @(negedge PCLK);   // SETUP -> ACCESS
    repeat(4) begin
        #1;
        check(15, 1, 1, 1, 8'h55, 8'h77, 0, 0);
        @(negedge PCLK);
    end
    PREADY   = 1;
    TRANSFER = 0;
    @(negedge PCLK); PREADY = 0; #1;

    // -------------------------------------------------------
    // TC16: Burst of 3 back-to-back writes
    // -------------------------------------------------------
    begin : burst_write
        reg [7:0] addrs  [0:2];
        reg [7:0] wdatas [0:2];
        integer i;
        addrs[0]  = 8'h10; addrs[1]  = 8'h20; addrs[2]  = 8'h30;
        wdatas[0] = 8'hAA; wdatas[1] = 8'hBB; wdatas[2] = 8'hCC;
        READ_WRITE = 1;
        for (i = 0; i < 3; i = i + 1) begin
            APB_WRITE_PADDR = {1'b1, addrs[i]};
            APB_WRITE_DATA  = {1'b0, wdatas[i]};
            TRANSFER = 1;
            if (i == 0) @(negedge PCLK); // IDLE -> SETUP only for first
            // SETUP phase
            #1;
            check(16, 1, 0, 1, addrs[i], wdatas[i], 0, 0);
            PREADY = 0;
            @(negedge PCLK); // SETUP -> ACCESS
            #1;
            check(16, 1, 1, 1, addrs[i], wdatas[i], 0, 0);
            PREADY   = 1;
            if (i == 2) TRANSFER = 0;
            @(negedge PCLK); // ACCESS -> SETUP or IDLE
            PREADY = 0;
        end
        #1;
        check(16, 0, 0, 0, 0, 0, 0, 0);
    end

    // -------------------------------------------------------
    // TC17: READ with PSEL1=0 (MSB of READ_PADDR=0)
    // -------------------------------------------------------
    APB_READ_PADDR = 9'b0_0011_0010; // PSEL1=0, addr=8'h32
    READ_WRITE = 0;
    TRANSFER   = 1;
    @(negedge PCLK);   // IDLE -> SETUP
    #1;
    check(17, 0, 0, 0, 8'h32, 0, 0, 0);
    PREADY = 0;
    @(negedge PCLK);   // SETUP -> ACCESS
    PRDATA   = 9'h7F;
    PSLVERR  = 0;
    TRANSFER = 0;
    PREADY   = 1;
    @(posedge PCLK); #1;
    @(negedge PCLK); PREADY = 0; #1;
    check(17, 0, 0, 0, 0, 0, 8'h7F, 1);

    // -------------------------------------------------------
    // Summary
    // -------------------------------------------------------
    $display("\n===== RESULTS: %0d PASSED, %0d FAILED =====", pass_count, fail_count);
    $finish;
end

initial #5000 begin
    $display("TIMEOUT");
    $finish;
end

endmodule
