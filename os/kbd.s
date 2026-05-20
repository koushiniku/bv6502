; SPDX-License-Identifier: MIT
; kbd.s
; PS/2 keyboard driver
; attached to VIA port A

        .include "bv6502.inc"

        .constructor kbd_init
        .destructor kbd_done
        .interruptor kbd_irq
        .export kbd_nmi, kbd_kb_getc, kbd_check
        .import cursor, lcd_inst_wr


        .segment RO256
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

        .segment RO32
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

scan_in:        .res    1       ; scancode input buffer
scan_cur:       .res    1       ; scancode temporary buffer
scan_out:       .res    1       ; previous scancode for retry
kb_rp:          .res    1       ; ascii read pointer
kb_wp:          .res    1       ; ascii write pointer

kb_fl0:         .res    1       ; keyboard flags
KB_SHIFT_MASK   = %00000110
KB_LSHIFT       = 1             ; 1: left shift pressed
KB_RSHIFT       = 2             ; 2: right shift pressed
KB_CTRL_MASK    = %00011000
KB_LCTRL        = 3             ; 3: left ctrl pressed
KB_RCTRL        = 4             ; 4: right ctrl pressed
KB_SCRLOCK      = 5             ; 5: kb_scrlock on
KB_NUMLOCK      = 6             ; 6: kb_numlock on
KB_CAPSLOCK     = 7             ; 7: kb_capslock on

kb_fl1:         .res    1       ; more keyboard flags
KB_ALT_MASK     = %00001100
KB_LALT         = 2             ; 2: left alt pressed
KB_RALT         = 3             ; 3: right alt pressed
KB_PAUSE_MASK   = %00110000
KB_PAUSE1       = 4             ; 4: first $E1 of "pause" seen
KB_PAUSE2       = 5             ; 5: second $E1 of "pause" seen
KB_E0CODE       = 6             ; 6: $E0 was received
KB_F0CODE       = 7             ; 7: $F0 was received

kb_nmi_cb:      .res    2       ; NMI state machine callback function

KB_T_PULSE      = MHZ * 100     ; 100us low clock pulse for starting H2D

KB_BUS_DATA     = 4             ; Data input to read ACK
KB_BUS_DDR      = 5             ; KB DDR is on PB5
KB_BUS_PULSE    = 6             ; KB low pulse timer output--set high normally


; keyboard input buffer
        .segment A256
        .align  256
kb_buf: .res    256


        .code

; initialize VIA for the keyboard
; PB6 is data I/O
; PB7 is timed clock low pulse output
; CB1 is clock interrupt/shift clock
; CB2 is shift data
kbd_init:
        stz     kb_rp
        stz     kb_wp
        stz     kb_fl0
        stz     kb_fl1
        lda     #BITPOS(KB_BUS_PULSE)
        sta     VIA::PORTB      ; high level disables clock low pulse
        lda     #(BITPOS(KB_BUS_PULSE) | BITPOS(KB_BUS_DDR))
        sta     VIA::DDRB       ; just 2 bits are outputs
        lda     #VIA_PCR_CA2_HI ; CA2 is our IRQ
        sta     #VIA::PCR
        lda     #(VIA_ACR_SR_SIEX | VIA_ACR_T2_PLS)
        sta     VIA::ACR        ; Shift in ext clock + T2 pulse counter
        lda     #11             ; Initialize pulse count
        sta     >VIA::T2C
        lda     #<kb_nmi_in_sr  ; first callback is  shift register interrupt
        sta     <kb_nmi_cb
        lda     #>kb_nmi_in_sr
        sta     >kb_nmi_cb
        lda     #$7F            ; Clear any interrupts
        sta     VIA::IFR
        lda     #(BITPOS(VIA_IFR_IER_SET) | BITPOS(VIA_IFR_IER_SR) | BITPOS(VIA_IFR_IER_T2))
        sta     VIA::IER        ; Enable SR and T2 interrupts
        rts

kbd_done:
        lda     #7F
        sta     #7F
        rts

; handle keyboard interrupt
; direct nmi handler
kbd_nmi_isr:
        jmp     (kb_callback)


; input shift register ISR
kb_nmi_in_sr:
        pha
        bbs     KB_IN_SEM,kb_fl0,@ignore ; buffer is not clear! abort!
        lda     VIA::SR
        sta     <kb_in_pkt
@ignore:
        lda     #11             ; Re-initialize pulse count
        sta     >VIA::T2C
        lda     #<kb_nmi_in_t2  ; second nmi is shift register interrupt
        sta     <kb_nmi_cb
        lda     #>kb_nmi_in_t2
        sta     >kb_nmi_cb
        lda     #$7F            ; assume interrupt is ours
        sta     VIA::IER
        pla
        rti

; input shift register ISR
kb_nmi_in_t2:
        pha
        bbs     KB_IN_SEM,kb_fl0,@ignore ; buffer is not clear! abort!
        lda     VIA::SR
        sta     >kb_in_pkt
@ignore:
        lda     #<kb_nmi_in_sr  ; first is shift register interrupt
        sta     <kb_nmi_cb
        lda     #>kb_nmi_in_sr
        sta     >kb_nmi_cb
        lda     #$7F            ; assume interrupt is ours
        sta     VIA::IER
        pla
        rti











old:
        ror     VIA::PORTB      ; stash start bit in PB5
        lda     #<kb_in_data    ; next function
        sta     <kb_callback
        lda     #>kb_in_data
        sta     >kb_callback
        lda     #VIA_ACR_SR_SIEX; Enable SR with external clock
        lda     #<KB_TO_DATA    ; arm timeout
        sta     <VIA::T2C
        lda     #>KB_TO_DATA
        sta     >VIA::T2C
        lda     $7F
        sta     VIA::IFR
        lda     #(VIA_IFR_IER_SET | VIA_IFR_IER_SR | VIA_IFR_IER_T2)
        sta     VIA::IER        ; enable SR and T2 interrupts
        pla
        rti

; ISR when we expected to shift in 8 bits of data
; Don't bother copying the data out of SR...it's not going anywhere
kb_in_data:
        lda     #<kb_in_parity  ; next function
        sta     <kb_callback
        lda     #>kb_in_parity
        sta     >kb_callback
        lda     #VIA_ACR_PBL    ; disable SR; enable PB latch
        lda     <VIA::T2C       ; restart timeout
        lda     >VIA::T2C
        lda     $7F
        sta     VIA::IFR
        lda     #(VIA_IFR_IER_SET | VIA_IFR_IER_CB1 | VIA_IFR_IER_T2)
        sta     VIA::IER        ; enable CB1 and T2 interrupts
        pla
        rti

; ISR when we expected to receive parity
; Store it and check it when we have cycles to spare
kb_in_parity:
        ror     VIA::PORTB      ; parity in PB5; start bit in PB4
        lda     #<kb_in_stop
        sta     <kb_callback
        lda     #>kb_in_stop
        sta     >kb_callback
        lda     <VIA::T2C       ; restart timeout
        lda     >VIA::T2C
        lda     $7F
        sta     VIA::IFR
        lda     #(VIA_IFR_IER_SET | VIA_IFR_IER_CB1 | VIA_IFR_IER_T2)
        sta     VIA::IER        ; enable CB1 and T2 interrupts
        pla
        rti

; Received stop bit (should be 1)
kb_in_stop:
        rmb     KB_CLK_BIT,VIA::PORTB       ; set clk low to inhibit more input
        smb     KB_CLK_BIT,VIA::DDRB
        phx
        phy
        ldy     #0              ; parity counter
        lda     VIA::PORTB      ; can't rot portb. bit 7 is an input
        rol     A               ; bit7 = stop, bit6=parity, bit5=start
        lda     #%001000000
        bmi     @err            ; error if start bit is 1
        beq     @err            ; error if stop bit is 0
        bvc     @zero           ; branch if parity bit was 0
        iny                     ; iny if parity bit was 1
@zero:
        lda     VIA::SR
        sta     scan_in
        ldx     #8              ; compute parity
@loop:
        ror     A
        bcc     @zero2
        iny
@zero2:
        dex
        bne     @loop
        tya
        ror     A               ; low bit should be 1
        bcc     @err
        lda     #<kb_in_start   ; reset callback to start bit input
        sta     <kb_callback
        lda     #>kb_in_start
        sta     >kb_callback
        lda     $FF             ; reset output pins to 1
        sta     VIA::PORTB
        lda     #(VIA_PCR_CB1_POS | VIA_PCR_CA2_LO)
        sta     VIA::PCR        ; raise IRQ: set CA2 low, keep CB1 rising edge
@err:
        ldx     #BITREVERSE $FE ; ask for resend
        ldy     #ODDPARITY $FE 
        jsr     kb_out_pulse
        ply
        plx
        pla
        rti

; bottom-half irq handler
; pop scan codes and parse them
kbd_irq:
        lda     #VIA_PCR_CA2
        bit     VIA::PCR
        bne     @mine
        bcc                     ; not mine
        rts
@mine:
        lda     #VIA_PCR_CB1_POS; clear the IRQ
        sta     VIA::PCR
        lda     scan_in         ; copy data out of the buffer
        sta     scan_cur
        rmb     KB_CLK_BIT,VIA::DDRB    ; release inhibit
        lda     $7F
        sta     VIA::IFR
        lda     #(VIA_IFR_IER_SET, VIA_IFR_IER_CB1)
        sta     VIA::IER        ; re-enable interrupts
                                ; TODO delay to allow clock to rise?
        jsr     kb_parse
        bcs
        rts


; push the ascii in A into the buffer
kb_buf_push:
        ldx     kb_rp
        txy
        inx
        cmp     kb_wp
        beq     @full
        sta     kb_buf,Y
        stx     kb_rp
@full:
        rts


; parse an incoming keyboard scan code
kb_parse:
        lda     scan_cur        ; begin parsing the scancode
        bpl     @noh
        bra     kb_hscan        ; bit 7 is set: parse high jump table
@noh:
        lda     #KB_F0CODE      ; was $F0 the previous code?
        trb     kb_fl1
        beq     @make
        lda     scan_cur 
        jsr     kb_bscan        ; parse "break" codes
        rmb     KB_E0CODE_BIT,kb_fl1; in case EO_CODE was set
        rts
@make:                          ; keypress, not release
        lda     #KB_ALT         ; is alt being pressed?
        bit     kb_fl1
        beq     @noalt
        rts                     ; ignoring alt-anything for now
@noalt:
        lda     #KB_E0CODE      ; was $E0 the previous code?
        trb     kb_fl1
        beq     @noe
        bra     kb_escan        ; parse the e0 keys
@noe:
        lda     #KB_CTRL
        bit     kb_fl0
        beq     @noctrl
        lda     scan_cur 
        ora     #%10000000      ; use uppercase table
        tax
        lda     kb_buf,X
        cmp     #'?'            ; check for "DEL"
        bne     @nodel
        lda     #$7F            ; push "DEL"
        bra     kb_buf_push
@nodel:                         ; check for $40..$5F ('@'..'_')
        sec
        sbc     #$40            ; $40..$5F -> $00..$1F
        cmp     #$20
        bcc     kb_buf_push     ; push caret code
        rts                     ; ignore other CTRL keys
@noctrl:                        ; check kb_mods effects of shift, caps, num
        lda     scan_cur        ; divide by 4: find byte index into kb_mods
        lsr     A
        lsr     A
        tax
        lda     #%00000011
        and     scan_cur        ; index of the crumb in the byte from kb_mods
        pha
        lda     kb_mods,X       ; get the byte from kb_mods
        ply
@modloop:
        beq     @moddone        ; shift by Y crumbs
        lsr     A
        lsr     A
        dey
        bra     @modloop
@moddone:                       ; A[1:0] is the kb_mod code we want
        ldx     #0              ; default to lowercase table
        and     #%00000011      ; lose the upper bits and check the low crumb
        beq     @lwr            ; crumb is 0
        tay
        lda     #KB_SHIFT
        bit     kb_fl0          ; Z=!shift, V=numlock, N=capslock
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
        ldx     #%10000000
@lwr:                           ; lowercase table
        txa
        ora     scan_cur 
        tax                     ; index into kb_map
        lda     kb_map,X
        beq     kb_lscan        ; check if ASCII code comes back as zero
        bra     kb_buf_push     ; valid ASCII
;
; scan codes < $80 that did not match ASCII
kb_lscan:
        lda     scan_cur
        case    $12, @ls
        case    $59, @rs
        case    $58, @cl
        case    $14, @lc
        case    $77, @nl
        case    $11, @la
        case    $7e, @sl
        rts
@ls:                            ; left shift
        smb     KB_LSHIFT_BIT,kb_fl0
        rts
@rs:                            ; right shift
        smb     KB_RSHIFT_BIT,kb_fl0
        rts
@cl:                            ; caps lock: toggle and track LED command
        lda     #(KB_CAPSLOCK | KB_LED)
        eor     kb_fl0          
        sta     kb_fl0
        lda     #$ED            ; turn on LED
        bra     kb_out_pulse
@lc:                            ; left control
        lda     #KB_PAUSE       ; part of pause key sequence?
        bit     kb_fl1
        bne     @lcp
        smb     KB_LCTRL_BIT,kb_fl0
@lcp:
        rts
@nl:                            ; numlock
        lda     #KB_PAUSE
        bit     kb_fl1
        bne     @nlp
        lda     #(KB_NUMLOCK | KB_LED)
        eor     kb_fl0          ; is numlock: toggle and track LED command
        lda     #$ED            ; turn on LED
        bra     kb_out_pulse
@nlp:
        rts
@la:                            ; left alt
        smb     KB_LALT_BIT,kb_fl1
        rts
@sl:                            ; scroll lock
        lda     #(KB_SCRLOCK | KB_LED)
        eor     kb_fl0          ; is scroll lock: toggle and track LED command
        lda     #$ED            ; turn on LED
        bra     kb_out_pulse

; scan code is >= $80
; scan code is stored in A
kb_hscan:
        case    $F0, @f0        ; key release prefix
        case    $E0, @e0        ; special code prefix
        case    $FA, @cc        ; command completion request
        case    $FE, @re        ; repeat request
        case    $E1, @ps        ; pause key
        case    $AA, @ok        ; reset successful
        case    $FC, @er        ; error/reset failed
@ret:
        rts                     ; not found
@f0:                            ; key release
        smb     KB_F0CODE_BIT,kb_fl1
        rts
@e0:                            ; alternate scancodes
        smb     KB_E0CODE_BIT,kb_fl1
        rts
@cc:                            ; command completion
        lda     #KB_LED         ; was it LED?
        trb     kb_fl1
        beq     @ret
        lda     kb_fl0          ; update keyboard LEDs
        rol     A               ; but they are at the wrong offset
        rol     A               ; because BIT needs numlock and capslock
        rol     A               ; in bits 6-7 (6-7!)
        rol     A               ; this is one instruction less
        and     #%00000111      ; than shifting them right
        bra     kb_out_pulse
@re:                            ; resend request
        lda     scan_prev
        bra     kb_out_pulse
@ps:                            ; stupid pause key
        lda     #KB_PAUSE1
        tsb     kb_fl1          ; first $E1
        bne     @p2
        rts
@p2:
        smb     KB_PAUSE2_BIT,kb_fl2; second $E1
        rts
@ok:
        bra     kbd_init        ; successful reset
@er:
        lda     #$FF
        bra     kb_send         ; idk, reset again?

; process post-$F0 ("break") $00-$7F scan codes
; We only care about keys where releasing has an effect
kb_bscan:
        case    $12,@ls
        case    $59,@rs
        case    $14,@c
        case    $77,@nl
        case    $11,@a
        rts
@ls:                            ; release left shift
        rmb     KB_LSHIFT_BIT,kb_fl0
        rts
@rs:                            ; release right shift
        rmb     KB_RSHIFT_BIT,kb_fl0
        rts
@c:                             ; release control
        lda     #KB_PAUSE       ; part of a pause key sequence?
        bit     kb_fl1
        bne     @clp
        bbs     KB_E0CODE_BIT,kb_fl1,@cr    ; left or right?
        rmb     KB_LCTRL_BIT,kb_fl0 ; left control
@clp:
        rts
@cr:
        rmb     KB_RCTRL_BIT,kb_fl0 ; right control
        rts
@nl:                            ; release numlock
        lda     kb_fl1          ; clear pause bits if they are set
        and     #(!KB_PAUSE)
        sta     kb_fl1
        rts
@al:
        bbs     KB_E0CODE_BIT,kb_fl1,@ar    ; left or right?
        rmb     KB_LALT_BIT,kb_fl1  ; left alt
        rts
@ar:
        rmb     KB_RALT_BIT,kb_fl1  ; right alt
        rts

; process $E0 $00-$7F scan codes
kb_escan:
        case    $71,@dl
        case    $14,@rc
        case    $5A,@ke
        case    $4A,@ks
        case    $11,@ra
        rts
@dl:
        lda     #$08            ; del key: send backspace
        bra     kb_buf_push
@rc:
        smb     KB_RCTRL_BIT,kb_fl0 ; right ctrl
        rts
@ke:
        lda     #$0D            ; keypad "enter": send cr
        bra     kb_buf_push
@ks:
        lda     #'/'            ; keypad slash
        bra     kb_buf_push
@ra:
        smb     KB_RALT_BIT,kb_fl1  ; right alt
        rts

kb_out_retry:
        ldx     scan_prev
        ldy     kb_fl1
; Send data byte stored in X and parity stored in Y to keyboard
; We could be entering from NMI or IRQ
kb_out_pulse:
        lda     #$7F            ; disable interrupts
        sta     VIA::IER
        lda     #VIA_ACR_T1_ONE ; start 100us low clock pulse
        lda     #<KB_T_PULSE
        sta     <VIA::T1
        lda     #>KB_T_PULSE
        sta     >VIA::T1
        sta     VIA::ACR
        rmb     KB_CLK_BIT, VIA::DDRB   ; clock may have been low already
        stx     VIA::SR
        stx     scan_prev
        tya
        ror
        bcs     @one            ; store parity backup and as bit after data
        rmb     KB_PARITY_BIT,kb_fl1
        bra     @next
@one:   smb     KB_PARITY_BIT,kb_fl1
@next:  lda     #<kb_out_parity ; set next callback
        sta     <kb_callback
        lda     #>kb_out_parity
        sta     >kb_callback
        lda     #(VIA_PCR_CB1_POS | VIA_PCR_CA2_LO)
        stz     VIA::PORTB      ; set bus to H2D
        sta     VIA::PCR        ; set CA2 output low for start bit
        lda     #(VIA_ACR_T1_ONE | VIA_ACR_SR_SOEX)
        sta     VIA::ACR        ; enable SR output on CB1 clock
        lda     #<KB_TO_START   ; set up timeout
        sta     <VIA::T2
        lda     #>KB_TO_START
        sta     >KB::T2
        lda     #$7F
        sta     VIA::IFR        ; clear any interrupt flags
        lda     #(VIA_IFR_IER_SR | VIA_IFR_IER_T2)
        sta     VIA::IER        ; enable shift and timeout interrupts
        rts

kb_out_parity:
        lda     #<kb_out_stop   ; set next callback
        sta     >kb_callback
        lda     #>kb_out_stop
        sta     >kb_callback
        bbs     kb_fl1,@one
        lda     #VIA_PCR_CB2_LO ; set CB2 output to match parity
        bra     @next
@one:   lda     #VIA_PCR_CB2_HI
@next:  sta     VIA::PCR        ; let CB1 interrupt be falling edge
        lda     #VIA_ACR_PBL    ; disable shift, re-enable latch
        sta     VIA::ACR
        lda     #<KB_TO_START   ; set up timeout
        sta     <VIA::T2
        lda     #>KB_TO_START
        sta     >KB::T2
        sta     VIA::IFR        ; clear any interrupt flags
        lda     #(VIA_IFR_IER_CB2 | VIA_IFR_IER_T2)
        sta     VIA::IER        ; enable shift and timeout interrupts
        





; char cgetc (void);
; return a character or wait
; if cursor is set to 1, blink while waiting
kb_getc:
        ldx     kb_rp
        cpx     kb_sp
        beq     @empty
        lda     kb_buf,X
        inc     kb_rp
        ldx     #0              ; C int high byte
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
        bra     kb_getc


kbd_check:
        lda     #0
        ldx     kb_rp
        cpx     kb_sp
        beq     @empty
        lda     #1
@empty:
        ldy     #0
        rts
