;;; 16-bit stack used for internal operations
;;;
;;; Forth depends on a 16-bit data stack, 
;;; which the 6502 doesn't have
;;;
;;; So this file will set up a stack to be used internally,
;;; along with some basic core functionality

;;;
;;; Stack Memory Definitions
;;;

;; We're putting the stack at the top half of the zero page
;; It'll grow downward towards $80 (from $FF)
;;
;; x register indexes the stack (so x is the top of the stack)
;; dex will grow the size of the stack, inx decreases (push/pop, resp.)
;;
;; $80, $81 hold the 16-bit value going onto or coming off the stack
;; All data will be stored little-endian so that loading with builtins
;; is a lot easier
stackaccess = $80
stackbase = $00

initstack:
  ldx #$FF              ; top of stack
  rts

;;;
;;; Basic Operations
;;;

;; Push a 16-bit value from $80 into stackbase,x and decrement x
;; value comes from stackaccess (must store first)
push16:
  lda stackaccess+1     ; first byte (big end)
  sta stackbase,x
  dex
  lda stackaccess     ; second byte (little end)
  sta stackbase,x
  dex 
  rts

;; Pop a 16-bit value into stackaccess
;; Uses: A, stackaccess
pop16:
  inx                 ; start by moving up one place in stack
  lda stackbase,x               
  sta stackaccess     ; first byte (big end)
  inx
  lda stackbase,x               
  sta stackaccess+1   ; second byte (little end)
  rts

;; Duplicate top value onto stack
dup16:
  lda stackbase+2,x             ; load first byte of previous stack entry
  sta stackbase,x               ; store it at top of stack
  dex                   
  lda stackbase+2,x             ; repeat for second byte
  sta stackbase,x
  dex
  rts

;; Swap top two values of stack
;; Note: uses stackaccess, so if you need to pop-swap-push,
;;       ensure stackaccess value is stored in TMP before calling swap
swap16:
  ; start by moving the top value into stackaccess
  lda stackbase+1,x             ; first byte (big end) in stackaccess
  sta stackaccess
  lda stackbase+2,x             ; second byte (little end) in stackaccess+1
  sta stackaccess+1

  ; copy second entry to top
  lda stackbase+3,x
  sta stackbase+1,x
  lda stackbase+4,x
  sta stackbase+2,x

  ; copy 2 stackaccess bytes to second entry
  lda stackaccess
  sta stackbase+3,x
  lda stackaccess+1
  sta stackbase+4,x

  rts

;; Add top two values of stack, leaving result on top
add16:
  clc                 ; clear carry bit

  ; add lower byte (LSB) and store in second slot
  lda stackbase+1,x
  adc stackbase+3,x
  sta stackbase+3,x

  ; add upper byte (MSB) and store in second slot
  lda stackbase+2,x
  adc stackbase+4,x
  sta stackbase+4,x

  ; shrink the stack so the sum is now on top
  inx
  inx
  rts

;; Same as add16, but for subtract
sub16:
  sec                 ; set carry bit

  ; subtract lower byte
  lda stackbase+3,x
  sbc stackbase+1,x
  sta stackbase+3,x

  ; subtract upper byte
  lda stackbase+4,x
  sbc stackbase+2,x
  sta stackbase+4,x

  ; shrink stack so difference on top
  inx
  inx
  rts

