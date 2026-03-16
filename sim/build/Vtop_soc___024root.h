// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design internal header
// See Vtop_soc.h for the primary calling header

#ifndef VERILATED_VTOP_SOC___024ROOT_H_
#define VERILATED_VTOP_SOC___024ROOT_H_  // guard

#include "verilated.h"


class Vtop_soc__Syms;

class alignas(VL_CACHE_LINE_BYTES) Vtop_soc___024root final : public VerilatedModule {
  public:

    // DESIGN SPECIFIC STATE
    VL_IN8(clk,0,0);
    VL_IN8(reset,0,0);
    VL_OUT8(counter,7,0);
    CData/*0:0*/ __Vtrigprevexpr___TOP__clk__0;
    CData/*0:0*/ __VactContinue;
    IData/*31:0*/ __VactIterCount;
    VlTriggerVec<1> __VactTriggered;
    VlTriggerVec<1> __VnbaTriggered;

    // INTERNAL VARIABLES
    Vtop_soc__Syms* const vlSymsp;

    // CONSTRUCTORS
    Vtop_soc___024root(Vtop_soc__Syms* symsp, const char* v__name);
    ~Vtop_soc___024root();
    VL_UNCOPYABLE(Vtop_soc___024root);

    // INTERNAL METHODS
    void __Vconfigure(bool first);
};


#endif  // guard
