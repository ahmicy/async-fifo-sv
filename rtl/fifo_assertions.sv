module fifo_assertions #(
	parameter ADDRSIZE = 4,
	parameter DATASIZE = 8
)(
	input logic wclk,
	input logic wrst_n,
	input logic winc,
	input logic wfull,
	input logic [ADDRSIZE:0] wptr,

	input logic rclk,
	input logic rrst_n,
	input logic rinc,
	input logic rempty,
	input logic [ADDRSIZE:0] rptr
);

	// No write overflow: when full, a write request must not advance the write pointer
	property p_no_overflow;
		@(posedge wclk) disable iff (!wrst_n)
		(wfull && winc) |=> $stable(wptr);
	endproperty
	assert_no_overflow: assert property (p_no_overflow)
		else $error("[SVA FAIL] Write pointer advanced while FIFO was full.");

	// No read underflow: when empty, a read request must not advance the read pointer
	property p_no_underflow;
		@(posedge rclk) disable iff (!rrst_n)
		(rempty && rinc) |=> $stable(rptr);
	endproperty
	assert_no_underflow: assert property (p_no_underflow)
		else $error("[SVA FAIL] Read pointer advanced while FIFO was empty.");

	// Gray code single-bit transition check (write domain)
	property p_wptr_gray_step;
		@(posedge wclk) disable iff (!wrst_n)
		$countones(wptr ^ $past(wptr)) <= 1;
	endproperty
	assert_wptr_gray_step: assert property (p_wptr_gray_step)
		else $error("[SVA FAIL] Write gray pointer changed by more than 1 bit.");

	// Gray code single-bit transition check (read domain)
	property p_rptr_gray_step;
		@(posedge rclk) disable iff (!rrst_n)
		$countones(rptr ^ $past(rptr)) <= 1;
	endproperty
	assert_rptr_gray_step: assert property (p_rptr_gray_step)
		else $error("[SVA FAIL] Read gray pointer changed by more than 1 bit.");

	// Reset check: flags must settle to empty/not-full on the cycle after reset is asserted
	property p_reset_wfull;
		@(posedge wclk) !wrst_n |=> !wfull;
	endproperty
	assert_reset_wfull: assert property (p_reset_wfull);

	property p_reset_rempty;
		@(posedge rclk) !rrst_n |=> rempty;
	endproperty
	assert_reset_rempty: assert property (p_reset_rempty);

endmodule