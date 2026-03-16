# My notes for conio

* bgcolor(color)
    - Set BG color. System dependent.
    - valid for whole screen
* bordercolor(color)
    - set border color. system dependent.
* cclear(length)
    - overwrite part of a line by writing spaces
    - where does the cursor end up?
    - line wrap?
* cclearxy(x, y, length)
    - clear part of a line by writing spaces at a given position
    - cursor? line wrap?
* char cgetc()
    - fetch a character
    - wait if buffer is empty
    - pass through crlf and bs? tab?
* char\* cgets(\*buffer, size)
    - c: cgets.c
    - reads size - 1 characters from console into buffer and returns
    - returns on cr or lf
    - handles multi-line input and backspace
    - does multi-line input mean line wrap is supported?
    - echoes crlf on screen when cr or lf read from buffer but does not put it in buffer
* chline(length)
    - output horizontal line to screen of given length in text mode
    - line drawing character
    - line that goes off edge of screen leads to undefined behavior
* chlinexy(x, y, length)
    - same as above, with coords
* clrscr()
    - clear the screen
    - cursor in upper left corner
* cpeekc()
    - get character at cursor from display memory
    - converted into encoding that can be passed to cputc
    - doesn't move cursor
* cpeekcolor()
    - get color at current location of cursor
    - might turn bg in high nibble, text color in low nibble
* cpeekrevers()
    - get a reverse-character attribute from the display memory
    - return boolean that can be passed to revers()
* int cprintf(format, ...)
    - like c printf
    - distinguishes between cr and lf
* cputc(char)
    - output character to console at current cursor position
    - distinguishes between \r and \n
* cputcxy(x, y, c)
    - above at specified position
* cputs(char \*s)
    - output string to console
    - \r and \n
* cputsxy(x, y, char \*s)
    - above with coords
* int cscanf(char \*format, ...)
    - scans input from console with format like c scanf
    - control characters like backspaces are not recognized
    - maybe use cgets() to retrieve and sscanf() to parse
* cursor(char onoff)
    - enable blinking cursor
* cvline(length)
    - vertical line at cursor position
    - drawing downward?
* cvlinexy(x, y, length)
* gotox(x)
    - move text mode cursor to new x position
    - offscreen coords is undefined
* gotoxy(x, y)
    - top left is 0,0
* gotoy(y)
* char kbhit()
    - check the keyboard buffer
* revers(onoff)
    - control reverse character display
    - may not be supported by hardware
* screensize(\*x, \*y)
* uchar textcolor (uchar)
    - sets text color
    - returns old text color
    - colors are system dependent
* vcprintf(char \*format, va_list ap)
* uchar wherex()
* uchar wherey()

Everything typed is printed?

Functions implemented by cc65 lib:

    * cgets
        - libsrc/conio/cgets.c
    * cprintf
        - libsrc/conio/cprintf.s
    * cputs
        - libsrc/conio/cputs.s
    * cputsxy
        - libsrc/conio/cputs.s
    * cscanf
        - libsrc/conio/cscanf.s
    * cursor
        - libsrc/conio/cursor.s

