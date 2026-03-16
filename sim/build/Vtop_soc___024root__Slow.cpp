// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vtop_soc.h for the primary calling header

#include "Vtop_soc__pch.h"
#include "Vtop_soc__Syms.h"
#include "Vtop_soc___024root.h"

void Vtop_soc___024root___ctor_var_reset(Vtop_soc___024root* vlSelf);

Vtop_soc___024root::Vtop_soc___024root(Vtop_soc__Syms* symsp, const char* v__name)
    : VerilatedModule{v__name}
    , vlSymsp{symsp}
 {
    // Reset structure values
    Vtop_soc___024root___ctor_var_reset(this);
}

void Vtop_soc___024root::__Vconfigure(bool first) {
    if (false && first) {}  // Prevent unused
}

Vtop_soc___024root::~Vtop_soc___024root() {
}
