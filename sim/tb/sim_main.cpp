#include "Vtop_soc.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <iostream>
#include <iomanip>

vluint64_t main_time = 0;

void tick(Vtop_soc* top, VerilatedVcdC* tfp) {
    top->clk = 0;
    top->eval();
    if (tfp) tfp->dump(main_time++);
    top->clk = 1;
    top->eval();
    if (tfp) tfp->dump(main_time++);
}

void run_test(Vtop_soc* top, VerilatedVcdC* tfp, uint64_t a, uint64_t b, uint8_t ctrl, bool is_slow, uint64_t expected, const char* name) {
    top->alu_a = a;
    top->alu_b = b;
    top->alu_ctrl = ctrl;
    top->alu_start = 1;
    
    tick(top, tfp);
    top->alu_start = 0; // De-assert start after one tick

    int timeout = 100; // Cycles to wait
    while (!top->alu_ready && timeout-- > 0) {
        tick(top, tfp);
    }
    
    std::cout << "[" << name << "] result=" << std::hex << top->alu_result 
              << " expected=" << expected << " cycles=" << std::dec << (100-timeout);
    
    if (top->alu_result == expected) std::cout << " [PASS]\n";
    else std::cout << " [FAIL]\n";
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vtop_soc* top = new Vtop_soc;

    Verilated::traceEverOn(true);
    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("waveforms/dump.vcd");

    // Reset Sequence
    top->rst_n = 0;
    for (int i=0; i<5; i++) tick(top, tfp);
    top->rst_n = 1;
    tick(top, tfp);

    std::cout << "--- Starting SoC ALU Verification ---\n";

    // ========== FAST PATH TESTS ==========
    // 1. FAST PATH: ADDW (Sign-extended)
    run_test(top, tfp, 0x000000007FFFFFFFULL, 1, 0x20 | 0x00, false, 0xFFFFFFFF80000000ULL, "ADDW");

    // 2. FAST PATH: SH2ADD (Bitmanip)
    // (a << 2) + b = (10 << 2) + 5 = 45
    run_test(top, tfp, 10, 5, 0x03, false, 45, "SH2ADD");

    // 3. FAST PATH: BSET (Bitmanip Single-bit)
    // 0x0 | (1 << 5) = 0x20
    run_test(top, tfp, 0, 5, 0x0C, false, 0x20, "BSET");

    // ========== MULTIPLICATION TESTS ==========
    // 4. MEDIUM PATH: MUL (3 Cycles)
    run_test(top, tfp, 12, 12, 0x10, true, 144, "MUL");

    // ========== DIVISION TESTS ==========
    // 5. SLOW PATH: DIV (signed division)
    run_test(top, tfp, 1000, 10, 0x14, true, 100, "DIV");

    // 6. SLOW PATH: DIVU (unsigned division)
    run_test(top, tfp, 100, 10, 0x15, true, 10, "DIVU");

    // 7. SLOW PATH: REM (signed remainder)
    run_test(top, tfp, 100, 3, 0x16, true, 1, "REM");

    // 8. SLOW PATH: REMU (unsigned remainder)
    run_test(top, tfp, 100, 3, 0x17, true, 1, "REMU");

    // ========== DIVISION EDGE CASES ==========
    // 9. Division by zero - quotient should be -1 (all 1s)
    run_test(top, tfp, 100, 0, 0x14, true, 0xFFFFFFFFFFFFFFFFULL, "DIV_BY_ZERO_Q");

    // 10. Division by zero - remainder should be dividend
    run_test(top, tfp, 100, 0, 0x16, true, 100, "DIV_BY_ZERO_R");

    // 11. Signed overflow: MIN_INT / -1 should return MIN_INT
    run_test(top, tfp, 0x8000000000000000ULL, 0xFFFFFFFFFFFFFFFFULL, 0x14, true, 0x8000000000000000ULL, "DIV_OVERFLOW");

    // 12. Signed division with negative numbers: -100 / 10 = -10
    run_test(top, tfp, static_cast<uint64_t>(-100LL), 10, 0x14, true, static_cast<uint64_t>(-10LL), "DIV_NEG");

    std::cout << "--- Verification Complete ---\n";

    tfp->close();
    delete top;
    return 0;
}
