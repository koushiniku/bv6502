; SPDX-License-Identifier: MIT
;
; irq.s

        .include "bv6502.inc"

        .import _init, _stop

        .code

_nmi_int:
	 rti

_irq_int:
	 phx
	 tsx
	 pha
	 inx
	 inx
	 lda	$100,x
	 and	#$10
	 bne	break
irq:
	 jsr	callirq
	 pla
	 plx
	 rti

break:	 jmp	_stop

        .segment  "VECTORS"

        .addr	  _nmi_int	; NMI vector
        .addr	  _init		; Reset vector
        .addr	  _irq_int	; IRQ/BRK vector
