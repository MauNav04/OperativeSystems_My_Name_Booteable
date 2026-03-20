
# pa legacy

# Archivo fuente de la primera etapa
LEGACY_STAGE1_SRC = src/boot.asm

# Archivo fuente de la segunda etapa
LEGACY_STAGE2_SRC = src/myname.asm

# Binarios intermedios
LEGACY_STAGE1_BIN = build/stage1.bin
LEGACY_STAGE2_BIN = build/stage2.bin

# Imagen final booteable para QEMU legacy
LEGACY_IMG        = build/boot.img


# UEFI miedo terror

# Código fuente principal en C
UEFI_SRC = src/uefi/main.c

# Archivos intermedios de compilación
UEFI_OBJ = build/main.o
UEFI_SO  = build/main.so

# Binario EFI final que va dentro de EFI/BOOT/
UEFI_EFI = uefi_disk/EFI/BOOT/BOOTX64.EFI

# Copia local de las variables UEFI que usa QEMU
OVMF_VARS = build/OVMF_VARS.fd

# Firmware UEFI de QEMU (OVMF)
OVMF_CODE = /usr/share/OVMF/OVMF_CODE_4M.fd

# Plantilla base de variables UEFI
OVMF_VARS_TEMPLATE = /usr/share/OVMF/OVMF_VARS_4M.fd


# Si alguien solo pone "make", se compilan ambas versiones
all: legacy-build uefi-build


# compilamos stage 1 y 2 y los concatenamos para crear boot.img
legacy-build:
	mkdir -p build
	nasm -f bin $(LEGACY_STAGE1_SRC) -o $(LEGACY_STAGE1_BIN)
	nasm -f bin $(LEGACY_STAGE2_SRC) -o $(LEGACY_STAGE2_BIN)
	cat $(LEGACY_STAGE1_BIN) $(LEGACY_STAGE2_BIN) > $(LEGACY_IMG)



# corremos el legacy en qemu
legacy-run: legacy-build
	qemu-system-i386 -fda $(LEGACY_IMG) -boot a



# Compila main.c como aplicación UEFI:
# .c -> .o -> .so -> BOOTX64.EFI

uefi-build:
	mkdir -p build
	mkdir -p uefi_disk/EFI/BOOT
	gcc -I/usr/include/efi -I/usr/include/efi/x86_64 \
	  -fpic -ffreestanding -fno-stack-protector -fno-stack-check \
	  -fshort-wchar -mno-red-zone -maccumulate-outgoing-args \
	  -c $(UEFI_SRC) -o $(UEFI_OBJ)
	ld -nostdlib -znocombreloc -T /usr/lib/elf_x86_64_efi.lds \
	  -shared -Bsymbolic /usr/lib/crt0-efi-x86_64.o $(UEFI_OBJ) \
	  -L/usr/lib -lefi -lgnuefi -o $(UEFI_SO)
	objcopy -j .text -j .sdata -j .data -j .dynamic -j .dynsym \
	  -j .rel -j .rela -j .reloc \
	  --target=efi-app-x86_64 $(UEFI_SO) $(UEFI_EFI)



# Compila la versión UEFI, copia una versión limpia
# de OVMF_VARS y luego arranca QEMU en modo UEFI
uefi-run: uefi-build
	cp $(OVMF_VARS_TEMPLATE) $(OVMF_VARS)
	qemu-system-x86_64 \
	  -drive if=pflash,format=raw,readonly=on,file=$(OVMF_CODE) \
	  -drive if=pflash,format=raw,file=$(OVMF_VARS) \
	  -drive format=raw,file=fat:rw:uefi_disk


# limpiamos por si acaso
clean:
	rm -rf build
	rm -f uefi_disk/EFI/BOOT/BOOTX64.EFI