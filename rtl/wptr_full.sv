module wptr_full #(
	parameter ADDRSIZE = 4
)(
	input logic wclk,
	input logic wrst_n,
	input logic winc,
	input logic [ADDRSIZE:0] wq2_rptr,
	output logic wfull,
	output logic [ADDRSIZE-1:0] waddr,
	output logic [ADDRSIZE:0] wptr
);

	logic [ADDRSIZE:0] wbin, wbin_next, wgray_next;
	logic wfull_val;

	assign wbin_next = wbin + (winc & ~wfull);

	assign wgray_next = (wbin_next >> 1) ^ wbin_next;

	assign waddr = wbin[ADDRSIZE-1:0];

	assign wfull_val = (wgray_next == {~wq2_rptr[ADDRSIZE:ADDRSIZE-1], wq2_rptr[ADDRSIZE-2:0]});

	always_ff @(posedge wclk or negedge wrst_n) begin
		if (!wrst_n) begin
			wbin <= '0;
			wptr <= '0;
			wfull <= 1'b0;
		end else begin
			wbin <= wbin_next;
			wptr <= wgray_next;
			wfull <= wfull_val;
		end
	end
endmodule