# Can I make a 2 byte LCD display controller?

1. Data Reg
2. CS Reg

1MHz external oscillator?


## Write Sequence

From host perspective:

1. Host writes RS bit to control reg.
2. Host writes to data reg. Data write makes it go, that way you can leave RS as its and keep writing.
3. Controller writes to LCD.
4. Controller sets IRQ flag.
5. Host reads flag, which clears IRQ after reading. No R/W1C.

From controller perspective:

1. Set CS, Addr = 1: latch data PLD.
2. Set RW=W, CS, Addr = 0: latch data (separate IC).
3. Put Data on bus.
    1. OSC rise: set E.
    2. OSC fall: clear E.
5. Poll busy flag. (RS=0).
    1. OSC rise: set E.
    2. OSC fall: clear E.
6. Flag set, goto 5.
7. Flag clear: set IRQ.


## PLD

### Inputs

1. PHI2
2. CS#
3. R/W#
4. A0
5. LCLK - Divide host clock, 555, <=1MHz oscillator, etc.

### Outputs/Regs

LCD_E is wired

1. BF (latched last read)
2. BUS_EN (RS 
2. LCD_RS (Toggled by address the host writes to)
3. LCD_RW (Also register output enable)
4. D_LE# (Bus Enable + Register Latch Enable)
5. LCLK_PREV1 (edge detection)
6. LCLK_PREV2
6. STATE_BUSY_L (
7. STATE_BUSY_H
8. STATE_WRITE_H
9. STATE_WRITE_L
10



