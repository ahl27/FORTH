* = $0300

;; Quick tests to make sure the stack is working properly

;; main noop loop

main
  jsr initstack
  jsr pushtest1
  jsr pushtest2
  jsr pushzero
  ;jsr pop16
  ;jsr swap16
  jsr add16
  ;jsr sub16
  jsr dup16
  jsr pop16
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

pushzero
  lda #$00
  sta stackaccess
  sta stackaccess+1
  rts

