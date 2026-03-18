; SPDX-License-Identifier: MIT
; main.s

        .include "bv6502.inc"

        .import _cputs

        .export _main


        .rodata

hello:  .asciiz "Hello, world!\r\n"


        .code

_main:
        lda     #<hello
        ldy     #>hello
        jsr     _cputs
@forever:
        jmp     @forever
