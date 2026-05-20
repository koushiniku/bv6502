; SPDX-License-Identifier: MIT
; bv6502.inc

        .if (!.defined (__bv6502_inc__))
        .define __bv6502_inc__

        .pwc02
        .feature string_escapes
        .feature line_continuations

        .include "zeropage.inc"

MHZ     = 4

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

        .define BITERVERSE(b) (b >> 7 & 1 | b >> 5 & 2 | b >> 3 & 4 \
                        | b >> 1 & 8 | b << 1 & 16 | b << 3 & 32 | b << 5 & 64 \
                        | b << 7 & 128)

        .define EVENPARITY(b) ((b ^ b >> 1 ^ b >> 2 ^ b >> 3 ^ b >> 4 ^ b >> 5 \
                ^ b >> 6 ^ b >> 7) & 1)

        .define ODDPARITY(b) (1 ^ EVENPARITY b)

        .define BITPOS(b) (1 << b)

        .endif
