# Project Folders
RTL_DIR = ../rtl
TB_DIR  = ./tb
BUILD_DIR = ./build
WAVE_DIR  = ./waveforms

# Tools
VERILATOR = verilator

# Use --Mdir for compatibility with older Verilator versions
# -Wall: enable all warnings
# --trace: enable waveform tracing
# --cc: generate C++ output
# --exe: generate an executable
# --build: automatically call make on the generated C++ (Verilator 4.0+)
VERILATOR_FLAGS = -Wall --trace --cc --exe --build -j 4 --Mdir $(BUILD_DIR)

# The name of your top Verilog module
TOP_MODULE = top_soc
# Your C++ testbench wrapper
CPP_TB = $(TB_DIR)/sim_main.cpp

all: run

compile:
	@mkdir -p $(BUILD_DIR)
	@mkdir -p $(WAVE_DIR)
	@echo "--- Verilating and Building ---"
	$(VERILATOR) $(VERILATOR_FLAGS) \
		-I$(RTL_DIR) \
		--top-module $(TOP_MODULE) \
		$(RTL_DIR)/$(TOP_MODULE).v $(CPP_TB)

run: compile
	@echo "--- Running Simulation ---"
	@# Execute the binary created by Verilator
	./$(BUILD_DIR)/V$(TOP_MODULE)

view:
	@echo "--- Opening GTKWave ---"
	gtkwave $(WAVE_DIR)/dump.vcd

clean:
	rm -rf $(BUILD_DIR) $(WAVE_DIR)