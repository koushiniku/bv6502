; SPDX-License-Identifier: MIT
; bv6502.inc
; zeropage via data structure

        .if (!.defined (__via_inc__))
        .define __via_inc__

        .struct VIA             ; W65C22
        .org    $0              ; that's right
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

VIA_PORTB_T2I   = 6             ; T2 timer count negative pulse input
VIA_PORTB_T1O   = 7             ; T1 One shot or square wave output

VIA_PCR_CA1     = 0                     ; CA1 Interrupt Control
VIA_PCR_CA2     = 1                     ; CA2 Control
VIA_PCR_CA2_MASK= %00001110             ; CA2 Control
VIA_PCR_CA2_NEG = (0 << VIA_PCR_CA2)    ; CA2 Input--negative active edge
VIA_PCR_CA2_ING = (1 << VIA_PCR_CA2)    ; CA2 Independent negative edge
VIA_PCR_CA2_POS = (2 << VIA_PCR_CA2)    ; CA2 Input--positive active edge
VIA_PCR_CA2_IPS = (3 << VIA_PCR_CA2)    ; CA2 Independent positive edge
VIA_PCR_CA2_HS  = (4 << VIA_PCR_CA2)    ; CA2 Handshake Output
VIA_PCR_CA2_PUL = (5 << VIA_PCR_CA2)    ; CA2 Pulse Output
VIA_PCR_CA2_LO  = (6 << VIA_PCR_CA2)    ; CA2 Low Output
VIA_PCR_CA2_HI  = (7 << VIA_PCR_CA2)    ; CA2 High Output
VIA_PCR_CB2     = 5                     ; CB2 Control
VIA_PCR_CB2_MASK= %11100000             ; CB2 Control
VIA_PCR_CB2_NEG = (0 << VIA_PCR_CB2)    ; CB2 Input--negative active edge
VIA_PCR_CB2_ING = (1 << VIA_PCR_CB2)    ; CB2 Independent negative edge
VIA_PCR_CB2_POS = (2 << VIA_PCR_CB2)    ; CB2 Input--positive active edge
VIA_PCR_CB2_IPS = (3 << VIA_PCR_CB2)    ; CB2 Independent positive edge
VIA_PCR_CB2_HS  = (4 << VIA_PCR_CB2)    ; CB2 Handshake Output
VIA_PCR_CB2_PUL = (5 << VIA_PCR_CB2)    ; CB2 Pulse Output
VIA_PCR_CB2_LO  = (6 << VIA_PCR_CB2)    ; CB2 Low Output
VIA_PCR_CB2_HI  = (7 << VIA_PCR_CB2)    ; CB2 High Output

VIA_ACR_PAL     = 0                     ; ACR PA Latch Enable/Disable
VIA_ACR_PBL     = 1                     ; ACR PA Latch Enable/Disable
VIA_ACR_SR      = 3                     ; ACR Shift Register Control
VIA_ACR_SR_MASK = %00011100
VIA_ACR_SR_DIS  = (0 << VIA_ACR_SR)     ; ACR Shift Disabled
VIA_ACR_SR_SIT2 = (1 << VIA_ACR_SR)     ; ACR Shift in T2
VIA_ACR_SR_SIP2 = (2 << VIA_ACR_SR)     ; ACR Shift in PHI2
VIA_ACR_SR_SIEX = (3 << VIA_ACR_SR)     ; ACR Shift in external clock
VIA_ACR_SR_SOFR = (4 << VIA_ACR_SR)     ; ACR Shift out free running T2
VIA_ACR_SR_SOT2 = (5 << VIA_ACR_SR)     ; ACR Shift out T2
VIA_ACR_SR_SOP2 = (6 << VIA_ACR_SR)     ; ACR Shift out PHI2
VIA_ACR_SR_SOEX = (7 << VIA_ACR_SR)     ; ACR Shift out external clock
VIA_ACR_T2_CTL  = 5                     ; ACR T2 Timer Control

VIA_ACR_T1_PB7  = 6                     ; ACR T1 Timer PB7 Output Enable
VIA_ACR_T2_CTL  = 5                     ; ACR T2 Timer Control
VIA_ACR_T2_INT  = (0 << VIA_ACR_T2_CTL) ; ACR Shift Disabled
VIA_ACR_T2_PLS  = (1 << VIA_ACR_T2_CTL) ; ACR Shift in T2

VIA_IFR_IER_CA2 = 0             ; Interrupt Flags/Enable CA2
VIA_IFR_IER_CA1 = 1             ; Interrupt Flags/Enable CA1
VIA_IFR_IER_SR  = 2             ; Interrupt Flags/Enable Shift Register
VIA_IFR_IER_CB2 = 3             ; Interrupt Flags/Enable CB2
VIA_IFR_IER_CB1 = 4             ; Interrupt Flags/Enable CB1
VIA_IFR_IER_T2  = 5             ; Interrupt Flags/Enable Timer 2
VIA_IFR_IER_T1  = 6             ; Interrupt Flags/Enable Timer 1
VIA_IFR_IER_SET = 7             ; Intterupt Flags IRQ/Interrupt Enable Set/Clear

        .endif
