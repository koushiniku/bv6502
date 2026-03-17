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
lcd_init:
; Port B setup
        lda     VIA::DDRB       ; default to output
        ora     #%01111111
        sta     VIA::DDRB
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
        dec     VIA::PORTB      ; Function set: 4-bit mode
        jsr     lcd_wr
; rest of the init
        lda     #%00101000      ; Fn set: 4-bit mode, 2-line display, 5x8 font.
        jsr     lcd_inst_wr
        lda     #%00001000      ; Display off.
        jsr     lcd_inst_wr
        lda     #%00000110      ; Entry mode: shift cursor, don't shift display.
        jsr     lcd_inst_wr
        lda     #%00001100      ; Display on, cursor off, blink cursor off.
        jsr     lcd_inst_wr
        jmp     lcd_cls

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
        lda     VIA::DDRB       ; Set Port B back to input.
        and     #%10000000
        sta     VIA::DDRB
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
        inc     lcd_cur         ; fix line wrap after writing to LCD
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
        plp
        rts


; If at beginning of next line, fix the LCD cursor to the right place
lcd_wrap_cur:
        lda     lcd_cur
        cmp     #20
        beq     @fixit
        cmp     #40
        beq     @fixit
        cmp     #60
        beq     @fixit
        cmp     #80
        beq     @scroll
        rts
@fixit:
        jsr     lcd_cur_sync
        rts
@scroll:
        jsr     lcd_scroll
        rts


; compute the LCD cursor position given lcd_cur
; add bit 7 for the command and send the command to set it
lcd_cur_sync:
        lda     lcd_cur
        clc
        cmp     #20
        bpl     :+
        adc     #128
        rts
:
        cmp     #40
        bpl     :+
        adc     #172
        rts
:
        cmp     #60
        bpl     :+
        sbc     #108
        rts
:
        clc
        adc     #152
        jsr     lcd_inst_wr
        rts


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
        bne     @loop
        ldx     #60
        lda     #' '            ; fill the remaining internal buffer with spaces
@loop2:
        sta     lcd_buf,X
        inx
        cmp     #80
        bne     @loop2
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
        lda     VIA::DDRB       ; set port B data nibble to read
        and     #%11110000
        sta     VIA::DDRB
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
        lda     VIA::DDRB       ; set Port B data nibble back to write
        ora     #%00001111
        sta     VIA::DDRB
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
        lda     #0
        clc
        cpy     #0
@loop:
        beq     @done
        adc     #20
        dey
        jmp     @loop
@done:
        stx     lcd_cur
        adc     lcd_cur
        sta     lcd_cur
        jmp     lcd_cur_sync


; Handle a carriage return
; Set cursor to the beginning of the current line
lcd_cr_wr:
        lda     lcd_cur
        cmp     #20
        bpl     :+
        lda     #0
        jsr     @fixit
:
        cmp     #40
        bpl     :+
        lda     #20
        jsr     @fixit
:
        cmp     #60
        bpl     :+
        lda     #40
        jsr     @fixit
:
        lda     #60
@fixit:
        sta     lcd_cur
        jmp     lcd_cur_sync


; Handle a line feed
; Set cursor to same position of next line
lcd_lf_wr:
        lda     lcd_cur         ; set internal cursor first
        clc
        adc     #20
        tax                     ; will be new lcd_cur if not >= 80
        sec
        sbc     #80             ; scroll if we need to
        bmi     @noscroll
        pha                     ; a goes on the stack...
        jsr     lcd_scroll
        plx                     ; ...x comes off the stack
@noscroll:
        stx     lcd_cur
        rts


; return the character under the cursor in A
lcd_cur_char:
        ldx     lcd_cur
        lda     lcd_buf,X
        ldx     #0
        rts

; clear the screen
lcd_cls:
        lda     #' '            ; initialize the internal buffer with spaces.
        ldx     #0
@loop:
        sta     lcd_buf,X
        inx
        cmp     #80
        bcc     @loop
        lda     #%00000001
        jmp     lcd_inst_wr
