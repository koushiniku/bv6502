; SPDX-License-Identifier: MIT
;
; crt0.s

        .include "bv6502.inc"

        .export _exit, _stop, _wait
        .import _main
        .export __STARTUP__ : absolute = 1
        .import __RAM_START__, __RAM_SIZE__
        .import copydata, zerobss, initlib, donelib, callirq


        .segment "VECTORS"

        .addr   _nmi_int
        .addr   _init
        .addr   _irq_int


        .code

_init:
        ldx     #$FF
        txs
        cld
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


        .code

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


