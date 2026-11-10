DEF rP1 EQU $FF00
DEF rIF EQU $FF0F
DEF rLCDC EQU $FF40
DEF rSTAT EQU $FF41
DEF rSCY EQU $FF42
DEF rSCX EQU $FF43
DEF rLY EQU $FF44
DEF rBGP EQU $FF47
DEF rIE EQU $FFFF
DEF MAX_P EQU 2047

SECTION "Entry", ROM0[$100]
    nop
    jp Boot
    ds $150-@, 0

SECTION "Program", ROM0[$150]
Boot:
    ld [wHardware], a
    di
    ld sp, $DFFF
    xor a
    ldh [rIE], a
    ldh [rIF], a
    ld a, [BootExponent]
    ld [wExponent], a
    ld a, [BootExponent+1]
    ld [wExponent+1], a
    call InitDisplay
    call RunTest
Idle:
    call HandleInput
    jr Idle
BootExponent: dw 127

; wExponent = p, 2..2047. Store the residue in wS, with low byte first.
RunTest:
    xor a
    ld [wStatus], a
    ld [wIteration], a
    ld [wIteration+1], a
    ld a, [wExponent+1]
    cp 8
    jp nc, Invalid
    ld d, a
    ld a, [wExponent]
    ld e, a
    ld a, d
    or a
    jr nz, .inRange
    ld a, e
    cp 2
    jp c, Invalid
    jp z, PrimeTwo
.inRange:
    bit 0, e
    jp z, ExponentComposite
    ; No exponent in range needs a trial divisor above 45.
    ld c, 3
.divisor:
    ld h, d
    ld l, e
    ld a, h
    or a
    jr nz, .modulo
    ld a, l
    cp c
    jr z, .primeExponent
    jr c, .primeExponent
.modulo:
    ld a, l
    sub c
    ld l, a
    ld a, h
    sbc 0
    ld h, a
    jr c, .nextDivisor
    or l
    jp z, ExponentComposite
    jr .modulo
.nextDivisor:
    inc c
    inc c
    ld a, c
    cp 47
    jr c, .divisor
.primeExponent:
    call Setup
    call DrawStatus
.iteration:
    call Square
    call Reduce
    call SubtractTwo
    ld hl, wIteration
    ld a, [hl]
    ; I found ncw1's INC leaves Z clear at $FF -> $00. Use ADD 1 here.
    add 1
    ld [hl], a
    jr nz, IterationDone
    inc hl
    inc [hl]
IterationDone:
    call ServiceDisplay
    jr c, Cancelled
    ld a, [wTotal]
    ld b, a
    ld a, [wIteration]
    cp b
    jr nz, RunTest.iteration
    ld a, [wTotal+1]
    ld b, a
    ld a, [wIteration+1]
    cp b
    jr nz, RunTest.iteration
    ld hl, wS
    ldh a, [hCount]
    ld b, a
    xor a
.zero:
    or [hl]
    inc hl
    dec b
    jr nz, .zero
    ; I caught this with p=11: DEC B left Z set and called it prime.
    ; Check A, which holds the OR of the residue bytes.
    or a
    ld a, 1
    jr z, Finish
    inc a
    jr Finish
PrimeTwo:
    call Setup
    xor a
    ld [wS], a
    ld a, 1
    jr Finish
ExponentComposite:
    ld a, 3
    jr Finish
Invalid:
    ld a, 4
Finish:
    ld [wStatus], a
ResultReady:
    call DrawStatus
    ret

Cancelled:
    ld a, $20
    ld [wOldKeys], a
    ld a, 6
    jr Finish

Setup:
    ; Count 0 gives 256 passes through DEC loop.
    ld a, [wExponent]
    ld e, a
    and 7
    ldh [hShift], a
    ld c, a
    ld a, [wExponent+1]
    ld d, a
    ld hl, -2
    add hl, de
    ld a, l
    ld [wTotal], a
    ld a, h
    ld [wTotal+1], a
    ld h, d
    ld l, e
    dec hl
    REPT 3
        srl h
        rr l
    ENDR
    ld a, l
    ldh [hLast], a
    inc a
    ldh [hCount], a
    ld b, c
    ld a, b
    or a
    ld a, $FF
    ; Keep all eight top bits when p is a multiple of 8.
    jr z, .mask
    ld a, 1
.maskLoop:
    add a
    dec b
    jr nz, .maskLoop
    dec a
.mask:
    ldh [hMask], a
    ld hl, wS
    ld b, 0
    xor a
.clear:
    ld [hli], a
    dec b
    jr nz, .clear
    ld a, 4
    ld [wS], a
    ret

; Each byte pair contributes at i+j; carry into the next byte.
Square:
    ld hl, wProduct
    ld bc, 514
.clear:
    xor a
    ld [hli], a
    dec bc
    ld a, b
    or c
    jr nz, .clear
    ldh [hRow], a
.row:
    xor a
    ldh [hColumn], a
    ldh [hCarry], a
.column:
    ld h, HIGH(wS)
    ldh a, [hColumn]
    ld l, a
    ld c, [hl]
    ldh a, [hRow]
    ld l, a
    ld a, [hl]
    call Multiply
    ld d, h
    ld e, l
    ldh a, [hCarry]
    add e
    ld e, a
    ld a, d
    adc 0
    ld d, a
    ; i+j can exceed 255, so carry into H too.
    ldh a, [hRow]
    ld l, a
    ldh a, [hColumn]
    add l
    ld l, a
    ld a, HIGH(wProduct)
    adc 0
    ld h, a
    ld a, [hl]
    add e
    ld [hli], a
    ld a, d
    adc 0
    ldh [hCarry], a
    ldh a, [hLast]
    ld b, a
    ldh a, [hColumn]
    cp b
    jr z, .endRow
    inc a
    ldh [hColumn], a
    jr .column
.endRow:
    ldh a, [hCarry]
    ld [hl], a
    ldh a, [hRow]
    cp b
    ret z
    inc a
    ldh [hRow], a
    jr .row

; A * C -> HL.
Multiply:
    ld e, a
    ld d, 0
    ld hl, 0
    ld b, 8
.bit:
    srl c
    jr nc, .skip
    add hl, de
.skip:
    sla e
    rl d
    dec b
    jr nz, .bit
    ret

; M = 2^p-1. Reduce x to (x & M)+(x >> p).
; x<M*M, so one more carry fold is enough.
Reduce:
    ld a, [wExponent]
    ld l, a
    ld a, [wExponent+1]
    ld h, a
    REPT 3
        srl h
        rr l
    ENDR
    ld de, wProduct
    add hl, de
    ld de, wHigh
    ldh a, [hCount]
    ld b, a
.highCopy:
    ld a, [hli]
    ld [de], a
    inc de
    dec b
    jr nz, .highCopy
    ld a, [hl]
    ; Keep the extra byte before shifting across the p-bit boundary.
    ld [de], a
    ld a, e
    ldh [hHighEnd], a
    ld a, d
    ldh [hHighEnd+1], a
    ldh a, [hShift]
    ld c, a
    or a
    jr z, .lowCopy
.shift:
    ldh a, [hHighEnd]
    ld l, a
    ldh a, [hHighEnd+1]
    ld h, a
    srl [hl]
    dec hl
    ldh a, [hCount]
    ld b, a
.shiftByte:
    rr [hl]
    dec hl
    dec b
    jr nz, .shiftByte
    dec c
    jr nz, .shift
.lowCopy:
    ld hl, wProduct
    ld de, wS
    ldh a, [hCount]
    ld b, a
.copy:
    ld a, [hli]
    ld [de], a
    inc de
    dec b
    jr nz, .copy
    dec de
    ldh a, [hMask]
    ld b, a
    ld a, [de]
    and b
    ld [de], a
    ld hl, wHigh
    ld de, wS
    ldh a, [hCount]
    ld b, a
    and a
.add:
    ld a, [de]
    adc [hl]
    ld [de], a
    inc de
    inc hl
    dec b
    jr nz, .add
    ld a, 0
    adc 0
    ld c, a                    ; Use this carry when p is a multiple of 8.
    ldh a, [hShift]
    or a
    jr z, .fold
    ld b, a
    dec de
    ld a, [de]
.top:
    srl a
    dec b
    jr nz, .top
    ld c, a
    ldh a, [hMask]
    ld b, a
    ld a, [de]
    and b
    ld [de], a
.fold:
    ld hl, wS
    ld a, [hl]
    add c
    ld [hli], a
    jr nc, .normalize
.foldCarry:
    ld a, [hl]
    add 1
    ld [hl], a
    inc hl
    jr z, .foldCarry
.normalize:
    ; Replace M with 0: both give the same remainder.
    ld hl, wS
    ldh a, [hLast]
    ld b, a
    or a
    jr z, .checkTop
.checkFF:
    ld a, [hli]
    cp $FF
    ret nz
    dec b
    jr nz, .checkFF
.checkTop:
    ldh a, [hMask]
    cp [hl]
    ret nz
    ld hl, wS
    ldh a, [hCount]
    ld b, a
    xor a
.zero:
    ld [hli], a
    dec b
    jr nz, .zero
    ret

SubtractTwo:
    ld hl, wS
    ldh a, [hCount]
    ld b, a
    ld a, [hl]
    sub 2
    ld [hli], a
    dec b
    jr z, .borrow
.subtract:
    ld a, [hl]
    sbc 0
    ld [hli], a
    dec b
    jr nz, .subtract
.borrow:
    ret nc
    ; Only 0 and 1 underflow. Subtract one more and mask to get M-2 or M-1.
    ld hl, wS
    dec [hl]
    ldh a, [hLast]
    ld l, a
    ldh a, [hMask]
    and [hl]
    ld [hl], a
    ret

INCLUDE "src/display.asm"

SECTION "padding", ROMX[$7FFF], BANK[1]
    db $FF

SECTION "Residue", WRAM0[$C000]
wS: ds 256
wProduct: ds 514
wHigh: ds 257
SECTION "State", WRAM0[$C500]
wExponent: ds 2
wIteration: ds 2
wTotal: ds 2
wStatus: ds 1
wOldKeys: ds 1
wLeading: ds 1
wInk: ds 1
wDecimal: ds 1
wHardware: ds 1
SECTION "Fast state", HRAM
hCount: ds 1
hLast: ds 1
hShift: ds 1
hMask: ds 1
hRow: ds 1
hColumn: ds 1
hCarry: ds 1
hHighEnd: ds 2
