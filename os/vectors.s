; SPDX-License-Identifier: MIT
; vectors.s

        .include "bv6502.inc"

        .import _nmi_int, _init, _irq_int

        .segment "VECTORS"

        .addr   _nmi_int
        .addr   _init
        .addr   _irq_int
