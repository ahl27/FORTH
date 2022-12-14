;;;
;;; Aidan Lakshman
;;;
;;; FORTH for the 65C02
;;;
;;; Memory Map:
;;;
;;; $0000-7FFF: RAM (32 KiB)
;;; $8000-9FFF: I/O
;;; $A000-BFFF: Not decoded
;;; $C000-FFFF: ROM (16 KiB)
;;;
;;; Symon Memory Map:
;;;
;;; $0000-7FFF: RAM (32 KiB)
;;; $8000-800F: 6522 VIA
;;; $8800-8803: 6551 ACIA Serial Console
;;; $8804-BFFF: CRTC or not decoded (ignore)
;;; $C000-FFFF: ROM (16 KiB)
;;;
;;; Development will start with the Symon Simulator, then be ported to hardware
;;; Initial Design based on SECND (https://github.com/dourish/secnd/blob/master/secnd1.a65)
;;; Will be adapted once the implementation is working at a base level
;;;
;;; This will be compiled using NASM

;;;
;;; Variables/Setup
;;; (zero paging common variables for speed)

;;; 2 byte variables
IP=$0050                   ; Forth instruction pointer
RP=$0052                   ; return stack pointer
DT=$0054                   ; pointer to top of dictionary stack
TMP1=$0056                 ; temp value
TMP2=$0058                 ; temp value

;; 1 byte variables
TPTR=$005A
TCNT=$005B

;; other
DPTR=$005C
INPUT=$7F00                ; input space
WORDSPC=$7EC0              ; temp space for parsing words (<=63 chars)

jmp initstart


;;;
;;; Initialization/Configuration
;;;
initstart:
  ldx #$FF                 ; initializes stack pointer to 00FF, top of zero page
  
  ;; Initializing values for variables

  stz IP                   ; zero out the instruction pointer
  stz IP+1

  stz RP                   ; store $0200 in return stack pointer (second page of memory)
  lda #$02                 ; this stack will grow upwards
  sta RP+1


  ;; Initialize dictionary top to last entry on dictionary (defined below)
  lda #d0entry 
  sta DT                   ; store first byte
  INA
  sta DT+1                 ; store second byte


  ;; jump to test code
  jmp gotest



;;;
;;; Dictionary
;;;

;;; TODO, just have one entry as a placeholder
d0entry:
  BYTE 4
  BYTE "exit"
d0link:
  WORD $0000
d0code:
  WORD exit


;;; Test code will go here
gotest:
  nop
  jmp gotest



