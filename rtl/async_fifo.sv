module async_fifo #(
	parameter ADDRSIZE = 4,
	parameter DATASIZE = 8
)(
	// Write Domain
	input logic wclk, wrst_n, winc,
	input logic [DATASIZE-1:0] wdata,
	output logic wfull,

	// Read Domain
	input logic rclk, rrst_n, rinc,
	output logic [DATASIZE-1:0] rdata,
	output logic rempty
);

	logic [ADDRSIZE-1:0] waddr, raddr;
	logic [ADDRSIZE:0] wptr, rptr, wq2_rptr, rq2_wptr;

	// CDC Bridges
	sync_ptr #(ADDRSIZE) sync_r2w (
		.clk(wclk),
		.rst_n(wrst_n),
		.in_ptr(rptr),
		.out_ptr(wq2_rptr)
	);

	sync_ptr #(ADDRSIZE) sync_w2r (
		.clk(rclk),
		.rst_n(rrst_n),
		.in_ptr(wptr),
		.out_ptr(rq2_wptr)
	);

	// Memory Core, Read Logic, Write Logic
	fifomem #(ADDRSIZE, DATASIZE) fifomem_inst (.*);
	rptr_empty #(ADDRSIZE) rptr_empty_inst (.*);
	wptr_full #(ADDRSIZE) wptr_full_inst (.*);
endmodule