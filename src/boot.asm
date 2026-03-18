[bits 16]
[org 0x7C00]

STAGE2_SEG     equ 0x0000
STAGE2_OFF     equ 0x8000
STAGE2_SECTORS equ 8

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti
    cld

    mov [boot_drive], dl

    call clear_screen
    mov si, welcome_msg
    call print_string

wait_enter:
    xor ah, ah
    int 0x16
    cmp al, 13
    jne wait_enter

    call load_stage2
    jmp STAGE2_SEG:STAGE2_OFF

hang:
    jmp hang

load_stage2:
    mov ax, STAGE2_SEG
    mov es, ax
    mov bx, STAGE2_OFF

    mov ah, 0x02
    mov al, STAGE2_SECTORS
    mov ch, 0x00
    mov cl, 0x02
    mov dh, 0x00
    mov dl, [boot_drive]
    int 0x13
    jc disk_error
    ret

disk_error:
    call clear_screen
    mov si, error_msg
    call print_string
    jmp hang

clear_screen:
    mov ax, 0x0003
    int 0x10
    ret

print_string:
.next_char:
    lodsb
    cmp al, 0
    je .done
    mov ah, 0x0E
    mov bh, 0x00
    mov bl, 0x07
    int 0x10
    jmp .next_char
.done:
    ret

welcome_msg db 'MY NAME BOOT', 13, 10
            db 'ENTER para iniciar', 13, 10, 0

error_msg   db 'Error cargando stage2', 13, 10, 0

boot_drive  db 0

times 510 - ($ - $$) db 0
dw 0xAA55