; SPDX-License-Identifier: MIT
; bv6502.inc

        .if (!.defined (__bv6502_inc__))
        .define __bv6502_inc__

        .pwc02
        .feature string_escapes
        .feature line_continuations

        .include "zeropage.inc"

MHZ     := 6

        .macro smb bit, addr
                .ident(.sprintf("smb%d", bit)) addr
        .endmacro

        .macro rmb bit, addr
                .ident(.sprintf("rmb%d", bit)) addr
        .endmacro

        .macro bbs bit, addr, target
                .ident(.sprintf("bbs%d", bit)) addr, target
        .endmacro

        .macro bbr bit, addr, target
                .ident(.sprintf("bbr%d", bit)) addr, target
        .endmacro

        .macro case key, target
                cmp #key
                beq target
        .endmacro

        .define BITPOS(b) (1 << b)

        .endif
