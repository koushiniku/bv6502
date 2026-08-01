; SPDX-License-Identifier: MIT
;
; ft245.s
;
; Console driver for FT245 or FT232H in FIFO mode.

        .include "bv6502.inc"
        .include "via.inc"

        .import popa, cursor

        .export ft245_bgcolor, ft245_cclear, ft245_cclearxy, ft245_cgetc
        .export ft245_clrscr, ft245_cpeekc, ft245_cpeeks, ft245_cputc
        .export ft245_cputcxy, ft245_gotox, ft245gotoxy, ft245_gotoxy
        .export ft245_kbhit, ft245_revers, ft245screensize, ft245_textcolor
        .export ft245_wherex, ft245_wherey

        .constructor    ft245_init
        .destructor     ft245_done
        .interruptor    ft245_irq
        .interruptor    ft245_timer_irq

        .struct FT245
                .org    $C00C
                DATA    .byte
                CSR     .byte
        .endstruct

FT245_CSR_IRQ_EN        = 4
FT245_CSR_DCD           = 5
FT245_CSR_RXF           = 6
FT245_CSR_TXE           = 7

FLAGS_REVERS            = 0
FLAGS_CSI_SEEN          = 5
FLAGS_ESC_TIMEOUT       = 6
FLAGS_ESC_SEEN          = 7

PARAM_BYTES             = 6     ; max 3 words

        .rodata
scrsz_str:      .asciiz "\x1B[18t"
where_str:      .asciiz "\x1B[6n"
clrscr_str:     .asciiz "\x1B[2J\x1B[H"
cur_on_str:     .asciiz "\x1B[?25h"
cur_off_str:    .asciiz "\x1B[?25l"
rvrs_on_str:    .asciiz "\x1B[?5h"
rvrs_off_str:   .asciiz "\x1B[?5l"

        .zeropage
rx_rp:          .res    1
rx_wp:          .res    1
flags:          .res    1
esc_sp:         .res    1
esc_ep:         .res    1

        .bss
rx_buf:         .res    256
param_buf:      .res    PARAM_BYTES

        .code
ft245_init:
        lda     #SETBIT(FT245_CSR_IRQ_EN)
        sta     FT245::CSR
        lda     #$FF
        sta     VIA::T1L        ; pre-load the low-oder timer once
        lda     #SETBIT(VIA_IFR_IER_SET) | SETBIT(VIA_IFR_IER_T1)
        sta     VIA::IER        ; enable incoming escape code timeout
        rts

ft245_done:
        stz     FT245::CSR
        lda     #SETBIT(VIA_IFR_IER_T1)
        sta     VIA::IER
        rts

ft245_irq:
        lda     #SETBIT(FT245_CSR_IRQ_EN)
        bit     FT245::CSR
        bvc     @notmine
        bne     @notmine
        sec
@loop:
        ldy     rx_wp
        iny
        cpy     rx_rp
        beq     @full
        dey
        lda     FT245::DATA
        sta     rx_buf,Y
        inc     rx_wp
        bit     FT245::CSR
        bvs     @loop
        rts
@notmine:
        clc
        rts
@full:
        stz     FT245::CSR      ; disable interrupt
        rts

ft245_timer_irq:
        lda     #SETBIT(VIA_IFR_IER_T1)
        tsb     VIA::IFR
        beq     @notmine
        tsb     flags           ; both are bit 6; this must be atomic
        sec
        rts
@notmine:
        clc
        rts

ft245_kbhit:
        lda     rx_rp
        sec
        sbc     rx_rp
        ldx     #0
        rts

ft245_cgetc:
        ldy     rx_rp
@retry:
        cpy     rx_wp
        beq     @empty
        inc     rx_rp
        lda     rx_buf,Y
        beq     ft245_cgetc     ; skip nulls
        ldx     #0
        rts
@empty:
        lda     #SETBIT(FT245_CSR_IRQ_EN)
        sta     FT245::CSR
        phy
        sec                     ; turn on
        jsr     set_cursor
        wai
        clc                     ; turn off
        jsr     set_cursor
        ply
        bra     @retry

; transmit byte in decimal ascii
; omit leading zeroes
; omit zero itself
itoa_tx:
        ldy     #$FF
        sty     tmp1            ; set zero when leading nonzero digit found
@loop100:
        iny
        tax
        sec
        sbc     #100
        bcs     @loop100
        tya
        beq     @skip100
        stz     tmp1
        adc     #$30            ; carry is clear from bcs
        phx
        jsr     ft245_cputc
        pla
@skip100:
        ldy     #$FF
@loop10:
        iny
        tax
        sec
        sbc     #10
        bcs     @loop10
        tya
        bne     @noskip10
        bit     tmp1
        bmi     @skip10
        tya
@noskip10:
        stz     tmp1
        adc     #$30            ; carry is clear from bcs
        phx
        jsr     ft245_cputc
        pla
@skip10:
        bne     @noskip1
        bit     tmp1
        bmi     @skip1
@noskip1:
        clc
        adc     #$30
        bra     ft245_cputc
@skip1:
        rts

; character in A
; y coord in X
; x coord in sreg
ft245_cputcxy:
        pha
        tya
        ldx     sreg
        jsr     ft245_gotoxy
        pla
ft245_cputc:
        tax
@loop:
        lda     #SETBIT(FT245_CSR_DCD)
        bit     FT245::CSR
        bne     @nocarrier      ; drop the data rather than stall
        bpl     @loop           ; poll until empty
        pla
        stx     FT245::DATA
@nocarrier:
        rts

; color value is 4-bit IRGB
ft245_bgcolor:
        sec
        bra     color_set

ft245_textcolor:
        clc
color_set:
        pha
        php
        cmp     #$08
        php
        jsr     csi_tx
        bcs     @hi
        plp
        bcs     @lobg
        lda     #'3'
        bra     @cont
@hi:
        plp
        bcs     @hibg
        lda     #'9'
        bra     @cont
@lobg:
        lda     #'4'
        bra     @cont
@hibg:
        lda     #'1'
        jsr     ft245_cputc
        lda     #'0'
@cont:
        jsr     ft245_cputc
        pla
        and     #$07
        ora     #$30
        jsr     ft245_cputc
        lda     #'m'
        bra     ft245_cputc

csi_tx:
        lda     #$1B
        jsr     ft245_cputc
        lda     #$5B
        bra     ft245_cputc

ft245_gotoy:
        lda     #'G'
        bra     goto

ft245_gotox:
        ldx     #'d'
goto:
        phx
        pha
        jsr     csi_tx
        pla
        jsr     itoa_tx
        pla
        bra     ft245_cputc

ft245gotoxy:
        jsr     popa
ft245_gotoxy:
        phx
        plx
        jsr     csi_tx
        pla
        jsr     itoa_tx
        lda     #';'
        jsr     ft245_cputc
        pla
        jsr     itoa_tx
        lda     #'H'
        bra     ft245_cputc

set_cursor:
        php
        lda     cursor
        bne     @cont
        plp
        rts
@cont:
        plp
        bcc     @off
        lda     cur_on_str
        ldx     cur_on_str + 1
        bra     @send
@off:
        lda     cur_off_str
        ldx     cur_off_str + 1
@send:
        bra     esc_tx

esc_tx:
        sta     ptr1
        stx     ptr1 + 1
        ldy     #0
@loop:
        lda     (ptr1),Y
        bne     @cont
        rts
@cont:
        jsr     ft245_cputc
        iny
        bra     @loop

ft245_clrscr:
        lda     clrscr_str
        ldx     clrscr_str + 1
        bra     esc_tx

ft245_revers:
        ldx     flags           ; preserve the old value
        phx
        cmp     #0
        beq     @off
        lda     rvrs_on_str
        ldx     rvrs_on_str + 1
        jsr     esc_tx
        smb     FLAGS_REVERS,flags
        bra     @cont
@off:
        lda     rvrs_off_str
        ldx     rvrs_off_str + 1
        jsr     esc_tx
        rmb     FLAGS_REVERS,flags
@cont:
        pla
        ora     #SETBIT(FLAGS_REVERS)
        ldx     #0
        rts

; length in A, y in X, x in sreg
ft245_cclearxy:
        pha
        tya
        ldx     sreg
        jsr     ft245_gotoxy
        pla
ft245_cclear:
        tay
        beq     @done
        lda     #' '
@loop:
        jsr     ft245_cputc
        dey
        bne     @loop
@done:
        rts

; return width in X and height in Y
ft245screensize:
        lda     scrsz_str
        ldx     scrsz_str + 1
        jsr     esc_tx
        jsr     esc_rx
        bcs     @err
        cmp     #'t'            ; expected terminator
        bne     @err
        cpx     #6              ; expected # params * 2
        bne     @err
        ldy     #0
        lda     param_buf,Y
        cmp     #8              ; first param should be 8
        bne     @err
        iny
        lda     param_buf,Y
        bne     @err
        iny
        ldx     param_buf,Y
        iny
        lda     param_buf,Y
        beq     @noclampy
        ldx     #$FF
@noclampy:
        phx
        iny
        ldx     param_buf,Y
        iny
        lda     param_buf,Y
        beq     @noclampx
        ldx     #$FF
@noclampx:
        phx
        jsr     esc_rx_erase
        plx
        ply
        rts
@err:                           ; fake values
        ldx     #80
        ldy     #24
        rts

ft245_wherex:
        jsr     wherexy
        txa
        ldx     #0
        rts

ft245_wherey:
        jsr     wherexy
        tya
        ldx     #0
        rts

wherexy:
        lda     where_str
        ldx     where_str + 1
        jsr     esc_tx
        jsr     esc_rx
        bcs     @err
        cmp     #'R'            ; expected terminator
        bne     @err
        cpx     #4              ; expected # params * 2
        ldy     #0
        ldx     param_buf,Y
        iny
        lda     param_buf,Y
        beq     @noclampy
        ldx     #$FF
@noclampy:
        phx
        iny
        ldx     param_buf,Y
        iny
        lda     param_buf,Y
        beq     @noclampx
        ldx     #$FF
@noclampx:
        phx
        jsr     esc_rx_erase
        plx
        ply
        rts
@err:
        ldx     #0              ; fake values
        ldy     #0
        rts

; Receive an escape code
;       sets carry on error
;       returns terminator in A
;       returns param count * 2 in X
esc_rx:
        ldy     rx_rp
        sty     esc_ep
        lda     #$FF            ; start timeout timer
        sta     VIA::T1L + 1
@restart:
        ldy     #PARAM_BYTES - 1
@zloop:
        lda     #0
        tax
        sta     param_buf,Y
        dey
        bpl     @zloop
@next:
        ldy     esc_ep
@retry:
        cpy     rx_wp
        beq     @empty
        inc     esc_ep
        lda     rx_buf,Y
        beq     @next
        cmp     #$1B
        beq     @is_esc
        lda     #SETBIT(FLAGS_CSI_SEEN)
        bit     flags
        bne     @csi_seen
        bpl     @next
        cmp     #$5B
        bne     @err
        smb     FLAGS_CSI_SEEN,flags
        bra     @next
@empty:
        wai
        bit     flags
        bvc     @retry
        sec
        rts
@is_esc:
        lda     flags
        ora     #SETBIT(FLAGS_ESC_SEEN)
        and     #<~(SETBIT(FLAGS_CSI_SEEN))
        sta     flags
        sty     esc_sp
        bra     @next
@err:
        lda     flags
        and     #<~(SETBIT(FLAGS_CSI_SEEN)|SETBIT(FLAGS_ESC_SEEN))
        sta     flags
        bra     @next
@csi_seen:
        cmp     #$30
        bcc     @err            ; no intermediate bytes supported
        cmp     #$3A
        bcc     @is_param       ; digit
        beq     @err            ; no colons supported
        cmp     #$3B
        beq     @is_semi        ; semicolon
        cmp     #$40
        bcc     @err            ; no private prefixes
        lda     $7F
        bcs     @err            ; too high
        inc     esc_ep
        rts                     ; is terminator--all done
@is_semi:
        inx
        inx
        bra     @next
@is_param:                      ; multiply existing param by 10 and append
        pha
        lda     param_buf,X
        asl     A
        sta     tmp1
        inx
        lda     param_buf,X
        rol     A
        sta     tmp2
        dex
        asl     param_buf,X
        rol     A
        asl     param_buf,X
        rol     A
        inx
        sta     param_buf,X
        dex
        lda     param_buf,X
        clc
        adc     tmp1
        sta     param_buf,X
        inx
        lda     param_buf,X
        adc     tmp2
        sta     param_buf,X
        dex
        pla
        and     #$0F
        ora     param_buf,X
        sta     param_buf,X
        jmp     @next

esc_rx_erase:
        lda     #0
        ldy     rx_rp
@next:
        cpy     rx_wp
        beq     @done
        sta     rx_buf,Y
        iny
        bra     @next
@done:
        rts

; just return null
ft245_cpeekc:
        lda     #0
        tax
        rts

; just null terminate the string
ft245_cpeeks:
        lda     #0
        sta     (sreg)
        rts
