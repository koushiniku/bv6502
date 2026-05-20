# Direct PS/2 to W65C22 Driver

## WC6C22 Wiring

* IRQ# -> W65C02 NMI# for real-time handling.
* CA1 -> NC.
* CA2 -> Use as IRQ# for handing off NMI# to slower input scan code parser.
* CB1 -> Keyboard clock input for shift register.
* CB2 -> Keyboard data for shift register I/O and output for start bit and parity.
* PB0 -> Direcition output 1 = D2H, 0 = H2D.
* PB1-5 -> NC. Set as output. Rotate start, stop, parity into these for performance.
    * Initialize these to 1 so they don't change PB0 when rotating.
* PB6 -> Keyboard data start, stop, parity input. Never used for output.
* PB7 -> Keyboard clock low output for initiating host-to-device mode. Diode prevents driving high.

## Initialization

* Set PB to $FF.
* PB0..5 are outputs, PB6..7 are inputs.
* Latching is enabled on PB.
* Interrupt on CB1 rising edge. In theory we're guaranteed a hold time of 5us.
* CB1 interrupt enabled.

## NMI Entry

Same entry routine for all NMIs.

* Disable interrupts to prevent further preemption since NMI is edge triggered.
* Read and clear interrupt flags.
* If T2 interrupt flag was set:
    * LDA "resend" command ($FE) and jsr to H2D output routine.
    * Pop stack and RTI.
* Jump to stored pointer (`jmp (kb_callback)`). This points to the next routine in the state machine.


## Input

Input NMIs:

1. Start bit.
    * Rotate start bit on PB6 into PB5.
    * Set data input as the next callback.
    * Enable shift in under CB1 clock.
    * Reload T2 with 2ms timeout.
    * Enable SR and T2 interrupts.
    * Pop stack and RTI.
2. Data bits.
    * Set parity input as the next callback.
    * Disable shift in; enable latching on PB.
    * Reload T2 with 2ms timeout.
    * Enable CB1 and T2 interrupts.
    * Pop stack and RTI.
3. Parity bit.
    * Rotate parity bit on PB6 into PB5. (Start bit rotates into PB4.)
    * Set stop bit input as the next callback.
    * Reload T2 with 2ms timeout.
    * Enable CB1 and T2 interrupts.
    * Pop stack and RTI.
4. Stop bit.
    * Set PB7 low output to inhibit new input.
    * Check start, stop, parity for errors.
    * If clean:
        * Set start bit as the next callback.
        * Set PB outputs to 1.
        * Enable CB1 interrupt.
        * Read scan code from SR and push into buffer.
        * Set CA2 low to trigger IRQ.
    * Else:
        * Send host-to-device command to retransmit.
    * Pop stack and RTI.

Input IRQ (as ca65 interruptor):

* Test and clear CA2 low condition.
* If not my interrupt, clear carry flag and RTS.
* Else:
    * Copy scancode from buffer.
    * Clear PB7 to allow new input from keyboard.
    * Enable CB1 interrupt. (Do we need to allow time for the clock pullup?)
    * Call scancode parser.
    * Set carry flag, and RTS.


## Output

We don't use the one-shot pulse because we need to wait 100us, then pull the data low, then release the clock.

Output scancodes are preprocessor bit-reversed constants. Compute output parity with preprocessor, not runtime.


1. Setup. Data and parity are inputs. (X and Y?)
    * Disable all interrupts. We could be starting from any state.
    * Set up T1 as one shot output to PB7.
    * Load 100us PB7 low pulse into T1 and let it start. (And disable any SR.)
    * Set PB7 DDR as input.
    * Store data into SR.
    * Store data + parity into retry buffers.
    * Set parity bit output as the next callback.
    * Set PB0 low to switch data bus to D2H.
    * Set CB2 as a low output. This is the start bit.
    * Enable shift out under CB1 clock.
        * Shifts happen on falling edge.
        * Pray CB2 stays low until the first shift. If it doesn't work that way, we can experiment with how long *after* releasing the clock we can enable shift out, giving the keyboard enough time to consume the low bit before putting some random value on the bus.
    * Load 15ms timeout into T2 and let it start.
    * Clear interrupts.
    * Enable SR and T2 interrupts.
    * RTS.
3. Parity bit.
    * Set stop bit output as the next callback.
    * Set CB2 output level to match parity (bit 5 of PCR). Let CB1 interrupt be falling edge.
    * Disable SR. This should restore PCR control over CB2. (Restore PB latch for later.)
    * Load T2 with 2ms timeout.
    * Enable CB1 and T2 interrupts.
    * Pop stack and RTI.
4. Stop bit.
    * Set ack input as the next callback.
    * Set CB1 as a rising edge input. Restore CB2 as an input.
    * Set PB outputs as all 1s and switch bus back to D2H.
    * Load T2 with 2ms timeout.
    * Enable CB1 and T2 interrupts.
    * Pop stack and RTI.
5. Ack bit (input).
    * Check ack bit from PB6.
    * If ack is 1: Call output setup again with retry data.
    * Set start input as the next callback.
    * Set PB outputs to 1.
    * Enable CB1 interrupt.
    * Pop stack and RTI.

