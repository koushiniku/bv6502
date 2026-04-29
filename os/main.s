; SPDX-License-Identifier: MIT
; main.s

        .include "bv6502.inc"

        .import _cputs

        .export _main


        .rodata

hello:  .asciiz "Hello,\r\nworld!\r\nScroll\r\nup\r\nnow!"
;hello:  .asciiz "Hello,\r\nworld!\r\nScroll\r\nup!"
;hello:  .asciiz "Hello,\rworld!"

        .code

_main:
        lda     #<hello
        ldx     #>hello
        jsr     _cputs
@forever:
        jmp     @forever
