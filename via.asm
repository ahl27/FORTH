#ifndef memlocs_incl
#define memlocs_incl true
#include "memlocs.asm"
#endif

VIA_PORTB = VIA
VIA_PORTA = VIA+1
VIA_DDRB = VIA+2
VIA_DDRA = VIA+3
VIA_T1CL = VIA+4
VIA_T1CH = VIA+5
VIA_ACR = VIA+$0B
VIA_IFR = VIA+$0D
VIA_IER = VIA+$0E

TOGGLETIME = DELAYCOUNT+4
TODELAY = DELAYCOUNT+5

; low and high bits of counter (in microseconds)
; C350 is equivalent to 50,000 = 50ms
; note that continuous interrupts trigger every n+2 interrupts
; so for 10ms delay, set to 9998 = 270E
; for 9600 baud = 1.04ms for a char, use 1038 = 040E
TDLOW = $0E
TDHIGH = $04

; 0000 0000 in ACR initializes to one shot mode
; 0100 0000 in ACR initializes to continuous interrupts

reset_via:
  lda #$FF    ; set all pins on port A to output
  sta VIA_DDRA
  lda #0
  sta VIA_PORTA    
  sta TOGGLETIME
  jsr init_via_timer
  rts

init_via_timer:
  ; initialize counts of delay
  lda #0
  sta DELAYCOUNT
  sta DELAYCOUNT+1
  sta DELAYCOUNT+2
  sta DELAYCOUNT+3
  lda #%01000000  ; continuous interrupts
  sta VIA_ACR
  lda TDLOW
  sta VIA_T1CL
  lda TDHIGH
  sta VIA_T1CH
  ; enable interrupts for timer 1 and processor
  lda #%11000000
  sta VIA_IER
  cli   
  rts

delay_once_via:
  pha
  lda DELAYCOUNT
  sta TOGGLETIME
  .(
    loop:
      sec
      lda DELAYCOUNT
      sbc TOGGLETIME
      beq loop
  .)
  pla
  rts


; Interrupt handler, triggers every x seconds ( x set by TDHIGH TDLOW )
nmi:
irq:
  bit VIA_T1CL  ; read interrupt without clearing it (to acknowledge)
  inc DELAYCOUNT
  bne end_irq
  inc DELAYCOUNT+1
  bne end_irq
  inc DELAYCOUNT+2
  bne end_irq
  inc DELAYCOUNT+3
end_irq:
  rti

