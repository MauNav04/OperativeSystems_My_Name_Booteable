[bits 16]
[org 0x8000]


; boot.asm carga este archivo en 0000:8000


; Largo del texto con los nombres
NAME_LEN     equ 7

; Límite horizontal para que el nombre no se salga
; cuando está en horizontal.
MAX_COL      equ 79 - NAME_LEN

; Límite vertical para cuando el texto está hacia abajo.
MAX_ROW_DOWN equ 24 - (NAME_LEN - 1)

start2:
    ; pone una posición inicial random
    call random_start

    ; Dirección inicial:
    ; 0 = derecha / horizontal normal
    mov byte [dir], 0

main_loop:
    ; Dibujamos toda la escena en pantalla
    call draw_scene

    ; Esperamos una tecla con BIOS
    xor ah, ah
    int 0x16

    ; esc reinicia la máquina
    cmp al, 27
    je reboot

    ; r o R nueva posición random
    cmp al, 'r'
    je reset_game
    cmp al, 'R'
    je reset_game

    ; Si AL = 0, se presiono una flecha
    ; Si no, volvemos al loop.
    cmp al, 0
    jne main_loop

    ; Código de flechas en AH
    cmp ah, 0x4B
    je key_left

    cmp ah, 0x4D
    je key_right

    cmp ah, 0x48
    je key_up

    cmp ah, 0x50
    je key_down

    jmp main_loop

key_left:
    ; dir = 1 significa horizontal invertido
    mov byte [dir], 1

    ; Si ya estamos al borde izquierdo, no bajamos más
    cmp byte [col], 0
    je main_loop

    ; Mover una columna a la izquierda
    dec byte [col]
    jmp main_loop

key_right:
    ; dir = 0 significa horizontal normal
    mov byte [dir], 0

    ; Revisamos si ya estamos al límite
    mov al, [col]
    cmp al, MAX_COL
    jae main_loop

    ; Mover una columna a la derecha
    inc byte [col]
    jmp main_loop

key_up:
    ; dir = 3 significa vertical hacia arriba
    mov byte [dir], 3

    ; Cuando está vertical hacia arriba,
    ; dejamos espacio suficiente arriba.
    mov al, [row]
    cmp al, NAME_LEN - 1
    jb clamp_up
    je main_loop

    ; Subir una fila
    dec byte [row]
    jmp main_loop

clamp_up:
    ; Si se pasó, lo clavamos en un límite seguro
    mov byte [row], NAME_LEN - 1
    jmp main_loop

key_down:
    ; dir = 2 significa vertical hacia abajo
    mov byte [dir], 2

    ; Revisamos límite inferior
    mov al, [row]
    cmp al, MAX_ROW_DOWN
    ja clamp_down
    je main_loop

    ; Bajar una fila
    inc byte [row]
    jmp main_loop

clamp_down:
    ; Si se pasó, que no se pase de gracioso
    mov byte [row], MAX_ROW_DOWN
    jmp main_loop

reset_game:
    ; Nueva posición random
    call random_start

    ; Volvemos a orientación horizontal normal
    mov byte [dir], 0
    jmp main_loop

reboot:
    ; Reinicio simple usando BIOS
    int 0x19

clear_screen:
    mov ax, 0x0003
    int 0x10
    ret

print_string:
.next_char:
    ; Toma el siguiente carácter desde DS:SI
    lodsb

    ; Si llegamos al 0, termina el string
    cmp al, 0
    je .done

    ; Imprime carácter con BIOS
    mov ah, 0x0E
    mov bh, 0x00
    mov bl, 0x07
    int 0x10

    jmp .next_char

.done:
    ret

set_cursor:
    ; Posiciona el cursor en DH=fila, DL=columna
    mov ah, 0x02
    mov bh, 0x00
    int 0x10
    ret

print_char:
    ; Imprime un carácter individual en AL
    mov ah, 0x0E
    mov bh, 0x00
    mov bl, 0x0F
    int 0x10
    ret

random_start:
    ; Usamos el reloj del BIOS como base

    mov ah, 0x00
    int 0x1A

    ; Mezclamos DX, CX y una semilla previa
    mov ax, dx
    xor ax, cx
    add ax, [seed]
    rol ax, 1
    add ax, 0x1234
    mov [seed], ax

    ; Random para fila

    xor dx, dx
    mov bx, 10
    div bx
    mov al, dl
    add al, 8
    mov [row], al

    ; Mezcla extra para la columna
    mov ax, [seed]
    xor ah, al
    add ax, [seed]
    add ax, 37
    mov [seed], ax

    ; Random para columna
    xor dx, dx
    mov bx, MAX_COL + 1
    div bx
    mov al, dl
    mov [col], al
    ret

draw_scene:

    ; limpiamos pantalla
    ;  imprimimos instrucciones
    ; dibujamos el nombre según la orientación
    call clear_screen

    mov si, info_msg
    call print_string

    ; Revisamos la dirección actual
    mov al, [dir]

    ; 2 = vertical hacia abajo
    cmp al, 2
    je draw_down

    ; 3 = vertical hacia arriba
    cmp al, 3
    je draw_up

    ; Si no, estamos en horizontal
    mov dh, [row]
    mov dl, [col]
    call set_cursor

    ; 1 = horizontal invertido
    cmp al, 1
    je draw_left

    ; 0 = horizontal normal
    mov si, name_h
    call print_string
    ret

draw_left:
    ; Dibuja el nombre invertido en horizontal
    mov si, name_rev
    call print_string
    ret

draw_down:
    ; Dibuja el nombre en vertical hacia abajo
    mov si, name_h
    mov dh, [row]
    mov dl, [col]

.down_loop:
    lodsb
    cmp al, 0
    je draw_done

    ; Guardamos la posición actual
    push dx

    ; Posicionamos cursor e imprimimos el carácter
    call set_cursor

    ; Recuperamos posición
    pop dx
    call print_char

    ; Bajamos una fila
    inc dh
    jmp .down_loop

draw_up:
    ; Dibuja el nombre en vertical hacia arriba

    mov si, name_rev
    mov dh, [row]
    mov dl, [col]

.up_loop:
    lodsb
    cmp al, 0
    je draw_done

    push dx
    call set_cursor
    pop dx
    call print_char

    ; Subimos una fila
    dec dh
    jmp .up_loop

draw_done:
    ret

info_msg db 'Flechas | R=random | ESC=reboot', 13, 10, 13, 10, 0

; Nombre normal e invertido.
name_h   db 'MAU+MAU', 0
name_rev db 'UAM+UAM', 0

; dir:
; 0 = horizontal normal
; 1 = horizontal invertido
; 2 = vertical hacia abajo
; 3 = vertical hacia arriba
dir  db 0

; Posición actual del nombre
row  db 10
col  db 20

; Semilla simple para random
seed dw 0A55Ah

; Rellenamos hasta completar 8 sectores
; porque boot.asm espera cargar exactamente 8 sectores.
times (8*512) - ($ - $$) db 0