; SPDX-License-Identifier: MIT
;
; bv6502.inc

        .if (!.defined (__bv6502_inc__))
        .define __bv6502_inc__

        .pwc02

        .include "zeropage.inc"

MHZ     = 4

        .struct VIA             ; W65C22
        .org    $7F80
PORTB   .byte
PORTA   .byte
DDRB    .byte
DDRA    .byte
T1C     .word
T1L     .word
T2C     .word
SR      .byte
ACR     .byte
PCR     .byte
IFR     .byte
IER     .byte
NHSPA   .byte
        .endstruct

        .struct ACIA            ; W65C51
        .org    $7F90
DATA    .byte
STS     .byte
CMD     .byte
CTL     .byte
        .endstruct

        .endif
