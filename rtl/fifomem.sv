module fifomem #(
	parameter ADDRSIZE = 4,
	parameter DATASIZE = 8
)(
	input logic wclk,
	input logic winc,
	input logic wfull,
	input logic [ADDRSIZE-1:0] waddr,
	input logic [ADDRSIZE-1:0] raddr,
	input logic [DATASIZE-1:0] wdata,
	output logic [DATASIZE-1:0] rdata
);

	// Calculate capacity and declare storage array
	localparam DEPTH = 1 << ADDRSIZE;
	logic [DATASIZE-1:0] mem [0:DEPTH-1];

	// Synchronous write
	always_ff @(posedge wclk) begin
		if (winc && !wfull) begin
			mem[waddr] <= wdata;
		end
	end

	// Asynchronous read
	assign rdata = mem[raddr];
endmodule