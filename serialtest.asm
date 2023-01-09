;;;
;;; Test script to try out serial functionality
;;;
;* = $0300
#ifndef memlocs_incl
#define memlocs_incl true
#include "memlocs.asm"
#endif

* = $C000

main:
  jsr reset_acia
  bra buffstringtest
mainloop:
  jsr acia_read_char
  jsr acia_rbuff_char
  jsr acia_wbuff_char
  jsr acia_send_char
  bra mainloop

buffstringtest:
  ldy #0
buffnextchar:
  lda message,y
  beq sendstring
  jsr acia_wbuff_char
  iny
  bra buffnextchar
sendstring:
  lda OPT1
  cmp OPT2
  beq mainloop
  jsr acia_send_char
  bra sendstring

message: 
  .aasc "Hello, world!"
  .dsb 1,0

#include "acia.asm"


; Solved using instruction from http://forum.6502.org/viewtopic.php?t=1393
; Move irq to end of code
; original solution of .byte has been changed to .dsb
.dsb $fffa-*,$ff
.word $00
.word ROMSTART
.word $00