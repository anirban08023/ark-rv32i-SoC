# Comprehensive Guide to the 64-bit RISC-V ALU

This document explains the `alu.v` hardware module in detail. It is designed for readers who are new to hardware description languages (Verilog) and computer architecture.

---

## 1. What is an ALU?
An **ALU (Arithmetic Logic Unit)** is the "calculator" inside a computer's processor. It takes two numbers, performs a mathematical or logical operation (like addition or a bitwise AND), and outputs the result.

In our project, this ALU follows the **RISC-V** standard, specifically the **RV64I** (Base) and **RV64M** (Math) extensions.

---

## 2. Code Structure: The Module Header
The first few lines define the "box" and its "pins" (inputs and outputs).

```verilog
module alu (
    input wire [63:0] a,
    input wire [63:0] b,
    input wire [4:0] alu_ctrl,
    output reg [63:0] result,
    output wire zero
);
```

### Syntax Breakdown:
*   **`module ... endmodule`**: Think of this as a "class" in software. It encapsulates all the logic for this specific piece of hardware.
*   **`input wire [63:0] a`**: 
    *   `input`: Electricity flows *into* this pin.
    *   `wire`: A physical connection that carries a signal.
    *   `[63:0]`: This is a **64-bit bus**. It means there are 64 individual wires bundled together to represent one large number (bits 0 through 63).
*   **`output reg [63:0] result`**:
    *   `output`: The answer flows *out* of this pin.
    *   `reg`: Short for "register." In Verilog, if you want to assign a value to an output inside a `case` or `if` block, it must be declared as a `reg`.
*   **`alu_ctrl`**: A 5-bit signal that tells the ALU *which* math problem to solve (e.g., `0` for add, `16` for multiply).

---

## 3. Multiplication Helpers
Before doing the math, we calculate the product of `a` and `b`.

```verilog
wire [127:0] mul_full_ss = $signed(a) * $signed(b);
wire [127:0] mul_full_su = $signed(a) * $signed({1'b0, b});
wire [127:0] mul_full_uu = a * b;
```

### Why 128 bits?
When you multiply two 64-bit numbers (e.g., $10 \times 10 = 100$), the result can be twice as long as the inputs. We need 128 bits to hold the full potential answer.

### Syntax Breakdown:
*   **`$signed()`**: Tells the computer to treat the number as having a positive or negative sign (Two's Complement).
*   **`{1'b0, b}`**: This is **concatenation**. It adds a `0` to the front of `b` to force it to be treated as a positive (unsigned) number during a signed multiplication.
*   **`ss`, `su`, `uu`**: These stand for Signed-Signed, Signed-Unsigned, and Unsigned-Unsigned.

---

## 4. The Main Logic Block
This is where the actual calculation happens.

```verilog
always @(*) begin
    case (alu_ctrl)
        ...
    endcase
end
```

### Syntax Breakdown:
*   **`always @(*)`**: This means "Always perform the following logic whenever *any* input (`a`, `b`, or `alu_ctrl`) changes." It is **combinational logic**, meaning it happens instantly.
*   **`case (alu_ctrl)`**: Just like a "switch" statement in C++ or Java. It looks at the 5-bit control code and picks the matching operation.

---

## 5. Operations Explained

### A. Basic Math (RV64I)
*   **`5'b00000: result = a + b;`**: Standard addition.
*   **`5'b01000: result = a - b;`**: Standard subtraction.
*   **`5'b00111: result = a & b;`**: **AND Gate**. Only keeps bits that are `1` in both `a` and `b`.
*   **`5'b00001: result = a << b[5:0];`**: **Shift Left**. Moves all bits in `a` to the left. `b[5:0]` means we only use the last 6 bits of `b` to determine how far to shift (since $2^6 = 64$).

### B. Set Less Than (SLT)
*   **`5'b00010: result = ($signed(a) < $signed(b)) ? 64'd1 : 64'd0;`**
    *   If `a` is less than `b`, the result is `1`. Otherwise, it's `0`.
    *   **`64'd1`**: Means "a 64-bit Decimal number with the value 1."

### C. Multiplication and Division (RV64M)
*   **`MUL` (5'b10000)**: Returns the lower 64 bits of the product.
*   **`MULH` (5'b10001)**: Returns the upper 64 bits of a signed product (the "carry" part).
*   **`DIV` (5'b10100)**:
    ```verilog
    if (b == 64'b0) result = 64'hFFFF_FFFF_FFFF_FFFF;
    ```
    *   If you divide by zero, the hardware doesn't crash; it returns `-1` (which is all `F`s in hexadecimal).

---

## 6. The Status Flag (Zero)
```verilog
assign zero = (result == 64'b0);
```
*   **`assign`**: Creates a permanent "live" connection.
*   If the `result` of any math operation is exactly zero, the `zero` wire turns "High" (1).
*   **Usage**: The processor uses this to handle "Branches." For example: "If $A - B = 0$, then $A$ and $B$ are equal, so jump to a different part of the code."

---

## Summary of Syntax Used
| Symbol | Meaning | Example |
| :--- | :--- | :--- |
| `[63:0]` | Bit range (64 bits) | `wire [7:0] my_byte;` |
| `5'b101` | 5-bit Binary number | `5'b00101` is the number 5. |
| `64'hFF` | 64-bit Hexadecimal | `h` stands for Hex. |
| `<<<` | Arithmetic Shift | Keeps the sign bit. |
| `==` | Equality Check | Returns 1 if values match. |
| `? :` | Ternary Operator | `(condition) ? true_val : false_val` |
