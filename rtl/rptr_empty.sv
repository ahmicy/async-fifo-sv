module rptr_empty #(
	parameter ADDRSIZE = 4
)(
	input logic rclk,
	input logic rrst_n,
	input logic rinc,
	input logic [ADDRSIZE:0] rq2_wptr,
	output logic rempty,
	output logic [ADDRSIZE-1:0] raddr,
	output logic [ADDRSIZE:0] rptr
);

	logic [ADDRSIZE:0] rbin, rbin_next, rgray_next;

	assign rbin_next = rbin + (rinc & ~rempty);

	assign rgray_next = (rbin_next >> 1) ^ rbin_next;

	assign raddr = rbin[ADDRSIZE-1:0];

	always_ff @(posedge rclk or negedge rrst_n) begin
		if (!rrst_n) begin
			rbin <= '0;
			rptr <= '0;
			rempty <= 1'b1;
		end else begin
			rbin <= rbin_next;
			rptr <= rgray_next;
			rempty <= (rgray_next == rq2_wptr);
		end
	end

endmodule