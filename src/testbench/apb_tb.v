`timescale 1ns/1ps
`include "apb_top.v"

module tb_apb;

parameter size = 8;

reg PCLK, PRESETn, READ_WRITE, TRANSFER;
reg [size:0] APB_READ_PADDR, APB_WRITE_PADDR;
reg [size-1:0] APB_WRITE_DATA;
wire [size-1:0] APB_READ_DATA_OUT;

apb_top #(.size(size)) u_top(.*);

initial PCLK = 0;
always #5 PCLK = ~PCLK;

task apb_write;
	input [size:0]   addr;
	input [size-1:0] data;
	begin
		@(negedge PCLK);
		APB_WRITE_PADDR = addr;
		APB_WRITE_DATA  = data;
		READ_WRITE      = 1;
		TRANSFER        = 1;
		@(negedge PCLK);
		TRANSFER = 0;
		wait(u_top.PREADY);
		@(negedge PCLK);
	end
endtask

task apb_read;
	input [size:0] addr;
	begin
		@(negedge PCLK);
		APB_READ_PADDR = addr;
		READ_WRITE     = 0;
		TRANSFER       = 1;
		@(negedge PCLK);
		TRANSFER = 0;
		wait(u_top.PREADY);
		@(negedge PCLK);
		@(negedge PCLK);
	end
endtask

integer pass_count, fail_count;

initial begin
	$dumpfile("tb_apb.vcd");
	$dumpvars(0, tb_apb);

	pass_count      = 0;
	fail_count      = 0;
	PRESETn         = 0;
	TRANSFER        = 0;
	READ_WRITE      = 0;
	APB_WRITE_PADDR = 0;
	APB_READ_PADDR  = 0;
	APB_WRITE_DATA  = 0;
	repeat(3) @(negedge PCLK);
	PRESETn = 1;
	@(negedge PCLK);

	// -------------------------------------------------------
	// Slave 1  (addr[8] = 0)
	// -------------------------------------------------------

	apb_write(9'h010, 8'hAB);
	apb_read(9'h010);
	if(APB_READ_DATA_OUT === 8'hAB) begin
		$display("TC1  PASS: slv1 wr/rd 0x10 = 0x%02h", APB_READ_DATA_OUT);
		pass_count = pass_count + 1;
	end else begin
		$display("TC1  FAIL: slv1 rd 0x10 = 0x%02h, exp 0xAB", APB_READ_DATA_OUT);
		fail_count = fail_count + 1;
	end

	apb_write(9'h020, 8'h55);
	apb_read(9'h020);
	if(APB_READ_DATA_OUT === 8'h55) begin
		$display("TC2  PASS: slv1 wr/rd 0x20 = 0x%02h", APB_READ_DATA_OUT);
		pass_count = pass_count + 1;
	end else begin
		$display("TC2  FAIL: slv1 rd 0x20 = 0x%02h, exp 0x55", APB_READ_DATA_OUT);
		fail_count = fail_count + 1;
	end

	apb_read(9'h005);
	if(APB_READ_DATA_OUT === 8'h05) begin
		$display("TC3  PASS: slv1 ROM 0x05 = 0x%02h", APB_READ_DATA_OUT);
		pass_count = pass_count + 1;
	end else begin
		$display("TC3  FAIL: slv1 ROM 0x05 = 0x%02h, exp 0x05", APB_READ_DATA_OUT);
		fail_count = fail_count + 1;
	end

	apb_read(9'h07F);
	if(APB_READ_DATA_OUT === 8'h7F) begin
		$display("TC4  PASS: slv1 ROM 0x7F = 0x%02h", APB_READ_DATA_OUT);
		pass_count = pass_count + 1;
	end else begin
		$display("TC4  FAIL: slv1 ROM 0x7F = 0x%02h, exp 0x7F", APB_READ_DATA_OUT);
		fail_count = fail_count + 1;
	end

	apb_write(9'h0FF, 8'hA5);
	apb_read(9'h0FF);
	if(APB_READ_DATA_OUT === 8'hA5) begin
		$display("TC5  PASS: slv1 wr/rd 0xFF = 0x%02h", APB_READ_DATA_OUT);
		pass_count = pass_count + 1;
	end else begin
		$display("TC5  FAIL: slv1 rd 0xFF = 0x%02h, exp 0xA5", APB_READ_DATA_OUT);
		fail_count = fail_count + 1;
	end

	// -------------------------------------------------------
	// Slave 2  (addr[8] = 1)
	// -------------------------------------------------------

	apb_write(9'h130, 8'hCD);
	apb_read(9'h130);
	if(APB_READ_DATA_OUT === 8'hCD) begin
		$display("TC6  PASS: slv2 wr/rd 0x30 = 0x%02h", APB_READ_DATA_OUT);
		pass_count = pass_count + 1;
	end else begin
		$display("TC6  FAIL: slv2 rd 0x30 = 0x%02h, exp 0xCD", APB_READ_DATA_OUT);
		fail_count = fail_count + 1;
	end

	apb_write(9'h17F, 8'hFF);
	apb_read(9'h17F);
	if(APB_READ_DATA_OUT === 8'hFF) begin
		$display("TC7  PASS: slv2 wr/rd 0x7F = 0x%02h", APB_READ_DATA_OUT);
		pass_count = pass_count + 1;
	end else begin
		$display("TC7  FAIL: slv2 rd 0x7F = 0x%02h, exp 0xFF", APB_READ_DATA_OUT);
		fail_count = fail_count + 1;
	end

	apb_read(9'h10A);
	if(APB_READ_DATA_OUT === 8'h0A) begin
		$display("TC8  PASS: slv2 ROM 0x0A = 0x%02h", APB_READ_DATA_OUT);
		pass_count = pass_count + 1;
	end else begin
		$display("TC8  FAIL: slv2 ROM 0x0A = 0x%02h, exp 0x0A", APB_READ_DATA_OUT);
		fail_count = fail_count + 1;
	end

	apb_write(9'h100, 8'h00);
	apb_read(9'h100);
	if(APB_READ_DATA_OUT === 8'h00) begin
		$display("TC9  PASS: slv2 wr/rd 0x00 = 0x%02h", APB_READ_DATA_OUT);
		pass_count = pass_count + 1;
	end else begin
		$display("TC9  FAIL: slv2 rd 0x00 = 0x%02h, exp 0x00", APB_READ_DATA_OUT);
		fail_count = fail_count + 1;
	end

	// -------------------------------------------------------
	// Cross-slave independence: write slv1 addr, read same
	// offset on slv2 — slv2 ROM default must be undisturbed
	// -------------------------------------------------------

	apb_write(9'h040, 8'hBB);
	apb_read(9'h140);
	if(APB_READ_DATA_OUT === 8'h40) begin
		$display("TC10 PASS: slv2 ROM 0x40 undisturbed = 0x%02h", APB_READ_DATA_OUT);
		pass_count = pass_count + 1;
	end else begin
		$display("TC10 FAIL: slv2 rd 0x40 = 0x%02h, exp 0x40", APB_READ_DATA_OUT);
		fail_count = fail_count + 1;
	end

	// -------------------------------------------------------
	// Consecutive writes then reads — slv1
	// -------------------------------------------------------

	apb_write(9'h001, 8'h11);
	apb_write(9'h002, 8'h22);
	apb_write(9'h003, 8'h33);

	apb_read(9'h001);
	if(APB_READ_DATA_OUT === 8'h11) begin
		$display("TC11 PASS: consec slv1 rd 0x01 = 0x%02h", APB_READ_DATA_OUT);
		pass_count = pass_count + 1;
	end else begin
		$display("TC11 FAIL: consec slv1 rd 0x01 = 0x%02h, exp 0x11", APB_READ_DATA_OUT);
		fail_count = fail_count + 1;
	end

	apb_read(9'h002);
	if(APB_READ_DATA_OUT === 8'h22) begin
		$display("TC12 PASS: consec slv1 rd 0x02 = 0x%02h", APB_READ_DATA_OUT);
		pass_count = pass_count + 1;
	end else begin
		$display("TC12 FAIL: consec slv1 rd 0x02 = 0x%02h, exp 0x22", APB_READ_DATA_OUT);
		fail_count = fail_count + 1;
	end

	apb_read(9'h003);
	if(APB_READ_DATA_OUT === 8'h33) begin
		$display("TC13 PASS: consec slv1 rd 0x03 = 0x%02h", APB_READ_DATA_OUT);
		pass_count = pass_count + 1;
	end else begin
		$display("TC13 FAIL: consec slv1 rd 0x03 = 0x%02h, exp 0x33", APB_READ_DATA_OUT);
		fail_count = fail_count + 1;
	end

	// -------------------------------------------------------
	// Consecutive writes then reads — slv2
	// -------------------------------------------------------

	apb_write(9'h101, 8'hAA);
	apb_write(9'h102, 8'hBB);
	apb_write(9'h103, 8'hCC);

	apb_read(9'h101);
	if(APB_READ_DATA_OUT === 8'hAA) begin
		$display("TC14 PASS: consec slv2 rd 0x01 = 0x%02h", APB_READ_DATA_OUT);
		pass_count = pass_count + 1;
	end else begin
		$display("TC14 FAIL: consec slv2 rd 0x01 = 0x%02h, exp 0xAA", APB_READ_DATA_OUT);
		fail_count = fail_count + 1;
	end

	apb_read(9'h102);
	if(APB_READ_DATA_OUT === 8'hBB) begin
		$display("TC15 PASS: consec slv2 rd 0x02 = 0x%02h", APB_READ_DATA_OUT);
		pass_count = pass_count + 1;
	end else begin
		$display("TC15 FAIL: consec slv2 rd 0x02 = 0x%02h, exp 0xBB", APB_READ_DATA_OUT);
		fail_count = fail_count + 1;
	end

	apb_read(9'h103);
	if(APB_READ_DATA_OUT === 8'hCC) begin
		$display("TC16 PASS: consec slv2 rd 0x03 = 0x%02h", APB_READ_DATA_OUT);
		pass_count = pass_count + 1;
	end else begin
		$display("TC16 FAIL: consec slv2 rd 0x03 = 0x%02h, exp 0xCC", APB_READ_DATA_OUT);
		fail_count = fail_count + 1;
	end

	// -------------------------------------------------------
	// Reset recovery
	// -------------------------------------------------------

	@(negedge PCLK);
	PRESETn = 0;
	repeat(2) @(negedge PCLK);
	PRESETn = 1;
	@(negedge PCLK);

	apb_write(9'h050, 8'hEE);
	apb_read(9'h050);
	if(APB_READ_DATA_OUT === 8'hEE) begin
		$display("TC17 PASS: post-reset slv1 wr/rd 0x50 = 0x%02h", APB_READ_DATA_OUT);
		pass_count = pass_count + 1;
	end else begin
		$display("TC17 FAIL: post-reset slv1 rd 0x50 = 0x%02h, exp 0xEE", APB_READ_DATA_OUT);
		fail_count = fail_count + 1;
	end

	apb_write(9'h150, 8'h77);
	apb_read(9'h150);
	if(APB_READ_DATA_OUT === 8'h77) begin
		$display("TC18 PASS: post-reset slv2 wr/rd 0x50 = 0x%02h", APB_READ_DATA_OUT);
		pass_count = pass_count + 1;
	end else begin
		$display("TC18 FAIL: post-reset slv2 rd 0x50 = 0x%02h, exp 0x77", APB_READ_DATA_OUT);
		fail_count = fail_count + 1;
	end

	repeat(5) @(negedge PCLK);
	$display("----------------------------------");
	$display("RESULTS: %0d PASS / %0d FAIL", pass_count, fail_count);
	$display("----------------------------------");
	$finish;
end

endmodule
