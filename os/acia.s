; SPDX-License-Identifier: MIT
;
; acia.s

        .include "bv6502.inc"

        .include "via.inc"

        .import incsp2, popa, return0, cursor

        .export acia_bgcolor, acia_bordercolor, acia_cclear, acia_cclearxy
        .export acia_chline, acia_chlinexy, acia_clrscr, acia_cpeekc
        .export acia_cpeekcolor, acia_cpeekrevers, acia_cputc, acia_cputcxy
        .export acia_cvline, acia_cvlinexy, acia_gotox, acia_gotoxy
        .export acia_revers, acia_screensize, acia_textcolor, acia_wherex
        .export acia_wherey, acia_setcursor, acia_cgetc, acia_kbhit

        .constructor acia_init
        .destructor acia_done
        .interruptor acia_irq
        .interruptor acia_via_irq

        .struct ACIA
                .org    $C00C
                DATA    .byte
                STS     .byte
                CMD     .byte
                CTRL    .byte
        .endstruct

ACIA_STS_FERR           = 1
ACIA_STS_OVRN           = 2
ACIA_STS_RDRF           = 3
ACIA_STS_DCD            = 5     ; attached to remote RTS
ACIA_STS_DSR            = 6     ; attached to remote DTR
ACIA_STS_IRQ            = 7

ACIA_CMD_DTR            = 0     ; attached to remote DCD+DSR
ACIA_CMD_IRD            = 1
ACIA_CMD_RTS            = 3
ACIA_CMD_REM            = 4

ACIA_CTRL_RCS           = 4


; 10 bits/write / 115200 bits/s * (MHZ * 1000000) cycles/s
; = 87 * MHZ cycles per write

ACIA_WR_CYCLES          = 87 * MHZ


        .zeropage

acia_rx_rp:
        .res 1
acia_rx_wp:
        .res 1
acia_tx_rp:
        .res 1
acia_tx_wp:
        .res 1
acia_fl:
        .res 1
ACIA_TDRF               = 0     ; transmit data register full



        .bss

acia_rx_buf:
        .res    256
acia_tx_buf:
        .res    256


        .code

; set up ACIA and VIA T1 timer for writes
acia_init:
        stz     acia_rx_rp
        stz     acia_rx_wp
        stz     acia_tx_rp
        stz     acia_tx_wp
        stz     acia_fl
        lda     #(BITPOS(ACIA_CTRL_RCS))
        sta     ACIA::CTRL
        lda     #(BITPOS(ACIA_CMD_DTR) | BITPOS(ACIA_CMD_RTS))
        sta     ACIA::CMD
        lda     VIA::ACR
        and     #<~(BITPOS(VIA_ACR_T1_PB7) | BITPOS(VIA_ACR_T1_CTL))
        sta     VIA::ACR
        lda     #(BITPOS(VIA_IFR_IER_T1) | BITPOS(VIA_IFR_IER_SET))
        sta     VIA::IFR
        sta     VIA::IER
        lda     #<ACIA_WR_CYCLES
        sta     VIA::T1C
        rts

; just disable interrupts
acia_done:
        lda     #VIA_IFR_IER_T1
        sta     VIA::IER
        lda     #BITPOS(ACIA_CMD_IRD)
        sta     ACIA::CMD
        rts

acia_irq:
        lda     ACIA::STS       ; clears IRQ
        bit     #BITPOS(ACIA_STS_RDRF)
        bpl     @notmine        ; check IRQ status
        beq     acia_tx         ; check RDRF status
        ldx     ACIA::DATA      ; Clears framing and overrun error bits
        bit     #BITPOS(ACIA_STS_FERR)
        bne     acia_tx         ; check framing error (bad data)
        ldy     acia_rx_wp
        iny
        cpy     acia_rx_rp
        beq     acia_tx         ; rx buffer full
        dey
        txa
        sta     acia_rx_buf,Y
        inc     acia_rx_wp
        bra     acia_tx
@notmine:
        clc
        rts

; VIA timer for waiting for ACIA tx buffer empty.
acia_via_irq:
        lda     #BITPOS(VIA_IFR_IER_T1)
        tsb     VIA::IFR
        beq     @notmine
        lda     #$01
        rmb     ACIA_TDRF,acia_fl
        bra     acia_tx
@notmine:
        clc
        rts

; Transmits a byte if the stars align.
acia_tx:
        ldy     acia_tx_rp      ; anything to transmit?
        cpy     acia_tx_wp
        beq     @tx_done
        lda     #BITPOS(ACIA_STS_DCD)
        bit     ACIA::STS
        bvs     @tx_done        ; check DSR
        bne     @tx_done        ; check DCD
        lda     #BITPOS(ACIA_TDRF)      ; test and set tx full
        tsb     acia_fl
        bne     @tx_done
        lda     acia_tx_buf,Y   ; write tx data
        sta     ACIA::DATA
        inc     acia_tx_rp
        lda     #>ACIA_WR_CYCLES; restart the timer
        sta     VIA::T1C + 1
@tx_done:
        sec                     ; for marking IRQ as handled
        rts

; Read the next rx character or wait.
acia_cgetc:
        ldy     #0
        ldx     acia_rx_rp
        cpx     acia_rx_wp
        beq     @empty
        lda     acia_rx_buf,X
        inc     acia_rx_rp
        ldx     #(BITPOS(ACIA_CMD_DTR) | BITPOS(ACIA_CMD_RTS))
        stx     ACIA::CMD
        rts
@empty:
        wai
        bra     acia_cgetc

acia_kbhit:
        ldy     #0
        ldx     acia_rx_rp
        cpx     acia_rx_wp
        beq     @empty
        lda     #1
        rts
@empty:
        lda     #0
        rts

; Write the next tx character or wait.
acia_cputc:
        ldx     acia_tx_wp
        inx
@retry:
        cpx     acia_tx_rp
        beq     @full
        dex
        sta     acia_tx_buf,X
        inc     acia_tx_wp
        bra     acia_tx
@full:
        wai
        bra     @retry

; other conio functions, currently unimplemented
; maybe implement vt100 someday. :)

acia_bgcolor            := return0
acia_bordercolor        := return0
acia_cpeekc             := return0
acia_cpeekcolor         := return0
acia_cpeekrevers        := return0
acia_revers             := return0
acia_wherex             := return0
acia_wherey             := return0
acia_textcolor          := return0

acia_cclear:
acia_cclearxy:
acia_chline:
acia_chlinexy:
acia_clrscr:
acia_cputcxy:
acia_cvline:
acia_cvlinexy:
acia_gotox:
acia_gotoxy:
acia_setcursor:
        rts

acia_screensize:
        sta     ptr1
        stx     ptr1 + 1
        lda     #0
        sta     (ptr1)
        sta     (c_sp)
        jmp     incsp2

