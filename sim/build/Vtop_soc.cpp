// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Model implementation (design independent parts)

#include "Vtop_soc__pch.h"
#include "verilated_vcd_c.h"

//============================================================
// Constructors

Vtop_soc::Vtop_soc(VerilatedContext* _vcontextp__, const char* _vcname__)
    : VerilatedModel{*_vcontextp__}
    , vlSymsp{new Vtop_soc__Syms(contextp(), _vcname__, this)}
    , clk{vlSymsp->TOP.clk}
    , reset{vlSymsp->TOP.reset}
    , counter{vlSymsp->TOP.counter}
    , rootp{&(vlSymsp->TOP)}
{
    // Register model with the context
    contextp()->addModel(this);
}

Vtop_soc::Vtop_soc(const char* _vcname__)
    : Vtop_soc(Verilated::threadContextp(), _vcname__)
{
}

//============================================================
// Destructor

Vtop_soc::~Vtop_soc() {
    delete vlSymsp;
}

//============================================================
// Evaluation function

#ifdef VL_DEBUG
void Vtop_soc___024root___eval_debug_assertions(Vtop_soc___024root* vlSelf);
#endif  // VL_DEBUG
void Vtop_soc___024root___eval_static(Vtop_soc___024root* vlSelf);
void Vtop_soc___024root___eval_initial(Vtop_soc___024root* vlSelf);
void Vtop_soc___024root___eval_settle(Vtop_soc___024root* vlSelf);
void Vtop_soc___024root___eval(Vtop_soc___024root* vlSelf);

void Vtop_soc::eval_step() {
    VL_DEBUG_IF(VL_DBG_MSGF("+++++TOP Evaluate Vtop_soc::eval_step\n"); );
#ifdef VL_DEBUG
    // Debug assertions
    Vtop_soc___024root___eval_debug_assertions(&(vlSymsp->TOP));
#endif  // VL_DEBUG
    vlSymsp->__Vm_activity = true;
    vlSymsp->__Vm_deleter.deleteAll();
    if (VL_UNLIKELY(!vlSymsp->__Vm_didInit)) {
        vlSymsp->__Vm_didInit = true;
        VL_DEBUG_IF(VL_DBG_MSGF("+ Initial\n"););
        Vtop_soc___024root___eval_static(&(vlSymsp->TOP));
        Vtop_soc___024root___eval_initial(&(vlSymsp->TOP));
        Vtop_soc___024root___eval_settle(&(vlSymsp->TOP));
    }
    VL_DEBUG_IF(VL_DBG_MSGF("+ Eval\n"););
    Vtop_soc___024root___eval(&(vlSymsp->TOP));
    // Evaluate cleanup
    Verilated::endOfEval(vlSymsp->__Vm_evalMsgQp);
}

//============================================================
// Events and timing
bool Vtop_soc::eventsPending() { return false; }

uint64_t Vtop_soc::nextTimeSlot() {
    VL_FATAL_MT(__FILE__, __LINE__, "", "%Error: No delays in the design");
    return 0;
}

//============================================================
// Utilities

const char* Vtop_soc::name() const {
    return vlSymsp->name();
}

//============================================================
// Invoke final blocks

void Vtop_soc___024root___eval_final(Vtop_soc___024root* vlSelf);

VL_ATTR_COLD void Vtop_soc::final() {
    Vtop_soc___024root___eval_final(&(vlSymsp->TOP));
}

//============================================================
// Implementations of abstract methods from VerilatedModel

const char* Vtop_soc::hierName() const { return vlSymsp->name(); }
const char* Vtop_soc::modelName() const { return "Vtop_soc"; }
unsigned Vtop_soc::threads() const { return 1; }
void Vtop_soc::prepareClone() const { contextp()->prepareClone(); }
void Vtop_soc::atClone() const {
    contextp()->threadPoolpOnClone();
}
std::unique_ptr<VerilatedTraceConfig> Vtop_soc::traceConfig() const {
    return std::unique_ptr<VerilatedTraceConfig>{new VerilatedTraceConfig{false, false, false}};
};

//============================================================
// Trace configuration

void Vtop_soc___024root__trace_decl_types(VerilatedVcd* tracep);

void Vtop_soc___024root__trace_init_top(Vtop_soc___024root* vlSelf, VerilatedVcd* tracep);

VL_ATTR_COLD static void trace_init(void* voidSelf, VerilatedVcd* tracep, uint32_t code) {
    // Callback from tracep->open()
    Vtop_soc___024root* const __restrict vlSelf VL_ATTR_UNUSED = static_cast<Vtop_soc___024root*>(voidSelf);
    Vtop_soc__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    if (!vlSymsp->_vm_contextp__->calcUnusedSigs()) {
        VL_FATAL_MT(__FILE__, __LINE__, __FILE__,
            "Turning on wave traces requires Verilated::traceEverOn(true) call before time 0.");
    }
    vlSymsp->__Vm_baseCode = code;
    tracep->pushPrefix(std::string{vlSymsp->name()}, VerilatedTracePrefixType::SCOPE_MODULE);
    Vtop_soc___024root__trace_decl_types(tracep);
    Vtop_soc___024root__trace_init_top(vlSelf, tracep);
    tracep->popPrefix();
}

VL_ATTR_COLD void Vtop_soc___024root__trace_register(Vtop_soc___024root* vlSelf, VerilatedVcd* tracep);

VL_ATTR_COLD void Vtop_soc::trace(VerilatedVcdC* tfp, int levels, int options) {
    if (tfp->isOpen()) {
        vl_fatal(__FILE__, __LINE__, __FILE__,"'Vtop_soc::trace()' shall not be called after 'VerilatedVcdC::open()'.");
    }
    if (false && levels && options) {}  // Prevent unused
    tfp->spTrace()->addModel(this);
    tfp->spTrace()->addInitCb(&trace_init, &(vlSymsp->TOP));
    Vtop_soc___024root__trace_register(&(vlSymsp->TOP), tfp->spTrace());
}
