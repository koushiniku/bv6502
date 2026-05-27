; SPDX-License-Identifier: MIT
;
; lcd.s
; 20x4 character LCD driver.

        .include "bv6502.inc"

        .import incsp2, popa, return0, cursor

        .export con_bgcolor, con_bordercolor, con_cclear, con_cclearxy
        .export con_chline, con_chlinexy, con_clrscr, con_cpeekc
        .export con_cpeekcolor, con_cpeekrevers, con_cputc, con_cputcxy
        .export con_cvline, con_cvlinexy, con_gotox, con_gotoxy
        .export con_revers, con_screensize, con_textcolor, con_wherex
        .export con_wherey, con_setcursor

        .constructor lcd_init
        .destructor lcd_done

        .struct LCD
                .org    $C00A
                INST    .byte
                CHAR    .byte
        .endstruct

        .zeropage

; cursor position in local buffer
lcd_cur:
        .res    1


        .bss

; local copy of character buffer
lcd_buf:
        .res    80


        .code

; void __fastcall__ cclear (unsigned char length);
con_cclear:
        ldy     #' '
        bra     lcd_rep

; void __fastcall__ cclearxy (unsigned char x, unsigned char y,
; unsigned char length);
con_cclearxy:
        ldy     #' '
        bra     lcd_repxy

; void __fastcall__ chline (unsigned char length);
con_chline:
        ldy     #'-'
        bra     lcd_rep

; void __fastcall__ chlinexy (unsigned char x, unsigned char y,
; unsigned char length);
con_chlinexy:
        ldy     #'-'
; fall through
; move cursor to coords and repeat character write
;       length    -> A
;       ycoord:   -> X
;       xcoord:   -> (c_sp)
;       character:-> Y
lcd_repxy:                      ; want: xcoord -> X; ycoord -> A
        phy                     ; character -> stack
        pha                     ; length -> stack
        phx                     ; ycoord -> stack
        jsr     popa            ; xcoord -> A
        tax                     ; xcoord -> X
        pla                     ; ycoord -> A
        jsr     con_gotoxy
        ply
        pla

; repeat character write
;       length  -> A
;       character -> Y
lcd_rep:
        cmp     #0
        beq     @done
        sta     tmp1            ; length -> zp
        sty     tmp2            ; character -> zp
@loop:
        ldx     #0
        jsr     lcd_char_wr
        lda     tmp1
        dec     tmp2
        bne     @loop
@done:
        rts

; Send a character to the LCD and fix line wrap.
; If X != 0, scroll up when writing to bottom right.
; Otherwise, cursor wraps to top left.
lcd_char_wr:
        ldy     lcd_cur         ; store locally
        sta     lcd_buf,Y
        iny
        sty     lcd_cur
@busy:
        bit     LCD::CHAR
        bmi     @busy
        sta     LCD::CHAR
        cpy     #20
        beq     @r1
        cpy     #40
        beq     @r2
        cpy     #60
        beq     @r3
        cpy     #80
        beq     @end
        rts
@r1:
        lda     #$80 | 64
        bra     lcd_inst_wr
@r2:
        lda     #$80 | 20
        bra     lcd_inst_wr
@r3:    
        lda     #$80 | 84
        bra     lcd_inst_wr
@end:
        txa
        beq     lcd_scroll
        stz     lcd_cur
        lda     #$80
        bra     lcd_inst_wr

; void __fastcall__ cputcxy (unsigned char x, unsigned char y, char c);
;       char   -> A
;       ycoord -> X
;       xcoord -> (c_sp)
con_cputcxy:                    ; want: xcoord -> X; ycoord -> A
        pha                     ; char -> stack
        phx                     ; xcoord -> stack
        jsr     popa            ; xcoord -> A
        tay                     ; xcoord -> Y
        pla                     ; ycoord -> A
        jsr     con_gotoxy
        pla                     ; char -> A
; fall through
; void __fastcall__ cputc (char c);
; handle \r, \n, \t, bs, otherwise output the character
con_cputc:
        cmp     #$0D
        beq     lcd_cr_wr
        cmp     #$0A
        beq     lcd_lf_wr
        cmp     #$08
        beq     lcd_bs_wr
        cmp     #$09
        beq     lcd_tab_wr
        ldx     #1
        bra     lcd_char_wr

; Handle a carriage return ("\r").
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
        bra     @loop
@fix:
        stx     lcd_cur
        jmp     lcd_cur_sync

; handle a backspace ("\b").
; Except on column 0, move left, print space, move left
lcd_bs_wr:
        lda     lcd_cur
        cmp     #0
        beq     @done
        cmp     #20
        beq     @done
        cmp     #40
        beq     @done
        cmp     #60
        beq     @done
        dec     lcd_cur
        jsr     lcd_cur_sync
        lda     #' '
        ldx     #0
        jsr     lcd_char_wr
        dec     lcd_cur
        jmp     lcd_cur_sync
@done:
        rts

; Send and instruction
lcd_inst_wr:
        bit     LCD::INST
        bmi     lcd_inst_wr
        sta     LCD::INST
        rts

; We went off the bottom
lcd_scroll:
        lda     $01             ; clear screen
        sta     lcd_inst_wr
        stz     lcd_cur
        ldy     #20             ; copy characters 20-79 to 0-59
@loop:
        ldx     #0
        lda     lcd_buf,Y
        jsr     lcd_char_wr     ; recursive...careful...
        cpy     #60
        bcc     @next
        lda     #' '            ; fill buffer bottom row with spaces
        sta     lcd_buf,Y
@next:
        iny
        cpy     #80
        bcc     @loop
        lda     #60             ; set cursor to beginning of last line
        sta     lcd_cur
        lda     #$80 | 84
        bra     lcd_inst_wr


; Handle a line feed ("\n").
; Set cursor to the beginning of the next line.
; Scroll if on bottom line already.
lcd_lf_wr:
        lda     lcd_cur
        cmp     #60
        bcc     @cursordown
        bra     lcd_scroll
@cursordown:
        clc
        adc     #20
        sta     lcd_cur
        rts

; handle a tab character ("\t").
; Print spaces until column (not lcd_cur) is divisible by 8
lcd_tab_wr:
        lda     lcd_cur
@loop:
        sec
        sbc     #20
        bcs     @loop
        clc
        adc     #20
        tay
@loop2:
        phy
        ldx     #1
        lda     #' '
        jsr     lcd_char_wr
        ply
        iny
        cpy     #8
        jsr     @done
        cpy     #16
        jsr     @done
        cpy     #20
        jsr     @done
        bra     @loop2
@done:
        rts

; Initialize the LCD
lcd_init:
        jsr     lcd_inst_wr
        lda     #$38            ; Fn set: 8-bit mode, 2-line display, 5x8 font.
        jsr     lcd_inst_wr
        lda     #$08            ; Display off.
        jsr     lcd_inst_wr
        lda     #$01            ; Clear display, set DDRAM address to 0.
        jsr     lcd_inst_wr
        lda     #$06            ; Entry mode: shift cursor, don't shift display.
        jsr     lcd_inst_wr
        lda     #$0C            ; Display on, cursor off, blink cursor off.
        jsr     lcd_inst_wr
        stz     lcd_cur         ; init the local cursor tracker
        rts

;void __fastcall__ gotoxy (unsigned char x, unsigned char y);
; y coord in A
; x coord in X
con_gotoxy:
        tay
        cpy     #4              ; clamp Y
        bcc     @yok
        ldy     #3
@yok:
        cpx     #20             ; clamp X
        bcc     lcd_xy_set
        ldx     #19
;fall through
lcd_xy_set:                     ; set cursor to X, Y coords stored in X and Y
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
        adc     lcd_cur         ; a = lcd_cur + a
        sta     lcd_cur         ; lcd_cur = a
; fall through
; compute and set the LCD's cursor position in lcd_cur
; add bit 7 for the command and send the command to set it
lcd_cur_sync:
        lda     lcd_cur
        cmp     #20
        bcc     @r0
        cmp     #40
        bcc     @r1
        cmp     #60
        bcc     @r2
        clc
        adc     #152
        jmp     lcd_inst_wr
@r0:
        clc
        adc     #128
        jmp     lcd_inst_wr
@r1:
        clc
        adc     #172
        jmp     lcd_inst_wr
@r2:
        clc
        adc     #108
        jmp     lcd_inst_wr

; void __fastcall__ gotoy (unsigned char y);
con_gotoy:
        cmp     #4              ; clamp Y
        bcc     @yok
        lda     #3
@yok:
        pha
        jsr     lcd_xy_get
        ply
        bra     lcd_xy_set

; void clrscr (void);
con_clrscr:
        lda     #$01
        jsr     lcd_inst_wr
        lda     #' '
        ldy     #79
@loop:
        sta     lcd_buf,X
        dey
        bpl     @loop
        stz     lcd_cur
        rts

con_setcursor:
        ldx     cursor
        beq     @done
        ror
        bcs     @set
        lda     #$0C
        jmp     lcd_inst_wr
@set:
        lda     $0F
        jmp     lcd_inst_wr
@done:
        rts

; void __fastcall__ cvlinexy (unsigned char x, unsigned char y,
; unsigned char length);
;       length -> A
;       ycoord -> X
;       xcoord -> (c_sp)
con_cvlinexy:
        cmp     #0
        beq     lcd_done
        sta     tmp1            ; length -> zp
        jsr     popa            ; xcoord -> A
        cmp     #20             ; clamp xcoord < 20
        bcc     @xok
        lda     #19
@xok:
        cpx     #4              ; clamp ycoord < 4
        bcc     @yok
        ldx     #3
@yok:
        sty     tmp2            ; xcoord -> zp
        txa                     ; ycoord -> A
        tay                     ; ycoord -> Y
lcd_cvloop:
        ldx     tmp2            ; xcoord -> X
        phy                     ; ycoord -> stack
        jsr     lcd_xy_set
        ldx     #0
        lda     #'|'
        jsr     lcd_inst_wr
        ply                     ; ycoord -> Y
        cpy     #3
        beq     lcd_done        ; already at bottom?
        iny
        dec     tmp1
        beq     lcd_done        ; length
        bra     lcd_cvloop
lcd_done:
        rts

;void __fastcall__ cvline (unsigned char length);
con_cvline:
        cmp     #0
        beq     lcd_done
        sta     tmp1            ; length -> zp
        jsr     lcd_xy_get
        stx     tmp2            ; xcoord -> zp
        bra     lcd_cvloop


; void __fastcall__ gotox (unsigned char x);
con_gotox:
        cmp     #20             ; clamp X
        bcc     @xok
        lda     #19
@xok:
        pha
        jsr     lcd_xy_get
        plx
        jmp     lcd_xy_set

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

; char cpeekc (void);
con_cpeekc:
        ldy     lcd_cur
        lda     lcd_buf,X
        ldx     #0
        rts

;unsigned char wherex (void);
con_wherex:
        jsr     lcd_xy_get
        txa
        ldx     #0
        rts

;unsigned char wherey (void);
con_wherey:
        jsr     lcd_xy_get
        tya
        ldx     #0
        rts

; unsigned char cpeekcolor (void);
con_cpeekcolor     := return0

; unsigned char cpeekrevers (void);
con_cpeekrevers    := return0

; unsigned char __fastcall__ revers (unsigned char onoff); 
con_revers         := return0

;void __fastcall__ screensize (unsigned char* x, unsigned char* y);
; lower address for y coord is in A
; upper address for y coord is in X
; lower address for X coord is in (c_sp)
; upper address for X coord is in (c_sp+1)
con_screensize:
        sta     <ptr1
        stx     >ptr1
        lda     #4
        sta     (ptr1)
        lda     #20
        sta     (c_sp)
        jmp     incsp2

; unsigned char __fastcall__ textcolor (unsigned char color);
con_textcolor   := return0
       
; unsigned char __fastcall__ bgcolor (unsigned char color);
con_bgcolor     := return0

; unsigned char __fastcall__ bordercolor (unsigned char color);
con_bordercolor := return0

