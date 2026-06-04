`timescale 1ns/1ps

module apb_tb;
	parameter size = 8;

	reg  PCLK, PRESETn, READ_WRITE, TRANSFER;
	reg  [size:0]   APB_READ_PADDR, APB_WRITE_PADDR;
	reg  [size-1:0] APB_WRITE_DATA;
	wire [size-1:0] APB_READ_DATA_OUT;
	wire [size-1:0] MON_PRDATA;
	wire [1:0]      MON_SLV1_STATE;
	wire [1:0]      MON_SLV2_STATE;

	integer pass_count, fail_count, test_num;
	reg [size-1:0] captured_read;

	apb_top #(.size(size)) dut(
		.PCLK             (PCLK),
		.PRESETn          (PRESETn),
		.READ_WRITE       (READ_WRITE),
		.TRANSFER         (TRANSFER),
		.APB_READ_DATA_OUT(APB_READ_DATA_OUT),
		.APB_READ_PADDR   (APB_READ_PADDR),
		.APB_WRITE_DATA   (APB_WRITE_DATA),
		.APB_WRITE_PADDR  (APB_WRITE_PADDR),
		.MON_PRDATA       (MON_PRDATA),
		.MON_SLV1_STATE   (MON_SLV1_STATE),
		.MON_SLV2_STATE   (MON_SLV2_STATE)
	);

	initial PCLK = 0;
	always #5 PCLK = ~PCLK;

	always @(posedge PCLK) begin
		if(MON_SLV1_STATE == 2'd1 || MON_SLV2_STATE == 2'd1)
			captured_read <= MON_PRDATA;
	end

	task do_write;
		input [size:0]   wr_addr;
		input [size-1:0] wr_data;
		integer i;
		begin
			@(negedge PCLK);
			APB_WRITE_PADDR = wr_addr;
			APB_WRITE_DATA  = wr_data;
			READ_WRITE      = 1;
			TRANSFER        = 1;
			for(i=0; i<7; i=i+1) @(posedge PCLK);
			@(negedge PCLK);
			TRANSFER = 0;
			repeat(2) @(posedge PCLK);
		end
	endtask

	task do_read;
		input [size:0]   rd_addr;
		input [size-1:0] exp;
		integer i;
		begin
			@(negedge PCLK);
			APB_READ_PADDR = rd_addr;
			READ_WRITE     = 0;
			TRANSFER       = 1;
			for(i=0; i<7; i=i+1) @(posedge PCLK);
			@(negedge PCLK);
			TRANSFER = 0;
			repeat(2) @(posedge PCLK);
			test_num = test_num + 1;
			if(captured_read === exp) begin
				$display("  [PASS] #%02d  addr=0x%03h  exp=0x%02h  got=0x%02h",
					test_num, rd_addr, exp, captured_read);
				pass_count = pass_count + 1;
			end else begin
				$display("  [FAIL] #%02d  addr=0x%03h  exp=0x%02h  got=0x%02h",
					test_num, rd_addr, exp, captured_read);
				fail_count = fail_count + 1;
			end
		end
	endtask

	task idle_bus;
		input integer n;
		integer i;
		begin
			TRANSFER = 0;
			for(i=0; i<n; i=i+1) @(posedge PCLK);
		end
	endtask

	initial begin
		$dumpfile("apb_tb.vcd");
		$dumpvars(0, apb_tb);

		pass_count=0; fail_count=0; test_num=0;
		captured_read=0;
		TRANSFER=0; READ_WRITE=0;
		APB_READ_PADDR=0; APB_WRITE_PADDR=0; APB_WRITE_DATA=0;

		PRESETn=0;
		repeat(4) @(posedge PCLK);
		@(negedge PCLK); PRESETn=1;
		repeat(2) @(posedge PCLK);

		$display("\n============================================================");
		$display("  APB Self-Checking Testbench");
		$display("  Slave1(u_slave1) = apb_slave2, PSEL=1, addr[8]=1, 4-state");
		$display("  Slave2(u_slave2) = apb_slave,  PSEL=0, addr[8]=0, 3-state");
		$display("============================================================\n");

		$display("--- GROUP 1: Slave2 ROM reads (addr[8]=0) ---");
		do_read(9'h000, 8'h00);
		do_read(9'h001, 8'h01);
		do_read(9'h007, 8'h07);
		do_read(9'h055, 8'h55);
		do_read(9'h0AA, 8'hAA);
		do_read(9'h0FE, 8'hFE);

		$display("\n--- GROUP 2: Slave1 ROM reads (addr[8]=1) ---");
		do_read(9'h100, 8'h00);
		do_read(9'h101, 8'h01);
		do_read(9'h155, 8'h55);
		do_read(9'h1AA, 8'hAA);
		do_read(9'h1FE, 8'hFE);

		$display("\n--- GROUP 3: Write->Read Slave2 (addr[8]=0) ---");
		do_write(9'h010, 8'hBE); do_read(9'h010, 8'hBE);
		do_write(9'h020, 8'hEF); do_read(9'h020, 8'hEF);
		do_write(9'h000, 8'hFF); do_read(9'h000, 8'hFF);
		do_write(9'h0FE, 8'h01); do_read(9'h0FE, 8'h01);

		$display("\n--- GROUP 4: Write->Read Slave1 (addr[8]=1) ---");
		do_write(9'h110, 8'hDE); do_read(9'h110, 8'hDE);
		do_write(9'h120, 8'hAD); do_read(9'h120, 8'hAD);
		do_write(9'h100, 8'h5A); do_read(9'h100, 8'h5A);
		do_write(9'h1FE, 8'hA5); do_read(9'h1FE, 8'hA5);

		$display("\n--- GROUP 5: Corner Cases ---");
		do_write(9'h030, 8'h11);
		do_write(9'h030, 8'h22);
		do_read(9'h030, 8'h22);

		do_write(9'h040, 8'h00); do_read(9'h040, 8'h00);
		do_write(9'h041, 8'hFF); do_read(9'h041, 8'hFF);

		do_write(9'h050, 8'hCC);
		do_write(9'h051, 8'hCC);
		do_read(9'h050, 8'hCC);
		do_read(9'h051, 8'hCC);

		do_write(9'h060, 8'hAB);
		do_write(9'h160, 8'hCD);
		do_read(9'h060, 8'hAB);
		do_read(9'h160, 8'hCD);

		idle_bus(15);
		do_write(9'h070, 8'h99);    
		idle_bus(10);
		do_read(9'h070, 8'h99);

		do_write(9'h001, 8'h12);
		do_write(9'h101, 8'h34);
		do_read(9'h001, 8'h12);
		do_read(9'h101, 8'h34);

		do_write(9'h0FF, 8'hC3); do_read(9'h0FF, 8'hC3);
		do_write(9'h1FF, 8'h3C); do_read(9'h1FF, 8'h3C);

		do_write(9'h080, 8'hA1);
		do_write(9'h180, 8'hB2);
		do_write(9'h081, 8'hA3);
		do_write(9'h181, 8'hB4);
		do_read(9'h080, 8'hA1);
		do_read(9'h180, 8'hB2);
		do_read(9'h081, 8'hA3);
		do_read(9'h181, 8'hB4);

		do_write(9'h090, 8'h11);
		idle_bus(5);
		do_write(9'h090, 8'h22);
		idle_bus(5);
		do_read(9'h090, 8'h22);

		do_write(9'h0A0, 8'h01); do_read(9'h0A0, 8'h01);
		do_write(9'h0A1, 8'h02); do_read(9'h0A1, 8'h02);
		do_write(9'h0A2, 8'h04); do_read(9'h0A2, 8'h04);
		do_write(9'h0A3, 8'h08); do_read(9'h0A3, 8'h08);
		do_write(9'h0A4, 8'h10); do_read(9'h0A4, 8'h10);
		do_write(9'h0A5, 8'h20); do_read(9'h0A5, 8'h20);
		do_write(9'h0A6, 8'h40); do_read(9'h0A6, 8'h40);
		do_write(9'h0A7, 8'h80); do_read(9'h0A7, 8'h80);

		repeat(4) @(posedge PCLK);
		$display("\n============================================================");
		$display("  RESULTS:  %0d PASSED  |  %0d FAILED  |  %0d TOTAL",
			pass_count, fail_count, pass_count+fail_count);
		$display("============================================================\n");
		$finish;
	end

	initial begin #2000000; $display("[TIMEOUT]"); $finish; end
endmodule
