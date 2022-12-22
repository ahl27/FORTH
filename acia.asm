;;;
;;; General I/O Functions
;;;
;;; I/O is handled with a MOS 6551 ACIA Serial Console
;;; On Symon, this is mapped to $8800-8803
;;; Simulator is programmed for 9600 baud (I think)
;;; ACIA has an onboard chip for controlling baud rate
#ifndef memlocs_incl
#define memlocs_incl true
#include "memlocs.asm"
#endif

ACIA_RX = ACIA         ; high here allows reading, low allows writing
ACIA_TX = ACIA
ACIA_STATUS = ACIA+1   ; Goes low when an interrupt occurs (?)
ACIA_COMMAND = ACIA+2
ACIA_CONTROL = ACIA+3  ; resets 

;; Initialization to 19200 baud is $1F
;;                to  9600 baud is $1E
;; Should be stored in ACIA_CONTROL

;; Command Register controls transmit/receive
;; Value $0B sets to:
;;    $0x: parity disabled, none generated or received, normal (non-echo) mode
;;    $xB: transmit interrupt disabled, rts low, irq disabled, enabled receiver/transmitter
;;
;; Send  

;; Example code taken from https://mike42.me/blog/2021-07-adding-a-serial-port-to-my-6502-computer
reset_acia:
  pha
  ; ACIA setup
  lda #$00
  sta ACIA_STATUS       ; writing anything to status resets the chip

  ; initialize io buffers to zero
  sta IPT1
  sta IPT2
  sta OPT1
  sta OPT2

  lda #$0B
  sta ACIA_COMMAND
  lda #$1E
  sta ACIA_CONTROL

  pla
  rts

; These will eventually need to be changed to be interrupt-driven
; not sure how I'll do that yet, but I can come back to it later
; Probably a good idea to make a buffer in memory, and then R/W 
; in the interrupt logic in the VIA code
acia_send_char:
  phy
  lda #$10              ; %0001 0000, bit corresponding to write ready
  ldy OPT2
acia_tx_full:
  bit ACIA_STATUS
  beq acia_tx_full
  lda OPTBUFF,y
  inc OPT2
  sta ACIA_TX
  ;jsr delay_once_via    ; this delay is recommended to fix 65C51 transmit bug
  ply
  rts

acia_read_char:
  phy
  lda #$08              ; %0000 1000, bit corresponding to read ready
  ldy IPT2
acia_rx_full:
  bit ACIA_STATUS       ; check to see if buffer is full
  beq acia_rx_full
  lda ACIA_RX
  sta IPTBUFF,y
  inc IPT2
  ply
  rts

acia_wbuff_char:
  phy
  ldy OPT1
  sta OPTBUFF,y
  inc OPT1
  ply
  rts

acia_rbuff_char:
  phy
  ldy IPT1
  lda IPTBUFF,y
  inc IPT1
  ply
  rts



; Includes
;#ifldef reset_via
;#else
;  #include "via.asm"
;#endif
