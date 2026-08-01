; SPDX-License-Identifier: MIT
; console.s
; cc65 library console calls

        .include "bv6502.inc"

        .import popa

        .macro FN_LIST job, arg
                job arg, _bgcolor
                job arg, _cclear
                job arg, _cclearxy
                job arg, _cgetc
                job arg, _clrscr
                job arg, _cpeekc
                job arg, _cpeeks
                job arg, _cputc
                job arg, _cputcxy
                job arg, _gotox
                job arg, gotoxy
                job arg, _gotoxy
                job arg, _kbhit
                job arg, _revers
                job arg, screensize
                job arg, _textcolor
                job arg, _wherex
                job arg, _wherey
        .endmacro

        .export _console_switch

        .macro FN_EXPORT na, stub
                .export .ident(.string(stub));
        .endmacro

        FN_LIST FN_EXPORT na

        .macro FN_IMPORT prefix, stub
                .import .ident(.concat(.string(prefix), .string(stub)))
        .endmacro

        FN_LIST FN_IMPORT con
        FN_LIST FN_IMPORT ft245

        .code

        .macro FN_REDIR prefix, stub
                .ident(.string(stub)) :
                        .byte $4C
                .ident(.concat(.string(stub), "_p")) :
                        .word .ident(.concat(.string(prefix), .string(stub)))
        .endmacro

        FN_LIST FN_REDIR con

        .macro FN_SET prefix, stub
                lda     #<.ident(.concat(.string(prefix), .string(stub)))
                sta     .ident(.concat(.string(stub), "_p"))
                lda     #>.ident(.concat(.string(prefix), .string(stub)))
                sta     .ident(.concat(.string(stub), "_p")) + 1
        .endmacro

_console_switch:
        ldy     #0
        cmp     #0
        beq     @con
        jmp     @ft245
@con:
        FN_LIST FN_SET con
        rts
@ft245:
        FN_LIST FN_SET ft245
        rts
