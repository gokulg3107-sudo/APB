`include "apb_master.v"
`include "apb_slave1.v"
`include "apb_slave2.v"
module apb_top(PCLK, PRESETn, READ_WRITE, TRANSFER, APB_READ_DATA_OUT, APB_READ_PADDR, APB_WRITE_DATA, APB_WRITE_PADDR);
input PCLK, PRESETn, READ_WRITE, TRANSFER;
parameter size = 8;
input [size:0] APB_READ_PADDR, APB_WRITE_PADDR;
input [size-1:0] APB_WRITE_DATA;
output [size-1:0] APB_READ_DATA_OUT;

wire PENABLE, PWRITE, PSEL1;
wire [size-1:0] PWDATA, PADDR;
wire PSLVERR;
wire PREADY1, PREADY2;
wire [7:0] PRDATA1, PRDATA2;
wire [7:0] PRDATA;
wire PREADY;

assign PRDATA = PSEL1 ? PRDATA1 : PRDATA2;
assign PREADY = PSEL1 ? PREADY1 : PREADY2;

apb_master #(.size(size)) u_master(
	.PCLK             (PCLK),
	.PRESETn          (PRESETn),
	.READ_WRITE       (READ_WRITE),
	.TRANSFER         (TRANSFER),
	.PREADY           (PREADY),
	.PSLVERR          (PSLVERR),
	.PRDATA           (PRDATA),
	.APB_READ_PADDR   (APB_READ_PADDR),
	.APB_WRITE_PADDR  (APB_WRITE_PADDR),
	.APB_WRITE_DATA   (APB_WRITE_DATA),
	.APB_READ_DATA_OUT(APB_READ_DATA_OUT),
	.PENABLE          (PENABLE),
	.PWRITE           (PWRITE),
	.PSEL1            (PSEL1),
	.PWDATA           (PWDATA),
	.PADDR            (PADDR)
);

apb_slave #(.size(size)) u_slave1(
	.PCLK      (PCLK),
	.PRESETn   (PRESETn),
	.SLV_PSEL  (PSEL1),
	.PENABLE   (PENABLE),
	.PWRITE    (PWRITE),
	.PADDR     (PADDR),
	.PWDATA    (PWDATA),
	.SLV_PREADY(PREADY1),
	.PSLVERR   (PSLVERR),
	.SLV_PRDATA(PRDATA1)
);

apb_slave2 #(.size(size)) u_slave2(
	.PCLK      (PCLK),
	.PRESETn   (PRESETn),
	.SLV_PSEL  (PSEL1),
	.PENABLE   (PENABLE),
	.PWRITE    (PWRITE),
	.PADDR     (PADDR),
	.PWDATA    (PWDATA),
	.SLV_PREADY(PREADY2),
	.PSLVERR   (PSLVERR),
	.SLV_PRDATA(PRDATA2)
);

endmodule
