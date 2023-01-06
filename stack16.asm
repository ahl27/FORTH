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

;; Multiply two unsigned binary 16 bit numbers
;; I'm using Russian peasant multiplication:
;;    1. Write the multiplier (m) and the multiplicand (c)
;;    2. If c is odd, add m to the sum, else skip
;;    3. Halve c (drop remainder) and double m
;;    4. Repeat 2-3 until c==0
mult16:
  ; First add some space on the stack
  dex
  dex

  ; Initialize both entries to zero
  stz stackbase+1,x
  stz stackbase+2,x
  
  ; run the algorithm
  mult16loop:
    lda #$01
    bit stackbase+5,x         ; test is c is odd
    .(
      beq skip                ; skip to shift if even
      clc                     ; else add
      lda stackbase+3,x
      adc stackbase+1,x
      sta stackbase+1,x
      lda stackbase+4,x
      adc stackbase+2,x
      sta stackbase+2,x
      skip:
    .)

    ;; Bitshift the values
    clc
    asl stackbase+3,x         ; multiply m by two (note MSB is at highest address)
    rol stackbase+4,x

    clc
    lsr stackbase+6,x         ; divide c by two, starting with LSB
    ror stackbase+5,x

    ;; Check if the multiplier is now zero
                             ; check if c is zero
    lda #$FF
    bit stackbase+5,x
    bne mult16loop
    bit stackbase+6,x
    bne mult16loop

  ; store the result
  lda stackbase+1,x
  sta stackbase+5,x
  lda stackbase+2,x
  sta stackbase+6,x

  ; shrink stack back down two positions
  inx
  inx
  inx
  inx
  rts

;;;
;;; 16-bit division
;;; remainder will also be stored at top of stack
;;; Top element treated as divisor, bottom as numerator
;;;
div16withmod:
  ;; Max iterations is 16 = 0x10, since we have 16 bit numbers
  phy
  ldy #$10 

  ;; add two spaces on stack
  dex
  dex
  dex
  dex

  stz stackbase+1,x             ; remainder
  stz stackbase+2,x
  stz stackbase+3,x             ; quotient
  stz stackbase+4,x
                                ; +5-6 is denominator
                                ; +7-8 is numerator

  ;; Set up the numerator
  .(
    lda #0
    ora stackbase+8,x
    ora stackbase+7,x
    beq earlyexit

    ;; checking is denominator is zero (if so we'll just store zeros)
    lda #0
    ora stackbase+6,x
    ora stackbase+5,x
    bne loop

    earlyexit:
      ;; Numerator or denominator are zero, just return
      stz stackbase+6,x
      stz stackbase+5,x
      inx
      inx
      inx
      inx
      ply
      rts

    ;; Trim down to leading bit
    loop:
      lda stackbase+8,x
      bit #%10000000            ; test upper bit
      bne end
      clc
      asl stackbase+7,x
      rol stackbase+8,x
      dey
      jmp loop
    end:
  .)

  ;; Main division loop
  .(
    loop:
      ;; Left-shift the remainder
      clc
      asl stackbase+1,x         
      rol stackbase+2,x

      ;; Left-shift the quotient
      clc
      asl stackbase+3,x
      rol stackbase+4,x


      ;; Set least significant bit to bit i of numerator
      clc
      asl stackbase+7,x
      rol stackbase+8,x

      lda stackbase+1,x
      adc #0
      sta stackbase+1,x
      lda stackbase+2,x
      adc #0
      sta stackbase+2,x

      ;; Compare remainder to denominator
      ; upper byte (stackbase+2 is already in A)
      cmp stackbase+6,x
      bmi skip                  ; if R < D, skip to next iteration 
      bne subtract              ; if R > D, we can skip comparing lower byte
                                ; if R = D, we have to check the lower byte   
                                
      ; lower byte
      lda stackbase+1,x
      cmp stackbase+5,x
      bmi skip

    subtract:
      ;; Subtract denominator from remainder
      sec
      ; subtract lower byte
      lda stackbase+1,x
      sbc stackbase+5,x
      sta stackbase+1,x

      ; subtract upper byte
      lda stackbase+2,x
      sbc stackbase+6,x
      sta stackbase+2,x

      ;; Add one to quotient
      inc stackbase+3,x


    skip:
      dey
      beq exit
      jmp loop

    exit:  
  .)

  ;; Cleanup
  lda stackbase+1,x
  sta stackbase+5,x
  lda stackbase+2,x
  sta stackbase+6,x

  lda stackbase+3,x
  sta stackbase+7,x
  lda stackbase+4,x
  sta stackbase+8,x

  inx
  inx
  inx
  inx
  ply
  rts


;;;
;;; Division helper functions
;;;
div16:
  jsr div16withmod
  inx
  inx
  rts

mod16:
  jsr div16withmod
  lda stackbase+1,x
  sta stackbase+3,x
  lda stackbase+2,x
  sta stackbase+4,x
  inx
  inx
  rts