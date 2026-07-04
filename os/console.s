; SPDX-License-Identifier: MIT
; console.s
; cc65 library console calls

        .include "bv6502.inc"
        .include "via.inc"

        .import popa

        .macro FN_LIST job, arg
                job arg, bgcolor
                job arg, bordercolor
                job arg, cclear
                job arg, cclearxy
                job arg, cgetc
                job arg, chline
                job arg, chlinexy
                job arg, clrscr
                job arg, cpeekc
                job arg, cpeekcolor
                job arg, cpeekrevers
                job arg, cputc
                job arg, cputcxy
                job arg, cvline
                job arg, cvlinexy
                job arg, gotox
                job arg, gotoxy
                job arg, kbhit
                job arg, revers
                job arg, screensize
                job arg, textcolor
                job arg, wherex
                job arg, wherey
                job arg, setcursor
        .endmacro

        .export gotoxy, _console_switch

        .macro FN_EXPORT na, stub
                .export .ident(.concat("_", .string(stub)));
        .endmacro

        FN_LIST FN_EXPORT na

        .macro FN_IMPORT prefix, stub
                .import .ident(.concat(.string(prefix), "_", .string(stub)))
        .endmacro

        FN_LIST FN_IMPORT con
        FN_LIST FN_IMPORT acia


        .code

        .macro FN_REDIR prefix, stub
                .ident(.concat("_", .string(stub))) :
                        .byte $4C
                .ident(.concat(.string(stub), "_p")) :
                        .word .ident(.concat(.string(prefix), "_", .string(stub)))
        .endmacro

        FN_LIST FN_REDIR con

gotoxy:
        jsr     popa
        jmp     _gotoxy

        .macro FN_SET prefix, stub
                lda     #<.ident(.concat(.string(prefix), "_", .string(stub)))
                sta     .ident(.concat(.string(stub), "_p"))
                lda     #>.ident(.concat(.string(prefix), "_", .string(stub)))
                sta     .ident(.concat(.string(stub), "_p")) + 1
        .endmacro

_console_switch:
        ldy     #0
        cmp     #0
        beq     @con
        jmp     @acia
@con:
        FN_LIST FN_SET con
        rts
@acia:
        FN_LIST FN_SET acia
        rts
