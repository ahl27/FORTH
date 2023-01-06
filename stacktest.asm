#include "memlocs.asm"
* = ROMSTART

;; Quick tests to make sure the stack is working properly

;; main noop loop

main
  jsr initstack
  ;jsr pushtest1
  ;jsr pushtest2
  ;jsr pushzero
  ;jsr pop16
  ;jsr swap16
  ;jsr add16
  ;jsr sub16
  ;jsr dup16
  ;jsr pop16

  ;; multiplication
  ;; running all three multtests should store 0x0050, 0x7008, 0x1E08
  ;jsr multtest1
  ;jsr multtest2
  ;jsr multtest3   

  ;; division with remainder 
  ;; running all three tests should store 0x00A1, 0x008A, 0x001A     
  jsr divtest1
  jsr divtest2
  jsr modtest

  brk


#include "stack16.asm"

;; test pushing
pushtest1
  ;; push ABCD to stackaccesss
  lda #$CD
  sta stackaccess
  lda #$AB
  sta stackaccess+1
  jsr push16
  rts

pushtest2
  lda #$01
  sta stackaccess
  lda #$00
  sta stackaccess+1
  jsr push16
  rts

multtest1:            ; 10 * 8 = 80 (0x50), this test has no rollover
  lda #$0A
  sta stackaccess
  lda #$00
  sta stackaccess+1
  jsr push16
  lda #$08
  sta stackaccess
  lda #$0
  sta stackaccess+1
  jsr push16
  jsr mult16
  rts

multtest2:            ; 0x04AB * 0x0018 = 0x7008, this test has rollover
  lda #$AB
  sta stackaccess
  lda #$04
  sta stackaccess+1
  jsr push16
  lda #$18
  sta stackaccess
  lda #$00
  sta stackaccess+1
  jsr push16
  jsr mult16
  rts

multtest3:            ; 0x04AB * 0x0A18 = 0x002F1E08 = 0x1E08, this test has rollover and overflows
  lda #$AB
  sta stackaccess
  lda #$04
  sta stackaccess+1
  jsr push16
  lda #$18
  sta stackaccess
  lda #$0A
  sta stackaccess+1
  jsr push16
  jsr mult16
  rts

divtest1:             ; 0x0A10 / 0x0010 = 0x00A1, Remainder 0x0000
  lda #$10
  sta stackaccess
  lda #$0A
  sta stackaccess+1
  jsr push16

  lda #$10
  sta stackaccess
  lda #$00
  sta stackaccess+1
  jsr push16
  jsr div16
  rts


divtest2:             ; 0x8A1A / 0x0100 = 0x008A, Remainder 0x001A
  jsr divmodsetup
  jsr div16
  rts

modtest:              ; Same as divtest2, should save remainder
  jsr divmodsetup
  jsr mod16
  rts

divmodsetup:
  lda #$1A
  sta stackaccess
  lda #$8A
  sta stackaccess+1
  jsr push16

  lda #$00
  sta stackaccess
  lda #$01
  sta stackaccess+1
  jsr push16
  rts

pushzero
  lda #$00
  sta stackaccess
  sta stackaccess+1
  rts

.dsb $fffa-*,$ff
.word $00
.word ROMSTART
.word $00