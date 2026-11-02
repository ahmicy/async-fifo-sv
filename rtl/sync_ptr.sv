module sync_ptr #(
	parameter ADDRSIZE = 4
) (
	input logic clk,
	input logic rst_n,
	input logic [ADDRSIZE:0] in_ptr,
	output logic [ADDRSIZE:0] out_ptr
);
	logic [ADDRSIZE:0] sync_reg;

	// Run on a rising clock edge or when reset goes low
	always_ff @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			sync_reg <= '0;
			out_ptr  <= '0;
		end else begin
			sync_reg <= in_ptr;
			out_ptr <= sync_reg;
		end
	end
endmodule