; SPDX-License-Identifier: MIT
; kbd.s
; PS/2 keyboard driver
; attached to VIA port A

        .include "bv6502.inc"

        .constructor kbd_init
        .destructor kbd_done
        .interruptor kbd_isr
        .export kb_getc, kb_check
        .import cursor, lcd_inst_wr


        .rodata

kb_map:                         ; index bit 7 selects which half
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
kb_mods:
        .byte   %00000000, %00000000, %00000000, %00010000
        .byte   %00000000, %00011000, %10100000, %00011010
        .byte   %10101000, %00011010, %10100000, %00011010
        .byte   %10101000, %00011010, %10100000, %00010110
        .byte   %10100100, %00010110, %10010100, %00011001
        .byte   %00010000, %00000101, %01000000, %00000100
        .byte   %00000000, %00000000, %11001100, %00000011
        .byte   %11111111, %00001111, %00110000, %00001100


        .zeropage

kb_cur          = tmp1
kb_rp:          .res    1       ; keyboard read pointer
kb_wp:          .res    1       ; keyboard write pointer
kb_fl0:         .res    1       ; keyboard flags
                                ; 0: left shift pressed
                                ; 1: right shift pressed
                                ; 2: left ctrl pressed
                                ; 3: right ctrl pressed
                                ; 4: rsvd
                                ; 5: kb_scrlock on
                                ; 6: kb_numlock on
                                ; 7: kb_capslock on
KB_SHIFTBITS    = %00000011
KB_CTRLBITS     = %00001100
kb_fl1:         .res    1       ; more keyboard flags
                                ; 0: left alt pressed
                                ; 1: right alt pressed
                                ; 2: first $E1 of "pause" seen
                                ; 3: second $E1 of "pause" seen
                                ; 4: sent command to set LEDs
                                ; 5: rsvd
                                ; 6: $E0 was received
                                ; 7: $F0 was received
KB_ALTBITS      = %00000011
KB_PAUSEBITS    = %00001100
KB_PAUSE1       = %00000100     ; pause key make
KB_LED          = %00010000     ; LED command was sent
KB_E0CODE       = %01000000     ; E0 code in progress
KB_F0CODE       = %10000000     ; F0 code in progress


        .bss

; keyboard input buffer
kb_buf:
        .res    256

kb_prevcmd:
        .res    1


        .segment "ONCE"

; initialize VIA for the keyboard
; except for bit 7, port B is owned by LCD, so don't mess with it
; port B bit 7 stays input to avoid clobbering the data signal until we need it
kbd_init:
        stz     VIA::DDRA       ; all input
        lda     #%10000000
        trb     VIA::DDRB       ; port B-7 defaults to input
        lda     VIA::PCR
        and     #$F0            ; clear the "CA" nibble
        ora     #%00001101      ; set CA1 rising edge interrupt, CA2 low output
        sta     VIA::PCR
        lda     #%10000010
        sta     VIA::IFR        ; clear the CA1 interrupt
        sta     VIA::IER        ; enable the CA1 interrupt
        rts


        .code

; restore VIA to defaults
kbd_done:
        lda     #%00000010      ; disable the interrupt
        sta     VIA::IER
        lda     #$0F            ; clear CA nibble of PCR
        trb     VIA::PCR
        lda     #%10000000      ; restore B.7 to input default
        trb     VIA::DDRB
        stz     VIA::DDRA       ; restore A to input default
        rts

;handle keyboard input
kbd_isr:
        lda     VIA::IFR
        and     #%00000010
        bne     @mine           ; CA1 interrupt
        clc                     ; not my interrupt
        rts
@mine:
        lda     VIA::PORTA      ; clears interrupt, gets scancode
        jsr     kbd_parse
        sec                     ; handled my interrupt
        rts

; push the ascii in A into the buffer
kb_buf_push:
        ldx     kb_wp
        inx
        cmp     kb_wp
        beq     @full
        dex
        sta     kb_buf,X
        inc     kb_wp
@full:
        rts

; parse a scancode in A
; if it's a character, put it in the buffer
kbd_parse:
        sta     kb_cur          ; zeropage backup copy
        bpl     @noh
        jmp     kb_hscan        ; bit 7 is set: parse high jump table
@noh:
        lda     #KB_F0CODE      ; was $F0 the previous code?
        trb     kb_fl1
        beq     @make
        lda     kb_cur
        jsr     kb_bscan        ; parse "break" codes
        rmb6    kb_fl1          ; in case EO_CODE was set
        rts
@make:                          ; keypress, not release
        lda     #KB_ALTBITS     ; is alt being pressed?
        bit     kb_fl1
        beq     @noalt
        rts                     ; ignoring alt-anything for now
@noalt:
        lda     #KB_E0CODE      ; was $E0 the previous code?
        trb     kb_fl1
        beq     @noe
        jmp     kb_escan        ; parse the e0 jump table
@noe:
        lda     #KB_CTRLBITS
        bit     kb_fl0
        beq     @noctrl
        lda     kb_cur
        ora     #%10000000      ; use uppercase table
        tax
        lda     kb_buf,X
        cmp     #'?'            ; check for "DEL"
        bne     @nodel
        lda     #$7F            ; push "DEL"
        jmp     kb_buf_push
@nodel:                         ; check for $40..$5F ('@'..'_')
        sec
        sbc     #$40            ; $40..$5F -> $00..$1F
        cmp     #$20
        bcc     kb_buf_push     ; push caret code
        rts
@noctrl:                        ; check kb_mods effects of shift, caps, num
        lda     kb_cur          ; divide by 4: find byte index into kb_mods
        lsr     A
        lsr     A
        tax
        lda     #%00000011
        and     kb_cur          ; index of the crumb in the byte from kb_mods
        pha
        lda     kb_mods,X       ; get the byte from kb_mods
        ply
@modloop:
        beq     @moddone        ; shift by Y crumbs
        lsr     A
        lsr     A
        dey
        jmp     @modloop
@moddone:                       ; A[1:0] is the kb_mod code we want
        ldx     #0              ; default to lowercase table
        and     #%00000011      ; lose the upper bits and check the low crumb
        beq     @lwr            ; crumb is 0
        tay
        lda     #KB_SHIFTBITS
        bit     kb_fl0          ; Z=!shift, V=numlock, N=capslock
        php                     ; save flags
        dey
        bne     @xor
        plp                     ; crumb is 1
        beq     @lwr            ; shift=0
        jmp     @upr            ; shift=1
@xor:
        dey
        bne     @sxn
        plp                     ; crumb is 2
        beq     @sxc_s0
        bmi     @lwr            ; shift=1, capslock=1
        jmp     @upr            ; shift=1, capslock=0
@sxc_s0:
        bmi     @upr            ; shift=0, capslock=1
        jmp     @lwr            ; shift=0, capslock=0
@sxn:
        plp                     ; crumb is 3
        beq     @sxn_s0
        bvs     @lwr            ; shift=1, numlock=1
        jmp     @upr            ; shift=1, numlock=0
@sxn_s0:
        bvs     @upr            ; shift=0, numlock=1
        jmp     @lwr            ; shift=0, numlock=0
@upr:                           ; uppercase table
        ldx     #%10000000
@lwr:                           ; lowercase table
        txa
        ora     kb_cur
        tax                     ; index into kb_map
        lda     kb_map,X
        beq     kb_mscan        ; ascii table returned $00
        jmp     kb_buf_push

; process non-character $00-$7F scan codes
kb_mscan:
        cmp     #$12
        bne     :+
        smb0    kb_fl0          ; left shift
        rts
:
        cmp     #$59
        bne     :+
        smb1    kb_fl0          ; right shift
        rts
:
        cmp     #$58
        bne     :+
        smb7    kb_fl0          ; caps lock
        smb4    kb_fl1          ; tracking LED command
        lda     $ED
        jmp     kb_send
:
        cmp     #$14            ; left control
        bne     :+
        lda     #KB_PAUSEBITS   ; is it a fake?
        bit     kb_fl1
        beq     @lctrl
        rts
@lctrl:
        smb2    kb_fl0          ; left control
        rts
:
        cmp     #$77            ; numlock
        bne     :+
        lda     #KB_PAUSEBITS   ; is it a fake?
        bit     kb_fl1
        beq     @nmlck
        rts
@nmlck:
        smb6    kb_fl0          ; numlock
        smb4    kb_fl1          ; tracking LED command
        lda     #$ED
        jmp     kb_send
:
        cmp     #$11
        bne     :+
        smb0    kb_fl1          ; left alt
        rts
:
        cmp     #$7E
        bne     :+
        smb5    kb_fl0          ; scroll lock
        smb4    kb_fl1          ; tracking LED command
        lda     #$ED
        jmp     kb_send
:
        rts

kb_hscan:                       ; process $80-$FF scan codes
        cmp     #$FA
        bne     :+
        lda     #KB_LED         ; command completion--was it LED?
        trb     kb_fl1
        beq     @nl
        lda     kb_fl0          ; update keyboard LEDs
        rol     A               ; but they are at the wrong offset
        rol     A               ; because BIT needs numlock and capslock
        rol     A               ; in bits 6-7 (6-7!)
        rol     A               ; this is one instruction less
        and     #%00000111      ; than shifting them right
        jmp     kb_send
@nl:                            ; not an LED command = no data packet
        rts                     ; nothing else to do
:                               ; not a command completion
        cmp     #$F0
        bne     :+
        smb7    kb_fl1          ; key release
        rts
:
        cmp     #$E0
        bne     :+
        smb6    kb_fl1          ; alternate scancodes
        rts
:
        cmp     #$FE
        bne     :+
        lda     kb_prevcmd      ; resend request
        jmp     kb_send
:
        cmp     #$E1
        bne     :+
        lda     #KB_PAUSE1
        trb     kb_fl1
        beq     @p2
        smb2    kb_fl1          ; first $E1
        rts
@p2:
        smb3    kb_fl1          ; second $E1
        rts
:
        cmp     #$AA
        bne     :+
        stz     kb_rp           ; reset successfully
        stz     kb_wp
        stz     kb_fl0
        stz     kb_fl1
        rts
:
        cmp     #$FC
        bne     :+
        lda     #$FF
        jmp     kb_send         ; idk, reset again?
:
        rts

; process post-$F0 ("break") $00-$7F scan codes
; We only care about keys where releasing has an effect
kb_bscan:

        cmp     #$12
        bne     :+
        rmb0    kb_fl0          ; left shift
        rts
:
        cmp     #$59
        bne     :+
        rmb1    kb_fl0          ; right shift
        rts
:
        cmp     #$14
        bne     :+
        lda     #KB_PAUSEBITS   ; is it a fake?
        bit     kb_fl1
        beq     @ctrl
        rts
@ctrl:
        bbs6    kb_fl1,@cr      ; which one?
        rmb2    kb_fl0          ; left control
        rts
@cr:
        rmb3    kb_fl0          ; right control
        rts
:
        cmp     #$11
        bne     :+
        bbs6    kb_fl1,@ar      ; which one?
        rmb0    kb_fl1          ; left alt
        rts
@ar:
        rmb1    kb_fl1          ; right alt
:
        rts

; process $E0 $00-$7F scan codes
kb_escan:
        cmp     #$71
        bne     :+
        lda     #$08            ; del key: send backspace
        jmp     kb_buf_push
:
        cmp     #$14
        bne     :+
        smb3    kb_fl0          ; right ctrl
        rts
:
        cmp     #$5A
        bne     :+
        lda     #$0D            ; keypad "enter": send cr
        jmp     kb_buf_push
:
        cmp     #$4A
        bne     :+
        lda     #'/'            ; keypad slash
        jmp     kb_buf_push
:
        cmp     #$11
        bne     :+
        smb1    kb_fl1          ; right alt
:
        rts

; Bit-bang a host-to-keyboard command or data byte stored in A.
; Setting CA2 high enables H2D mode.
;       - PA0-6 are floating inputs.
;       - PA7 becomes clock input.
;       - PB7 becomes data output.
;       - other PB pins are outputs so we can't change them.
;       - CA1 will go high, so we need to disable IRQ.
;         and clear the flag before going back to D2H.
; LCD code disables interrupts, so we may clear PB1-7 as long as we don't set.
kb_send:
        php                     ; critical section for real-time clock polling
        sei
        sta     kb_prevcmd      ; save for retransmits
        sta     kb_cur          ; save for below
        lda     #%00000010      ; set CA2 high, switch to H2D mode
        tsb     VIA::PCR
        sta     VIA::IER        ; disable the CA1 interrupt
        lda     #%10000000
        trb     VIA::PORTB      ; start bit is 0
        tsb     VIA::DDRB       ; set the data bit to output
        jsr     kb_clk_poll
        ldy     #1              ; y is parity to increment
        ldx     #8              ; x is loop count
        ror     kb_cur          ; bit 0 -> carry
@loop:
        ror     kb_cur          ; carry -> bit 7
        bpl     @even
        tsb     VIA::PORTB      ; odd: set bit 7
        iny                     ; increment parity on odd bits
        jmp     @cont
@even:
        trb     VIA::PORTB      ; even: clear bit 7
@cont:
        dex
        bne     @loop
        sty     kb_cur          ; get parity
        ror     kb_cur          ; bit 0 -> carry
        bcc     @evenp
        tsb     VIA::PORTB
        jmp     @contp
@evenp:
        trb     VIA::PORTB
@contp:
        jsr     kb_clk_poll
        tsb     VIA::PORTB      ; stop bit is 1
@l1:
        bit     VIA::PORTA      ; poll for rising edge
        bmi     @l1
        trb     VIA::DDRB       ; stop clobbering data input      
@l2:
        bit     VIA::PORTA      ; poll for falling edge
        bpl     @l2
@l3:
        bit     VIA::PORTA      ; poll for final rising edge
        bmi     @l3
        lda     #%00000010
        trb     VIA::PCR        ; set CA2 low, restore D2H mode
        lda     #%10000010      ; re-enable the interrupt
        sta     VIA::IER
        plp
        rts


kb_clk_poll:
        bit     VIA::PORTA      ; poll for rising edge
        bmi     kb_clk_poll
@l2:
        bit     VIA::PORTA      ; poll for falling edge
        bpl     @l2
        rts

; char cgetc (void);
; return a character or wait
; if cursor is set to 1, blink while waiting
kb_getc:
        ldx     kb_rp
        cpx     kb_wp
        beq     @empty
        lda     kb_buf,X
        inc     kb_rp
        ldx     #>$0000
        rts
@empty:
        ldx     cursor
        beq     @noblink
        lda     #%00001111
        jsr     lcd_inst_wr
@noblink:
        wai
        ldx     cursor
        beq     kb_getc
        lda     #%00001100
        jsr     lcd_inst_wr
        jmp     kb_getc


kb_check:
        lda     #0
        ldx     kb_rp
        cpx     kb_wp
        beq     @empty
        lda     #1
@empty:
        ldy     #0
        rts
