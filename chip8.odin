package chip8

import rl "vendor:raylib"
import "core:os"
import "core:log"
import "core:math/rand"
import "core:fmt"

MEMORY_SIZE :: 4096
REGISTERS_SIZE :: 16
STACK_SIZE :: 16
KEYPAD_SIZE :: 16
SPRITE_SIZE :: 5

SCREEN_WIDTH :: 64
SCREEN_HEIGHT :: 32

PROGRAM_START :: 0x200

Chip8 :: struct {
    memory: [MEMORY_SIZE]u8,
    V: [REGISTERS_SIZE]u8,
    I: u16,
    PC: u16,


    SP: u8,
    stack: [STACK_SIZE]u16,

    ST: u8,
    DT: u8,

    display: [SCREEN_HEIGHT][SCREEN_WIDTH]bool,
    keypad: [KEYPAD_SIZE]bool,
}

load_fonts :: proc(chip: ^Chip8) {
    for font, i in default_fonts {
        chip.memory[i] = font
    }
}
load_rom :: proc(chip: ^Chip8, path: string) {
    fd, err := os.open(path)

    if err != os.ERROR_NONE {
        panic("Can't open rom file")
    }

    bytes_readed, read_error := os.read(fd, chip.memory[PROGRAM_START:])

    if read_error != os.ERROR_NONE || bytes_readed == 0 {
        panic("Can't load roms")
    }

    if os.close(fd) != os.ERROR_NONE {
        panic("Can't close rom file, yeah I know a bit exagerate but please nun scassare le pallucce")
    }

    chip.PC = PROGRAM_START
}

default_fonts :: [80]u8 {
    0xF0, // ****
    0x90, // *  *
    0x90, // *  *
    0x90, // *  *
    0xF0, // ****

    0x20, //   *
    0x60, //  **
    0x20, //   *
    0x20, //   *
    0x70, //  ***

    0xF0, // ****
    0x10, //    *
    0xF0, // ****
    0x80, // *
    0xF0, // ****


    0xF0, // ****
    0x10, //    *
    0xF0, // ****
    0x10, //    *
    0xF0, // ****

    0x90, // *  *
    0x90, // *  *
    0xF0, // ****
    0x10, //    *
    0x10, //    *

    0xF0, // ****
    0x80, // *
    0xF0, // ****
    0x10, //    *
    0xF0, // ****

    0xF0, // ****
    0x80, // *
    0xF0, // ****
    0x90, // *  *
    0xF0, // ****

    0xF0, // ****
    0x10, //    *
    0x20, //   *
    0x40, //  *
    0x40, //  *

    0xF0, // ****
    0x90, // *  *
    0xF0, // ****
    0x90, // *  *
    0xF0, // ****

    0xF0, // ****
    0x90, // *  *
    0xF0, // ****
    0x10, //    *
    0xF0, // ****

    0xF0, // ****
    0x90, // *  *
    0xF0, // ****
    0x90, // *  *
    0x90, // *  *

    0xE0, // ***
    0x90, // *  *
    0xE0, // ***
    0x90, // *  *
    0xE0, // ***

    0xF0, // ****
    0x80, // *
    0x80, // *
    0x80, // *
    0xF0, // ****

    0xE0, // ***
    0x90, // *  *
    0x90, // *  *
    0x90, // *  *
    0xE0, // ***

    0xF0, // ****
    0x80, // *
    0xF0, // ****
    0x80, // *
    0xF0, // ****

    0xF0, // ****
    0x80, // *
    0xF0, // ****
    0x80, // *
    0x80, // *
}

fetch_instruction :: proc(chip: ^Chip8) -> u16 {
    next := (u16(chip.memory[chip.PC]) << 8) | u16(chip.memory[chip.PC + 1])
    chip.PC += 2
    return next
}

execute_instruction :: proc(chip: ^Chip8, instr: u16) {
    x := u8(instr & 0x0F00 >> 8)
    y := u8(instr & 0x00F0 >> 4)
    n := u8(instr & 0x000F)
    kk := u8(instr & 0x00FF)
    nnn := instr & 0x0FFF

    switch instr & 0xF000 {
    case 0x0000:
        switch {
        case instr == 0x00E0:
            log.info("Execute := CLS [0x00e0]")
            for i in 0..<SCREEN_HEIGHT {
                for j in 0..<SCREEN_WIDTH {
                    chip.display[i][j] = false
                }
            }

        case instr == 0x00EE:
            log.info("Execute := RET [0x00ee]")
            chip.SP -= 1
            chip.PC = chip.stack[chip.SP]
            chip.stack[chip.SP] = 0

        case:
            log.infof("Execute := SYS addr [0x%4x], addr := %4x", instr, nnn)
            chip.PC = nnn
        }

    case 0x1000:
        log.infof("Execute := JP addr [0x%4x], addr := %4x", instr, nnn)
        chip.PC = nnn

    case 0x2000:
        log.infof("Execute := CALL addr [0x%4x], addr := %4x", instr, nnn)
        chip.stack[chip.SP] = chip.PC
        assert(chip.SP < 16)
        chip.SP += 1
        chip.PC = nnn

    case 0x3000:
        log.infof("Execute := SE Vx, byte [0x%4x], x := %1x, kk := %2x", instr, x, kk)
        if chip.V[x] == kk {
            chip.PC += 2
        }

    case 0x4000:
        log.infof("Execute := SNE Vx, byte [0x%4x], x := %1x, kk := %2x", instr, x, kk)
        if chip.V[x] != kk {
            chip.PC += 2
        }

    case 0x5000:
        // ensure nibble == 0
        assert (n == 0)
        if chip.V[x] == chip.V[y] {
            log.infof("Execute := SE Vx, Vy [0x%4x], x := %1x, y := %1x", instr, x, y)
            chip.PC += 2
        }

    case 0x6000:
        log.infof("Execute := LD Vx, byte [0x%4x], x := %1x, kk := %2x", instr, x, kk)
        chip.V[x] = kk

    case 0x7000:
        log.infof("Execute := ADD Vx, byte [0x%4x], x := %1x, kk := %2x", instr, x, kk)
        chip.V[x] += kk

    case 0x8000:
        switch n {
        case 0x0:
            log.infof("Execute := LD Vx, Vy [0x%4x], x := %1x, y := %1x", instr, x, y)
            chip.V[x] = chip.V[y]

        case 0x1:
            log.infof("Execute := OR Vx, Vy [0x%4x], x := %1x, y := %1x", instr, x, y)
            chip.V[x] |= chip.V[y]

        case 0x2:
            log.infof("Execute := AND Vx, Vy [0x%4x], x := %1x, y := %1x", instr, x, y)
            chip.V[x] &= chip.V[y]

        case 0x3:
            log.infof("Execute := XOR Vx, Vy [0x%4x], x := %1x, y := %1x", instr, x, y)
            chip.V[x] ~= chip.V[y]

        case 0x4:
            log.infof("Execute := ADD Vx, Vy [0x%4x], x := %1x, y := %1x, VF carry", instr, x, y)
            sum : u16 = u16(chip.V[x]) + u16(chip.V[y])

            chip.V[x] = u8(sum & 0x00FF)
            chip.V[0xF] = 1 if sum & 0xFF00 != 0 else 0

        case 0x5:
            log.infof("Execute := SUB Vx, Vy [0x%4x], x := %1x, y := %1x, VF not borrow", instr, x, y)
            chip.V[0xF] = 1 if chip.V[y] > chip.V[x] else 0
            chip.V[x] -= chip.V[y]

        // https://github.com/trapexit/chip-8_documentation
        case 0x6:
            log.infof("Execute := SHR Vx {, Vy} [0x%4x], x := %1x, y := %1x, VF not borrow", instr, x, y)
            chip.V[0xF] = 0x01 & chip.V[x]
            chip.V[x] >>= 1

        case 0x7:
            log.infof("Execute := SUBN Vx, Vy [0x%4x], x := %1x, y := %1x, VF not borrow", instr, x, y)
            chip.V[0xF] = 1 if chip.V[x] > chip.V[y] else 0
            chip.V[x] = chip.V[y] - chip.V[x]

        // https://github.com/trapexit/chip-8_documentation
        case 0xE:
            log.infof("Execute := SHL Vx {, Vy} [0x%4x], x := %1x, y := %1x, VF not borrow", instr, x, y)
            chip.V[0xF] = 1 if 0x80 & chip.V[x] != 0 else 0
            chip.V[x] <<= 1
        }

    case 0x9000:
        // ensure nibble == 0
        assert (n == 0)
        if chip.V[x] != chip.V[y] {
            log.infof("Execute := SNE Vx, Vy [0x%4x], x := %1x, y := %1x", instr, x, y)
            chip.PC += 2
        }

    case 0xA000:
        log.infof("Execute := LD I, addr [0x%4x], I := %4x, addr := %3x", instr, chip.I, nnn)
        chip.I = nnn

    case 0xB000:
        log.infof("Execute := JP V0, addr [0x%4x], V0 := %2x, addr := %3x", instr, chip.V[0], nnn)
        chip.PC = nnn + u16(chip.V[0])

    case 0xC000:
        rng_byte := u8(rand.int31() % 0xFF)
        chip.V[x] = rng_byte & kk
        log.infof("Execute := RND Vx, byte [0x%4x], V0 := %2x, byte := %2x, rng := %2x, res := %2x", instr, chip.V[0], kk, rng_byte, chip.V[x])

    case 0xD000:
        start_x, start_y := chip.V[x], chip.V[y]
        chip.V[0xF] = 0 // start with no collision

        for sprite_row in 0..<n {
            row := chip.memory[chip.I + u16(sprite_row)]
            y := (start_y + sprite_row) % SCREEN_HEIGHT
            for sprite_col: u8 = 0; sprite_col < 8; sprite_col += 1 {
                if row & (0x80 >> sprite_col) != 0 { // if the pixel is on in the sprite
                    x := (start_x + sprite_col) % SCREEN_WIDTH

                    // if the pixel will be erased set VF = 1
                    if chip.display[y][x] {
                        chip.V[0xF] = 1
                    }
                    chip.display[y][x] ~= true
                }
            }
        }

    case 0xE000:
        switch kk {
        case 0x9E:
            log.infof("Execute := SKP Vx [0x%4x], x := %1x, Vx := %2x", instr, x, chip.V[x])
            assert(chip.V[x] >= 0 && chip.V[x] <= 0xF)
            if chip.keypad[chip.V[x]] {
               chip.PC += 2
            }
        case 0xA1:
            log.infof("Execute := SKNP Vx [0x%4x], x := %1x, Vx := %2x", instr, x, chip.V[x])
            assert(chip.V[x] >= 0 && chip.V[x] <= 0xF)
            if !chip.keypad[chip.V[x]] {
               chip.PC += 2
            }
        }

    case 0xF000:
        switch kk {
        case 0x07:
            log.infof("Execute := LD Vx, DT, [0x%4x], x := %1x", instr, x)
            chip.V[x] = chip.DT

        case 0x0A:
            /* await for keypress and store in */
            log.infof("Execute := LD Vx, K, [0x%4x], x := %1x", instr, x)
            key_pressed: bool
            for i: u8 = 0; i <= 0xF; i += 1  {
                if chip.keypad[i] {
                    chip.V[x] = i
                    key_pressed = true
                    break
                }
            }

            if !key_pressed {
                chip.PC -= 2 // decrease Program Counter to repeat current instr
            }

        case 0x15:
            log.infof("Execute := LD DT, Vx, [0x%4x], x := %1x", instr, x)
            chip.DT = chip.V[x]

        case 0x18:
            log.infof("Execute := LD ST, Vx, [0x%4x], x := %1x", instr, x)
            chip.ST = chip.V[x]

        case 0x1E:
            log.infof("Execute := ADD I, Vx, [0x%4x], x := %1x", instr, x)
            chip.I += u16(chip.V[x])

        case 0x29:
            log.infof("Execute := LD F, Vx, [0x%4x], x := %1x", instr, x)
            assert(chip.V[x] <= 0xF)
            chip.I = u16(chip.V[x]) * SPRITE_SIZE

        case 0x33:
            log.infof("Execute := LD B, Vx, [0x%4x], x := %1x", instr, x)
            assert(chip.I < MEMORY_SIZE - 2)
            digits := chip.V[x] % 10
            tens := chip.V[x] / 10 % 10
            hundreds := chip.V[x] / 100

            chip.memory[chip.I] = hundreds
            chip.memory[chip.I + 1] = tens
            chip.memory[chip.I + 2] = digits

        case 0x55:
            log.infof("Execute := LD [I], Vx, [0x%4x], x := %1x", instr, x)
            assert(chip.I < MEMORY_SIZE - u16(x))

            for idx: u16 = 0; idx <= u16(x); idx+=1 {
                chip.memory[chip.I + idx] = chip.V[idx]
            }

        case 0x65:
            log.infof("Execute := LD Vx, [I], [0x%4x], x := %1x", instr, x)
            assert(chip.I < MEMORY_SIZE - u16(x))

            for idx: u16 = 0; idx <= u16(x); idx += 1 {
                chip.V[idx] = chip.memory[chip.I + idx]
            }
        }
    }

}

main :: proc() {
}
