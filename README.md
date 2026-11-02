# Asynchronous FIFO (SystemVerilog)

A parameterized dual-clock FIFO implemented and verified in SystemVerilog. The write and read domains operate on independent, asynchronous clock sources. The architecture uses local binary pointers for memory addressing, Gray-coded pointers for safe clock-domain crossing (CDC), and two-stage flip-flop synchronizers to generate conservative full and empty flags. The verification environment includes a concurrent, multi-threaded testbench, continuous SystemVerilog Assertions (SVA) for protocol and CDC step-integrity checking, and functional coverage tracking for corner cases.

## Contents

* `rtl/async_fifo.sv` — Top-level FIFO wrapper integrating all sub-blocks

* `rtl/fifomem.sv` — Storage array with synchronous write and combinational (asynchronous) read output

* `rtl/wptr_full.sv` — Write pointer management and full-flag comparison logic

* `rtl/rptr_empty.sv` — Read pointer management and empty-flag comparison logic

* `rtl/sync_ptr.sv` — Two-stage flip-flop synchronizer for Gray pointers

* `rtl/fifo_assertions.sv` — SystemVerilog Assertions (SVA) checking overflow, underflow, Gray coding, and reset rules

* `rtl/fifo_coverage.sv` — Functional coverage groups tracking operational states and cross-conditions

* `rtl/design.sv` — Include wrapper for compilation

* `tb/tb_fifo.sv` — Dual-clock verification testbench

## Architecture

`async_fifo` manages data flow across two independent clock domains (`wclk` and `rclk`) without a fixed phase or frequency relationship.

### Pointers and CDC

Each domain maintains an `(ADDRSIZE+1)`-bit pointer:

* The lower `ADDRSIZE` bits directly address the internal memory array.

* The MSB serves as the circular wrap/phase bit.

To safely pass pointers across the CDC boundary into 2-stage synchronizers (`sync_ptr`), binary pointers are converted to Gray code:

$$
\text{Gray} = (\text{Binary} \gg 1) \oplus \text{Binary}
$$

Gray encoding guarantees that only a single bit changes per increment cycle. If the destination clock samples during a signal transition, setup/hold violations can only affect the single switching bit, preventing catastrophic multi-bit sampling glitches.

### Full and Empty

Both status flags are registered in their respective local clock domains and are computed from the next local Gray pointer and the synchronized remote Gray pointer:

* **Empty:** `rgray_next == rq2_wptr`. It resets to `1` and is updated on each rising `rclk` edge. A read request while empty does not advance the read pointer.

* **Full:** `wgray_next == {~wq2_rptr[ADDRSIZE:ADDRSIZE-1], wq2_rptr[ADDRSIZE-2:0]}`. The two most-significant bits of the synchronized read Gray pointer are inverted for the full comparison; the remaining bits are unchanged. It resets to `0` and is updated on each rising `wclk` edge. A write request while full does not advance the write pointer or write memory.

Using next pointers makes the flag reflect whether the pointer after a permitted operation would meet the boundary condition. Because remote pointers pass through two destination-clocked stages, status can conservatively lag remote activity by synchronization latency.

## Memory Behavior

`fifomem` declares `2**ADDRSIZE` words, each `DATASIZE` bits wide. A write occurs on a rising `wclk` edge only when `winc` is high and `wfull` is low. The write address is the low bits of the current binary write pointer. The read output is a continuous assignment from `mem[raddr]`, so it is an asynchronous read addressed by the current binary read pointer; advancing the read pointer changes the selected output location.

The memory array is not reset or initialized. Before a location has been written, its read value is not guaranteed and may appear unknown in simulation. Resetting the pointers makes the FIFO logically empty; it does not clear stored bits. The design does not include output registering, memory collision handling, or a vendor-specific RAM inference wrapper.

## Verification Environment

The testbench (`tb/tb_fifo.sv`) pairs concurrent stimulus generation with continuous protocol assertions and functional coverage metrics.

### Concurrency and Thread Orchestration

* **Thread Spawning (`fork ... join`):** The driver logic runs write operations (`wclk`) and read operations (`rclk`) on independent concurrent threads spawned from an initial block.

* **Watchdog Protection (`join_any` / `disable fork`):** Handshakes and flag-polling routines race against timeout timers to prevent test deadlocks if the FIFO stalls.

* **Delta-Cycle Sampling:** To prevent race conditions against the combinational read output (`assign rdata = mem[raddr]`), the testbench delays read observations (e.g., `#1ps` or clock-opposite sampling) ensuring pointer transitions settle before asserting correctness.

### SystemVerilog Assertions (`rtl/fifo_assertions.sv`)

* **No Overflow:** Proves `wptr` remains frozen on the following cycle if a write is attempted while full.

* **Single-Bit Gray Step:** Enforces that Gray pointers crossing the CDC boundary change by at most one bit per clock cycle.

* **Reset State Settlement:** Checks that `wfull` deasserts and `rempty` asserts in the cycle immediately following an active reset.

### Functional Coverage (`rtl/fifo_coverage.sv`)

A dedicated coverage group tracks whether test vectors reached boundary conditions:

* **Coverpoints:** Track active/idle states of control signals (`winc`, `rinc`, `wfull`, `rempty`).

* **Cross Coverage:** Captures simultaneous conditions such as:

  * `normal_write`: Write asserted while not full (`winc=1 && wfull=0`).

  * `overflow_attempt`: Write asserted while full (`winc=1 && wfull=1`) to confirm that overflow assertions were tested.

  * `normal_read`: Read asserted while not empty (`rinc=1 && rempty=0`).

  * `underflow_attempt`: Read asserted while empty (`rinc=1 && rempty=1`) to confirm underflow safeguards.

## Simulation

For EDA Playground or local simulators (Questa/ModelSim, VCS, Xcelium):

1. Compile `rtl/design.sv` (while uploading individual files) alongside `tb/tb_fifo.sv`.

2. The testbench sets `ADDRSIZE=4` and `DATASIZE=8`, initializes clocks (`10 ns` for `wclk`, `25 ns` for `rclk`), releases active-low resets, writes sequential byte patterns, verifies full and empty boundaries, and prints verification status upon completion.

## AI Usage

AI was used for assisted learning to understand the concepts, SystemVerilog syntax, assertion development (SVA), coverage modeling, and design principles needed to build and verify this RTL design. AI also assisted in creating this README.