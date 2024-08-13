package chip8

import "core:testing"
import "core:os"

@(test)
test_init_chip8 :: proc(t: ^testing.T) {
    chip: Chip8

    init_chip8(&chip)

    for font, index in default_fonts {
        testing.expect_value(t, chip.memory[index], font)
    }

    testing.expect_value(t, chip.SP, -1)
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
        testing.expect_value(t, fetch(&chip), expected)
    }
}

@(test)
test_cls_instr_0x00E0 :: proc(t: ^testing.T) {
    chip: Chip8

    chip.display[0][0] = true
    chip.display[31][0] = true
    chip.display[0][63] = true
    chip.display[31][63] = true

    chip.memory[1] = 0xE0

    testing.expect_value(t, chip.display[0][0], true)
    testing.expect_value(t, chip.display[31][0], true)
    testing.expect_value(t, chip.display[0][63], true)
    testing.expect_value(t, chip.display[31][63], true)

    instr := fetch(&chip)
    execute(&chip, instr)

    for i in 0..<SCREEN_HEIGHT {
        for j in 0..<SCREEN_WIDTH {
            testing.expect_value(t, chip.display[i][j], false)
        }
    }
}

@(test)
test_ret_instr_0x00EE :: proc(t: ^testing.T) {
    chip: Chip8
    chip.SP = 0

    chip.memory[1] = 0xEE
    // push manually into the stack
    chip.stack[0] = 0xA0A0 // return addr expected

    instr := fetch(&chip)
    execute(&chip, instr)

    testing.expect_value(t, chip.PC, 0xA0A0)
    testing.expect_value(t, chip.stack[0], 0)
    testing.expect_value(t, chip.SP, -1)
}

@(test)
test_sys_addr_instr_0x0nnn :: proc(t: ^testing.T) {
    chip: Chip8

    chip.memory[0] = 0x0A
    chip.memory[1] = 0xAA

    instr := fetch(&chip)
    execute(&chip, instr)

    testing.expect_value(t, chip.PC, 0x0AAA)
}

@(test)
test_jp_addr_instr_0x1nnn :: proc(t: ^testing.T) {
    chip: Chip8

    chip.memory[0] = 0x1A
    chip.memory[1] = 0xAA

    instr := fetch(&chip)
    execute(&chip, instr)

    testing.expect_value(t, chip.PC, 0x0AAA)
}

@(test)
test_call_addr_instr_0x2nnn :: proc(t: ^testing.T) {
    chip: Chip8
    chip.SP = -1

    chip.PC = 0x0001
    chip.memory[1] = 0x2A
    chip.memory[2] = 0xBC

    instr := fetch(&chip)
    execute(&chip, instr)

    testing.expect_value(t, chip.PC, 0x0ABC)
    testing.expect_value(t, chip.SP, 0)
    testing.expect_value(t, chip.stack[0] - 2, 0x0001)
    testing.expect_value(t, chip.stack[0], 0x0003) // pc gets incremented by 2
}

@(test)
test_call_skip_equal_0x3xkk :: proc(t: ^testing.T) {
    chip: Chip8

    chip.memory[0] = 0x31
    chip.memory[1] = 0x01

    chip.memory[2] = 0x31
    chip.memory[3] = 0xFF

    chip.V[1] = 0xFF

    instr := fetch(&chip)
    execute(&chip, instr)

    testing.expect_value(t, chip.PC, 2)

    instr = fetch(&chip)
    execute(&chip, instr)

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

    instr := fetch(&chip)
    execute(&chip, instr)

    testing.expect_value(t, chip.PC, 4)

    instr = fetch(&chip)
    execute(&chip, instr)

    testing.expect_value(t, chip.PC, 6)

}

@(test)
test_call_skip_equal_0x5xy0 :: proc(t: ^testing.T) {
    chip: Chip8

    chip.memory[0] = 0x51 // reg 1
    chip.memory[1] = 0x20 // reg 2

    chip.memory[2] = 0x51 // reg 1
    chip.memory[3] = 0x30 // reg 3

    chip.V[1] = 0xF
    chip.V[2] = 0xC
    chip.V[3] = 0xF

    instr := fetch(&chip)
    execute(&chip, instr)

    testing.expect_value(t, chip.PC, 2)

    instr = fetch(&chip)
    execute(&chip, instr)

    testing.expect_value(t, chip.PC, 6)
}

@(test)
test_call_load_reg_0x6xkk :: proc(t: ^testing.T) {
    chip: Chip8

    chip.memory[0] = 0x6A
    chip.memory[1] = 0xFF

    instr := fetch(&chip)
    execute(&chip, instr)

    testing.expect_value(t, chip.V[0xA], 0xFF)
}

@(test)
test_call_add_to_reg_0x7xkk :: proc(t: ^testing.T) {
    chip: Chip8

    chip.memory[0] = 0x7A
    chip.memory[1] = 0x08
    chip.memory[2] = 0x7A
    chip.memory[3] = 0x08

    instr := fetch(&chip)
    execute(&chip, instr)

    testing.expect_value(t, chip.V[0xA], 0x08)

    instr = fetch(&chip)
    execute(&chip, instr)

    testing.expect_value(t, chip.V[0xA], 0x08 << 1)
    testing.expect_value(t, chip.V[0xA], 0x10)
}

@(test)
test_call_ld_reg_x_y_0x8xy0 :: proc(t: ^testing.T) {
    chip: Chip8

    chip.memory[0] = 0x8A
    chip.memory[1] = 0xB0

    chip.V[0xA] = 0x1
    chip.V[0xB] = 0x0F

    instr := fetch(&chip)
    execute(&chip, instr)

    testing.expect_value(t, chip.V[0xA], 0x0F)
}

@(test)
test_call_or_x_y_0x8xy1 :: proc(t: ^testing.T) {
    chip: Chip8

    chip.memory[0] = 0x8A
    chip.memory[1] = 0xB1

    chip.V[0xA] = 0xF0
    chip.V[0xB] = 0x0F

    instr := fetch(&chip)
    execute(&chip, instr)

    testing.expect_value(t, chip.V[0xA], 0xFF)
}

@(test)
test_call_and_x_y_0x8xy2 :: proc(t: ^testing.T) {
    chip: Chip8

    chip.memory[0] = 0x8A
    chip.memory[1] = 0xB2
    chip.memory[2] = 0x8B
    chip.memory[3] = 0xC2

    chip.V[0xA] = 0xF0
    chip.V[0xB] = 0x0F
    chip.V[0xC] = 0x18

    instr := fetch(&chip)
    execute(&chip, instr)

    testing.expect_value(t, chip.V[0xA], 0x00)

    instr = fetch(&chip)
    execute(&chip, instr)

    testing.expect_value(t, chip.V[0xB], 0x08)
}

@(test)
test_call_xor_x_y_0x8xy3 :: proc(t: ^testing.T) {
    chip: Chip8

    chip.memory[0] = 0x80
    chip.memory[1] = 0x13
    chip.memory[2] = 0x82
    chip.memory[3] = 0x33
    chip.memory[4] = 0x84
    chip.memory[5] = 0x53
    chip.memory[6] = 0x86
    chip.memory[7] = 0x73

    chip.V[0x0] = 0x00
    chip.V[0x1] = 0x00
    chip.V[0x2] = 0xF0
    chip.V[0x3] = 0x0F
    chip.V[0x4] = 0x0F
    chip.V[0x5] = 0xF0
    chip.V[0x6] = 0xFF
    chip.V[0x7] = 0xFF

    expecteds := [?]u8{ 0x00, 0xFF, 0xFF, 0x00 }

    for expect, idx in expecteds {
        instr := fetch(&chip)
        execute(&chip, instr)
        testing.expect_value(t, chip.V[idx << 1], expect)
    }
}

@(test)
test_call_xor_x_y_0x8xy4 :: proc(t: ^testing.T) {
    chip: Chip8

    chip.memory[0] = 0x80
    chip.memory[1] = 0x14
    chip.memory[2] = 0x82
    chip.memory[3] = 0x34

    chip.V[0x0] = 0x03
    chip.V[0x1] = 0x07
    chip.V[0x2] = 0xF0
    chip.V[0x3] = 0x1F

    instr := fetch(&chip)
    execute(&chip, instr)
    testing.expect_value(t, chip.V[0], 0x0A)
    testing.expect_value(t, chip.V[0xF], 0)

    instr = fetch(&chip)
    execute(&chip, instr)
    testing.expect_value(t, chip.V[2], 0x0F)
    testing.expect_value(t, chip.V[0xF], 1)
}

@(test)
test_call_sub_reg_x_y_0x8xy5 :: proc(t: ^testing.T) {
    chip: Chip8

    chip.memory[0] = 0x80
    chip.memory[1] = 0x15
    chip.memory[2] = 0x82
    chip.memory[3] = 0x35

    chip.V[0x0] = 0x07
    chip.V[0x1] = 0x04
    chip.V[0x2] = 0x0E
    chip.V[0x3] = 0x0F

    instr := fetch(&chip)
    execute(&chip, instr)
    testing.expect_value(t, chip.V[0], 0x03)
    testing.expect_value(t, chip.V[0xF], 0x0)

    instr = fetch(&chip)
    execute(&chip, instr)
    testing.expect_value(t, chip.V[2], 0xFF)
    testing.expect_value(t, chip.V[0xF], 1)
}

@(test)
test_call_shr_x_y_1_0x8xy6 :: proc(t: ^testing.T) {
    chip: Chip8

    chip.memory[0] = 0x80
    chip.memory[1] = 0x16
    chip.memory[2] = 0x81
    chip.memory[3] = 0x06

    chip.V[0] = 0x08
    chip.V[1] = 0x09

    instr := fetch(&chip)
    execute(&chip, instr)
    testing.expect_value(t, chip.V[0], 0x04)
    testing.expect_value(t, chip.V[0xF], 0x0)

    instr = fetch(&chip)
    execute(&chip, instr)
    testing.expect_value(t, chip.V[1], 0x04)
    testing.expect_value(t, chip.V[0xF], 0x1)
}

@(test)
test_call_shl_x_y_1_0x8xyE :: proc(t: ^testing.T) {
    chip: Chip8

    chip.memory[0] = 0x80
    chip.memory[1] = 0x1E
    chip.memory[2] = 0x81
    chip.memory[3] = 0x0E

    chip.V[0] = 0x08
    chip.V[1] = 0x90

    instr := fetch(&chip)
    execute(&chip, instr)
    testing.expect_value(t, chip.V[0], 0x10)
    testing.expect_value(t, chip.V[0xF], 0x0)

    instr = fetch(&chip)
    execute(&chip, instr)
    testing.expect_value(t, chip.V[1], 0x20)
    testing.expect_value(t, chip.V[0xF], 0x1)
}

@(test)
test_call_subn_reg_x_y_0x8xy7 :: proc(t: ^testing.T) {
    chip: Chip8

    chip.memory[0] = 0x80
    chip.memory[1] = 0x17
    chip.memory[2] = 0x82
    chip.memory[3] = 0x37

    chip.V[0x0] = 0x04
    chip.V[0x1] = 0x07
    chip.V[0x2] = 0x0F
    chip.V[0x3] = 0x0E

    instr := fetch(&chip)
    execute(&chip, instr)
    testing.expect_value(t, chip.V[0], 0x03)
    testing.expect_value(t, chip.V[0xF], 0x0)

    instr = fetch(&chip)
    execute(&chip, instr)
    testing.expect_value(t, chip.V[2], 0xFF)
    testing.expect_value(t, chip.V[0xF], 1)
}

@(test)
test_call_skip_not_equal_0x9xy0 :: proc(t: ^testing.T) {
    chip: Chip8

    chip.memory[0] = 0x91 // reg 1
    chip.memory[1] = 0x20 // reg 2

    chip.memory[4] = 0x91 // reg 1
    chip.memory[5] = 0x30 // reg 3

    chip.V[1] = 0xF
    chip.V[2] = 0xC
    chip.V[3] = 0xF

    instr := fetch(&chip)
    execute(&chip, instr)

    testing.expect_value(t, chip.PC, 4)

    instr = fetch(&chip)
    execute(&chip, instr)

    testing.expect_value(t, chip.PC, 6)
}

@(test)
test_call_load_addr_into_I_0xAnnn :: proc(t: ^testing.T) {
    chip: Chip8

    chip.memory[0] = 0xA0
    chip.memory[1] = 0xA0

    instr := fetch(&chip)
    execute(&chip, instr)

    testing.expect_value(t, chip.I, 0x00A0)
}

@(test)
test_call_jump_addr_plus_v0_0xBnnn :: proc(t: ^testing.T) {
    chip: Chip8

    chip.memory[0] = 0xB0
    chip.memory[1] = 0xA0

    chip.V[0] = 0xF

    instr := fetch(&chip)
    execute(&chip, instr)

    testing.expect_value(t, chip.PC, 0x00AF)
}

@(test)
test_call_rng_0xCnnn :: proc(t: ^testing.T) {
    chip: Chip8

    chip.memory[0] = 0xCA
    chip.memory[1] = 0xFF

    instr := fetch(&chip)
    execute(&chip, instr)

    // silly test, how I can verify the rng properly?
    testing.expect_value(t, chip.V[0xA], chip.V[0xA])
}

@(test)
test_call_0xEx9E_and_0xEx9E :: proc(t: ^testing.T) {
    chip: Chip8

    chip.memory[0] = 0xE0
    chip.memory[1] = 0x9E

    chip.memory[4] = 0xE0
    chip.memory[5] = 0xA1

    chip.memory[6] = 0xE1
    chip.memory[7] = 0xA1

    chip.memory[10] = 0xE1
    chip.memory[11] = 0x9E

    chip.V[0] = 1
    chip.keypad[1] = true

    instr := fetch(&chip)
    execute(&chip, instr)
    testing.expect_value(t, chip.PC, 4)

    instr = fetch(&chip)
    execute(&chip, instr)
    testing.expect_value(t, chip.PC, 6)

    instr = fetch(&chip)
    execute(&chip, instr)
    testing.expect_value(t, chip.PC, 10)

    instr = fetch(&chip)
    execute(&chip, instr)
    testing.expect_value(t, chip.PC, 12)

}

@(test)
test_call_draw_x_y_n :: proc(t: ^testing.T) {
    chip: Chip8
    init_chip8(&chip)

    chip.memory[PROGRAM_START] = 0xD0
    chip.memory[PROGRAM_START + 1] = 0x05
    chip.memory[PROGRAM_START + 2] = 0xD0
    chip.memory[PROGRAM_START + 3] = 0x05
    chip.PC = PROGRAM_START

    // load default font 0 into screen
    instr := fetch(&chip)
    execute(&chip, instr)

    font := default_fonts
    for i in 0..<5 {
        for j: u8 = 0; j < 8; j += 1 {
            if font[i] & (0x80 >> j) != 0 {
                testing.expect_value(t, chip.display[i][j], true)
            } else {
                testing.expect_value(t, chip.display[i][j], false)
            }
        }
    }

    instr = fetch(&chip)
    execute(&chip, instr)

    for i in 0..<SCREEN_HEIGHT {
        for j in 0..<SCREEN_WIDTH {
            testing.expect_value(t, chip.display[i][j], false)
        }
    }
    testing.expect_value(t, chip.V[0xf], 1)
}


@(test)
test_call_load_dt_into_vx_0xFx07 :: proc(t: ^testing.T) {
    chip: Chip8

    chip.memory[0] = 0xF0
    chip.memory[1] = 0x07

    chip.DT = 0xff

    instr := fetch(&chip)
    execute(&chip, instr)

    testing.expect_value(t, chip.V[0], 0xff)
}

@(test)
test_call_load_vx_into_dt_0xFx15 :: proc(t: ^testing.T) {
    chip: Chip8

    chip.memory[0] = 0xF0
    chip.memory[1] = 0x15

    chip.V[0] = 0xff

    instr := fetch(&chip)
    execute(&chip, instr)

    testing.expect_value(t, chip.DT, 0xff)
}

@(test)
test_call_load_vx_into_st_0xFx18 :: proc(t: ^testing.T) {
    chip: Chip8

    chip.memory[0] = 0xF0
    chip.memory[1] = 0x18

    chip.V[0] = 0xff

    instr := fetch(&chip)
    execute(&chip, instr)

    testing.expect_value(t, chip.ST, 0xff)
}

@(test)
test_call_add_I_vx_0xFx1E :: proc(t: ^testing.T) {
    chip: Chip8

    chip.memory[0] = 0xF0
    chip.memory[1] = 0x1E
    chip.memory[2] = 0xF1
    chip.memory[3] = 0x1E

    chip.V[0] = 0x9
    chip.V[1] = 0x1

    instr := fetch(&chip)
    execute(&chip, instr)
    testing.expect_value(t, chip.I, 0x9)

    instr = fetch(&chip)
    execute(&chip, instr)
    testing.expect_value(t, chip.I, 0xA)
}

@(test)
test_call_load_font_vx_0xFx29 :: proc(t: ^testing.T) {
    chip: Chip8

    chip.memory[0] = 0xF0
    chip.memory[1] = 0x29

    chip.memory[2] = 0xF1
    chip.memory[3] = 0x29

    chip.V[0] = 0x0 // font 0
    chip.V[1] = 0xA // font A

    instr := fetch(&chip)
    execute(&chip, instr)

    testing.expect_value(t, chip.I, 0x0)

    instr = fetch(&chip)
    execute(&chip, instr)
    testing.expect_value(t, chip.I, 0x32)
}

@(test)
test_call_store_bcd_rapresentation_0xFx33 :: proc(t: ^testing.T) {
    chip: Chip8

    chip.memory[0] = 0xF0
    chip.memory[1] = 0x33

    chip.V[0] = 0x80

    instr := fetch(&chip)
    execute(&chip, instr)
    testing.expect_value(t, chip.memory[chip.I], 0x1)
    testing.expect_value(t, chip.memory[chip.I + 1], 0x2)
    testing.expect_value(t, chip.memory[chip.I + 2], 0x8)
}

@(test)
test_call_store_v0_vF_start_at_I_0xFx55 :: proc(t: ^testing.T) {
    chip: Chip8

    chip.memory[0] = 0xF4
    chip.memory[1] = 0x55
    chip.memory[2] = 0xFF
    chip.memory[3] = 0x55

    chip.I = PROGRAM_START

    for i in 0..=0xF {
        chip.V[i] = u8(i + 1)
    }

    instr := fetch(&chip)
    execute(&chip, instr)

    for i in 0..=0x4 {
        testing.expect_value(t, chip.memory[chip.I + u16(i)], u8(i + 1))
    }
    for i in 0x5..=0xF {
        testing.expect_value(t, chip.memory[chip.I + u16(i)], 0x0)
    }

    instr = fetch(&chip)
    execute(&chip, instr)

    for i in 0..=0xF {
        testing.expect_value(t, chip.memory[chip.I + u16(i)], u8(i + 1))
    }

}

@(test)
test_call_read_v0_vF_from_mem_start_at_I_0xFx65 :: proc(t: ^testing.T) {
    chip: Chip8

    chip.memory[0] = 0xF4
    chip.memory[1] = 0x65
    chip.memory[2] = 0xFF
    chip.memory[3] = 0x65

    chip.I = PROGRAM_START

    for i in 0..=0xF {
        chip.memory[PROGRAM_START + i] = u8(i + 1)
    }

    instr := fetch(&chip)
    execute(&chip, instr)

    for i: u8 = 0; i <= 0x4; i += 1 {
        testing.expect_value(t, chip.V[i], i + 1)
    }
    for i: u16 = 0x5; i <= 0xF; i += 1 {
        testing.expect_value(t, chip.V[i], 0x0)
    }

    instr = fetch(&chip)
    execute(&chip, instr)

    for i: u8 = 0; i <= 0xF; i += 1 {
        testing.expect_value(t, chip.V[i], i + 1)
    }

}

@(test)
test_call_wait_for_key_press_0xFx0A :: proc(t: ^testing.T) {
    chip: Chip8

    chip.memory[0] = 0xF0
    chip.memory[1] = 0x0A

    old_PC := chip.PC

    instr := fetch(&chip)
    execute(&chip, instr)
    testing.expect_value(t, chip.PC, old_PC)

    // simulate key press
    chip.keypad[0xA] = true

    instr = fetch(&chip)
    execute(&chip, instr)
    testing.expect_value(t, chip.PC, old_PC + 2)
    testing.expect_value(t, chip.V[0], 0xA)
}
