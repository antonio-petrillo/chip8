package chip8

import rl "vendor:raylib"
import "core:testing"
import "core:os"
import "core:log"

MEMORY_SIZE :: 4096
REGISTERS_SIZE :: 16
STACK_SIZE :: 16
KEYPAD_SIZE :: 16

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

    display: [SCREEN_WIDTH][SCREEN_HEIGHT]bool,
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
            for i in 0..<SCREEN_WIDTH {
                for j in 0..<SCREEN_HEIGHT {
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
        if n == 0 && chip.V[x] == chip.V[y] {
            log.infof("Execute := SE Vx, Vy [0x%4x], x := %1x, y := %1x", instr, x, y)
            chip.PC += 2
        }

    case 0x6000:
        log.infof("Execute := LD Vx, byte [0x%4x], x := %1x, kk := %2x", instr, x, kk)
        chip.V[x] = kk

    case 0x7000:
        log.infof("Execute := ADD Vx, byte [0x%4x], x := %1x, kk := %2x", instr, x, kk)
        chip.V[x] += kk
    }

}

main :: proc() {

}

// TESTS
@(test)
test_load_font :: proc(t: ^testing.T) {
    chip: Chip8

    load_fonts(&chip)

    for font, index in default_fonts {
        testing.expect_value(t, chip.memory[index], font)
    }
}

@(test)
test_load_rom :: proc(t: ^testing.T) {
    chip: Chip8

    load_rom(&chip, "./ibm.ch8")

    fd, err := os.open("./ibm.ch8")

    testing.expect(t, err == os.ERROR_NONE, "Can't open program")

    buffer: [MEMORY_SIZE]u8
    bytes_readed, read_error := os.read(fd, buffer[:])

    testing.expect(t, read_error == os.ERROR_NONE, "Can't read program")
    testing.expect(t, os.close(fd) == os.ERROR_NONE, "Can't close rom file, yeah I know a bit exagerate but please nun scassare le pallucce")

    for idx := 0; idx < bytes_readed; idx += 1 {
        testing.expect_value(t, chip.memory[PROGRAM_START + idx], buffer[idx])
    }

    testing.expect_value(t, chip.PC, PROGRAM_START)
}

@(test)
test_fetch_instruction :: proc(t: ^testing.T) {
    chip: Chip8

    chip.memory[0] = 0xA0
    chip.memory[1] = 0xA0

    chip.memory[2] = 0xF0
    chip.memory[3] = 0x0F

    chip.memory[4] = 0x80
    chip.memory[5] = 0x80

    chip.memory[6] = 0xFF
    chip.memory[7] = 0xFF

    expectings := [?]u16{
        0xA0A0, 0xF00F, 0x8080, 0xFFFF
    }

    for expected in expectings {
        testing.expect_value(t, fetch_instruction(&chip), expected)
    }
}

@(test)
test_cls_instr_0x00E0 :: proc(t: ^testing.T) {
    chip: Chip8

    chip.display[0][0] = true
    chip.display[0][31] = true
    chip.display[63][0] = true
    chip.display[63][31] = true

    chip.memory[1] = 0xE0

    testing.expect_value(t, chip.display[0][0], true)
    testing.expect_value(t, chip.display[0][31], true)
    testing.expect_value(t, chip.display[63][0], true)
    testing.expect_value(t, chip.display[63][31], true)

    instr := fetch_instruction(&chip)
    execute_instruction(&chip, instr)

    for i in 0..<SCREEN_WIDTH {
        for j in 0..<SCREEN_HEIGHT {
            testing.expect_value(t, chip.display[i][j], false)
        }
    }
}

@(test)
test_ret_instr_0x00EE :: proc(t: ^testing.T) {
    chip: Chip8

    chip.memory[1] = 0xEE
    // push into the stack
    chip.stack[chip.SP] = 0xA0A0
    chip.SP += 1

    instr := fetch_instruction(&chip)
    execute_instruction(&chip, instr)

    testing.expect_value(t, chip.PC, 0xA0A0)
    testing.expect_value(t, chip.stack[chip.SP], 0)
    testing.expect_value(t, chip.SP, 0)
}

@(test)
test_sys_addr_instr_0x0nnn :: proc(t: ^testing.T) {
    chip: Chip8

    chip.memory[0] = 0x0A
    chip.memory[1] = 0xAA

    instr := fetch_instruction(&chip)
    execute_instruction(&chip, instr)

    testing.expect_value(t, chip.PC, 0x0AAA)
}

@(test)
test_jp_addr_instr_0x1nnn :: proc(t: ^testing.T) {
    chip: Chip8

    chip.memory[0] = 0x1A
    chip.memory[1] = 0xAA

    instr := fetch_instruction(&chip)
    execute_instruction(&chip, instr)

    testing.expect_value(t, chip.PC, 0x0AAA)
}

@(test)
test_call_addr_instr_0x2nnn :: proc(t: ^testing.T) {
    chip: Chip8

    chip.PC = 0x0001
    chip.memory[1] = 0x2A
    chip.memory[2] = 0xBC

    instr := fetch_instruction(&chip)
    execute_instruction(&chip, instr)

    testing.expect_value(t, chip.PC, 0x0ABC)
    testing.expect_value(t, chip.SP, 1)
    log.infof("value on 0 := %d", chip.stack[0])
    testing.expect_value(t, chip.stack[0] - 2, 0x0001)
}

@(test)
test_call_skip_equal_0x3xkk :: proc(t: ^testing.T) {
    chip: Chip8

    chip.memory[0] = 0x31
    chip.memory[1] = 0x01

    chip.memory[2] = 0x31
    chip.memory[3] = 0xFF

    chip.V[1] = 0xFF

    instr := fetch_instruction(&chip)
    execute_instruction(&chip, instr)

    testing.expect_value(t, chip.PC, 2)

    instr = fetch_instruction(&chip)
    execute_instruction(&chip, instr)

    testing.expect_value(t, chip.PC, 6)

}

@(test)
test_call_skip_not_equal_0x4xkk :: proc(t: ^testing.T) {
    chip: Chip8

    chip.memory[0] = 0x41
    chip.memory[1] = 0x01

    chip.memory[4] = 0x41
    chip.memory[5] = 0xFF

    chip.V[1] = 0xFF

    instr := fetch_instruction(&chip)
    execute_instruction(&chip, instr)

    testing.expect_value(t, chip.PC, 4)

    instr = fetch_instruction(&chip)
    execute_instruction(&chip, instr)

    testing.expect_value(t, chip.PC, 6)

}

@(test)
test_call_skip_equal_0x5xy0 :: proc(t: ^testing.T) {
    chip: Chip8

    chip.memory[0] = 0x51 // reg 1
    chip.memory[1] = 0x20 // reg 2

    chip.memory[2] = 0x51 // reg 1
    chip.memory[3] = 0x30 // reg 3

    chip.memory[6] = 0x51 // reg 1
    chip.memory[7] = 0x31 // reg 3 but nibble is not 0

    chip.V[1] = 0xF
    chip.V[2] = 0xC
    chip.V[3] = 0xF

    instr := fetch_instruction(&chip)
    execute_instruction(&chip, instr)

    testing.expect_value(t, chip.PC, 2)

    instr = fetch_instruction(&chip)
    execute_instruction(&chip, instr)

    testing.expect_value(t, chip.PC, 6)

    instr = fetch_instruction(&chip)
    execute_instruction(&chip, instr)

    testing.expect_value(t, chip.PC, 8)
}

@(test)
test_call_load_reg_0x6xkk :: proc(t: ^testing.T) {
    chip: Chip8

    chip.memory[0] = 0x6A
    chip.memory[1] = 0xFF

    instr := fetch_instruction(&chip)
    execute_instruction(&chip, instr)

    testing.expect_value(t, chip.V[0xA], 0xFF)
}

@(test)
test_call_add_to_reg_0x7xkk :: proc(t: ^testing.T) {
    chip: Chip8

    chip.memory[0] = 0x7A
    chip.memory[1] = 0x08
    chip.memory[2] = 0x7A
    chip.memory[3] = 0x08

    instr := fetch_instruction(&chip)
    execute_instruction(&chip, instr)

    testing.expect_value(t, chip.V[0xA], 0x08)

    instr = fetch_instruction(&chip)
    execute_instruction(&chip, instr)

    testing.expect_value(t, chip.V[0xA], 0x08 << 1)
    testing.expect_value(t, chip.V[0xA], 0x10)
}
