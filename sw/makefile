# Directories
SRC_DIR = src
BIN_DIR = bin
DATA_DIR = data

# Compiler and flags
CC = gcc  # Change to g++ if you're using C++

# List of source files
SRCS = encode_image.c decode_m3.c decode_m2.c decode_m1.c

# Extract program names (without .c extension)
PROGS = $(SRCS:.c=)

.PHONY: all clean run $(BIN_DIR)

# Default target: Compile all programs
all: $(BIN_DIR) $(PROGS) run_encode_image run_decode_m3

# Compile each program separately
$(PROGS): %: %.c | $(BIN_DIR)
	@echo "Compiling $@..."
	@$(CC) $(CFLAGS) -o $(BIN_DIR)/$@ $<

# Run a specific program
run_encode_image: $(BIN_DIR)/encode_image
	@echo "Running encode_image with the following parameters:"
	@echo "Image Path: data/truck.ppm"
	@echo "Output File: image.mic18"
	@echo "Quantization Choice: 0"
	@$(BIN_DIR)/encode_image ../data/truck.ppm truck.mic18 0

run_decode_m3: $(BIN_DIR)/decode_m3
	@echo "Running decode_m3 with the following parameters:"
	@echo "Compressed Image Path: truck.mic18"
	@echo "Output File: image.sram_d2"
	@$(BIN_DIR)/decode_m3 truck.mic18 image.sram_d2

run:
	@if [ -z "$(prog)" ]; then \
		echo "Please specify a program to run using 'make run prog=<name>'" && \
		exit 1; \
	fi
	@$(BIN_DIR)/$(prog)

	

# Clean compiled files
clean:
	rm -rf $(BIN_DIR)


