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
; File:	RemoteControl.asm
;
; Author: F.Fargon
;
; Purpose: 
;  - Manages the IR Remote Control input (RC5 protocol)
;******************************************************************************


; Function called when the RC5 Frame Start interrupt detects the begining of a new frame.
; The function acquires frame data and update User Input shared variables.
; The function returns a result in R16 register:
;   - 0x00 = The frame is fully decoded (new value) and RC5 frame detection can be enabled
;            back for next frame
;   - 0x01 = The frame contains the same information than previous frame. In this case the
;            function exits before the end of the frame. The frame detection must be enabled
;            back only when frame duration has elapsed (see 'RC5FrameStartEvent' and
;            'RC5FrameTimerEvent' handler for details).
;   - 0xFE = The frame is not addressed to this terminal. In this case the function exits
;            before the end of the frame. See previous paragraph for behaviour in such a case.
;   - 0xFF = The frame cannot be decoded because of timing inconsistency. In this case also
;            the function exits before the end of the frame. See previous paragraph for
;            behaviour in such a case.
;
; Note: In the comments and program bit levels are expressed in RC5 Pin states (rising 
;       transition for bit value 0 and falling transition for bit value 1).
;       These transitions are the opposite of the RC5 protocol specification because the 
;       TSOP2236 device is inverting the signal (TSOP2236 is 'active low').
RemoteControl_DecodeFrame:

	; Save work registers
	; R16, R17 and R18 are already saved by the calling function and not need to be 
	; preserved.
	push 	r19
	push 	r20
	push 	r21
	push 	r22
	push 	r23 
	
	; Step1: Wait for the second start bit and measure bit duration
	;
	; The interrupt is generated when first start bit is detected (bit equal to 1)
	; At the same time the RC5FrameTimer timer is started (a few instructions before 
	; entering this function).
	; The RC5 pin must go to level 1 and then to 0 to produce the second start bit 
	; (second start bit also equal to 1)
	; The function exits with error if the second start bit is not detected within
	; twice the theorical bit duration.
	ldi	r17, RC5BitDurationTimerTicks	; Theorical bit duration (number of 50µsec steps)
	lsl	r17				               ; Twice bit duration
						
	sbic	RC5PortPins, RC5ExtIntPinNum	; The RC5 pin must be at 0 level (= start bit 1 just detected)
	jmp	RemoteControl_ErrorExit		; Invalid pin state, exit with error
				
	; Wait for second start bit
RemoteControl_WaitSecondStartBitPinRise:
	sbic	RC5PortPins, RC5ExtIntPinNum   
	rjmp	RemoteControl_WaitSecondStartBitPinFall	; Transition detected (half bit), wait for new bit state
							 
	; Bit state unchanged, is bit duration elapsed?												
	lds	r16, RC5BitDurationCounter	; Note: RC5 timer counter is also accessed by RC5Timer interrupt.
						                  ;       As this variable is atomic, there is no need to protect
						                  ;       shared access by a critical section
	cp	   r16, r17
	brlo	RemoteControl_WaitSecondStartBitPinRise
	jmp	RemoteControl_ErrorExit		; Bit duration elapsed without transition
 
RemoteControl_WaitSecondStartBitPinFall:
	sbis	RC5PortPins, RC5ExtIntPinNum
	rjmp	RemoteControl_SecondStartBitDetected	; Transition detected (full bit), bit value OK
							 
	; Bit state unchanged, is bit duration elapsed?												
	lds	r16, RC5BitDurationCounter
	cp	   r16, r17
	brlo	RemoteControl_WaitSecondStartBitPinFall
	jmp	RemoteControl_ErrorExit		; Bit duration elapsed without transition

RemoteControl_SecondStartBitDetected:
	; Second start bit detected, store measured bit duration
	lds	r16, RC5BitDurationCounter
	sts	RC5BitMeasuredDuration, r16

; DEBUG
;#message "TO DO: REMOVE DBG -> RC5BitMeasuredDuration displayed on port L"
;sts PORTL, r16
;end debug



	; Compute 3/4 bit and 6/4 bit durations from the measured value.
	; The 3/4 bit duration is used to skip the half bit transition and start detection for the full bit
	; transition.
	; The 6/4 bit duration is used for timeout of full bit transition detection (the full bit transition
	; is expected between 3/4 bit and 6/4 bit of the theorical timing). In other words, the function look
	; for the full bit transition up to 3/4 bit duration starting 1/4 bit duration before the theorical
	; position of the transition.
	clc
	mov	r18, r16
	lsr	r16
	add	r18, r16	; 6/4 bit in r18
	mov	r17, r16
	lsr	r16
	add	r17, r16 	; 3/4 bit in r17

	; Acquire toggle bit value
	call	RemoteControl_AcquireFrameBit
	cpi	r19, 0xFF			; Is bit value acquired?
	brne	RemoteControl_StoreToggleBitChange
	jmp		RemoteControl_ErrorExit

RemoteControl_StoreToggleBitChange:
	; Check if toggle bit changed since previous frame and store information in R23
	ldi	r23, 0x01			    ; R23 is 0x01 if toggle bit changed
	lds	r16, RC5LastToggleBitState
	cp	r16, r19
	brne	RemoteControl_AcquireAddressBits
	ldi	r23, 0x00			    ; Toggle bit unchanged, R23 set to 0x00

RemoteControl_AcquireAddressBits:
	; start acquire loop for the 5 bits of the address word
	; Note: bits are received from A4 to A0 (MSB first)
	clr	r21		; Acquired bits stored in r21
	ldi	r22, 0x05	; Loop counter in r22

RemoteControl_AcquireAddressBitsLoop:
	call	RemoteControl_AcquireFrameBit
	cpi	r19, 0xFF			; Is bit value acquired?
	breq	RemoteControl_ErrorExit

	clc			; Store bit value in r21
	sbrc	r19, 0
	sec
	rol	r21

	dec	r22		; Is loop finished
	brne	RemoteControl_AcquireAddressBitsLoop

	; Check if the frame is addressed to this terminal

; DEBUG
;#message "TO DO: REMOVE DBG -> RC5 address displayed on port D"
;out PORTD, r21
;end debug

	lds	r16, RC5TerminalAddress
	cp	r16, r21
	breq	RemoteControl_CheckToggleBitChange
	ldi	r16, 0xFE	  			; Exit with discarded frame (other address) result
	jmp	RemoteControl_Exit

RemoteControl_CheckToggleBitChange:
	; The frame is concerning this device
	; If the toggle bit is unchanged, it is not needed to decode the whole frame
	cpi	r23, 0x00
	brne	RemoteControl_AcquireInstructionBits	; Toggle bit changed, acquire the instruction

	; The frame contains the same instruction than previous frame.
	; Update Input Polling shared variables.
	; Note: The corresponding action will be applied by the Input Polling and User Input interrupt
	;       functions.
	ENTER_CRITICAL_SECTION 						; Update operation is not atomic
	lds	r16, InputPollingRC5InstructionCount	; Increment last RC5 instruction count
	inc	r16
	sts	InputPollingRC5InstructionCount, r16
	ldi	r16, 0x01				; Set KeyPressed variable
	sts 	InputPollingRC5KeyPressed, r16
	LEAVE_CRITICAL_SECTION

	ldi	r16, 0x01	  			; Exit with toggle unchanged result
	jmp	RemoteControl_Exit

RemoteControl_AcquireInstructionBits:
	; start acquire loop for the 6 bits of the instruction word
	clr	r21		; Acquired bits stored in r21
	ldi	r22, 0x06	; Loop counter in r22

RemoteControl_AcquireInstructionBitsLoop:
	call	RemoteControl_AcquireFrameBit
	cpi	r19, 0xFF			; Is bit value acquired?
	breq	RemoteControl_ErrorExit

	clc			; Store bit value in r21
	sbrc	r19, 0
	sec
	rol	r21

	dec	r22		; Is loop finished
	brne	RemoteControl_AcquireInstructionBitsLoop

	; Update Input Polling shared variables.
	; Note: The corresponding action will be applied by the Input Polling and User Input interrupt
	;       functions.
	ENTER_CRITICAL_SECTION						; Update operation is not atomic
	sts	InputPollingLastRC5Instruction, r21	; New RC5 instruction 
	ldi	r16, 0x01				; The first one
	sts	InputPollingRC5InstructionCount, r16
	ldi	r16, 0x01				; Set KeyPressed variable
	sts 	InputPollingRC5KeyPressed, r16
	LEAVE_CRITICAL_SECTION

	; Frame successfully decoded (r16 is return code)
	clr	r16
	rjmp	RemoteControl_Exit

RemoteControl_ErrorExit:
	ldi	r16, 0xFF	; Frame not fully processed due to a timing error

RemoteControl_Exit:
	pop	r23
	pop 	r22
	pop 	r21
	pop 	r20
	pop 	r19

	ret

; Function called by 'RemoteControl_DecodeFrame' to acquire a bit value.
; The function implements bit timing for transition detection.
; The following registers must be set on entry:
;  - R17 = 3/4 bit duration (umodified by this function)
;  - R18 = 5/4 bit duration (umodified by this function)
; The result is returned in R19 register:
;  - 0x00 = bit detected at level 0
;  - 0x01 = bit detected at level 1
;  - 0xFF = timing error, bit not detected
; The R16 and R20 registers are modified by the function (and not preserved)
RemoteControl_AcquireFrameBit:

	; Clear RC5BitDurationCounter and start waiting to skip the eventual half bit transition
	clr	r16
	sts	RC5BitDurationCounter, r16

RemoteControl_AcquireFrameBitSkipHalfBitTransition:
	lds	r16, RC5BitDurationCounter
	cp	r16, r17
	brlo	RemoteControl_AcquireFrameBitSkipHalfBitTransition

	; 3/4 bit duration elapsed, should be located after eventual half bit transition
	; Store current bit state in r19
	in 	r19, RC5PortPins
	andi	r19, 1 << RC5ExtIntPinNum

RemoteControl_AcquireFrameBitWaitFullBitTransition:
	in 	r20, RC5PortPins
	andi	r20, 1 << RC5ExtIntPinNum
	cp 	r20, r19
	brne	RemoteControl_AcquireFrameBitFullBitDetected  ; Full bit transition detected
							 
	; Bit state unchanged, is bit duration elapsed?												
	lds	r16, RC5BitDurationCounter
	cp	r16, r18
	brlo	RemoteControl_AcquireFrameBitWaitFullBitTransition

	; Bit duration elapsed without transition, exit with error
	ldi	r19, 0xFF
	ret

RemoteControl_AcquireFrameBitFullBitDetected:
	; Bit detected, return result
	; Result returned in true value (i.e. invert current pin state/transition)
	clr	r19
	sbrs	r20, RC5ExtIntPinNum
	ldi	r19, 0x01

	ret
