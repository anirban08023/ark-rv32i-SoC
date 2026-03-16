#include "Vtop_soc.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vtop_soc* top = new Vtop_soc; // Instantiate our design

    // Setup waveform dumping
    Verilated::traceEverOn(true);
    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("waveforms/dump.vcd");

    int main_time = 0;
    top->reset = 1; // Start in reset

    while (main_time < 100) { // Run for 100 time units
        if (main_time > 10) top->reset = 0; // Release reset after 10 units
        
        top->clk = !top->clk; // Toggle clock
        top->eval();          // Evaluate logic
        
        tfp->dump(main_time); // Dump signals to VCD
        main_time++;
    }

    tfp->close();
    delete top;
    exit(0);
}