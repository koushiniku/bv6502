; SPDX-License-Identifier: MIT
; crt0.s

        .include "bv6502.inc"
        .include "via.inc"

        .export _init, _exit, _nmi_int, _irq_int, _stop, _wait
        .export initirq, doneirq
        .import _main
        .export __STARTUP__ : absolute = 1
        .import __RAM_START__, __RAM_SIZE__
        .import copydata, zerobss, initlib, donelib, callirq

        .code

_init:
        ldx     #$FF
        txs
        cld
        lda     #$FF
        sta     VIA::DDRB
@loop:
        lda     #$55
        pha
        lda     #$00
        pla
        sta     VIA::PORTB
        jmp     @loop
        lda     #<(__RAM_START__ + __RAM_SIZE__)
        sta     c_sp
        lda     #>(__RAM_START__ + __RAM_SIZE__)
        sta     c_sp + 1
        jsr     zerobss
        jsr     copydata
        jsr     initlib
        jsr     _main


_exit:
        jsr     donelib
        brk

_nmi_int:
        rti

_irq_int:
        phx
        tsx
        pha
        inx
        inx
        lda     $100, X
        and     #$10
        bne     _stop
        jsr     callirq
        pla
        plx
        rti

_stop:
        sei
        stp

_wait:
        cli
        wai
        rts

initirq:
        cli
        rts

doneirq:
