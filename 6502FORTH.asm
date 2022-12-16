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
;;;

;;; 2 byte variables
IP=$50                    ; Forth instruction pointer
RP=$52                    ; return stack pointer
DT=$54                    ; pointer to top of dictionary stack
TMP1=$56                  ; temp value
TMP2=$58                  ; temp value

;; 1 byte variables
TPTR=$5A
TCNT=$5B

;; other
DPTR=$5C
INPUT=$7F00                ; input space
WORDSPC=$7EC0              ; temp space for parsing words (<=63 chars)

jmp initstart

;;;
;;; Initialization/Configuration
;;;
initstart:
  ldx #$FF                 ; initializes stack pointer to $00FF, top of zero page
  
  ;; Initializing values for variables

  stz IP                   ; zero out the instruction pointer
  stz IP+1

  stz RP                   ; store $0200 in return stack pointer (second page of memory)
  lda #$02                 ; this stack will grow upwards
  sta RP+1


  ;; Initialize dictionary top to last entry on dictionary (defined below)
  lda #d0entry 
  sta DT                   ; store first byte
  ina
  sta DT+1                 ; store second byte


  ;; jump to test code
  jmp gotest



;;;
;;; Dictionary
;;;
;;; Each entry contains up to 5 values:
;;; - 1 byte w/ upper three bits corresponding to tags, 
;;;     lower 5 corresponding to word length
;;; - characters comprising the word definition name
;;; - pointer to next entry
;;; - "code word": address of coding handling this instruction
;;;     (usually DOLIST for compiled words)
;;; - parameter space
;;;     (usually list of addresses to execute this word, ending w/ EXIT)

;;; TODO, just have one entry as a placeholder
d0entry:
  BYTE 4
  BYTE "exit"
d0link:
  WORD $0000
d0code:
  WORD exit


;;; Test Dictionary Entries go here
doquitword
  BYTE 0
doquitlink
  WORD $0000
doquitcode
  WORD interploop

dummy
  BYTE 0
dummylink
  WORD $0000
dummycode
  WORD dolist      ; won't actually run this, start with NEXT instead
dummyparam
  WORD $0000       ; will write in the actual code link word here
  WORD doquitcode

;;;
;;; Inner Interpreter
;;;
;;; This section implements the core routines NEXT, DOLIST, and EXIT
;;;
;;; NEXT moves from one instruction to the next inside a defined word
;;; This will be called in *every* assembly language routine.
;;;   - increments instruction pointer
;;;   - loads location pointed to by IP
;;;   - jumps to that location
;;;
;;; DOLIST begins execution of a compiled word.
;;;   - stores instruction pointer on return stack
;;;   - resets instruction pointer to new word
;;;   - calls NEXT to start executing new word
;;;
;;; EXIT is the last address of all compiled words.
;;;   - undoes what DOLIST did
;;;   - jumps back to earlier execution context
;;;
;;; Stack pointed to by RP keeps track of these jumps, none are subroutines

;;; DOLIST Definition ;;;
dolist:
  ;; First, we store the instruction pointer on the return stack
  lda IP
  sta (RP)
  inc RP
  lda IP+1
  sta (RP)
  inc RP

  ;; Next, we get the address stored at the location in IP 
  ;; (double indirect access) and store in IP
  lda (IP)
  sta TMP1
  ldy #1
  lda (IP),y
  sta IP+1
  lda TMP1
  sta IP

  ;; IP now points to the code word of defined word we want
  ;; to execute, so we can just fall through to next
  ; jmp next

;;; ENSURE DOLIST FALLS THROUGH TO NEXT!!

;;; NEXT Definition ;;;
next:
  ;; finding the location of the next word
  ;; we advance 2 bytes
  ;; bne skips upper byte if we haven't rolled over
  inc IP
  bne .cont1
  inc IP+1
.cont1:
  inc IP
  bne .cont2
  inc IP+1
.cont2:
  ;; IP now points at location of next word to execute.
  ;; We need to fetch that location, then store it in TMP1.
  ldy #0 
  lda (IP),y
  sta TMP1
  iny
  lda (IP),y
  sta TMP1+1

  ;; Now we load the code address stored in TMP1 into TMP2
  lda (TMP1),y
  sta TMP2+1
  dey
  lda (TMP1)
  sta TMP2

  ;; Finally, we jump to the address stored in TMP2
  jmp (TMP2)  


;;; EXIT Definition ;;;
exit:
  ;; remove an address from return stack
  dec RP
  dec RP

  ;; Take the value that was on return stack
  ;; and replace it in instruction pointer
  ldy #1
  lda (RP),y
  sta IP+1
  lda (RP)
  sta IP

  ;; Finally, execute the next instruction
  jmp next


;;; DOLIT Definition ;;;



;;; Test code will go here
gotest:
  nop
  jmp gotest



