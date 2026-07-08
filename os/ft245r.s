; SPDX-License-Identifier: MIT
;
; ft245r.s
;
; Driver for FT245R USB-to-FIFO or Adafruit FT232H in FIFO mode

        .include "bv6502.inc"

        .import incsp2, popa, return0, cursor

        .export acia_bgcolor, acia_bordercolor, acia_cclear, acia_cclearxy
        .export acia_chline, acia_chlinexy, acia_clrscr, acia_cpeekc
        .export acia_cpeekcolor, acia_cpeekrevers, acia_cputc, acia_cputcxy
        .export acia_cvline, acia_cvlinexy, acia_gotox, acia_gotoxy
        .export acia_revers, acia_screensize, acia_textcolor, acia_wherex
        .export acia_wherey, acia_setcursor, acia_cgetc, acia_kbhit

        .constructor    ft245r_init
        .destructor     ft245r_done
        .interruptor    ft245r_irq
