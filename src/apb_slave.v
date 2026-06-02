module apb_slave(PCLK, SLV_PSEL, PRESETn, PADDR, PENABLE, PSLVERR, PWRITE, PWDATA,  SLV_PREADY, SLV_PRDATA );
input SLV_PSEL, PWRITE, PCLK, PRESETn, PENABLE;
parameter size = 8;
input [7:0] PWDATA;
input [size - 1: 0] PADDR;
output  SLV_PREADY, PSLVERR;
output  [7: 0] SLV_PRDATA;

//memory bank instantiation
reg [7:0] memory [(2 ** size) - 1: 0];
integer index;

//Initialising ROM values
initial begin
    for(index = 0; index < ((2 ** size) - 1); index = index + 1) memory[index]= index;
end

localparam [1:0] idle = 0, access = 1, ready = 2; 
reg [1:0] current_state, next_state;

always @(posedge PCLK or negedge PRESETn)begin
    if(~PRESETn) current_state <= idle;
    else current_state <= next_state;
end

always@(*)begin
    case(current_state)
        idle: next_state = (PENABLE && ~SLV_PSEL) ? access : idle;
        access: next_state = ready;
        ready: next_state = idle;
        default: next_state = idle;
    endcase
end

assign SLV_PREADY = current_state == ready ? 1'b1 : 1'b0;
assign SLV_PRDATA = current_state == access ? PWRITE ? 0 : memory[PADDR] : 0;
always@(current_state)begin
    if(current_state == access && PWRITE) memory[PADDR] = PWDATA;
end

endmodule

        

