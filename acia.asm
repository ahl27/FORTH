;;;
;;; General I/O Functions
;;;
;;; I/O is handled with a MOS 6551 ACIA Serial Console
;;; On Symon, this is mapped to $8800-8803
;;; Simulator is programmed for 9600 baud (I think)
;;; ACIA has an onboard chip for controlling baud rate
#ifldef ACIA
#else
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
  lda #$0B
  sta ACIA_COMMAND
  lda #$1E
  sta ACIA_CONTROL
  pla
  rts

acia_echo:
  pha
  .(
    loop:
      lda ACIA_STATUS
      and #$10
      beq loop
      pla
      sta ACIA_TX
      jsr delay_once_via
  .)
  rts

acia_read:
  lda #$08
acia_rx_full:
  bit ACIA_STATUS       ; check to see if buffer is full (bit 3 is 1 if not empty)
  beq acia_rx_full
  lda ACIA_RX
  rts

; Includes
#ifldef VIA_PORTB
#else
  #include "via.asm"
#endif
