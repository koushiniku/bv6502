; SPDX-License-Identifier: MIT
; bv6502.inc
; zeropage acia data structure

        .if (!.defined (__via_inc__))
        .define __via_inc__

        .struct ACIA            ; W65C51
        .org    $70
DATA    .byte
STS     .byte
CMD     .byte
CTL     .byte
        .endstruct

        .endif
