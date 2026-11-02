`timescale 1ns/1ps

module tb_fifo;
	localparam int ADDRSIZE = 4;
	localparam int DATASIZE = 8;

	logic wclk = 1'b0;
	logic wrst_n = 1'b0;
	logic winc = 1'b0;
	logic [DATASIZE-1:0] wdata = '0;
	logic wfull;

	logic rclk = 1'b0;
	logic rrst_n = 1'b0;
	logic rinc = 1'b0;
	logic [DATASIZE-1:0] rdata;
	logic rempty;

	logic [DATASIZE-1:0] expected [0:15];
	logic [DATASIZE-1:0] sampled_val;
	logic [DATASIZE-1:0] expected_val;
	integer errors;

	// Keep separate, asynchronous write and read clocks.
	always #5ns wclk = ~wclk;
	always #12.5ns rclk = ~rclk;

	async_fifo #(
		.ADDRSIZE(ADDRSIZE),
		.DATASIZE(DATASIZE)
	) dut (.*);

	initial begin
		errors = 0;
		$display("DUAL-CLOCK FIFO TEST");

		// Release each reset away from its active clock edge.
		@(negedge wclk);
		wrst_n = 1'b1;
		@(negedge rclk);
		rrst_n = 1'b1;

		$display("Writing 16 values...");
		for (int i = 0; i < 16; i++) begin
			@(negedge wclk);
			winc = 1'b1;
			wdata = 8'hb0 + i;
			expected[i] = wdata;
		end

		@(negedge wclk);
		winc = 1'b0;
		wdata = '0;

		// The flag is registered by the write-clock update above.
		if (wfull === 1'b1)
			$display("PASS: full after 16 writes.");
		else begin
			$display("FAIL: full did not assert after 16 writes.");
			errors = errors + 1;
		end

		$display("Reading 16 values in order...");
		wait (rempty == 1'b0);
		for (int i = 0; i < 16; i++) begin
			@(negedge rclk);
			expected_val = expected[i];
			sampled_val = rdata;
			rinc = 1'b1;
			if (sampled_val !== expected_val) begin
				$display("FAIL: read %0d got 0x%02h, expected 0x%02h.", i, sampled_val, expected_val);
				errors = errors + 1;
			end else begin
				$display("PASS: read %0d = 0x%02h.", i, sampled_val);
			end
		end

		@(negedge rclk);
		rinc = 1'b0;
		@(posedge rclk);
		#1ns;
		if (rempty === 1'b1)
			$display("PASS: empty after 16 reads.");
		else begin
			$display("FAIL: empty did not assert after 16 reads.");
			errors = errors + 1;
		end

		if (errors == 0)
			$display("PASS: all FIFO checks passed.");
		else
			$fatal(1, "%0d FIFO check(s) failed.", errors);

		$finish;
	end
endmodule