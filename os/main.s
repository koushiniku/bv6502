; SPDX-License-Identifier: MIT
; main.s

        .include "bv6502.inc"
        .include "via.inc"

        ;.import _cgetc, _cputc, cursor
        .import _cputs

        .export _main


        .rodata

;hello:  .asciiz "Hello,\r\nworld!\r\nScroll\r\nup\r\nnow!"
;hello:  .asciiz "Hello,\r\nworld!\r\nScroll\r\nup!"
hello:  .asciiz "What is hellord?\r\n"

        .code

_main:
        ; probably the easiest thing to do is blink lights on the VIA.
        lda     #$FF
        sta     VIA::DDRB
        stz     VIA::DDRA
@loop:
        lda     VIA::PORTA
        sta     VIA::PORTB
        lda     #<hello
        ldx     #>hello
        jsr     _cputs
        bra     @loop



;_main:
;        lda     #1
;        sta     cursor
;@loop:
;        jsr     _cgetc
;        cmp     #$0D
;        bne     @nocr
;        jsr     _cputc
;        lda     #$0A
;@nocr:
;        jsr     _cputc
;        jmp     @loop
