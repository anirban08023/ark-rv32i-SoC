# Comprehensive Guide to the Optimized 64-bit RISC-V ALU

This document provides a technical overview of the `alu.v` module, implementing a high-performance, hardware-optimized Arithmetic Logic Unit for the **ark-rv64i** SoC.

---

## 1. Overview
The ALU is the primary computational engine of the processor. This implementation supports multiple standard RISC-V extensions with a split execution path for optimal frequency and area.

### Supported Extensions:
- **RV64I**: Base Integer Instruction Set (including "Word" instructions).
- **RV64M**: Standard Extension for Integer Multiplication and Division.
- **Zba, Zbb, Zbs**: Bitmanipulation Extensions (Address generation, Bit-level logic, Single-bit ops).

---

## 2. Module Interface
The ALU uses a synchronous interface for multi-cycle operations.

```verilog
module alu (
    input wire clk,           // System Clock
    input wire rst_n,         // Active-low Reset
    input wire [63:0] a,      // Operand A
    input wire [63:0] b,      // Operand B
    input wire [5:0] alu_ctrl,// 6-bit Control (Bit 5: Word Mode, Bits 4-0: Opcode)
    input wire start,         // Start signal for multi-cycle units
    output reg [63:0] result, // Operation Result
    output wire ready,        // Handshake: High when result is valid
    output wire zero,         // Status: result == 0
    output wire eq,           // Branching: a == b
    output wire lt,           // Branching: a < b (signed)
    output wire ltu          // Branching: a < b (unsigned)
);
```

### Control Signal Mapping (`alu_ctrl`)
- **`alu_ctrl[5]` (Word Mode)**: 
    - `0`: 64-bit Doubleword operation.
    - `1`: 32-bit Word operation (results are sign-extended to 64 bits).
- **`alu_ctrl[4:0]` (Opcode)**: See the "Opcodes Table" below.

---

## 3. Hardware Architecture

### A. Fast Path (1 Clock Cycle)
**Operations**: ADD, SUB, Logical, Shifts, Bitmanip, Branch Comparisons.
- **Immediate Results**: `ready` is always high for these instructions.
- **Zba/Zbb/Zbs Integration**: Includes address generation (`SHxADD`), bit counting (`CLZ`, `CTZ`, `CPOP`), and single-bit manipulation (`BSET`, etc.).

### B. Medium Path (3 Clock Cycles, Pipelined)
**Operations**: MUL, MULH, MULHSU, MULHU.
- **3-Stage Pipeline**: Balanced for high clock frequency. Can accept a new multiplication every cycle.
- **Word Support**: `MULW` truncates and sign-extends correctly.

### C. Slow Path (Iterative, 32/64 Cycles)
**Operations**: DIV, DIVU, REM, REMU.
- **Restoring Division**: Processes 1 bit per cycle.
- **Full Compliance**: Handles divide-by-zero (returns -1) and signed overflow (returns the dividend) as per the RISC-V spec.
- **Latency**: 32 cycles for Word operations, 64 cycles for Doubleword.

---

## 4. Opcodes Table

| Opcode (5-bit) | Name | Description | Path |
| :--- | :--- | :--- | :--- |
| `00000` | ADD / ADDW | Addition | Fast |
| `01000` | SUB / SUBW | Subtraction | Fast |
| `00001` | SLL / SLLW | Shift Left Logical | Fast |
| `00101` | SRL / SRLW | Shift Right Logical | Fast |
| `01101` | SRA / SRAW | Shift Right Arithmetic | Fast |
| **Zba** | | | |
| `00010` | SH1ADD | `(a << 1) + b` | Fast |
| `00011` | SH2ADD | `(a << 2) + b` | Fast |
| `01110` | SH3ADD | `(a << 3) + b` | Fast |
| **Zbs** | | | |
| `01100` | BSET | Bit Set | Fast |
| `01011` | BCLR | Bit Clear | Fast |
| `01010` | BINV | Bit Invert | Fast |
| `01001` | BEXT | Bit Extract | Fast |
| **Zbb** | | | |
| `11001` | ANDN | `a & ~b` | Fast |
| `11010` | ORN | `a | ~b` | Fast |
| `01111` | XNOR | `~(a ^ b)` | Fast |
| `11011` | ROL / ROLW | Rotate Left | Fast |
| `11100` | ROR / RORW | Rotate Right | Fast |
| `11101` | CLZ / CLZW | Count Leading Zeros | Fast |
| `11110` | CTZ / CTZW | Count Trailing Zeros | Fast |
| `11111` | CPOP / CPOPW| Population Count | Fast |
| **RV64M** | | | |
| `10000` | MUL / MULW | Multiply (Lower) | Medium |
| `10001` | MULH | Multiply High (Signed) | Medium |
| `10010` | MULHSU | Multiply High (Signed/Unsigned) | Medium |
| `10011` | MULHU | Multiply High (Unsigned) | Medium |
| `10100` | DIV / DIVW | Division (Signed) | Slow |
| `10101` | DIVU / DIVUW | Division (Unsigned) | Slow |
| `10110` | REM / REMW | Remainder (Signed) | Slow |
| `10111` | REMU / REMUW| Remainder (Unsigned) | Slow |

---

## 5. Verification
The ALU is verified using a Verilator-based C++ testbench.
- **Waveforms**: Generated as `waveforms/dump.vcd` for analysis in GTKWave.
- **Success Criteria**: All opcodes match expected mathematical results, and multi-cycle handshake logic (`start`/`ready`) is strictly followed.
