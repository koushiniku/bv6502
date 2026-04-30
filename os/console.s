; SPDX-License-Identifier: MIT
; console.s
; cc65 library console calls

        .include "bv6502.inc"

        .import incsp2, popa, return0
        .import lcd_char_wr, lcd_cr_wr, lcd_lf_wr, lcd_bs_wr
        .import lcd_cls, lcd_scroll, lcd_xy_set, lcd_xy_get, lcd_cur_char
        .import kb_getc, kb_check

        .export _bgcolor, _bordercolor, _cclear, _cclearxy, _cgetc, _chline
        .export _chlinexy, _clrscr, _cpeekc, _cpeekcolor, _cpeekrevers, _cputc
        .export _cputcxy, _cvline, _cvlinexy, _gotox, gotoxy, _gotoxy, _revers
        .export _screensize, _textcolor, _wherex, _wherey


; unsigned char __fastcall__ bgcolor (unsigned char color);
_bgcolor        := return0


; unsigned char __fastcall__ bordercolor (unsigned char color);
_bordercolor    := return0

; void __fastcall__ cclear (unsigned char length);
_cclear:
        ldy     #' '
        jmp     put_rep

; void __fastcall__ cclearxy (unsigned char x, unsigned char y,
; unsigned char length);
_cclearxy:
        ldy     #' '
        jmp     put_repxy

; char cgetc (void);
_cgetc          := kb_getc

; void __fastcall__ chline (unsigned char length);
_chline:
        ldy     #'-'
        jmp     put_rep

; void __fastcall__ chlinexy (unsigned char x, unsigned char y,
; unsigned char length);
_chlinexy:
        ldy     #'-'            ; fall through

; move cursor to coords and repeat character write
; x coord in (c_sp)
; y coord in X
; length in A
; character in Y
put_repxy:
        pha                     ; length  -> stack
        phy                     ; char    -> stack
        phx                     ; y coord -> stack
        jsr     popa            ; x coord -> A
        tax                     ; x coord -> X
        pla                     ; y coord -> A
        jsr     _gotoxy
        ply                     ; char    -> Y
        pla                     ; length  -> A
; fall through
;
; repeat character write
; length in A
; character in Y
put_rep:
        tax                     ; length  -> X
        tya                     ; char    -> A
        cpx     #0
@loop:
        beq     @done
        jsr     lcd_char_wr     ; write character X times
        dex
        jmp     @loop
@done:
        rts

; void clrscr (void);
_clrscr         := lcd_cls

; char cpeekc (void);
_cpeekc         := lcd_cur_char

;unsigned char cpeekcolor (void);
_cpeekcolor     := return0

; unsigned char cpeekrevers (void);
_cpeekrevers    := return0

; void __fastcall__ cputcxy (unsigned char x, unsigned char y, char c);
; character in A
; Y coord in X
; X coord in (c_sp)
_cputcxy:
        pha                     ; char    -> stack
        phx                     ; y coord -> stack
        jsr     popa            ; x coord -> A
        tax                     ; x coord -> X
        pla                     ; y coord -> A
        jsr     _gotoxy
        pla                     ; char    -> A
; fall through

; void __fastcall__ cputc (char c);
; handle \r and \n, otherwise output the character
_cputc:
        cmp     #$0D
        bne     :+
        jmp     lcd_cr_wr
:
        cmp     #$08
        bne     :+
        jmp     lcd_bs_wr
:
        cmp     #$0A
        bne     :+
        jmp     lcd_lf_wr
:
        jmp     lcd_char_wr


; void __fastcall__ cvlinexy (unsigned char x, unsigned char y,
; unsigned char length);
; length is in A
; y coord is in X
; x coord is in (c_sp)
;
; want to count from y coord to y coord + length - 1

_cvlinexy:
        pha                     ; length  -> stack
        phx                     ; y coord -> stack
        jsr     popa            ; x coord -> A
        cmp     #20             ; clamp x
        bcc     @xok
        lda     #19
@xok:
        tax                     ; x coord -> X
        pha                     ; y coord -> A
        cmp     #4              ; clamp y
        bcc     @yok
        lda     #3
@yok:
        ply                     ; y coord -> Y
        pla                     ; length  -> A
vlloop:
        beq     @done
        pha                     ; length  -> stack
        phx                     ; x coord -> stack
        phy                     ; y coord -> stack
        jsr     lcd_xy_set
        lda     #'|'
        jsr     lcd_char_wr
        ply                     ; y coord -> Y
        cpy     #3              ; bottom row?
        bcc     @yok2
        jsr     lcd_scroll
        ldy     #2
@yok2:
        iny
        plx                     ; x coord -> X
        pla                     ; length  -> A
        dec     A
        jmp     vlloop
@done:
        rts


;void __fastcall__ cvline (unsigned char length);
_cvline:
        pha
        jsr     lcd_xy_get
        pla
        jmp     vlloop


;void __fastcall__ gotoxy (unsigned char x, unsigned char y);
; y coord in A
; x coord in X
gotoxy:
        jsr     popa            ; idk
_gotoxy:
        cmp     #4              ; clamp Y
        bcc     @yok
        lda     #3
@yok:
        tay
        txa
        cmp     #20             ; clamp X
        bcc     @xok
        lda     #19
@xok:
        tax
        jmp     lcd_xy_set

; void __fastcall__ gotox (unsigned char x);
_gotox:
        cmp     #20             ; clamp X
        bcc     @xok
        lda     #19
@xok:
        pha
        jsr     lcd_xy_get
        plx
        jmp     lcd_xy_set

; void __fastcall__ gotox (unsigned char y);
_gotoy:
        cmp     #4              ; clamp Y
        bcc     @yok
        lda     #3
@yok:
        pha
        jsr     lcd_xy_get
        ply
        jmp     lcd_xy_set

;unsigned char kbhit (void);
_kbhit          := kb_check


_revers         := return0


;void __fastcall__ screensize (unsigned char* x, unsigned char* y);
; lower address for y coord is in A
; upper address for y coord is in X
; lower address for X coord is in (c_sp)
; upper address for X coord is in (c_sp+1)
_screensize:
        sta     <ptr1
        stx     >ptr1
        lda     #4
        sta     (ptr1)
        lda     #20
        sta     (c_sp)
        jmp     incsp2


_textcolor      := return0


;unsigned char wherex (void);
_wherex:
        jsr     lcd_xy_get
        txa
        ldx     #0
        rts

;unsigned char wherey (void);
_wherey:
        jsr     lcd_xy_get
        tya
        ldx     #0
        rts
