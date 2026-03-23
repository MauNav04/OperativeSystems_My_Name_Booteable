[bits 16]
[org 0x7C00]





; Dirección donde vamos a cargar el stage 2
STAGE2_SEG     equ 0x0000
STAGE2_OFF     equ 0x8000

; Cantidad de sectores que ocupa el stage 2

STAGE2_SECTORS equ 8

start:
    ; Apagamos interrupciones mientras acomodamos registros
    cli

    ; AX = 0
    xor ax, ax

    ; Dejamos segmentos apuntando a 0
    mov ds, ax
    mov es, ax
    mov ss, ax

    ; Pila simple
    mov sp, 0x7C00

    ; Volvemos a activar interrupciones
    sti

    ; Aseguramos que lodsb avance hacia adelante
    cld

    ; La BIOS deja en DL la unidad desde donde arrancó

    ; La guardamos porque luego la ocupamos para leer stage 2 (el myname)
    mov [boot_drive], dl

    ; Limpiamos pantalla y mostramos mensaje de bienvenida
    call clear_screen
    mov si, welcome_msg
    call print_string

wait_enter:
    ; AH=0 en int 16h = esperar una tecla
    xor ah, ah
    int 0x16

    ; 13 = Enter
    cmp al, 13
    jne wait_enter

    ; Cuando se presiona enter:
    ; cargamos la segunda etapa y brincamos hacia ella.
    call load_stage2
    jmp STAGE2_SEG:STAGE2_OFF

hang:
    ; Si algo sale mal o no hay más nada que hacer,
    ; nos quedamos aquí.
    jmp hang

load_stage2:
    ; ES:BX = dirección destino donde se va a cargar stage 2
    mov ax, STAGE2_SEG
    mov es, ax
    mov bx, STAGE2_OFF

    ; INT 13h / AH=02h -> leer sectores del disco
    mov ah, 0x02

    ; Cuántos sectores leer
    mov al, STAGE2_SECTORS

    ; CHS básico:
    ; cilindro 0
    mov ch, 0x00

    ; sector 2

    mov cl, 0x02

    ; cabeza 0
    mov dh, 0x00

    ; unidad de arranque guardada antes
    mov dl, [boot_drive]

    ; leer desde disco
    int 0x13

    ; Si hubo error, carry = 1
    jc disk_error

    ret

disk_error:
    ; Si falla la lectura del stage 2,
    ; mostramos error y nos quedamos pegados.
    call clear_screen
    mov si, error_msg
    call print_string
    jmp hang

clear_screen:
    ; INT 10h, modo 03h = texto 80x25
    ; además de paso limpia pantalla
    mov ax, 0x0003
    int 0x10
    ret

print_string:
.next_char:
    ; lodsb toma el byte en DS:SI y lo pone en AL
    ; luego incrementa SI
    lodsb

    ; Si el byte es 0, terminamos
    cmp al, 0
    je .done

    ; INT 10h / AH=0Eh -> teletype output
    ; imprime el carácter en AL
    mov ah, 0x0E
    mov bh, 0x00
    mov bl, 0x07
    int 0x10

    jmp .next_char

.done:
    ret


; Mensajes

welcome_msg db 'MY NAME BOOT', 13, 10
            db 'ENTER para iniciar', 13, 10, 0

; Mensaje en caso de que falle la lectura del stage 2
error_msg   db 'Error cargando stage2', 13, 10, 0

; guardamos la unidad desde la que arrancó la BIOS
boot_drive  db 0

; Rellenamos hasta byte 510
times 510 - ($ - $$) db 0

; Firma obligatoria de boot sector
dw 0xAA55
