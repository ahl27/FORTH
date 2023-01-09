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
;;; This will be compiled using xa65

;;;
;;; Variables/Setup
;;; (zero paging common variables for speed)
;;;

* = $0300                 ; Program counter

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
DPTR=$5C                   ; Stores start of the entry for the word to execute
                           ;       its code word is at (DPTR) + wordlength + 1 (len) + 2 (link)
INPUT=$7F00                ; input space
WORDSPC=$7EC0              ; temp space for parsing words (<=63 chars)

bra initstart

;;;
;;; Initialization/Configuration
;;;
initstart:
  jsr initstack            ; initializes stack pointer to $00FF, top of zero page
  
  ;; Initializing values for variables

  stz IP                   ; zero out the instruction pointer
  stz IP+1

  stz RP                   ; store $0200 in return stack pointer (second page of memory)
  lda #$02                 ; this stack will grow upwards
  sta RP+1


  ;; Initialize dictionary top to last entry on dictionary (defined below)
  lda #<d7entry 
  sta DT                   ; store first byte
  lda #>d7entry
  sta DT+1                 ; store second byte


  ;; jump to test code
  bra gotest

;;;
;;; File Includes
;;;
#include "stack16.asm"
#include "acia.asm"
#include "via.asm"

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
  .byte 4
  .byte "exit"
d0link:
  .word $0000
d0code:
  .word exit

d1entry:
  .byte 1
  .byte "+"
d1link:
  .word d0entry
d1code:
  .word doplus

d2entry:
  .byte 1
  .byte "*"
d2link:
  .word d1entry
d2code:
  .word dotimes

d3entry:
  .byte 3
  .byte "dup"
d3link:
  .word d2entry
d3code:
  .word dodup

d4entry:
  .byte 4
  .byte "swap"
d4link:
  .word d3entry
d4code:
  .word doswap

d5entry:
  .byte 1
  .byte "/"
d5link:
  .word d4entry
d5code:
  .word dodiv

d6entry:
  .byte 3
  .byte "mod"
d6link:
  .word d5entry
d6code:
  .word domod

d7entry:
  .byte 5
  .byte "dolit"
d7link:
  .word d6entry
  .word dolit

;;; Test Dictionary Entries go here
doquitword
  .byte 0
doquitlink
  .word $0000
doquitcode
  .word interploop

dummy
  .byte 0
dummylink
  .word $0000
dummycode
  .word dolist      ; won't actually run this, start with NEXT instead
dummyparam
  .word $0000       ; will write in the actual code link word here
  .word doquitcode

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
  ; bra next

;;; ENSURE DOLIST FALLS THROUGH TO NEXT!!

;;; NEXT Definition ;;;
next:
  ;; finding the location of the next word
  ;; we advance 2 bytes
  ;; bne skips upper byte if we haven't rolled over
.(
  inc IP
  bne continue
  inc IP+1
  continue:
.)
.(
  inc IP
  bne continue
  inc IP+1
  continue:
.)
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
  bra (TMP2)  


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
  bra next


;;; DOLIT Definition ;;;
dolit:
  ; dolit operates on the word list of the word
  ; from which it's called.
.(
  ; Increment IP to next cell (stores the value to go to)
  inc IP
  bne continue
  inc IP+1
  continue:
.)
.(
  inc IP
  bne continue
  inc IP+1
  continue:
.)
  ; load the value in the next cell
  ldy #0 
  lda (IP),y

  ; push to data stack
  sta stackaccess
  iny
  lda (IP),y
  sta stackaccess+1
  jsr push16

  ; then jump to next to execute
  bra next


;;;
;;; Built-In Primitives
;;;
doplus:
  jsr add16
  bra next

dominus:
  jsr sub16
  bra next

dodup:
  jsr dup16
  bra next

dodrop:
  jsr pop16
  bra next

doswap:
  jsr swap16
  bra next

dotimes:
  jsr mult16
  bra next

dodiv:
  jsr div16
  bra next

domod:
  jsr mod16
  bra next

;;; Test code will go here
gotest:
  nop
  bra gotest


;;;
;;; Interpreter
;;;

startinterp:
  ;; Initialize buffer
  jsr reset_acia

startup_message:
  ;; Load startup message into buffer
  ldy #0
  .(
    loop:
      lda message,y
      beq exit
      jsr acia_wbuff_char
      iny
      bra loop
    exit:
  .)
  .(
    loop:
      lda OPT1
      cmp OPT2
      beq main_interp_loop
      jsr acia_send_char
      bra loop
  .)
main_interp_loop:
 jsr acia_read_word
 bra main_interp_loop           ; obviously this will be changed later

matchword:
  ;; Initialize the dictionary pointer
  lda DT
  sta DPTR
  lda DT+1
  sta DPTR+1

nextentry:
  ;; When DPTR is $0000, we're out of dictionary entries
  lda DPTR
  bne compareentry
  lda DPTR+1
  beq nomatch

compareentry:
  ;; Check for a word match
  ;; Start by checking word lengths, then letters
  ldy #0
  lda (DPTR),y
  and #%00011111        ; mask off leading three bits (tag)
  cmp WORDSPC,y         ; compare word lengths
  bne trynext           ; no match, try next one

  ;; else we compare letters directly
  ldy WORDSPC             ; load length of word, increment from end to front
  .(
    nextchar:
      lda (DPTR),y
      cmp WORDSPC,y
      bne trynext         ; if letter not same, continue to next word
      dey                 ; else go to the previous letter
      bne nextchar        ; if this gets to zero, we've matched everything in the word
  .)
  bra gotmatch

trynext:
  ;; Loop to next entry
  ;; recall DPTR points to start of entry for the word to execute
  ;; DPTR + wordlength + 1 is the next entry (linked word)
  ;; DPTR + wordlength + 1 + 2 is the codeword for that entry

  lda (DPTR)              ; get word length
  tay                     ; store in y, add one for pointer to next entry
  iny
  lda (DPTR),y            ; update DPTR to point to next entry
  sta TMP1
  iny                     ; nextentry checks if we're out of entries
  lda (DPTR),y            ; just to be sure, we'll store the previous entry
  sta DPTR+1              ; at DPTR+1, in case the current entry is 0
  lda TMP1
  sta DPTR
  bra nextentry

gotmatch:
  ;; if we have a match, we need the code word
  ;; this is at DPTR+wordlength+1+2
  lda (DPTR)              ; word length
  and #%00011111          ; mask off tag bits
  inc                     ; +1 for length byte
  inc                     ; +2 for link word
  inc                     
  clc
  adc DPTR                ; add to address and store in dummy word entry
  sta dummyparam
  lda DPTR+1
  adc #$0
  sta dummyparam+1

  ;; put dummy parameter address into IP
  ;; NEXT will increment it, so it'll be the code address
  lda #<dummycode
  sta IP
  lda #>dummycode
  sta IP+1

  ;; start execution by jumping to NEXT
  bra next

  ;; If not in dictionary, we can try to parse as a number

nomatch:
  ;; First we need to check that all letters are digits
  ldy WORDSPC

numcheck:
  ;; 0-9 are ascii codes 0x30 - 0x39
  lda WORDSPC,y
  cmp #$30                ; carry is set if Register < Memory
  bcc nointerpret         ; branches if strictly less than (letter < 0x30)
  cmp #$3A                ; Paul Dourish uses 0x40 here, which feels like a mistake
  bcs nointerpret         ; branches if greater than or equal (letter >= 0x40)
  dey
  bne numcheck

  ;; Convert to number then push to stack
  ldy WORDSPC
  iny
  lda #0
  sta WORDSPC,y           ; null-terminate the string
  lda #<WORDSPC           ; put address on stack threshold
  sta stackaccess
  lda #>WORDSPC
  sta stackaccess+1
  .(
    inc stackaccess       ; first address is count, need to skip
    bne done
    inc stackaccess+1
    done:   
  .)
  jsr pushdec16           ; interpret as decimal and push
  ;jsr readdec16           ; convert value and leave on stack
  bra main_interp_loop

nointerpret:
  bra main_interp_loop    ; I'll write this later

greeting:
  .aasc "Welcome to FORTH!\n"
  .dsb 1,0

.dsb $fffa-*,$ff
.word $00
.word ROMSTART
.word $00  
