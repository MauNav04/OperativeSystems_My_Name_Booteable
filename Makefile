ASM=nasm
BUILD=build
SRC=src

all: $(BUILD)/boot.img

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/stage1.bin: $(SRC)/boot.asm | $(BUILD)
	$(ASM) -f bin $< -o $@

$(BUILD)/stage2.bin: $(SRC)/myname.asm | $(BUILD)
	$(ASM) -f bin $< -o $@

$(BUILD)/boot.img: $(BUILD)/stage1.bin $(BUILD)/stage2.bin
	cat $(BUILD)/stage1.bin $(BUILD)/stage2.bin > $(BUILD)/boot.img

run: $(BUILD)/boot.img
	qemu-system-i386 -drive format=raw,file=$(BUILD)/boot.img

clean:
	rm -rf $(BUILD)