; SPDX-License-Identifier: MIT
; lcd.s
; 4-row LCD character display driver
; attached to VIA port B, 4-bit mode
; port B bit 7 belongs to the keyboard--can't change its DDR bit here.

        .include "bv6502.inc"

        .constructor lcd_init
        .destructor lcd_done
        .export lcd_char_wr, lcd_inst_wr, lcd_cr_wr, lcd_lf_wr
        .export lcd_cls, lcd_scroll, lcd_xy_set, lcd_xy_get, lcd_cur_char

LCD_RW          = $10           ; LCD Data R/~W
LCD_RS          = $20           ; LCD Register Select; 0=instruction, 1=data
LCD_E           = $40           ; LCD Data Xfer Enable

LCD_BZ          = $08           ; LCD Busy Flag


; maintain our own console buffer and cursor position because it's tedious to
; read from the display
        .zeropage

lcd_cur:
        .res    1


        .bss
lcd_buf:
        .res    80


        .segment "ONCE"

; Initialize LCD display.
; Not necessarily a cold reset, so we need to do the Initialization by
; Instruction on like page 46 of the datasheet.
; Port B bit 7 belongs to keyboard, so leave it as input.
lcd_init:
; Port B setup
        lda     #%01111111      ; default to output
        trb     VIA::PORTB
        tsb     VIA::DDRB
; coax it into 4-bit mode from whatever state we started in
        lda     #%00000011      ; Function set: 8-bit mode
        sta     VIA::PORTB
        jsr     lcd_wr          ; 1
        ldx     #(5 * MHZ)
        jsr     delay
        jsr     lcd_wr          ; 2
        ldx     #(1 * MHZ)
        jsr     delay
        jsr     lcd_wr          ; 3
        jsr     lcd_bz_poll
        lda     #%00000010
        sta     VIA::PORTB      ; Function set: 4-bit mode
        jsr     lcd_wr
        jsr     lcd_bz_poll
; rest of the init
        lda     #%00101000      ; Fn set: 4-bit mode, 2-line display, 5x8 font.
        jsr     lcd_inst_wr
        lda     #%00001000      ; Display off.
        jsr     lcd_inst_wr
        lda     #%00000001      ; Clear display, set DDRAM address to 0.
        jsr     lcd_inst_wr     
        lda     #%00000110      ; Entry mode: shift cursor, don't shift display.
        jsr     lcd_inst_wr
        lda     #%00001100      ; Display on, cursor off, blink cursor off.
        jsr     lcd_inst_wr
        jmp     lcd_clb         ; clear the local buffer

delay:                          ; rough x * 1000 clock delay
        ldy     200
@loop:
        dey
        bne     @loop
        dex
        bne     delay
        rts


        .code

; De-initialize the LCD display.
lcd_done:
        lda     #%00001000      ; Display off.
        jsr     lcd_inst_wr
        lda     #%01111111
        trb     VIA::DDRB
        tsb     VIA::PORTB
        rts

; Write an instruction to the LCD display.
lcd_inst_wr:
        php
        sei
        tay                     ; lcd_bz_poll doesn't clobber y
        jsr     lcd_bz_poll
        tya                     ; write upper nibble
        lsr     A
        lsr     A
        lsr     A
        lsr     A
        jsr     lcd_wr
        tya                     ; write lower nibble
        and     #$0F
        jsr     lcd_wr
        plp
        rts

; Write a character to the LCD display.
lcd_char_wr:
        php
        sei
        ldx     lcd_cur         ; update in-memory copy
        sta     lcd_buf,X
        inc     lcd_cur         ; (fix line wrap later after writing to LCD)
        tay                     ; lcd_bz_poll doesn't clobber y
        jsr     lcd_bz_poll
        tya                     ; write upper nibble
        lsr     A
        lsr     A
        lsr     A
        lsr     A
        ora     #LCD_RS         ; switch to data register
        jsr     lcd_wr
        tya                     ; write lower nibble
        and     #$0F
        ora     #LCD_RS         ; stay on data register
        jsr     lcd_wr
        stz     VIA::PORTB      ; set back to instruction register
        plp                     ; fall through

; If at beginning of next line, fix the LCD cursor to the right place
lcd_wrap_cur:
        lda     lcd_cur
        cmp     #20
        beq     lcd_cur_sync
        cmp     #40
        beq     lcd_cur_sync
        cmp     #60
        beq     lcd_cur_sync
        cmp     #80
        beq     lcd_scroll
        rts

; compute and set the LCD's cursor position given lcd_cur
; add bit 7 for the command and send the command to set it
lcd_cur_sync:
        lda     lcd_cur
        cmp     #20
        bpl     :+
        clc
        adc     #128
        jmp     lcd_inst_wr
:
        cmp     #40
        bpl     :+
        clc
        adc     #172
        jmp     lcd_inst_wr
:
        cmp     #60
        bpl     :+
        clc
        adc     #108
        jmp     lcd_inst_wr
:
        clc
        adc     #152
        jmp     lcd_inst_wr

; copy lines 1-3 to lines 0-2, erase line 3, put cursor at beginning of line 3
lcd_scroll:
        lda     #%00000001      ; clear display, reset cursor
        jsr     lcd_inst_wr
        stz     lcd_cur
        ldx     #20             ; copy characters 20-79 to 0-59
@loop:
        lda     lcd_buf,X
        phx
        jsr     lcd_char_wr     ; slightly recursive...
        plx
        inx
        cmp     #80
        bcc     @loop
        ldx     #60
        lda     #' '            ; fill the remaining internal buffer with spaces
@loop2:
        sta     lcd_buf,X
        inx
        cmp     #80
        bcc     @loop2
        rts

; store A to PORTB and pulse the enable bit
lcd_wr:
        sta     VIA::PORTB
        ora     #LCD_E
        sta     VIA::PORTB
        and     #<~LCD_E
        sta     VIA::PORTB
        rts

; Poll the LCD's busy flag.
lcd_bz_poll:
        lda     #$0F            ; set port B data nibble to read
        trb     VIA::DDRB
        lda     #LCD_RW         ; set LCD data bus to read
        sta     VIA::PORTB
@retry:
        ora     #LCD_E
        sta     VIA::PORTB
        ldx     VIA::PORTB      ; capture upper nibble
        and     #<~LCD_E
        sta     VIA::PORTB
        ora     #LCD_E          ; ignore lower nibble
        sta     VIA::PORTB
        and     #<~LCD_E
        sta     VIA::PORTB
        txa                     ; now check busy flag
        and     #LCD_BZ
        bne     @retry          ; retry if busy
        stz     VIA::PORTB      ; set LCD data bus back to write
        lda     #$0F            ; set Port B data nibble back to write
        tsb     VIA::DDRB
        rts

; get current cursor coordinates
; x coord = lcd_cur % 20; return it in X
; y coord = lcd_cur / 20; return it in Y
; clobbers A
lcd_xy_get:
        lda     lcd_cur         ; will be remainder
        ldy     #$FF            ; will be quotient
@loop:
        iny                     ; will start at 0
        tax
        sec
        sbc     #20
        bcs     @loop           ; if >=20, keep looping
        rts

; set cursor to X,Y coords stored in X,Y
; caller must do bounds check
lcd_xy_set:
        lda     #0              ; starting value
        clc
        cpy     #0              ; a = 20 * y
        beq     @done
@loop:
        adc     #20
        dey
        bne     @loop
@done:
        stx     lcd_cur         ; lcd_cur = x
        adc     lcd_cur         ; a = lcd_cur + y
        sta     lcd_cur         ; lcd_cur = a
        jmp     lcd_cur_sync

; Handle a carriage return.
; Set cursor to the beginning of the current line.
;     for (a = 20, x = 0; a <= lcd_cur; x = a, a += 20);
;     lcd_cur = x;
lcd_cr_wr:
        lda     #20
        ldx     #0
@loop:
        cmp     lcd_cur
        beq     :+
        bcs     @fix
:
        tax
        adc     #20
        jmp     @loop
@fix:
        stx     lcd_cur
        jmp     lcd_cur_sync

; Handle a line feed.
; Set cursor to same position of next line.
; Scroll if on bottom line already.
lcd_lf_wr:
        lda     lcd_cur
        tax
        clc
        adc     #20
        cmp     #80
        bcc     @fix
        jsr     lcd_scroll
        txa
@fix:
        sta     lcd_cur
        jmp     lcd_cur_sync

; return the character under the cursor in A
lcd_cur_char:
        ldx     lcd_cur
        lda     lcd_buf,X
        ldx     #0
        rts

; clear the screen
lcd_cls:                        ; clear the LCD screen
        lda     #%00000001
        jsr     lcd_inst_wr
lcd_clb:                        ; clear the local buffer
        lda     #' '
        ldx     #79
@loop:
        sta     lcd_buf,X
        dex
        bpl     @loop
        stz     lcd_cur
        rts
