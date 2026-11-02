# Asynchronous FIFO (SystemVerilog)

A parameterized dual-clock FIFO implemented in SystemVerilog. The write and read sides use independent clocks, local binary pointers for memory addressing, Gray-coded pointers for clock-domain crossing (CDC), and synchronized remote pointers to generate full and empty flags.

## Contents

- `rtl/async_fifo.sv` — top-level FIFO and module connections
- `rtl/fifomem.sv` — storage, synchronous writes, asynchronous read output
- `rtl/wptr_full.sv` — write pointer and full-flag logic
- `rtl/rptr_empty.sv` — read pointer and empty-flag logic
- `rtl/sync_ptr.sv` — two-stage pointer synchronizer
- `rtl/design.sv` — include wrapper for the RTL modules
- `tb/tb_fifo.sv` — dual-clock testbench

## Architecture

`async_fifo` is the public top-level module. It instantiates one synchronizer in each direction, the memory, and the two pointer/flag controllers. The remote read pointer is synchronized into the write-clock domain; the remote write pointer is synchronized into the read-clock domain. The top-level uses `.*` connections for the memory and pointer controllers, so their port names must continue to match the top-level signals. The two synchronizer instances use explicit port connections.

The clocks are not related by the RTL: `wclk` clocks writes, the write pointer, and the read-pointer synchronizer; `rclk` clocks reads, the read pointer, and the write-pointer synchronizer. Each side makes its decisions using only its local pointer and a synchronized copy of the other side's pointer. This allows independent clock rates and phases; it also means each side observes remote progress only after synchronization latency.

### Pointers and CDC

Each pointer controller keeps an `(ADDRSIZE+1)`-bit binary pointer and an `(ADDRSIZE+1)`-bit Gray pointer. The low `ADDRSIZE` bits of the binary pointer form the memory address. The additional most-significant bit tracks passage across the end of the circular address range (the wrap bit).

The next binary pointer advances by one only when the local request is asserted and the corresponding current flag permits the operation:

- Write: `winc && !wfull`
- Read: `rinc && !rempty`

The next Gray pointer is calculated from the next binary pointer as `(binary_next >> 1) ^ binary_next`. This Gray-coded value is the pointer passed across the clock boundary. A one-step binary increment changes one Gray bit, reducing the chance that the receiving domain samples a multi-bit transition as an inconsistent pointer. It does not eliminate the need for proper CDC implementation and timing constraints in a physical design.

`sync_ptr` has two registers clocked by the destination clock. On each rising edge, `sync_reg` samples `in_ptr`, then `out_ptr` samples the prior `sync_reg` value. Both registers have asynchronous active-low reset. The write-side instance synchronizes the read Gray pointer using `wclk`/`wrst_n`; the read-side instance synchronizes the write Gray pointer using `rclk`/`rrst_n`.

### Full and empty

Both status flags are registered in their respective local clock domains and are computed from the next local Gray pointer and the synchronized remote Gray pointer:

- **Empty:** `rgray_next == rq2_wptr`. It resets to `1` and is updated on each rising `rclk` edge. A read request while empty does not advance the read pointer.
- **Full:** `wgray_next == {~wq2_rptr[ADDRSIZE:ADDRSIZE-1], wq2_rptr[ADDRSIZE-2:0]}`. The two most-significant bits of the synchronized read Gray pointer are inverted for the full comparison; the remaining bits are unchanged. It resets to `0` and is updated on each rising `wclk` edge. A write request while full does not advance the write pointer or write memory.

Using next pointers makes the flag reflect whether the pointer after a permitted operation would meet the boundary condition. Because remote pointers pass through two destination-clocked stages, status can conservatively lag remote activity by synchronization latency.

## Memory behavior

`fifomem` declares `2**ADDRSIZE` words, each `DATASIZE` bits wide. A write occurs on a rising `wclk` edge only when `winc` is high and `wfull` is low. The write address is the low bits of the current binary write pointer. The read output is a continuous assignment from `mem[raddr]`, so it is an asynchronous read addressed by the current binary read pointer; advancing the read pointer changes the selected output location.

The memory array is not reset or initialized. Before a location has been written, its read value is not guaranteed and may appear unknown in simulation. Resetting the pointers makes the FIFO logically empty; it does not clear stored bits. The design does not include output registering, memory collision handling, or a vendor-specific RAM inference wrapper.

## Simulation

The RTL include wrapper `rtl/design.sv` includes the component source files by relative names:

```systemverilog
`include "fifomem.sv"
`include "sync_ptr.sv"
`include "rptr_empty.sv"
`include "wptr_full.sv"
`include "async_fifo.sv"
```

For EDA Playground, use `tb/tb_fifo.sv` as the testbench and make the files named by `design.sv` available to its include lookup (or use an equivalent source arrangement). Keep the include paths and file names aligned. If adding each RTL module as a separate compilation source instead, do not also compile the include wrapper in a way that compiles the same module definitions twice. The repository does not specify a simulator command or a saved EDA Playground configuration.

The testbench sets `ADDRSIZE=4` and `DATASIZE=8`, starts the two clocks at different periods (10 ns for `wclk`, 25 ns for `rclk`), and initializes both resets low. It releases the resets on their respective falling edges, writes the byte sequence `8'hb0` through `8'hbf`, checks that full is asserted after 16 writes, waits for data to become available, reads and compares all 16 values in order, then checks that empty is asserted. A nonzero error count ends with `$fatal`; otherwise it prints a pass message and finishes.

The testbench was reported to pass these 16-write, full, 16-ordered-read, and empty checks in EDA Playground with zero errors.

## AI usage

AI was used for assisted learning to understand the concepts, SystemVerilog syntax, and design principles needed to build this RTL design. AI also assisted in creating this README.
