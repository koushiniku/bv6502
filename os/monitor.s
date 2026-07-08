; SPDX-License-Identifier: MIT
; monitor.s

        .include "bv6502.inc"
        .include "via.inc"

        .import cursor, _console_switch, _cgets, _cputs, _cputc

        .export _main

BUF_BYTES       = $80

        .zeropage
flags:          .res    1
FL_EOL          = 4             ; differentiate space (eow) and null (eol)
FL_PEEK         = 5             ; parsing end address of a range (after dot)
FL_SHIFT        = 6             ; set after parsing first hex nibble
FL_POKE         = 7             ; parsing a byte value to write (after colon)
open_addr:      .res    2
cur_addr:       .res    2       ; current peek or poke address
end_addr:       .res    2       ; end peek address range
poke_val:       .res    1

        .bss
in_buf:         .res    BUF_BYTES

        .code
_main:
        lda     #1
        sta     cursor
        stz     open_addr
        stz     open_addr + 1
@esc:
        stz     flags
        stz     cur_addr
        stz     cur_addr + 1
        stz     end_addr
        stz     end_addr + 1
        lda     #$5C            ; "\"
        jsr     _cputc
        lda     #$0A            ; "\n"
        jsr     _cputc
@main_loop:
        stz     flags
        dec     c_sp            ; get a line of text
        lda     #>in_buf
        sta     (c_sp)
        dec     c_sp
        lda     #<in_buf
        sta     (c_sp)
        lda     #<BUF_BYTES
        ldy     #>BUF_BYTES
        jsr     _cgets
        cmp     #$00            ; error check
        bne     @ok
        cpy     #$00
        bne     @ok
        bra     @esc
@ok:
        lda     #$0A            ; "\n"
        jsr     _cputc
        ldy     #$FF
@parse_loop:
        inx
        lda     in_buf,Y
        case    '.',@peek
        case    ':',@poke
        case    'R',@run
        case    'r',@run
        case    ' ',@eow
        case    $00,@eol
        sec                     ; check for digit
        sbc     #$30
        bmi     @esc
        cmp     #$0A
        bcc     @nibble
        sbc     #$07            ; check for A-F
        cmp     #$0A
        bcc     @esc
        cmp     #$10
        bcc     @nibble
        sbc     #$20            ; check for a-f
        cmp     #$0A
        bcc     @esc
        cmp     #$10
        bcc     @nibble
        bra     @esc            ; unexpected character
@peek:
        lda     flags
        ora     #SETBIT(FL_PEEK)
        and     #<~(SETBIT(FL_SHIFT))
        sta     flags
        bra     @parse_loop
@poke:
        bit     flags
        bvc     @use_cur
        lda     open_addr       ; colon before address
        sta     cur_addr
        lda     open_addr + 1
        sta     cur_addr + 1
@use_cur:
        smb     FL_POKE,flags
        bra     @parse_loop
        phx
        jsr     peek
        plx
@run:
        jmp     (open_addr)
@eol:
        smb     FL_EOL,flags
@eow:
        bit     flags
        bpl     @dopeek
        lda     poke_val        ; do poke
        sta     (end_addr)
        inc     end_addr        ; set next address to poke
        bne     @done
        inc     end_addr + 1
        bra     @done
@dopeek:
        phx
        jsr     peek
        plx
        lda     open_addr       ; cur address reset to open address
        sta     cur_addr
        lda     open_addr + 1
        sta     cur_addr + 1
@done:
        lda     flags
        bit     #SETBIT(FL_EOL)
        bne     @noeol
        jmp     @main_loop
@noeol:
        and     #SETBIT(FL_POKE); EOL clears FL_POKE, but space doesn't
        sta     flags
        jmp     @parse_loop
@nibble:                        ; shift nibble into the appropriate address
        ldx     #0
        ora     flags           ; lower 4 bits are free to use for data
        bit     #SETBIT(FL_PEEK)
        beq     @nopeek
        ldx     #(end_addr - open_addr)
        bra     @nopoke
@nopeek:
        bmi     @nopoke
        ldx     #(poke_val - open_addr)
@nopoke:
        and     #$0F
        bvc     @noshift
        phx
        ldy     #4
@shift:
        asl     open_addr,X
        iny
        rol     open_addr,X
        dey
        dex
        bne     @shift
        ora     open_addr,X
        sta     open_addr,X
        plx
        jmp     @parse_loop
@noshift:
        sta     open_addr,X
        lda     flags
        ora     #SETBIT(FL_SHIFT)
        sta     flags
        and     #SETBIT(FL_POKE)
        bne     @nopoke2
        iny
        stz     open_addr,X
@nopoke2:
        jmp     @parse_loop

peek:                           ; print addresses and contents
        lda     open_addr
        sta     cur_addr
        lda     open_addr + 1
        sta     cur_addr + 1
@outer:
        lda     #cur_addr + 1   ; print address for row
        jsr     print_hex
        lda     #cur_addr
        jsr     print_hex
        lda     cur_addr
        jsr     print_hex
        lda     #':'
        jsr     _cputc
        ldx     #8
@inner:                         ; print 8 hex values
        phx
        lda     #' '
        jsr     _cputc
        lda     cur_addr
        jsr     print_hex
        inc     cur_addr
        bne     @nocarry
        inc     cur_addr + 1
@nocarry:
        plx
        lda     end_addr + 1    ; return when cur_addr == end_addr
        cmp     cur_addr + 1
        bcc     @cont
        lda     end_addr
        cmp     cur_addr
        bcc     @cont
        rts
@cont:
        dex
        bne     @inner
        

print_hex:                      ; print a byte as hex
        sta     poke_val        ; unused when peeking
        smb     FL_SHIFT,flags
        lsr     A
        lsr     A
        lsr     A
        lsr     A
@loop:
        cmp     #10
        beq     @char
        adc     $30
        bra     @ok
@char:
        adc     $41
@ok:
        jsr     _cputc
        lda     #SETBIT(FL_SHIFT)
        trb     flags
        beq     @done
        lda     poke_val
        and     #$0F
        bra     @loop
@done:
        rts
