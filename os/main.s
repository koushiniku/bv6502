; SPDX-License-Identifier: MIT
; main.s

        .include "bv6502.inc"

        .import _cputs

        .export _main


        .rodata

hello:  .asciiz "Hello,\r\nworld!"


        .code

_main:
        lda     #<hello
        ldx     #>hello
        jsr     _cputs
@forever:
        jmp     @forever
