; SPDX-License-Identifier: MIT
; main.s

        .include "bv6502.inc"
        .include "via.inc"

        .import _cputs, _cgetc, _cputc, cursor
        .import _console_switch

        .export _main


;       .rodata
HELLO:  .asciiz "Hellorld!\r\n"

        .code

_main:
        lda     #$FF
        sta     VIA::DDRA
        sta     VIA::DDRB
        lda     #1
        jsr     _console_switch
        lda     #1
        sta     cursor
        lda     #<HELLO
        ldx     #>HELLO
        jsr     _cputs
@loop:
        jsr     _cgetc
        cmp     #$0D
        bne     @nocr
        jsr     _cputc
        lda     #$0A
@nocr:
        jsr     _cputc
        jmp     @loop
