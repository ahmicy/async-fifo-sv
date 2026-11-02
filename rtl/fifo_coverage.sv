module fifo_coverage #(
	parameter ADDRSIZE = 4
)(
	input logic wclk,
	input logic wrst_n,
	input logic winc,
	input logic wfull,

	input logic rclk,
	input logic rrst_n,
	input logic rinc,
	input logic rempty
);

	// Write Domain Coverage
	covergroup cg_write @(posedge wclk);
		cp_winc: coverpoint winc {
			bins idle  = {0};
			bins write = {1};
		}
		cp_wfull: coverpoint wfull {
			bins not_full = {0};
			bins full     = {1};
		}
		cx_write_full: cross cp_winc, cp_wfull {
			bins normal_write   = binsof(cp_winc.write) && binsof(cp_wfull.not_full);
			bins overflow_attempt = binsof(cp_winc.write) && binsof(cp_wfull.full);
		}
	endgroup

	// Read Domain Coverage
	covergroup cg_read @(posedge rclk);
		cp_rinc: coverpoint rinc {
			bins idle = {0};
			bins read = {1};
		}
		cp_rempty: coverpoint rempty {
			bins not_empty = {0};
			bins empty     = {1};
		}
		cx_read_empty: cross cp_rinc, cp_rempty {
			bins normal_read    = binsof(cp_rinc.read) && binsof(cp_rempty.not_empty);
			bins underflow_attempt = binsof(cp_rinc.read) && binsof(cp_rempty.empty);
		}
	endgroup

	cg_write write_cov = new();
	cg_read  read_cov  = new();
endmodule