[bits 16]
[org 0x8000]

NAME_LEN     equ 7
MAX_COL      equ 79 - NAME_LEN
MAX_ROW_DOWN equ 24 - (NAME_LEN - 1)

start2:
    call random_start
    mov byte [dir], 0

main_loop:
    call draw_scene

    xor ah, ah
    int 0x16

    cmp al, 27
    je reboot

    cmp al, 'r'
    je reset_game
    cmp al, 'R'
    je reset_game

    cmp al, 0
    jne main_loop

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
    mov byte [dir], 1
    cmp byte [col], 0
    je main_loop
    dec byte [col]
    jmp main_loop

key_right:
    mov byte [dir], 0
    mov al, [col]
    cmp al, MAX_COL
    jae main_loop
    inc byte [col]
    jmp main_loop

key_up:
    mov byte [dir], 3
    mov al, [row]
    cmp al, NAME_LEN - 1
    jb clamp_up
    je main_loop
    dec byte [row]
    jmp main_loop

clamp_up:
    mov byte [row], NAME_LEN - 1
    jmp main_loop

key_down:
    mov byte [dir], 2
    mov al, [row]
    cmp al, MAX_ROW_DOWN
    ja clamp_down
    je main_loop
    inc byte [row]
    jmp main_loop

clamp_down:
    mov byte [row], MAX_ROW_DOWN
    jmp main_loop

reset_game:
    call random_start
    mov byte [dir], 0
    jmp main_loop

reboot:
    int 0x19

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

set_cursor:
    mov ah, 0x02
    mov bh, 0x00
    int 0x10
    ret

print_char:
    mov ah, 0x0E
    mov bh, 0x00
    mov bl, 0x0F
    int 0x10
    ret

random_start:
    mov ah, 0x00
    int 0x1A

    mov ax, dx
    xor ax, cx
    add ax, [seed]
    rol ax, 1
    add ax, 0x1234
    mov [seed], ax

    xor dx, dx
    mov bx, 10
    div bx
    mov al, dl
    add al, 8
    mov [row], al

    mov ax, [seed]
    xor ah, al
    add ax, [seed]
    add ax, 37
    mov [seed], ax

    xor dx, dx
    mov bx, MAX_COL + 1
    div bx
    mov al, dl
    mov [col], al
    ret

draw_scene:
    call clear_screen

    mov si, info_msg
    call print_string

    mov al, [dir]
    cmp al, 2
    je draw_down
    cmp al, 3
    je draw_up

    mov dh, [row]
    mov dl, [col]
    call set_cursor

    cmp al, 1
    je draw_left

    mov si, name_h
    call print_string
    ret

draw_left:
    mov si, name_rev
    call print_string
    ret

draw_down:
    mov si, name_h
    mov dh, [row]
    mov dl, [col]

.down_loop:
    lodsb
    cmp al, 0
    je draw_done
    push dx
    call set_cursor
    pop dx
    call print_char
    inc dh
    jmp .down_loop

draw_up:
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
    dec dh
    jmp .up_loop

draw_done:
    ret

info_msg db 'Flechas | R=random | ESC=reboot', 13, 10, 13, 10, 0
name_h   db 'MAU+MAU', 0
name_rev db 'UAM+UAM', 0

dir  db 0
row  db 10
col  db 20
seed dw 0A55Ah

times (8*512) - ($ - $$) db 0