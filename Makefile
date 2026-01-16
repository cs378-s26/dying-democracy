# rpi4-os/Makefile
# Usage:
#   make                (default BOARD=qemu_raspi4b)
#   make BOARD=rpi4
#   make run
#   make gdb            (starts QEMU paused with GDB server)
#   make clean

BOARD ?= qemu_raspi4b

# Toolchain prefix (adjust if you use a different one)
CROSS ?= aarch64-none-elf-

CC      := $(CROSS)gcc
CXX     := $(CROSS)g++
LD      := $(CROSS)ld
OBJCOPY := $(CROSS)objcopy
OBJDUMP := $(CROSS)objdump
NM      := $(CROSS)nm

QEMU ?= qemu-system-aarch64

BUILD := build
LINKER_SCRIPT := link/rpi4.ld

INCLUDES := -Iinclude -Iboard/$(BOARD)

# CPU target: Pi 4 is Cortex-A72 (ARMv8-A)
ARCH_CFLAGS  := -mcpu=cortex-a72 -march=armv8-a+simd+crc
COMMON_CFLAGS := $(ARCH_CFLAGS) -ffreestanding -fno-stack-protector -fno-omit-frame-pointer \
                 -fno-pic -fno-pie -Wall -Wextra -Werror -O2 -g3 -MMD -MP

# Freestanding C++ kernel settings (per your choice)
CXXFLAGS := $(COMMON_CFLAGS) $(INCLUDES) -std=gnu++20 \
            -fno-exceptions -fno-rtti -fno-threadsafe-statics

CFLAGS   := $(COMMON_CFLAGS) $(INCLUDES) -std=gnu11

ASFLAGS  := $(ARCH_CFLAGS) -g3

LDFLAGS  := -T $(LINKER_SCRIPT) -nostdlib --gc-sections -Map=$(BUILD)/kernel.map

# Define board macro to switch constants cleanly in code if you want
CPP_DEFS := -DBOARD_$(shell echo $(BOARD) | tr a-z A-Z)

# Sources
CPP_SRCS := \
  $(wildcard src/kernel/*.cpp) \
  $(wildcard src/drivers/*.cpp) \
  $(wildcard src/runtime/*.cpp) \
  board/$(BOARD)/board.cpp

C_SRCS := \
  $(wildcard src/runtime/*.c)

S_SRCS := \
  $(wildcard src/arch/aarch64/*.S)

OBJS := \
  $(patsubst %.cpp,$(BUILD)/%.o,$(CPP_SRCS)) \
  $(patsubst %.c,$(BUILD)/%.o,$(C_SRCS)) \
  $(patsubst %.S,$(BUILD)/%.o,$(S_SRCS))

DEPS := $(OBJS:.o=.d)

# Final outputs
KERNEL_ELF := $(BUILD)/kernel.elf
KERNEL_IMG := $(BUILD)/kernel8.img

.PHONY: all clean run gdb disasm symbols

all: $(KERNEL_IMG)

# Link ELF
$(KERNEL_ELF): $(OBJS) $(LINKER_SCRIPT)
	@mkdir -p $(dir $@)
	$(LD) $(LDFLAGS) -o $@ $(OBJS)

# Convert to raw image
$(KERNEL_IMG): $(KERNEL_ELF)
	$(OBJCOPY) -O binary $< $@

# Compile C++
$(BUILD)/%.o: %.cpp
	@mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) $(CPP_DEFS) -c $< -o $@

# Compile C
$(BUILD)/%.o: %.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

# Assemble
$(BUILD)/%.o: %.S
	@mkdir -p $(dir $@)
	$(CC) $(ASFLAGS) -c $< -o $@

run: $(KERNEL_IMG)
	$(QEMU) -M raspi4b -serial stdio -display none \
	        -kernel $(KERNEL_IMG) -smp 4 -m 2048

# Paused + GDB server on tcp::1234 (GDB: target remote :1234)
gdb: $(KERNEL_IMG)
	$(QEMU) -M raspi4b -serial stdio -display none \
	        -kernel $(KERNEL_IMG) -smp 4 -m 2048 \
	        -S -gdb tcp::1234

disasm: $(KERNEL_ELF)
	$(OBJDUMP) -d $(KERNEL_ELF) > $(BUILD)/kernel.dis

symbols: $(KERNEL_ELF)
	$(NM) -n $(KERNEL_ELF) > $(BUILD)/kernel.sym

clean:
	rm -rf $(BUILD)

-include $(DEPS)
