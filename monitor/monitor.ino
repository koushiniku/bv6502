// SPDX-License-Identifier: MIT AND CC-BY-4.0
//
// Derived from "6502-monitor.ino"
// https://eater.net/downloads/6502-monitor.ino
// Copyright (c) 2019 Ben Eater
// Licensed under CC BY 4.0
// https://creativecommons.org/licenses/by/4.0/
// 
// Modifications:
//  - Switched to direct port manipulation.
//  - Added more inputs to monitor and changed pins of existing ones.
//  - Made the clock an output rather than an input.
//  - Added no-output free-run mode, address breakpoint, and single-stepping by half clocks.
// 
// Modifications copyright (c) 2026 Bryan Veal
// This file is distributed under the MIT License, subject to the above attribution.


// Arduino Mega pins
// mask   0x80      0x40      0x20      0x10      0x08      0x04      0x02      0x01
// pos    7         6         5         4         3         2         1         0
// -----------------------------------------------------------------------------------
// PORTA  D29       D28       D27       D26       D25       D24       D23       D22
//        ram ce    a3        oe        a2        we        a1        rom ce    a0
// -----------------------------------------------------------------------------------
// PORTB  D13       D12       D11       D10       D50       D51       D52       D53
//        cb2       cb1       ca2       ca1       a14       d6        a15       d7
// -----------------------------------------------------------------------------------
// PORTC  D30       D31       D32       D33       D34       D35       D36       D37
//        a4        acia      a5        via2      a6        via1      a7        lcd
// -----------------------------------------------------------------------------------
// PORTD  D38       --        TX_LED    RX_LED    D18       D19       D20       D21
//        a8
// -----------------------------------------------------------------------------------
// PORTE  --        --        D3        D2        D5        --        TX/D1     RX/D0
//                            rw        clk
// -----------------------------------------------------------------------------------
// PORTF  A7/D61    A6/D60    A5/D59    A4/D58    A3/D57    A2/D56    A1/D55    A0/D54
//        pa7       pa6       pa5       pa4       pa3       pa2       pa1       pa0
// -----------------------------------------------------------------------------------
// PORTG  --        --        D4        --        --        D39       D40       D41
//                            irq                           d0        a9        d1
// -----------------------------------------------------------------------------------
// PORTH  --        D9        D8        D7        D6        --        D16       D17
//
// -----------------------------------------------------------------------------------
// PORTJ  --        --        --        --        --        --        D14       D15
//
// -----------------------------------------------------------------------------------
// PORTK  A15/D69   A14/D68   A13/D67   A12/D66   A11/D65   A10/D64   A9/D63    A8/D62
//        pb7       pb6       pb5       pb4       pb3       pb2       pb1       pb0
// -----------------------------------------------------------------------------------
// PORTL  D42       D43       D44       D45       D46       D47       D48       D49
//        a10       d2        a11       d3        a12       d4        a13       d5
// -----------------------------------------------------------------------------------

#define RST_ADDR  0xfffc
#define CODE_ADDR 0x8000

#define CLK_DDR   DDRE
#define CLK_PORT  PORTE
#define CLK_BIT   0x10

// Cycle counter.
unsigned long cycle = 0;

// Address where free running clock stops. Could be read or write, data or instruction.
word breakpoint = RST_ADDR;

// Whether we're single stepping or running until breakpoint.
boolean step_mode = false;

void setup()
{
  // Set bits we are reading as inputs with pullups.
  DDRA  =  0x00; PORTA  = 0xff;
  DDRB  =  0x00; PORTB |= 0xff;
  DDRC  =  0x00; PORTC  = 0xff;
  DDRD &= ~0x80; PORTD |= 0x80;
  DDRE &= ~0x20; PORTE |= 0x20;
  DDRF  =  0x00; PORTF  = 0xff;
  DDRG &= ~0x27; PORTG |= 0x27;
  DDRK  =  0x00; PORTK  = 0xff;
  DDRL  =  0x00; PORTL  = 0xff;

  // CLK is an output.
  CLK_PORT &= ~CLK_BIT; CLK_DDR |= CLK_BIT;

  Serial.begin(115200);
}

void loop()
{
  // My source clock is inverted from phi2
  // Toggle clock
  CLK_PORT |= CLK_BIT;
  delayMicroseconds(2);

  CLK_PORT &= ~CLK_BIT;
  delayMicroseconds(2);

  // Quickly capture current pin levels.
  byte pa = PINA,
       pb = PINB,
       pc = PINC,
       pd = PIND,
       pe = PINE,
       vpa = PINF,
       pg = PING,
       vpb = PINK,
       pl = PINL;

  // Get address bits.
  word addr = (pa & 0x01)       | (pa & 0x04) >> 1  | (pa & 0x10) >> 2  | (pa & 0x40) >> 3  |
              (pc & 0x80) >> 3  | (pc & 0x20)       | (pc & 0x08) << 3  | (pc & 0x02) << 6  |
              (pd & 0x80) << 1  | (pg & 0x02) << 8  | (pl & 0x80) << 3  | (pl & 0x20) << 6  |
              (pl & 0x08) << 9  | (pl & 0x02) << 12 | (pb & 0x08) << 11 | (pb & 0x02) << 14;

  // Get data bits.
  byte data = (pg & 0x04) >> 2  | (pg & 0x01) << 1  | (pl & 0x40) >> 4  | (pl & 0x10) >> 1  |
              (pl & 0x04) << 2  | (pl & 0x01) << 5  | (pb & 0x04) << 4  | (pb & 0x01) << 7;

  // Get the other signals.
  boolean rw      = pe & 0x20,
          irq     = pg & 0x20,
          rom_ce  = pa & 0x02,
          we      = pa & 0x08,
          oe      = pa & 0x20,
          ram_ce  = pa & 0x80,
          via     = pc & 0x04,
          vca1    = pb & 0x10,
          vca2    = pb & 0x20,
          vcb1    = pb & 0x40,
          vcb2    = pb & 0x80;

  // increment cycle count
  cycle++;

  if (rw && addr == RST_ADDR) {
    // reset cycle count
    cycle = -2;
  }

  // check for breakpoint cycle
  if (!step_mode) {
    step_mode = addr == breakpoint;
  }

  char output[128];

  if (step_mode) {
    // Only output in step mode.
    // "     cycle $aaaa r $dd IRQ WE OE ROM_CE RAM_CE VIA vpa $aa vpb $bb VCA1 VCA2 VCB1 VCB2"
    sprintf(output, "%10lu $%04hx %c $%02hhx %3s %2s %2s %6s %6s %3s vpa $%02hhx vpb $%02hhx %4s %4s %4s %4s",
        cycle,
        addr,
        rw ? 'r' : 'W',
        data,
        irq ? "" : "IRQ",
        we ? "" : "WE",
        oe ? "" : "OE",
        rom_ce ? "" : "ROM_CE",
        ram_ce ? "" : "RAM_CE",
        via ? "" : "VIA",
        vpa,
        vpb,
        vca1 ? "VCA1" : "vca1",
        vca2 ? "VCA2" : "vca2",
        vcb1 ? "VCB1" : "vcb1",
        vcb2 ? "VCB2" : "vcB2"
        );

    Serial.println(output);

    // "b addr" sets breakpoint and runs until addr is found
    // "r" runs until the next breakpoint
    // anything else steps a half cycle
    String input;
    Serial.print("> ");

    while (Serial.available() == 0);
    input = Serial.readStringUntil('\n');
    if (input.startsWith("b")) {
      breakpoint = (word) strtoul(input.substring(1).c_str(), NULL, 16);
      sprintf(output, "b = $%04hx", breakpoint);
      Serial.println(output);
      step_mode = false;
    } else if (input.startsWith("r")) {
      step_mode = false;
    }
  } else {
    // In run mode, any key breaks into step mode
    if (Serial.read() != -1) {
      step_mode = true;
    }
  }
}
