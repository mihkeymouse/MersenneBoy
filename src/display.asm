InitDisplay:
.vblank:
    ldh a, [rLY]
    cp 144
    jr c, .vblank
    xor a
    ldh [rLCDC], a
    ldh [rSCX], a
    ldh [rSCY], a
    ld [wOldKeys], a
    ld [wInk], a
    ld a, [wHardware]
    cp $11
    call z, InitColor
    ld hl, Font
    ld de, $8000
    ld bc, FontEnd-Font
.font:
    ld a, [hli]
    ld [de], a
    inc de
    dec bc
    ld a, b
    or c
    jr nz, .font
    ld hl, $9800
    ld bc, 1024
.clear:
    xor a
    ld [hli], a
    dec bc
    ld a, b
    or c
    jr nz, .clear
    ld hl, $9820
    ld de, Title
    call PutString
    ld hl, $9860
    ld de, Subtitle
    call PutString
    ; Big glyphs use a 2x2 block of tiles, so top row first.
    ld hl, $98C6
    ld a, 106
    call BigGlyph
    ld hl, $98CB
    ld a, 110
    call BigGlyph
    ld hl, $98CD
    ld a, 114
    call BigGlyph
    ld hl, $99A0
    ld de, Controls
    call PutString
    ld hl, $99C0
    ld de, ControlsTen
    call PutString
    ld a, $E4
    ldh [rBGP], a
    ld a, $91
    ldh [rLCDC], a
    ret

BigGlyph:
    ld [hli], a
    inc a
    ld [hl], a
    ld de, 31
    add hl, de
    inc a
    ld [hli], a
    inc a
    ld [hl], a
    ret

InitColor:
    ld a, 1
    ldh [$FF4F], a
    ld hl, $9800
    ld bc, 1024
.attributes:
    xor a
    ld [hli], a
    dec bc
    ld a, b
    or c
    jr nz, .attributes
    xor a
    ldh [$FF4F], a
    ld a, $80
    ldh [$FF68], a
    ld hl, Palette
    ld b, 8
.palette:
    ld a, [hli]
    ldh [$FF69], a
    dec b
    jr nz, .palette
    ret
Palette:
    dw 8 | (19 << 5) | (31 << 10), 0, 0, 0

; A = ASCII, HL = tile address. Add 80 for superscript digits.
PutChar:
    push bc
    sub 32
    ld b, a
    jr z, .space
    ld a, [wInk]
    add b
    ld b, a
.space:
.safe:
    ldh a, [rSTAT]
    and 2
    jr nz, .safe
    ld a, b
    ld [hli], a
    pop bc
    ret
PutString:
    ld a, [de]
    inc de
    or a
    ret z
    call PutChar
    jr PutString

; Print DE (0..9999), skip leading zeroes.
Decimal4:
    xor a
    ld [wLeading], a
    ld bc, 1000
    call .digit
    ld bc, 100
    call .digit
    ld bc, 10
    call .digit
    ld a, e
    add '0'
    jp PutChar
.digit:
    xor a
    ld [wDecimal], a
.subtract:
    ld a, e
    sub c
    ld e, a
    ld a, d
    sbc b
    ld d, a
    jr c, .restore
    ld a, [wDecimal]
    inc a
    ld [wDecimal], a
    jr .subtract
.restore:
    ld a, e
    add c
    ld e, a
    ld a, d
    adc b
    ld d, a
    ld a, [wLeading]
    ld b, a
    ld a, [wDecimal]
    or b
    ret z
    ld [wLeading], a
    ld a, [wDecimal]
    add '0'
    jp PutChar

DrawStatus:
    ld hl, $98A8
    ld de, FourSpaces
    call PutString
    ld a, 80
    ld [wInk], a
    ld a, [wExponent]
    ld e, a
    ld a, [wExponent+1]
    ld d, a
    ld hl, $98A8
    call Decimal4
    xor a
    ld [wInk], a
    ld a, [wStatus]
    add a
    ld e, a
    ld d, 0
    ld hl, StatusTable
    add hl, de
    ld a, [hli]
    ld d, [hl]
    ld e, a
    ld hl, $9920
    call PutString
    ld hl, $9960
    ld de, EmptyLine
    call PutString
    ld a, [wStatus]
    cp 3
    jr nc, .buttons
    ld a, [wIteration]
    ld e, a
    ld a, [wIteration+1]
    ld d, a
    ld hl, $9965
    call Decimal4
    ld a, ' '
    call PutChar
    ld a, '/'
    call PutChar
    ld a, ' '
    call PutChar
    ld a, [wTotal]
    ld e, a
    ld a, [wTotal+1]
    ld d, a
    call Decimal4
.buttons:
    ld de, Buttons
    ld a, [wStatus]
    or a
    jr nz, .printButtons
    ld de, StopButton
.printButtons:
    ld hl, $9A00
    jp PutString

ServiceDisplay:
    call ReadKeys
    bit 5, a
    jr z, .refresh
    scf
    ret
.refresh:
    ld a, [wIteration]
    and 7
    ret nz
    call DrawStatus
    and a
    ret

ReadKeys:
    ld a, $20
    ldh [rP1], a
    REPT 3
        ldh a, [rP1]
    ENDR
    cpl
    and 15
    ld b, a
    ld a, $10
    ldh [rP1], a
    REPT 3
        ldh a, [rP1]
    ENDR
    cpl
    and 15
    swap a
    or b
    ret

HandleInput:
.leaveBlank:
    ldh a, [rLY]
    cp 144
    jr nc, .leaveBlank
.waitBlank:
    ldh a, [rLY]
    cp 144
    jr c, .waitBlank
    call ReadKeys
    ld b, a
    ld a, [wOldKeys]
    cpl
    and b
    ld c, a
    ld a, b
    ld [wOldKeys], a
    bit 4, c
    jp nz, RunTest
    bit 7, c
    jp nz, RunTest
    ld hl, 127
    bit 5, c
    jr nz, .changed
    ld a, [wExponent]
    ld l, a
    ld a, [wExponent+1]
    ld h, a
    ld de, 1
    bit 0, c
    jr nz, .add
    ld de, -1
    bit 1, c
    jr nz, .add
    ld de, 10
    bit 2, c
    jr nz, .add
    ld de, -10
    bit 3, c
    ret z
.add:
    add hl, de
    bit 7, h
    jr nz, .minimum
    ld a, h
    or a
    jr nz, .maximum
    ld a, l
    cp 2
    jr nc, .changed
.minimum:
    ld hl, 2
    jr .changed
.maximum:
    cp 8
    jr c, .changed
    ld hl, MAX_P
.changed:
    ld a, l
    ld [wExponent], a
    ld a, h
    ld [wExponent+1], a
    ld a, 5
    ld [wStatus], a
    jp DrawStatus

Title:       db "    Mersenne Boy",0
Subtitle:    db "    Lucas-Lehmer",0
Controls:    db "     < >   +/-1",0
ControlsTen: db "     ^ v   +/-10",0
Buttons:     db "  A test   B reset  ",0
StopButton:  db "    Hold B to stop  ",0
FourSpaces:  db "    ",0
EmptyLine:   db "                    ",0
StatusTable: dw Busy, Prime, Composite, Composite, InvalidText, Ready, Stopped
Busy:        db "     testing...     ",0
Prime:       db "       prime        ",0
Composite:   db "     composite      ",0
InvalidText: db "    use 2 - 2047    ",0
Ready:       db "       ready        ",0
Stopped:     db "      stopped       ",0
Font: INCBIN "src/font.bin"
FontEnd:
