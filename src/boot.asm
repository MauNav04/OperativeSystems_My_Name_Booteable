[bits 16]
[org 0x7C00]

STAGE2_ADDR    equ 0x8000
STAGE2_SECTORS equ 8

start:
    start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    cld
    sti

    mov [boot_drive], dl

    ; reset disk
    mov ah, 0x00
    mov dl, [boot_drive]
    int 0x13
    jc disk_error

    ; leer stage2 desde sectores 2..9
    mov bx, STAGE2_ADDR
    mov ah, 0x02
    mov al, STAGE2_SECTORS
    mov ch, 0x00
    mov cl, 0x02
    mov dh, 0x00
    mov dl, [boot_drive]
    int 0x13
    jc disk_error

    jmp 0x0000:STAGE2_ADDR

disk_error:
    mov si, msg
.print:
    lodsb
    test al, al
    jz $
    mov ah, 0x0E
    mov bh, 0
    int 0x10
    jmp .print

boot_drive db 0
msg db 'Disk read error', 0

times 510 - ($ - $$) db 0
dw 0xAA55