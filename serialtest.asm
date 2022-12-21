

main:
  jsr reset_via
  jsr reset_acia
mainloop:
  jsr acia_read
  jsr acia_echo
  jmp mainloop


#include "via.asm"
#include "acia.asm"