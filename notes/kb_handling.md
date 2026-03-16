# Keyboard Scancode Handling

* If buffer is empty:
    Return no ascii (set carry flag).
* Save a copy of the buffer entry and increment the read pointer.
* If scancode high bit is set:
    * Process high bit jump table (F7 and Pause will need make and break branches).
    * Repeat.
* If "break" was previous scancode:
    * Process low bit "break" jump table (includes mix of "e0" and normal breaks).
    * Repeat.
* If either Alt is held:
    * Repeat. (unimplemented)
* If "e0" was previous code:
    * Process low bit "make" jump table.
    * Repeat.
* Lookup if key is modified by shift-only, shift^caps, shift^num, or none.
* Lookup in one of two ascii maps. Which one depends on lookup above.
* If either Ctrl is held:
    * If ascii makes carat code:
        * Return it and clear carry flag.
    * (else) Repeat.
* If ascii is $00:
    * Process low bit "make" jump table.
    * Repeat.
* Return the ascii (Put it in A and clear carry flag).

```
; keyboard scan codes
        ; $00:          F9              F5      F3      F1      F2      F12
        ; $08:          F10     F8      F6      F4      TAB     `
        ; $10:          LALT    LSHIFT          LCTRL   Q       1
        ; $18:                  Z       S       A       W       2
        ; $20:          C       X       D       E       4       3
        ; $28:          " "     V       F       T       R       5
        ; $30:          N       B       H       G       Y       6
        ; $38:                  M       J       U       7       8
        ; $40:          ,       K       I       O       0       9
        ; $48:          .       /       L       ;       P       -
        ; $50:                  '               [       =
        ; $58:  CAPSLCK RSHIFT  ENTER   ]               \
        ; $60:                                                  BKSP
        ; $68:          N1              N4      N7
        ; $70:  N0      N.      N2      N5      N6      N8      ESC     NUMLOCK
        ; $78:  F11     N+      N3      N-      N*      N9      SCRLOCK
; "E0" codes
        ; $11:  RALT
        ; $12:  PRTSC1
        ; $14:  RCTRL
        ; $1f:  LGUI
        ; $27:  RGUI
        ; $2f:  APPS
        ; $5a:  NENTER
        ; $69:  END
        ; $6b:  LEFT
        ; $6C:  HOME
        ; $70:  INSERT
        ; $71:  DEL
        ; $72:  DOWN
        ; $74:  RIGHT
        ; $75:  UP
        ; $7a:  PGDN
        ; $7c:  PRTSC2
        ; $7d:  PGUP
        ; $e1, $14, $77, $e1, $f0, $14, $f0, $77        PAUSE pressed/released
```
