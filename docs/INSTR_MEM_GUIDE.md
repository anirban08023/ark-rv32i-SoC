# Instruction Memory Design Guide

## Overview

The `instr_mem.v` module is a virtual instruction ROM for simulation and testing. It stores 32-bit RISC-V instructions and can be initialized in multiple ways.

## Key Features

- **Parameterizable size**: Default 1024 instructions (4KB)
- **Byte-addressed**: PC is in bytes, internally converted to word addresses
- **Combinational read**: Zero-latency instruction fetch
- **Multiple initialization methods**: Inline code, hex files, or testbench
- **Bounds checking**: Returns NOP for out-of-bounds addresses
- **Debug support**: Optional display for memory accesses

## Memory Organization

```
PC (Byte Address)    Word Address    Instruction
0x0000_0000          0x0000          instr[0]  (32 bits)
0x0000_0004          0x0001          instr[1]  (32 bits)
0x0000_0008          0x0002          instr[2]  (32 bits)
...
```

**Important**:
- PC increments by 4 (bytes per instruction)
- Word address = PC >> 2 (divide by 4)
- Instructions must be 4-byte aligned

## Default Test Program

The module includes a simple test program:

```assembly
0x00: ADDI x1, x0, 10      # x1 = 10
0x04: ADDI x2, x0, 20      # x2 = 20
0x08: ADD  x3, x1, x2      # x3 = 30
0x0C: SUB  x4, x2, x1      # x4 = 10
0x10: ADDI x5, x0, 5       # x5 = 5
0x14: MUL  x6, x3, x5      # x6 = 150
0x18: ADDI x7, x0, 2       # x7 = 2
0x1C: DIV  x8, x6, x7      # x8 = 75
0x20: SLLI x9, x1, 2       # x9 = 40
0x24: SRLI x10, x2, 1      # x10 = 10
0x28: AND  x11, x1, x2     # x11 = x1 & x2
0x2C: OR   x12, x1, x2     # x12 = x1 | x2
0x30: XOR  x13, x1, x2     # x13 = x1 ^ x2
0x34: JAL  x0, -4          # Infinite loop
```

This tests:
- Immediate operations (ADDI)
- Register-register operations (ADD, SUB)
- M-extension (MUL, DIV)
- Shift operations (SLLI, SRLI)
- Logic operations (AND, OR, XOR)
- Control flow (JAL)

## Initialization Methods

### Method 1: Inline Code (Default)

Directly write instructions in the `initial` block:

```verilog
initial begin
    mem[0] = 32'h00A00093;  // ADDI x1, x0, 10
    mem[1] = 32'h01400113;  // ADDI x2, x0, 20
    // ...
end
```

**Pros**: Simple, self-contained, good for small test programs
**Cons**: Not suitable for large programs

### Method 2: Hex File

Create a hex file (`program.hex`) with instructions:

```
00A00093
01400113
002081B3
40110233
```

Uncomment in `instr_mem.v`:
```verilog
initial begin
    $readmemh("program.hex", mem);
end
```

**Pros**: Easy to generate from assembler, supports large programs
**Cons**: Need external file management

### Method 3: Binary File

For binary format:
```verilog
initial begin
    $readmemb("program.bin", mem);
end
```

### Method 4: Testbench Initialization

Write to memory from testbench:

```verilog
// In testbench
initial begin
    // Wait for reset
    @(posedge rst_n);

    // Write instructions (if memory is writable)
    force top_soc.u_instr_mem.mem[0] = 32'h00A00093;
    force top_soc.u_instr_mem.mem[1] = 32'h01400113;
    // ...
    release top_soc.u_instr_mem.mem;
end
```

## Generating Programs

### Using RISC-V Toolchain

1. **Write assembly** (`program.s`):
```asm
.section .text
.globl _start

_start:
    addi x1, x0, 10
    addi x2, x0, 20
    add  x3, x1, x2
    # ...
```

2. **Assemble and link**:
```bash
riscv64-unknown-elf-as -o program.o program.s
riscv64-unknown-elf-ld -Ttext=0x0 -o program.elf program.o
```

3. **Extract hex**:
```bash
riscv64-unknown-elf-objcopy -O verilog program.elf program.hex
```

### Using Online Assemblers

- **RARS**: RISC-V Assembler and Runtime Simulator
- **Venus**: Web-based RISC-V assembler
- **riscv-asm**: Online RISC-V assembler

## Memory Size Configuration

Adjust based on program size:

```verilog
// Small programs (default)
instr_mem #(
    .ADDR_WIDTH(16),    // 64KB addressable
    .MEM_SIZE(1024)     // 1024 instructions = 4KB
) u_instr_mem (...);

// Large programs
instr_mem #(
    .ADDR_WIDTH(20),    // 1MB addressable
    .MEM_SIZE(65536)    // 64K instructions = 256KB
) u_instr_mem (...);
```

**Trade-offs**:
- Larger memory → More simulation time and memory usage
- Smaller memory → May not fit entire program

## Debugging

Enable debug output:

```bash
# Compile with DEBUG flag
iverilog -DDEBUG_INSTR_MEM -o sim testbench.v
```

This will print every instruction fetch:
```
[IMEM] PC=0x0000000000000000, word_addr=0x0000, instr=0x00A00093
[IMEM] PC=0x0000000000000004, word_addr=0x0001, instr=0x01400113
```

## Integration with top_soc.v

Add instruction memory to your SoC:

```verilog
// In top_soc.v
wire [31:0] instr;
wire [63:0] pc;

instr_mem #(
    .ADDR_WIDTH(16),
    .MEM_SIZE(1024)
) u_instr_mem (
    .clk(clk),
    .rst_n(rst_n),
    .pc(pc),
    .instr(instr)
);

// Connect instr to decoder...
```

## Migrating to FPGA

When moving to FPGA with real memory:

### Option 1: Block RAM (BRAM)
Replace `instr_mem.v` with FPGA vendor BRAM:
```verilog
// Xilinx example
blk_mem_gen_0 u_instr_mem (
    .clka(clk),
    .addra(pc[15:2]),
    .douta(instr)
);
```

### Option 2: External Memory (SPI Flash, DDR)
Add memory controller and cache:
```verilog
memory_controller u_mem_ctrl (
    .clk(clk),
    .addr(pc),
    .data_out(instr),
    // SPI/DDR interface...
);
```

### Option 3: Hybrid Approach
- Boot ROM in BRAM (small, fast)
- Main program in external memory
- Memory map:
  - 0x0000_0000 - 0x0000_3FFF: BRAM (16KB boot code)
  - 0x8000_0000 - 0x8FFF_FFFF: External RAM

## Memory Map Recommendations

Standard RISC-V memory map:

```
0x0000_0000 - 0x0000_FFFF: Boot ROM (64KB)
0x0001_0000 - 0x7FFF_FFFF: Reserved
0x8000_0000 - 0xFFFF_FFFF: RAM
```

For simulation, simplified map:
```
0x0000_0000 - 0x0000_0FFF: Instruction memory (4KB)
0x0001_0000 - 0x0001_0FFF: Data memory (4KB)
```

## Common Issues

### Issue 1: PC Misalignment
**Problem**: PC not multiple of 4
**Solution**: Always initialize PC to aligned address, check branch targets

### Issue 2: Out of Bounds
**Problem**: PC exceeds memory size
**Solution**:
- Increase MEM_SIZE parameter
- Add bounds checking in PC logic
- Use memory map with wraparound

### Issue 3: Instruction Not Updating
**Problem**: Same instruction fetched repeatedly
**Solution**: Check PC update logic, verify alu_ready signal

### Issue 4: Hex File Not Loading
**Problem**: $readmemh not finding file
**Solution**:
- Use absolute path or ensure file in simulation directory
- Check file format (32-bit hex values, one per line)
- Verify file permissions

## Performance Considerations

### Simulation Performance
- **Large MEM_SIZE**: Slower simulation initialization
- **Solution**: Use only needed memory size

### FPGA Performance
- **Combinational read**: May not meet timing at high frequencies
- **Solution**: Add pipeline register for synchronous read

```verilog
// Synchronous read version
always @(posedge clk) begin
    if (!rst_n)
        instr <= 32'h00000013;
    else if (word_addr < MEM_SIZE)
        instr <= mem[word_addr];
end
```

## Example: Loading Custom Program

```verilog
// In your testbench
initial begin
    // Simple Fibonacci program
    top.u_instr_mem.mem[0] = 32'h00100093;  // ADDI x1, x0, 1   (a=1)
    top.u_instr_mem.mem[1] = 32'h00100113;  // ADDI x2, x0, 1   (b=1)
    top.u_instr_mem.mem[2] = 32'h002081B3;  // ADD x3, x1, x2   (c=a+b)
    top.u_instr_mem.mem[3] = 32'h00010093;  // ADDI x1, x2, 0   (a=b)
    top.u_instr_mem.mem[4] = 32'h00018113;  // ADDI x2, x3, 0   (b=c)
    top.u_instr_mem.mem[5] = 32'hFF5FF06F;  // JAL x0, -12      (loop)
end
```

## Next Steps

1. Create data memory module for load/store
2. Integrate both memories into top_soc
3. Create testbench for full system verification
4. Profile and optimize for FPGA synthesis
5. Add cache for performance (optional)
