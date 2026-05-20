# Can I make a one byte keyboard controller with a 22v10, '595s, '165s, '245s, a '14, and a '280?

## Who is internal bus driver

* Host is writing (PHI2 & CS * !R): '245 is driving.
    * '595 OE# is high (disabled).
    * '245s DIR is high (A2B).
    * '245s OE# is low (enabled).
    * '165s SH/LD is low (load).
* Otherwise: '595 is driving.
    * '595 OE# is low (enabled).
    * '245s DIR is low (B2A).
    * '165s SH/LD# is high (shift).
    * Host is reading (PHI2 & CS & R)
        * Outer '245 OE is low.
        * Inner '245 OE depends on IRQ (PHI2 & CS & R & IRQ).
    * Host is not reading:
        * '245s OE# are low.

## IC signal logic

* ENABLED = PHI2 & CS
* READ = ENABLED & R
* WRITE = ENALBED & !R

* '245s:
    * DIR = WRITE (set high when writing)
    * BUS_OE# = !(WRITE | READ)
    * KB_OE# = !(WRITE | READ & IRQ)
* Pullup '245:
    * DIR = 1 (A to B)
    * OE# = !(KB_OE#)
* '595s:
    * OE# = WRITE (set high/disable when writing)
    * RCLK: set with device clock or EOM pulse
    * SRCLR# = 1
    * SRCLK: set with device clock
* '165s:
    * SH/LD# = H2D (shift in H2D mode, load otherwise)
    * CLK_INH = !H2D: Don't shift when not in H2D--this could pull down the data bus.

## PLD registers and outputs

1. IRQ: Host IRQ and keyboard input suppression.
    * .D = !H2D & !START & STOP & PARITY
    * .AR = !PHI2 & READ_LATCH
    * .CK = EOM
    * Positive logic output driving open drain NMOS.
2. READ_LATCH: Tracks when a host read is in progress. Sets the bus to input. We can't clear IRQ until the clock goes low or we'll lose the data! So this will stay set until the next clock cycle.
    * .D = CS & R
    * .CK = PHI2
    * NC pin (keep output enabled as a test pin)
3. H2D: Tracks when we are transmitting to the device.
    * .D = CTS
    * .AS = CS & !R & PHI2
    * .CK = EOM
4. CTS: Tracks when we have a CTS outstanding. We'll get 2 OEM clocks: once after the CTS pulse, and once after we are done shifting the data out. The output of this shifts into the H2D register.
    * .D = 0
    * .AS = CS & !R & PHI2
    * .CK = EOM
5. WRITE: Host is actively writing. For disabling '595 OE and switching the bus direction.
    * = PHI2 & CS & !R
6. !BUS_OE: Enables host data bus transceiver.
    * = PHI2 & CS
7. !KB_OE: Enables keyboard bus transceiver.
    * = PHI2 & CS & (!R | R & IRQ)
8. !INV_OE: Enables transceiver for putting an invalid opcode on the bus.
    * = PHI2 & CS & R & !IRQ
9. CLK_INH: Inhibit the shift out clock
    * = !H2D


## PLD Inputs

1. EOM: Pulse when clock has been high for 100us or so. Used as clock for most registers that track keyboard bus state.
2. PHI2: host clock.
3. !CS: chip select from host.
4. R: R/W# from host.
6. START: start bit from keyboard.
7. PARITY: computed from input data + parity. 1 means it's odd (correct).
8. !STOP: stop bit from keyboard.


## Device input sequence

* Keyboard clocks in 11 bits: start, eight data, parity, stop.
* EOM RC pulse sets off:
    * Start, stop, parity check (also check if in D2H mode).
        * Result set latched IRQ assertion (actually a S-R reset since active low):
            * IRQ to host.
            * Pulldown of device clock to inhibit new data.

## Host read sequence

* Sequence entry: PHI2 low, CS asserted, RW is R.
    * Sequence entry condition is latched.
    * '245s DIR are set B to A. (Default is A to B, so it's only B to A if this condition is true.)
    * Outer '245 output is already enabled. (Always enabled, since inner '245 gates the inner bus.)
    * Inner '245 output is disabled if IRQ is deasserted (and PHI2 low, CS asserted, RW is R.)
    * Either valid data or $FF (no IRQ) is driven to the host bus.

* Sequence exit: PHI2 high, sequence entry was latched.
    * Clear IRQ. IRQ is clocked on 
    * Also cleared on host writes.

## Reads

* Host read clears IRQ.
* If IRQ isn't asserted, host read returns $00 or $FF or something. This is controlled by the inner 'OE pin.

## Writes


## Signals

### PLD

* IRQ#
    * Asserted (low) on:
        * Valid input data ready.
    * Deasserted (high) on any of:
        * Host-to-device mode.
        * Wrong parity, start, or stop bits.
        * Data not ready.
    * Latched until read.
    * Latched by:
        * EOM pulse while in D2H mode.
        * 
* 

### 74HC595: Input (device-to-host) shifter

* OE#: Output enable.
    * Default assert (low) for device-to-host.
* RCLK: Storage register clock.
    * Could tie to EOM pulse or just trigger every rising clock (probably easier).
    * Schmitt invert, delay, Schmitt invert, invert.
* SRCLR#: Shift register clear.
    * Set high.
* SRCLK: Shift register clock.
    * Set to falling edge (inverted) device clock input. Delay a quarter clock cycle (15-25us).
    * Schmitt invert, delay, Schmitt invert.
* SER: Serial input.
    * Double inverted keyboard data input.


### 74HC165: Output (host-to-device) shifter

* SH/LD#: Load the shift register.
    * Pulse low on host write to latch the data from the bus.
* CLK: Shift clock.
    * Shift on falling edge. Same quarter clock delay as for input.
    * This includes DTS pulldown to shift out start bit even though it didn't come from the device.
* CLK_INH: Clock inhibit.
    * Set low. We can safely clock by backfilling the data with 1s. (Open drain means 1 doesn't drive the bus.)
* QH#: Inverted serial output.
    * Feed into the base of a MOSFET to make an open drain output.


### 74HC280: Parity checker/generator

* I0-I7: Connected to the internal bus.


## State Machine

So asynchronous setting/clearing isn't a thing. I need it to be clocked by the host clock.








































