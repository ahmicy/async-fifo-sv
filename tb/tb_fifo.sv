`timescale 1ns/1ps

bind async_fifo fifo_assertions #(
	.ADDRSIZE(ADDRSIZE),
	.DATASIZE(DATASIZE)
) u_sva (
	.wclk(wclk),
	.wrst_n(wrst_n),
	.winc(winc),
	.wfull(wfull),
	.wptr(wptr),
	.rclk(rclk),
	.rrst_n(rrst_n),
	.rinc(rinc),
	.rempty(rempty),
	.rptr(rptr)
);

bind async_fifo fifo_coverage #(
	.ADDRSIZE(ADDRSIZE)
) u_cov (
	.wclk(wclk),
	.wrst_n(wrst_n),
	.winc(winc),
	.wfull(wfull),
	.rclk(rclk),
	.rrst_n(rrst_n),
	.rinc(rinc),
	.rempty(rempty)
);

module tb_fifo_advanced;
	localparam int ADDRSIZE = 4;
	localparam int DATASIZE = 8;
	localparam int NUM_TXNS = 500;

	logic wclk = 0, wrst_n = 0, winc = 0, wfull;
	logic [DATASIZE-1:0] wdata = '0;

	logic rclk = 0, rrst_n = 0, rinc = 0, rempty;
	logic [DATASIZE-1:0] rdata;

	// Asynchronous clock generators
	always #5ns wclk = ~wclk; // 100 MHz
	always #10ns rclk = ~rclk; //  50 MHz

	// Instantiate top-level wrapper
	async_fifo #(.ADDRSIZE(ADDRSIZE), .DATASIZE(DATASIZE)) dut (.*);

	// Reference queue model
	logic [DATASIZE-1:0] ref_queue[$];
	int match_count = 0;
	int mismatch_count = 0;
	int total_written = 0;
	bit writes_done = 0;

	// Concurrently drive writes
	task automatic drive_writes();
		logic [DATASIZE-1:0] rand_byte;
		for (int i = 0; i < NUM_TXNS; i++) begin

			// Wait until falling edge; avoid conflicts with other components
			@(negedge wclk);

			// Respect FIFO backpressure and apply ~70% write traffic density
			if (!wfull && ($urandom_range(0, 100) < 70)) begin
				rand_byte = $urandom_range(8'h00, 8'hFF);
				wdata <= rand_byte;
				winc  <= 1'b1;
				ref_queue.push_back(rand_byte);
				total_written++;
			end else begin
				winc  <= 1'b0;
			end
		end
		@(negedge wclk);
		winc <= 1'b0;
		writes_done = 1;
	endtask

	// Concurrently drive reads and compare
	task automatic drive_reads();
		logic [DATASIZE-1:0] expected;

		// Run until writes finish and all queued data is verified
		while (!writes_done || ref_queue.size() > 0) begin
			@(negedge rclk);

			// Prevent FIFO underflow and apply ~60% read traffic density
			if (!rempty && ($urandom_range(0, 100) < 60) && (ref_queue.size() > 0)) begin
				rinc <= 1'b1;
				expected = ref_queue.pop_front();
				
				// Allow combinational read output to settle
				#1ps;
				if (rdata !== expected) begin
					$error("[MISMATCH] Expected 0x%02h, Received 0x%02h", expected, rdata);
					mismatch_count++;
				end else begin
					match_count++;
				end
			end else begin
				rinc <= 1'b0;
			end
		end
		@(negedge rclk);
		rinc <= 1'b0;
	endtask

	initial begin
		// Initial reset sequence
		@(negedge wclk) wrst_n = 1;
		@(negedge rclk) rrst_n = 1;

		// Watchdog timeout to prevent infinite simulation hangs
		fork
			begin
				#100us;
				$fatal(1, "[WATCHDOG TIMEOUT] Simulation hung!");
			end
			begin
				fork
					drive_writes();
					drive_reads();
				join

				$display("SIMULATION COMPLETE");
				$display("Total Written : %0d", total_written);
				$display("Total Verified : %0d", match_count + mismatch_count);
				$display("Matches : %0d", match_count);
				$display("Mismatches : %0d", mismatch_count);
				
				if (mismatch_count == 0 && (match_count == total_written)) begin
					$display("TEST STATUS: PASSED");
				end else begin
					$fatal(1, "TEST STATUS: FAILED with %0d errors", mismatch_count);
				end
				$finish;
			end
		join_any
	end
endmodule