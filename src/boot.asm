[bits 16]
[org 0x7C00]

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti

    call clear_screen

    mov si, welcome_msg
    call print_string

wait_enter:
    mov ah, 0x00
    int 0x16            ; espera una tecla

    cmp al, 13          ; Enter
    je game_start

    jmp wait_enter

game_start:
    call clear_screen

    mov si, start_msg
    call print_string

hang:
    jmp hang

; ----------------------------------------
; Rutina: clear_screen
; Limpia pantalla usando modo texto 80x25
; ----------------------------------------
clear_screen:
    mov ah, 0x00
    mov al, 0x03
    int 0x10
    ret

; ----------------------------------------
; Rutina: print_string
; Imprime string terminada en 0
; DS:SI -> string
; ----------------------------------------
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

welcome_msg db '*** MY NAME BOOTABLE ***', 13, 10
            db 13, 10
            db 'Presione ENTER para continuar', 13, 10
            db 0

start_msg   db 'Iniciando juego...', 13, 10
            db 0

times 510 - ($ - $$) db 0
dw 0xAA55
