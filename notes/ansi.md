# Notes on ANSI/ECMA/VT100/etc.

* ^[P: Device Control String (DCS)
* ^[[: Control Sequence Introducer (CSI)
* ^[\: String Terminator (ST)
* ^[]: Operating System Command (OSC)
* ^[O: Arrow keys, sometimes F1-F4 (but needs to be in this mode)

# What the terminal sends the host

* CSI P1..Pn I1..Im F
    * CSI: 0x1b or 0x9b
    * Intermediate bytes: 0x20-0x2F
    * Parameter: Numbers: 0x30-0x3B: 0-9:; One or more; may be semicolon separated
    * Private Prefix: < = > ? Terminal Specific
    * Final byte: 0x40-0x7e
* 2-byte ESC
    ^[<key>

# Conio Functions

* screensize
    * Send: ^[[18t
    * Receive: ^[[8;<height>;<width>t
* clrscr: clear the screen
    * Send: ^[[2J^[[H (clear display without moving cursor, then move home)
* cpeekc: get a character
    * Would need to track in a local mirror of the terminal.
* cpeekcolor: get character color
    * Can report what would be the color of the next character type, but not the current one under the cursor.
* cursor: enable cursor blinking
    * Show: ^[[?25h
    * Hide: ^[[?25l
    * Style: Blinking block (default) ^[1<sp>q
* gotox:
    * Send: ^[[<row>d
* gotoy:
    * Send: ^[[<col>G
* gotoxy:
    * Send: ^[[<row>;<col>H or ^[[<row>;<col>f
* revers(enable reverse character display)
* wherex,wherey
    * Send: ^[[6n
    * Receive: ^[[<row>;<col>R

# Functions that send a sequence and expect a response

* screensize
    * Send: ^[[18t
    * Receive: ^[[8;<height>;<width>t
* wherex,wherey
    * Send: ^[[6n
    * Receive: ^[[<row>;<col>R

These have a common function that:
    * Writes the command string to the terminal
    * Blocks for a response with a 300-500ms timeout
        * Use VIA for the timer?
    * Looks for ^[, [, some stuff, and a terminator
    * Characters stay in the rx buffer
    * Return good status if both ^[, [, ..., terminator seen
    * Return bad status on timeout, unexpected character, rx buffer full, etc.
    * Parse parameters, separators, terminator.
    * Keep index pointers to both ends of the escape sequence. Null these out so that they may be skipped by getc. Don't update the real read pointer as we may get keystrokes before the beginning of the escape sequence.

# Conio functions

* `_bgcolor`: can implement (send `^[[{4,10}<color>m`)
* `_bordercolor`: don't implement
* `_cclear`: can implement
* `_cclearxy`: can implement
* `_cgetc`: must implement
* `_cgets`: don't implement. common c implementation. Needs screensize, cursor, cgetc, strchr, cputs, wherex, wherey, gotoxy, cputc.
* `_chline`: don't implement
* `_clrscr`: can implement
* `_cpeekc`: implement dummy
* `_cpeekcolor`: don't implement
* `_cpeekrevers`: don't implement
* `_cpeeks`: implement dummy
* `_cprintf`: common asm implementation
* `_cputc`: must implement
* `_cputcxy`: can implement
* `_cputs`: don't implement. common asm implementation
* `_cputsxy`: don't implement. common asm implementation, uses gotoxy
* `_cscanf`: don't implement. common c implementation. uses cgetc, cputc
* `_cursor`: dont't implement. uses common asm implementation. sets "cursor" which is used by cgetc to enable cursor when blocking.
* `_cvline`: don't implement
* `_cvlinexy`: don't implement
* `_gotox`: must implement
* `_gotoxy`: must implement
* `gotoxy`: must implement. same as `_gotoxy` but with popa first
* `_gotoy`: must implement
* `_kbhit`: can implement
* `_revers`: implement dummy
* `_screensize`: don't implement. common asm implementation, but uses screensize
* `screensize`: implement. puts screensize into X and Y
* `textcolor`: can implement (send `^[[{3,9}<color>m`)
* `_vcprintf`: don't implement. common asm implementation.
* `_wherex`: must implement
* `_wherey`: must implement
