; via.s

LCD_RW      = $10   ; LCD Data R/W#
LCD_RS      = $20   ; LCD Register Select; 0=instruction, 1=data
LCD_E       = $40   ; LCD Data Xfer Enable
LCD_BUSY    = $08   ; LCD Busy Flag

value       = $0200 ; 2 bytes
mod10       = $0202 ; 2 bytes
message     = $0204 ; 6 bytes
counter     = $020a ; 2 bytes

        .org $8000

reset:
        ldx #$ff
        txs

        jsr dbg_led_init
        ldx #1
        jsr dbg_led_on
        jsr irq_init
        jsr dbg_led_off
        ldx #2
        jsr dbg_led_on
        jsr lcd_init
        jsr dbg_led_off

        lda #0              ; Set counter to 0
        sta counter
        sta counter + 1

        ldx #3
        jsr dbg_led_on
loop:
        lda #%00000010      ; LCD Home
        jsr lcd_inst_wr
        lda #0              ; Make message a null string
        sta message
        sei                 ; interrupt increments counter, so disable interrupts
        lda counter         ; Copy counter to value
        sta value
        lda counter + 1
        sta value + 1
        cli
divide$:
        lda #0              ; Initialize remainder to zero
        sta mod10
        sta mod10 + 1
        clc
        ldx #16
divloop$:
        rol value           ; Rotate quotient and remainder
        rol value + 1
        rol mod10
        rol mod10 + 1
        sec                 ; a,y = dividend - divisor
        lda mod10
        sbc #10
        tay                 ; save low byte in Y
        lda mod10 + 1
        sbc #0
        bcc ignore_result$  ; branch if dividend < divisor (branch if carry is clear)
        sty mod10
        sta mod10 + 1
ignore_result$:
        dex
        bne divloop$
        rol value           ; shift in the last bit of the quotient
        rol value + 1
        lda mod10
        clc                 ; clear carry bit
        adc #"0"
        jsr push_char
        lda value           ; If value != 0, then continue dividing
        ora value + 1
        bne divide$         ; branch if value not zero
        ldx #0
char$:
        lda message, x
        beq done$
        jsr lcd_char_wr
        inx
        jmp char$
done$:
        jmp loop
;--------------------

; Add the character in the A register to the beginning of the
; null-terminated string `message`
push_char:
        pha                 ; Push new first char onto stack
        ldy #0
char_loop$:
        lda message, y      ; Get char on string and push into X
        tax
        pla                 ; Pull char off stack and add it to the string
        sta message, y
        iny
        txa
        pha                 ; Push char from string into stack
        bne char_loop$
        pla
        sta message, y      ; Pull null off stack and add to end of string
        rts
;--------------------

; Enable IRQ when VIA CA2 is pulled low
irq_init:
        pha
        lda #%00100010      ; CA2/CB2 independent of ORA/ORB. All negative edge.
        sta VIA2_PCR
        lda #%10011011      ; Interrupt on CA1, CA2, CB1, CB2.
        sta VIA2_IER
        pla
        rts
;--------------------


dbg_led_init:
        pha
        lda #$ff
        sta VIA2_DDRA
        lda #0
        sta VIA2_PORTA
        pla
        rts
;--------------------

; Turns on the LED whose position is in X
dbg_led_on:
        pha
        phx
        lda #1
again$:
        cpx #0
        beq done$
        asl
        dex
        jmp again$
done$:
        tsb VIA2_PORTA
        plx
        pla
        rts
;--------------------

; Turns off the LED whose position is in X
dbg_led_off:
        pha
        phx
        lda #1
again$:
        cpx #0
        beq done$
        asl
        dex
        jmp again$
done$:
        trb VIA2_PORTA
        plx
        pla
        rts
;--------------------

irq:
        sei
        pha
        phx
        ldx #0
        jsr dbg_led_on
        lda ACIA_STS            ; clear ACIA interrupt
; not hooked up yet
        ; lda VIA1_IFR          ; clear VIA1 interrupt
        ; sta VIA1_IFR
        lda VIA2_IFR            ; clear VIA2 interrupt
        sta VIA2_IFR
        bne skip$               ; ignore interrupts not from VIA2
        inc counter             ; increment the counter
        bne skip$
        inc counter + 1
skip$:
        jsr dbg_led_off
        plx
        pla
        cli
        rti
;--------------------

nmi:
        rti
;--------------------

        .org $fffa
        .word nmi
        .word reset
        .word irq
