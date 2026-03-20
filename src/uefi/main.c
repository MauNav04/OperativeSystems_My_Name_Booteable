#include <efi.h>
#include <efilib.h>

#define NAME_LEN 7
#define TOP_MARGIN 4

static UINT32 seed = 0xA55A1234;

static CHAR16 name_h[]   = L"MAU+MAU";
static CHAR16 name_rev[] = L"UAM+UAM";

static UINTN row = 10;
static UINTN col = 20;
static UINTN dir = 0; /* 0=right, 1=left, 2=down, 3=up */

static void clear_screen(void) {
    uefi_call_wrapper(ST->ConOut->ClearScreen, 1, ST->ConOut);
}

static void set_cursor(UINTN x, UINTN y) {
    uefi_call_wrapper(ST->ConOut->SetCursorPosition, 3, ST->ConOut, x, y);
}

static void print_at(UINTN x, UINTN y, CHAR16 *text) {
    set_cursor(x, y);
    Print(text);
}

static void print_char_at(UINTN x, UINTN y, CHAR16 ch) {
    CHAR16 buf[2];
    buf[0] = ch;
    buf[1] = L'\0';
    set_cursor(x, y);
    Print(buf);
}

static void get_screen_size(UINTN *cols, UINTN *rows) {
    INT32 mode = ST->ConOut->Mode->Mode;
    uefi_call_wrapper(ST->ConOut->QueryMode, 4, ST->ConOut, mode, cols, rows);
}


static UINT64 read_tsc(void) {
    UINT32 lo, hi;
    __asm__ __volatile__("rdtsc" : "=a"(lo), "=d"(hi));
    return ((UINT64)hi << 32) | lo;
}

static void init_seed(void) {
    EFI_TIME t;
    UINT64 mix;

    mix = read_tsc();

    if (uefi_call_wrapper(RT->GetTime, 2, &t, NULL) == EFI_SUCCESS) {
        mix ^= ((UINT64)t.Nanosecond << 32);
        mix ^= ((UINT64)t.Second << 24);
        mix ^= ((UINT64)t.Minute << 16);
        mix ^= ((UINT64)t.Hour << 8);
        mix ^= (UINT64)t.Day;
    }

    seed ^= (UINT32)mix ^ (UINT32)(mix >> 32);
    seed = seed * 1664525u + 1013904223u;
}

static UINT32 next_rand(void) {
    seed = seed * 1664525u + 1013904223u;
    return seed;
}

static void random_start(void) {
    UINTN cols, rows;
    UINTN max_col, max_row;

    get_screen_size(&cols, &rows);

    if (cols <= NAME_LEN + 1) {
        col = 0;
    } else {
        max_col = cols - NAME_LEN;
        col = next_rand() % max_col;
    }

    if (rows <= TOP_MARGIN + 10) {
        row = TOP_MARGIN;
    } else {
        max_row = rows - 1;
        if (max_row < TOP_MARGIN) {
            row = TOP_MARGIN;
        } else {
            row = TOP_MARGIN + (next_rand() % (max_row - TOP_MARGIN + 1));
        }
    }
}

static void clamp_position(void) {
    UINTN cols, rows;

    get_screen_size(&cols, &rows);

    if (dir == 0 || dir == 1) {
        if (cols > NAME_LEN) {
            if (col > cols - NAME_LEN) col = cols - NAME_LEN;
        } else {
            col = 0;
        }

        if (row < TOP_MARGIN) row = TOP_MARGIN;
        if (row >= rows) row = rows - 1;
    } else if (dir == 2) {
        if (col >= cols) col = cols - 1;
        if (row < TOP_MARGIN) row = TOP_MARGIN;
        if (row + (NAME_LEN - 1) >= rows) row = rows - NAME_LEN;
    } else {
        if (col >= cols) col = cols - 1;
        if (row < TOP_MARGIN + (NAME_LEN - 1)) row = TOP_MARGIN + (NAME_LEN - 1);
        if (row >= rows) row = rows - 1;
    }
}

static void draw_scene(void) {
    clear_screen();

    print_at(0, 0, L"MY NAME UEFI");
    print_at(0, 1, L"Flechas | R=random | ESC=salir");

    if (dir == 0) {
        print_at(col, row, name_h);
    } else if (dir == 1) {
        print_at(col, row, name_rev);
    } else if (dir == 2) {
        UINTN i;
        for (i = 0; i < NAME_LEN; i++) {
            print_char_at(col, row + i, name_h[i]);
        }
    } else {
        UINTN i;
        for (i = 0; i < NAME_LEN; i++) {
            print_char_at(col, row - i, name_rev[i]);
        }
    }
}

static EFI_STATUS wait_key(EFI_INPUT_KEY *key) {
    UINTN index;
    uefi_call_wrapper(ST->BootServices->WaitForEvent, 3, 1, &ST->ConIn->WaitForKey, &index);
    return uefi_call_wrapper(ST->ConIn->ReadKeyStroke, 2, ST->ConIn, key);
}

EFI_STATUS efi_main(EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE *SystemTable) {
    EFI_INPUT_KEY key;

    InitializeLib(ImageHandle, SystemTable);

    clear_screen();
    print_at(0, 0, L"MY NAME UEFI");
    print_at(0, 1, L"ENTER para iniciar");

    while (1) {
        if (wait_key(&key) == EFI_SUCCESS) {
            if (key.UnicodeChar == CHAR_CARRIAGE_RETURN) {
                break;
            }
        }
    }

    dir = 0;
    init_seed();
    random_start();
    clamp_position();
    
    while (1) {
        draw_scene();

        if (wait_key(&key) != EFI_SUCCESS) {
            continue;
        }

        if (key.ScanCode == SCAN_ESC) {
            return EFI_SUCCESS;
        }

        if (key.UnicodeChar == L'r' || key.UnicodeChar == L'R') {
            dir = 0;
            random_start();
            clamp_position();
            continue;
        }

        if (key.ScanCode == SCAN_LEFT) {
            dir = 1;
            if (col > 0) col--;
            clamp_position();
            continue;
        }

        if (key.ScanCode == SCAN_RIGHT) {
            dir = 0;
            col++;
            clamp_position();
            continue;
        }

        if (key.ScanCode == SCAN_DOWN) {
            dir = 2;
            row++;
            clamp_position();
            continue;
        }

        if (key.ScanCode == SCAN_UP) {
            dir = 3;
            if (row > 0) row--;
            clamp_position();
            continue;
        }
    }
}