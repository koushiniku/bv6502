; SPDX-License-Identifier: MIT
; main.s

        .include "bv6502.inc"

        .import _cgetc, _cputc, cursor

        .export _main


        .rodata

;hello:  .asciiz "Hello,\r\nworld!\r\nScroll\r\nup\r\nnow!"
;hello:  .asciiz "Hello,\r\nworld!\r\nScroll\r\nup!"
;hello:  .asciiz "Hello,\rworld!"

        .code

_main:
        lda     #1
        sta     cursor
@loop:
        jsr     _cgetc
        cmp     #$0D
        bne     @nocr
        jsr     _cputc
        lda     #$0A
@nocr:
        jsr     _cputc
        jmp     @loop
