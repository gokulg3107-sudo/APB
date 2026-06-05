module apb_master(PCLK, PRESETn, READ_WRITE, PADDR, PSEL1, TRANSFER, PENABLE, PWRITE, PREADY, APB_READ_DATA_OUT, APB_READ_PADDR, APB_WRITE_DATA, APB_WRITE_PADDR, PSLVERR, PRDATA, PWDATA);
input PCLK, PRESETn, READ_WRITE, PREADY, TRANSFER, PSLVERR;
parameter size  = 8;
input [size: 0] APB_READ_PADDR, APB_WRITE_PADDR;
input [size - 1: 0] APB_WRITE_DATA, PRDATA;
output reg PWRITE, PENABLE, PSEL1;
output reg [size - 1 : 0] PWDATA, PADDR, APB_READ_DATA_OUT;

localparam [1:0] idle  = 0, setup = 1, access = 2;
reg [1:0] current_state, next_state;

// Registered copies to hold access-phase values
reg pwrite_r, psel1_r;
reg [size - 1: 0] pwdata_r, paddr_r;

//state transition logic
always @(posedge PCLK or negedge PRESETn)begin
	if(~PRESETn) current_state <= idle;
	else current_state <= next_state;
end

//next state logic(Combo block)
always @(*)begin
	case(current_state)
		idle: next_state = TRANSFER ? setup : idle;
		setup: next_state = access;
		access: begin
			if(PREADY) next_state = TRANSFER ? setup : idle;
			else next_state = access;
		end
		default: next_state = idle;
	endcase
end

// Latch setup-phase values into registers on clock edge
always @(posedge PCLK or negedge PRESETn)begin
	if(~PRESETn) begin
		pwrite_r <= 0;
		psel1_r  <= 0;
		pwdata_r <= 0;
		paddr_r  <= 0;
	end else if(current_state == setup) begin
		pwrite_r <= READ_WRITE;
		psel1_r  <= READ_WRITE ? APB_WRITE_PADDR[size] : APB_READ_PADDR[size];
		pwdata_r <= APB_WRITE_DATA;
		paddr_r  <= READ_WRITE ? APB_WRITE_PADDR[size - 1: 0] : APB_READ_PADDR[size - 1: 0];
	end
end

//output logic
always @(*)begin
	case(current_state)
		idle: begin
			PWRITE  = 0;
			PENABLE = 0;
			PWDATA  = 0;
			PSEL1   = 0;
			PADDR   = 0;
		end
		setup: begin
			PWRITE  = READ_WRITE;
			PENABLE = 0;
			PWDATA  = APB_WRITE_DATA;
			PSEL1   = READ_WRITE ? APB_WRITE_PADDR[size] : APB_READ_PADDR[size];
			PADDR   = READ_WRITE ? APB_WRITE_PADDR[size - 1: 0] : APB_READ_PADDR[size - 1: 0];
		end
		access: begin
			PWRITE  = pwrite_r;
			PWDATA  = pwdata_r;
			PSEL1   = psel1_r;
			PADDR   = paddr_r;
			PENABLE = 1;
		end
		default: begin
			PWRITE  = 0;
			PENABLE = 0;
			PWDATA  = 0;
			PSEL1   = 0;
			PADDR   = 0;
		end
	endcase
end

//Read operation data output
always@(posedge PCLK or negedge PRESETn)begin
	if(~PRESETn) APB_READ_DATA_OUT <= 0;
	else begin
		if(PREADY && !PWRITE) APB_READ_DATA_OUT <= PSLVERR ? APB_READ_DATA_OUT : PRDATA;
		else APB_READ_DATA_OUT <= APB_READ_DATA_OUT;
	end
end

endmodule
