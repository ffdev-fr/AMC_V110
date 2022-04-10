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
; File:	Utilities.asm
;
; Author: F.Fargon
;
; Purpose: 
;  - Utility functions
;******************************************************************************

; Enter a critical section
; The behaviour is the following:
;  - The Interrupt Flag is cleared (interrupts masked)
;  - The counter of entered critical sections is incremented
EnterCriticalSection:
   cli         ; Mask interrupts
   
	push	r16
	in    r16, SREG
	push	r16

   ; Critical section management allowed only in 'Operating' state
   ; (in other states interrupts are disabled)
   lds   r16, bOperatingState
   cpi   r16, 0x01
   brne  EnterCriticalSection_Exit

   ; Program is in 'Operating' state
   lds   r16, bNestedCriticalSectionCount
   inc   r16
   sts   bNestedCriticalSectionCount, r16

EnterCriticalSection_Exit:
   pop   r16
	out 	SREG, r16
   pop   r16
   ret

; Leave a critical section
; The behaviour is the following:
;  - The Interrupt Flag is cleared
;  - If the counter of entered critical sections is greater than 0, it is 
;    decremented
;  - If the number of entered critical sections is 0, the Interrupt Flag is set
;    (interrupts allowed)
;
; NOTE: The interrupts are disabled at the beginning of the function to protect
;       access to the counter (i.e. in case of call to this function out of
;       a critical section)
LeaveCriticalSection:
   cli         ; Mask interrupts for counter access (if not in a critical section)

	push	r16
	in    r16, SREG
	push	r16

   ; Critical section management allowed only in 'Operating' state
   ; (in other states interrupts are disabled)
   lds   r16, bOperatingState
   cpi   r16, 0x01
   brne  LeaveCriticalSection_Exit

   ; Program is in 'Operating' state
   lds   r16, bNestedCriticalSectionCount
   cpi   r16, 0x00                       ; Is critical section entered
   breq  LeaveCriticalSection_EnableInt

   ; One or more critical sections have been entered
   dec   r16                              ; Decrement recursion counter
   sts   bNestedCriticalSectionCount, r16 ; Update counter
   cpi   r16, 0x00
   brne  LeaveCriticalSection_Exit       ; Do not enable interrupt if there are still
                                         ; critical sections entered

LeaveCriticalSection_EnableInt:
   pop   r16
	out 	SREG, r16
   pop   r16
   sei            ; Enable interrupts
   ret

LeaveCriticalSection_Exit:
   pop   r16
	out 	SREG, r16
   pop   r16
   ret


; Write a persistent byte in EEPROM
; Arguments:
;  - r16 register is the byte data to write
;  - r18:r17 register is pointer to ESEG address
WritePersistentByte:
	; Wait for completion of previous write
	sbic 	EECR, EEPE
	rjmp 	WritePersistentByte

	; Set up address (r18:r17) in address register
	out 	EEARH, r18
	out 	EEARL, r17

	; Write data (r16) to data register
	out 	EEDR, r16

	; Write logical one to EEMPE
	sbi 	EECR, EEMPE

	; Start eeprom write by setting EEPE
	sbi 	EECR, EEPE
	
	ret


; Read a persistent byte from EEPROM
; Arguments:
;  - r16 register is the read byte data
;  - r18:r17 register is pointer to ESEG address
ReadPersistentByte:
	; Wait for completion of previous write
	sbic 	EECR, EEPE
	rjmp 	ReadPersistentByte

	; Set up address (r18:r17) in address register
	out 	EEARH, r18
	out 	EEARL, r17

	; Start eeprom read by writing EERE
	sbi 	EECR, EERE

	; Read data from data register
	in 	r16, EEDR
	ret

