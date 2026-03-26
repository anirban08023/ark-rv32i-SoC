# RV64I SoC Datapath Verification

## Complete Datapath Connections

### ✅ 1. INSTRUCTION DECODE PATH
```
instr[31:0] (input)
    ↓
[Decoder] (lines 81-99)
    ↓
Outputs:
  - rs1_addr[4:0]    → Register File
  - rs2_addr[4:0]    → Register File
  - rd_addr[4:0]     → Register File
  - imm[63:0]        → ALU mux & PC
  - alu_ctrl[5:0]    → ALU
  - alu_src          → ALU mux control
  - alu_start        → ALU
  - reg_write        → Register File
  - branch           → PC (output)
  - jump             → PC & Write-back mux (output)
  - branch_type[2:0] → PC (output)
  - mem_*            → Memory interface (outputs)
  - is_valid         → Validity flag (output)
```

### ✅ 2. REGISTER FILE PATH
```
[Register File] (lines 104-114)
Inputs:
  - rs1_addr ← Decoder
  - rs2_addr ← Decoder
  - rd_addr  ← Decoder
  - rd_data  ← Write-back mux (line 55)
  - reg_write ← Decoder

Outputs:
  - rs1_data[63:0] → ALU operand A
  - rs2_data[63:0] → ALU operand B mux

Special:
  - x0 hardwired to 0 (in reg_file.v)
  - x0 write protected (in reg_file.v)
```

### ✅ 3. ALU OPERAND SELECTION
```
Operand A (line 122):
  rs1_data (direct from Register File)

Operand B (lines 49, 123):
  alu_b = alu_src ? imm : rs2_data

  alu_src = 0 → rs2_data (R-type: ADD, SUB, MUL, etc.)
  alu_src = 1 → imm      (I-type: ADDI, XORI, LOAD, etc.)
```

### ✅ 4. ALU EXECUTION PATH
```
[ALU] (lines 119-132)
Inputs:
  - a = rs1_data
  - b = alu_b (muxed)
  - alu_ctrl[5:0] ← Decoder
  - start = alu_start ← Decoder

Outputs:
  - result[63:0]  → Write-back mux & PC (for JALR)
  - ready         → PC update control
  - zero          → Output
  - eq, lt, ltu   → PC (branch conditions) & Outputs

Operations Supported:
  - Base RV64I: ADD, SUB, SLL, SRL, SRA, AND, OR, XOR
  - Word ops: ADDW, SUBW, SLLW, SRLW, SRAW
  - M-extension: MUL, MULH, MULHSU, MULHU, DIV, DIVU, REM, REMU (+ W variants)
  - Zba: SH1ADD, SH2ADD, SH3ADD
  - Zbb: ANDN, ORN, XNOR, ROL, ROR, CLZ, CTZ, CPOP (+ W variants)
  - Zbs: BSET, BCLR, BINV, BEXT
```

### ✅ 5. WRITE-BACK PATH
```
Write-back Mux (line 55):
  rd_data = jump ? pc_plus_4 : alu_result

For JAL/JALR (jump=1):
  rd_data = pc_plus_4  (return address)

For all other instructions (jump=0):
  rd_data = alu_result (computation result)

rd_data → Register File.rd_data (line 110)
```

### ✅ 6. PROGRAM COUNTER PATH
```
[PC] (lines 60-76)
Inputs:
  - branch       ← Decoder
  - jump         ← Decoder
  - branch_type  ← Decoder
  - instr        ← Top-level input (for JALR detection)
  - imm          ← Decoder
  - alu_eq       ← ALU
  - alu_lt       ← ALU
  - alu_ltu      ← ALU
  - alu_ready    ← ALU
  - alu_result   ← ALU (for JALR target)

Outputs:
  - pc[63:0]      → Top-level output (instruction fetch address)
  - pc_next[63:0] → Top-level output (next PC)
  - pc_plus_4     → Write-back mux (for JAL/JALR)

PC Update Logic:
  - Sequential:    pc = pc + 4
  - Branch taken:  pc = pc + imm
  - JAL:           pc = pc + imm
  - JALR:          pc = (rs1 + imm) & ~1
  - Multi-cycle:   pc holds when alu_ready=0
```

## Signal Flow Summary

### Complete Instruction Execution Cycle:

1. **Fetch** (external to this module)
   - Use `pc` output to fetch instruction from memory
   - Feed instruction into `instr` input

2. **Decode** (Decoder module)
   - Parse opcode, funct3, funct7
   - Extract register addresses
   - Decode immediate
   - Generate control signals

3. **Register Read** (Register File)
   - Read rs1_data and rs2_data
   - Combinational read (asynchronous)

4. **Execute** (ALU)
   - Compute result based on alu_ctrl
   - Generate comparison flags
   - Multi-cycle for MUL/DIV

5. **Write-back** (Register File)
   - Write rd_data to rd_addr
   - Synchronous write on clock edge
   - Only when reg_write=1

6. **PC Update** (PC module)
   - Update PC based on instruction type
   - Sequential, branch, or jump
   - Only when alu_ready=1

## Critical Timing Dependencies

### ✅ Multi-cycle Operation Handling:
- **MUL instructions**: 3 cycles
- **DIV instructions**: up to 64 cycles
- **PC frozen**: When alu_ready=0, PC doesn't advance
- **Register writes frozen**: reg_write controlled by decoder

### ✅ Combinational Paths:
1. `instr` → `decoder` → `reg_file` → `alu` → `result` (single cycle for fast ops)
2. `decoder` → `pc` → `pc_next` (branch/jump decision)

### ✅ Sequential Elements:
1. Register File write (synchronous)
2. PC update (synchronous, gated by alu_ready)
3. ALU multi-cycle operations (pipelined/iterative)

## Verification Checklist

- [x] Decoder outputs connected to all downstream modules
- [x] Register addresses routed correctly
- [x] ALU operand B mux implemented (rs2 vs immediate)
- [x] Write-back mux implemented (alu_result vs pc_plus_4)
- [x] Branch flags (eq, lt, ltu) connected to PC
- [x] Jump signal used for write-back selection
- [x] PC outputs exposed for instruction fetch
- [x] Multi-cycle ALU ready signal gates PC updates
- [x] JALR detection using instruction input to PC
- [x] Memory interface signals exposed for future use
- [x] All decoder control signals utilized
- [x] x0 hardwired to zero in register file
- [x] Sign-extended immediates (64-bit)

## Architecture Compliance

### ✅ RV64I Base ISA:
- [x] 32 × 64-bit general-purpose registers
- [x] x0 hardwired to zero
- [x] PC-relative branches and jumps
- [x] I/S/B/U/J immediate formats
- [x] Register-register and register-immediate ops
- [x] 32-bit word operations with sign extension

### ✅ Extensions:
- [x] M: Integer multiplication and division
- [x] Zba: Address generation instructions
- [x] Zbb: Basic bit manipulation
- [x] Zbs: Single-bit instructions

## Remaining Work

### To-Do:
1. **Instruction Memory**: ROM/RAM to hold program
2. **Data Memory**: RAM for load/store operations
3. **Memory Interface**: Connect mem_read/mem_write to actual memory
4. **Load data path**: Mux memory data into write-back
5. **Pipeline stages** (optional): IF/ID/EX/MEM/WB for performance
6. **Exception handling** (optional): Trap on invalid instructions
7. **CSR support** (optional): Control and status registers

### Current Capabilities:
✅ Can execute all integer ALU operations (R-type, I-type)
✅ Can handle branches and jumps (control flow)
✅ Proper register write-back including JAL/JALR return addresses
✅ Multi-cycle operation support (MUL/DIV)
⚠️ Cannot execute LOAD/STORE (needs memory interface)
⚠️ Cannot fetch instructions automatically (needs instruction memory)

## Notes

The current datapath is **architecturally complete** for computational instructions. All connections are verified and follow the standard RISC-V 5-stage pipeline logic, currently implemented as a single-cycle design (with multi-cycle support for MUL/DIV).

To make this a functional processor, only memory components are needed:
- Instruction Memory (ROM) connected to PC
- Data Memory (RAM) connected to ALU result and mem_* signals
