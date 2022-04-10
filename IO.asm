;******************************************************************************
; Amplifier Main Controller V1.1.0
;
; Feature summary:
;  - Controls a single or dual channel amplifier
;  - Stand alone or network amplifier
;  - User input interface and information display
;  - Audio potentiometer with 7 bit resolution
;  - Audio input and output configuration
;  - Power on/off control
;  - Audio output error detection
;
; File:	IO.asm
;
; Author: F.Fargon
;
; Purpose: 
;  - Low level IO control functions
;  - Device access via address/data bus
;******************************************************************************
	  

; Write a byte in a PIO register
; Arguments:
;  - r16 PIO index (0 to 5)
;  - r17 PIO register index
;  - r18 is the byte to write
WriteByteInPIORegister:
	
	ret


; Read a byte from a PIO register
; Arguments:
;  - r16 PIO index (0 to 5)
;  - r17 PIO register index
; Return:
;  - r16 register contains the read byte
ReadByteFromPIORegister:

	ret


; Write a byte in the internal ouput latch
; Arguments:
;  - r16 is the byte to write
WriteByteInOutputLatch:
	
	ret

; Read a byte from the internal input latch
; Arguments:
;  - None
; Return:
;  - r16 register contains the read byte
ReadByteFromInputLatch:

	ret

