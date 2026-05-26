; SPDX-License-Identifier: MIT
;
; kbd.s
; PS/2 keyboard driver

        .include "bv6502.inc"

        .export con_cgetc, con_kbhit
        .import _setcursor

        .constructor kbd_init
        .destructor kbd_done
        .interruptor kbd_irq

        .struct KBD
                .org    $C008
                CSR     .byte
                DATA    .byte
        .endstruct


        .rodata
kbd_map:                        ; index bit 7 selects which half
; no modifier
        .byte   $00,    $00,    $00,    $00,    $00,    $00,    $00,    $00
        .byte   $00,    $00,    $00,    $00,    $00,    $09,    '`',    $00
        .byte   $00,    $00,    $00,    $00,    $00,    'q',    '1',    $00
        .byte   $00,    $00,    'z',    's',    'a',    'w',    '2',    $00
        .byte   $00,    'c',    'x',    'd',    'e',    '4',    '3',    $00
        .byte   $00,    ' ',    'v',    'f',    't',    'r',    '5',    $00
        .byte   $00,    'n',    'b',    'h',    'g',    'y',    '6',    $00
        .byte   $00,    $00,    'm',    'j',    'u',    '7',    '8',    $00
        .byte   $00,    ',',    'k',    'i',    'o',    '0',    '9',    $00
        .byte   $00,    '.',    '/',    'l',    ';',    'p',    '-',    $00
        .byte   $00,    $00,    $27,    $00,    '[',    '=',    $00,    $00
        .byte   $00,    $00,    $0D,    ']',    $00,    $5C,    $00,    $00
        .byte   $00,    $00,    $00,    $00,    $00,    $00,    $08,    $00
        .byte   $00,    $00,    $00,    $00,    $00,    $00,    $00,    $00
        .byte   $00,    $00,    $00,    $00,    $00,    $00,    $1B,    $00
        .byte   $00,    '+',    $00,    '-',    '*',    $00,    $00,    $00
; modified by shift, capslock, or numlock
        .byte   $00,    $00,    $00,    $00,    $00,    $00,    $00,    $00
        .byte   $00,    $00,    $00,    $00,    $00,    $09,    '~',    $00
        .byte   $00,    $00,    $00,    $00,    $00,    'Q',    '!',    $00
        .byte   $00,    $00,    'Z',    'S',    'A',    'W',    '@',    $00
        .byte   $00,    'C',    'X',    'D',    'E',    '$',    '#',    $00
        .byte   $00,    ' ',    'V',    'F',    'T',    'R',    '%',    $00
        .byte   $00,    'N',    'B',    'H',    'G',    'Y',    '^',    $00
        .byte   $00,    $00,    'M',    'J',    'U',    '&',    '*',    $00
        .byte   $00,    '<',    'K',    'I',    'O',    ')',    '9',    $00
        .byte   $00,    '>',    '?',    'L',    ':',    'P',    '_',    $00
        .byte   $00,    $00,    '"',    $00,    '{',    '+',    $00,    $00
        .byte   $00,    $00,    $0D,    '}',    $00,    '|',    $00,    $00
        .byte   $00,    $00,    $00,    $00,    $00,    $00,    $08,    $00
        .byte   $00,    '1',    $00,    '4',    '7',    $00,    $00,    $00
        .byte   '0',    '.',    '2',    '5',    '6',    '8',    $1B,    $00
        .byte   $00,    '+',    $00,    '-',    '*',    '9',    $00,    $00


; Each scancode gets a crumb:
;       0:      keys unaffected by shift, capslock, or numlock
;       1:      keys affected only by shift (symbols, number-symbols)
;       2:      keys affected by shift xor capslock (alphabet)
;       3:      keys affected by shift xor numlock (numeric keypad)
kbd_mods:
        .byte   %00000000, %00000000, %00000000, %00010000
        .byte   %00000000, %00011000, %10100000, %00011010
        .byte   %10101000, %00011010, %10100000, %00011010
        .byte   %10101000, %00011010, %10100000, %00010110
        .byte   %10100100, %00010110, %10010100, %00011001
        .byte   %00010000, %00000101, %01000000, %00000100
        .byte   %00000000, %00000000, %11001100, %00000011
        .byte   %11111111, %00001111, %00110000, %00001100


        .zeropage

kbd_scan:       .res    1       ; scancode temporary buffer
kbd_retry:      .res    1       ; previous output for retry
kbd_rp:         .res    1       ; ascii read pointer
kbd_wp:         .res    1       ; ascii write pointer

kbd_fl0:        .res    1       ; keyboard flags
KBD_LED          = 0
KBD_SHIFT_MASK   = %00000110
KBD_LSHIFT       = 1            ; 1: left shift pressed
KBD_RSHIFT       = 2            ; 2: right shift pressed
KBD_CTRL_MASK    = %00011000
KBD_LCTRL        = 3            ; 3: left ctrl pressed
KBD_RCTRL        = 4            ; 4: right ctrl pressed
KBD_SCRLOCK      = 5            ; 5: kbd_scrlock on
KBD_NUMLOCK      = 6            ; 6: kbd_numlock on
KBD_CAPSLOCK     = 7            ; 7: kbd_capslock on

kbd_fl1:         .res    1      ; more keyboard flags
KBD_E0CODE       = 0            ; 6: $E0 was received
KBD_F0CODE       = 1            ; 7: $F0 was received
KBD_ALT_MASK     = %00001100
KBD_LALT         = 2            ; 2: left alt pressed
KBD_RALT         = 3            ; 3: right alt pressed
KBD_PAUSE        = 7            ; 4: $E1 was received


        .bss

; keyboard input buffer
kbd_buf: .res    256


        .code

kbd_init:
        stz     kbd_rp
        stz     kbd_wp
        stz     kbd_fl0
        stz     kbd_fl1
        lda     #$20            ; IRQ enable
        sta     KBD::CSR
        rts

kbd_done:
        stz     KBD::CSR        ; IRQ disable
        rts

kbd_irq:
        lda     KBD::CSR
        sta     KBD::CSR
        bit     #0
        bpl     @notmine
        bvc     @error
        lda     KBD::DATA
        jsr     kbd_parse
        sec
        rts
@notmine:
        clc
        rts
@error:
        lda     $FE             ; ask for retransmit
        sta     kbd_retry
        sta     KBD::DATA
        clc
        rts


; process $F0 $E0 key releases
kbd_bescan:
        case    $14,@rctrl
        case    $11,@ralt
        rts
@rctrl:
        rmb     KBD_RCTRL,kbd_fl0
        rts
@ralt:
        rmb     KBD_RALT,kbd_fl1
        rts

; process post-$F0 ("break") $00-$7F scan codes
; We only care about keys where releasing has an effect
kbd_bscan:
        lda     #BITPOS(KBD_E0CODE)     ; check for $E0 key releases
        trb     kbd_fl1
        bne     kbd_bescan
@scan:
        case    $12,@lshift
        case    $59,@rshift
        case    $14,@lctrl
        case    $77,@numlock
        case    $11,@lalt
@return:
        rts
@lshift:
        rmb     KBD_LSHIFT,kbd_fl0
        rts
@rshift:
        rmb     KBD_RSHIFT,kbd_fl0
        rts
@lctrl:
        bit     kbd_fl1
        bmi     @return
        rmb     KBD_LCTRL,kbd_fl0
        rts
@numlock:
        rmb     KBD_PAUSE,kbd_fl1
        rts
@lalt:
        rmb     KBD_LALT,kbd_fl1
        rts

; process $E0 $00-$7F scan codes
kbd_escan:
        case    $71,@del
        case    $14,@rctrl
        case    $5A,@kpenter
        case    $4A,@kpslash
        case    $11,@ralt
        rts
@del:
        lda     #$08            ; del key: send backspace
        jmp     kbd_buf_push
@rctrl:
        smb     KBD_RCTRL,kbd_fl0 ; right ctrl
        rts
@kpenter:
        lda     #$0D            ; keypad "enter": send cr
        jmp     kbd_buf_push
@kpslash:
        lda     #'/'            ; keypad slash
        jmp     kbd_buf_push
@ralt:
        smb     KBD_RALT,kbd_fl1; right alt
        rts

; parse an incoming keyboard scan code
; scan code is in A
kbd_parse:
        sta     kbd_scan
        cmp     #0
        beq     @noh
        jmp     kbd_hscan       ; bit 7 is set: parse high jump table
@noh:
        lda     #BITPOS(KBD_F0CODE) ; was $F0 the previous code?
        trb     kbd_fl1
        bne     kbd_bscan
        lda     #KBD_ALT_MASK   ; is alt being pressed?
        bit     kbd_fl1
        bne     @return         ; ignoring alt-anything for now
        lda     #BITPOS(KBD_E0CODE) ; was $E0 the previous code?
        trb     kbd_fl1
        bne     kbd_escan       ; parse the e0 keys
        lda     #KBD_CTRL_MASK
        bit     kbd_fl0
        beq     @nocaret
        jmp     kbd_caret       ; parse control codes
@nocaret:
        lda     kbd_scan        ; check kbd_mods effects of shift, caps, num
        lsr     A               ; divide by 4: find byte index into kbd_mods
        lsr     A
        tax
        lda     #$03
        and     kbd_scan        ; index of the crumb in the byte from kbd_mods
        pha
        lda     kbd_mods,X      ; get the byte from kbd_mods
        ply
@modloop:
        beq     @moddone        ; shift by Y crumbs
        lsr     A
        lsr     A
        dey
        bra     @modloop
@moddone:                       ; A[1:0] is the kbd_mod code we want
        ldx     #$00            ; default to lowercase table
        and     #$03            ; lose the upper bits and check the low crumb
        beq     @lwr            ; crumb is 0
        tay
        lda     #KBD_SHIFT_MASK
        bit     kbd_fl0         ; Z=!shift, V=numlock, N=capslock
        php                     ; save flags
        dey
        bne     @xor
        plp                     ; crumb is 1
        beq     @lwr            ; shift=0
        bra     @upr            ; shift=1
@xor:
        dey
        bne     @sxn
        plp                     ; crumb is 2
        beq     @sxc_s0
        bmi     @lwr            ; shift=1, capslock=1
        bra     @upr            ; shift=1, capslock=0
@sxc_s0:
        bmi     @upr            ; shift=0, capslock=1
        bra     @lwr            ; shift=0, capslock=0
@sxn:
        plp                     ; crumb is 3
        beq     @sxn_s0
        bvs     @lwr            ; shift=1, numlock=1
        bra     @upr            ; shift=1, numlock=0
@sxn_s0:
        bvs     @upr            ; shift=0, numlock=1
        bra     @lwr            ; shift=0, numlock=0
@upr:                           ; uppercase table
        ldx     #$80
@lwr:                           ; lowercase table
        txa
        ora     kbd_scan
        tax                     ; index into kbd_map
        lda     kbd_map,X
        beq     kbd_lscan       ; check if ASCII code comes back as zero
        bra     kbd_buf_push    ; valid ASCII
@return:
        rts

; scan codes < $80 that did not match ASCII
kbd_lscan:
        lda     kbd_scan
        case    $12, @lshift
        case    $59, @rshift
        case    $58, @capslock
        case    $14, @lctrl
        case    $77, @numlock
        case    $11, @lalt
        case    $7E, @scrlock
        rts
@lshift:
        smb     KBD_LSHIFT,kbd_fl0
        rts
@rshift:
        smb     KBD_RSHIFT,kbd_fl0
        rts
@capslock:
        lda     #BITPOS(KBD_CAPSLOCK) | BITPOS(KBD_LED)
@set_leds:
        eor     kbd_fl0
        sta     kbd_fl0
        lda     #$ED
        sta     kbd_retry
        sta     KBD::DATA
        rts
@lctrl:
        bit     kbd_fl1
        bmi     @return
        smb     KBD_LCTRL,kbd_fl0
@return:
        rts
@numlock:
        bit     kbd_fl1
        bmi     @return
        lda     #BITPOS(KBD_NUMLOCK) | BITPOS(KBD_LED)
        bra     @set_leds
@lalt:
        smb     KBD_LALT,kbd_fl1
        rts
@scrlock:
        lda     #BITPOS(KBD_SCRLOCK) | BITPOS(KBD_LED)
        bra     @set_leds

; push the ascii in A into the buffer
kbd_buf_push:
        ldy     kbd_wp
        iny
        cpy     kbd_rp
        beq     @full
        dey
        sta     kbd_buf,Y
        inc     kbd_wp
@full:
        rts

; process control key caret codes
kbd_caret:                       ; process CTRL key
        lda     kbd_scan
        ora     #$80            ; use uppercase table
        tax
        lda     kbd_buf,X
        cmp     #'?'            ; check for "DEL"
        beq     @del
        sec                     ; check for $40..$5F ('@'..'_')
        sbc     #$40            ; $40..$5F -> $00..$1F
        cmp     #$20
        bcc     kbd_buf_push    ; push caret code
        rts                     ; ignore other CTRL keys
@del:                           ; Handle ^?
        lda     #$7F            ; push "DEL"
        bra     kbd_buf_push

; char cgetc (void);
; return a character or wait
; if cursor is set to 1, blink while waiting
con_cgetc:
        ldx     kbd_rp
        cpx     kbd_wp
        beq     @empty
        lda     kbd_buf,X
        inc     kbd_rp
        ldy     #0
        rts
@empty:
        lda     #1
        jsr     _setcursor
        wai
        lda     #0
        jsr     _setcursor
        bra     con_cgetc

; unsigned char kbhit (void);
con_kbhit:
        ldy     #0
        lda     kbd_rp
        cmp     kbd_wp
        beq     @empty
        lda     #1
        rts
@empty:
        lda     #0
        rts

; scan code is >= $80
; scan code is stored in A
kbd_hscan:
        case    $F0, @f0        ; key release prefix
        case    $E0, @e0        ; special code prefix
        case    $FA, @ack       ; command completion/data request
        case    $FE, @repreq    ; repeat request
        case    $E1, @pause     ; pause key
        case    $FC, @err       ; error/reset failed
        rts                     ; not found
@f0:
        smb     KBD_F0CODE,kbd_fl1
        rts
@e0:
        smb     KBD_E0CODE,kbd_fl1
        rts
@ack:
        lda     #BITPOS(KBD_LED) ; acking an LED command?
        trb     kbd_fl1
        beq     @return
        lda     kbd_fl0         ; update keyboard LEDs
        lsr     A               ; bits are on the left
        lsr     A
        lsr     A
        lsr     A
        lsr     A
        sta     kbd_retry
        sta     KBD::DATA
@return:
        rts
@repreq:
        lda     kbd_retry
        sta     KBD::DATA
        rts
@pause:
        smb     KBD_PAUSE,kbd_fl1
        rts
@err:
        lda     #$FF            ; idk, reset again?
        sta     KBD::DATA
        rts
