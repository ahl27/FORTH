;;;
;;; Memory map for hardware
;;; Other files will implement specific values
;;;

VIA = $8000
ACIA = $8800
DELAYCOUNT = $02F9  ; 7 before program counter (4 byte number)
ROMSTART = $C000

IPT1 = $4C
IPT2 = $4D
OPT1 = $4E
OPT2 = $4F

IPTBUFF = $7E00
OPTBUFF = $7D00