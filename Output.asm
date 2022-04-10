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
; File:	Output.asm
;
; Author: F.Fargon
;
; Purpose: 
;  - Potentiometer relays control
;******************************************************************************


; Update the 2 channel outputs (relays) according to value stored in 
; 'bCurrentLevel' variable and persistent or temporary offsets 
; The offset value range is from -127 to +127 and the output level range is
; from 0 to +127
; If the offset value is too large the output level is clipped to its limit
SetOutputValue:
	push 	r16
	push 	r17
	push 	r18

	; Read current value
	lds 	r16, bCurrentLevel			


;debug
;#message "TO DO: REMOVE DBG -> Display bCurrentLevel on Port D"
;out PORTD, r16
;end debug

	; Process Left Channel
	; Left Channel Offset to apply depends on Main Menu mode
	lds 	r17, bCurrentMainMenuOption
	cpi 	r17, MAIN_MENU_LEFT_OFFSET
	brne 	SetOutputValue_CurrentLeftChannel
	lds 	r17, bCurrentKeyboardInput      ; Edit Left Channel Offset mode, use keyboard input
						; (i.e. temporary value)
	rjmp 	SetOutputValue_CheckLeftChannel

SetOutputValue_CurrentLeftChannel:
	lds 	r17, bCurrentLeftChannelOffset 		; Not edit mode, use persistent offset

SetOutputValue_CheckLeftChannel:
	; The output level must be in the range from 0 to +127 (clip if necessary)
	cpi 	r17, 0x00
	brlt 	SetOutputValue_NegLeftOffset	; Signed compare

	; Positive offset, clip to 0x7F if necessary
	add 	r17, r16
	cpi 	r17, 0x80
	brlo 	SetOutputValue_SetLeftChannel
	ldi 	r17, 0x7F	; Clip to max value
	rjmp 	SetOutputValue_SetLeftChannel

SetOutputValue_NegLeftOffset:
	mov 	r18, r17	; Offset absolute value cannot be greater than current value 
	neg 	r18
	cp 	r18, r16
	brlo 	SetOutputValue_NoLeftChannelClip
	ldi 	r17, 0x00	; Clip to min value
	rjmp 	SetOutputValue_SetLeftChannel

SetOutputValue_NoLeftChannelClip:
	mov 	r17, r16
	sub 	r17, r18

SetOutputValue_SetLeftChannel:
	; Adjust Left channel relays
	; Check relay pins states to avoid a call to the switching procedure 
	; for nothing
	in 	r18, LeftChannelData
	cp 	r18, r17
	breq 	SetOutputValue_RightChannel

	; Left Channel relays states must be updated
	push 	r16
	mov 	r16, r17
	ldi 	r17, LeftChannelData
	call 	RelaySetLevel
	pop 	r16

SetOutputValue_RightChannel:
	; Process Right Channel
	; Right Channel Offset to apply depends on Main Menu mode
	lds 	r17, bCurrentMainMenuOption
	cpi 	r17, MAIN_MENU_RIGHT_OFFSET
	brne 	SetOutputValue_CurrentRightChannel
	lds 	r17, bCurrentKeyboardInput      ; Edit Right Channel Offset mode, use keyboard input
				    		; (i.e. temporary value)
	rjmp 	SetOutputValue_CheckRightChannel

SetOutputValue_CurrentRightChannel:
	lds 	r17, bCurrentRightChannelOffset 	; Not edit mode, use persistent offset

SetOutputValue_CheckRightChannel:
	; The output level must be in the range from 0 to +127 (clip if necessary)
	cpi 	r17, 0x00
	brlt 	SetOutputValue_NegHighOffset	; Signed compare

	; Positive offset, clip to 0x7F if necessary
	add 	r17, r16
	cpi 	r17, 0x80
	brlo 	SetOutputValue_SetRightChannel
	ldi 	r17, 0x7F		; Clip to max value
	rjmp 	SetOutputValue_SetRightChannel

SetOutputValue_NegHighOffset:
	mov 	r18, r17	; Offset absolute value cannot be greater than current value 
	neg 	r18
	cp 	r18, r16
	brlo 	SetOutputValue_NoRightChannelClip
	ldi 	r17, 0x00	; Clip to min value
	rjmp 	SetOutputValue_SetRightChannel

SetOutputValue_NoRightChannelClip:
	mov 	r17, r16
	sub 	r17, r18

SetOutputValue_SetRightChannel:
	; Adjust Right Channel relays
	; Check relay pins states to avoid a call to the switching procedure 
	; for nothing
	in 	r18, RightChannelData
	cp 	r18, r17
	breq 	SetOutputValue_Exit

	; High Pass relays states must be updated
	mov 	r16, r17
	ldi 	r17, RightChannelData
	call 	RelaySetLevel
	
SetOutputValue_Exit:
	pop 	r18
	pop 	r17
	pop 	r16
	ret


; Switch ON the Input Mute relays (Left and Right channels)
; This function switches ON the Global Mute relays on Letf and Right potentiometers
; Typically, this function in called during power on routine
UnMuteAmplifierInput:

	sbi 	LeftChannelData, 7		
	sbi 	RightChannelData, 7		
	ret

; Switch OFF the Input Mute relays (Left and Right channels)
; This function switches OFF the Global Mute relays on Letf and Right potentiometers
; Typically, this function in called during power off routine
MuteAmplifierInput:

	cbi 	LeftChannelData, 7		
	cbi 	RightChannelData, 7		
	ret

; Execute Relay Switching Strategy for Mute operation on Left Channel
; This function executes the strategy for switching relays to the lowest output
; level (i.e. all relays switched OFF)
; The strategy rules are:
;  - Switch relays off starting with the MSB relay
;  - Execute the strategy in about 1 millisec (150 usec delay between each relay
;    state change)
RelayMuteLeftChannel:

	cbi 	LeftChannelData, 6
	call 	RelaySwitchingStdDelay
	cbi 	LeftChannelData, 5
	call 	RelaySwitchingStdDelay
	cbi 	LeftChannelData, 4
	call 	RelaySwitchingStdDelay
	cbi 	LeftChannelData, 3
	call 	RelaySwitchingStdDelay
	cbi 	LeftChannelData, 2
	call 	RelaySwitchingStdDelay
	cbi 	LeftChannelData, 1
	call 	RelaySwitchingStdDelay
	cbi 	LeftChannelData, 0
	call 	RelaySwitchingStdDelay

	ret

; Execute Relay Switching Strategy for Mute operation on High Pass channel
; See 'RelayMuteLeftChanne'
RelayMuteRightChannel:

	cbi 	RightChannelData, 6
	call 	RelaySwitchingStdDelay
	cbi 	RightChannelData, 5
	call 	RelaySwitchingStdDelay
	cbi 	RightChannelData, 4
	call 	RelaySwitchingStdDelay
	cbi 	RightChannelData, 3
	call 	RelaySwitchingStdDelay
	cbi 	RightChannelData, 2
	call 	RelaySwitchingStdDelay
	cbi 	RightChannelData, 1
	call 	RelaySwitchingStdDelay
	cbi 	RightChannelData, 0
	call 	RelaySwitchingStdDelay

	ret

; Execute Relay Switching Strategy for UnMute operation on Low Pass Channel
; This function executes the strategy for switching relays to the specified 
; output level (typically current output level plus current or temporary
; offset)
; The Output Level to set is specified in the r16 register
; The strategy rules are:
;  - Switch relays to their final state starting with the LSB relay
;  - Execute the strategy in about 1 millisec (150 usec delay between each relay
;    state change)
RelayUnMuteLeftChannel:
	; Set relay states
	sbrc 	r16, 0 	; Is bit 0 switched ON
	sbi 	LeftChannelData, 0		
	call 	RelaySwitchingStdDelay
	sbrc 	r16, 1
	sbi 	LeftChannelData, 1		
	call 	RelaySwitchingStdDelay
	sbrc 	r16, 2
	sbi 	LeftChannelData, 2		
	call 	RelaySwitchingStdDelay
	sbrc 	r16, 3
	sbi 	LeftChannelData, 3		
	call 	RelaySwitchingStdDelay
	sbrc 	r16, 4
	sbi 	LeftChannelData, 4		
	call 	RelaySwitchingStdDelay
	sbrc 	r16, 5
	sbi 	LeftChannelData, 5		
	call 	RelaySwitchingStdDelay
	sbrc 	r16, 6
	sbi 	LeftChannelData, 6		
	call 	RelaySwitchingStdDelay
	
	ret

; Execute Relay Switching Strategy for UnMute operation on High Pass Channel
; See 'RelayUnMuteLeftChannel'
RelayUnMuteRightChannel:
	; Set relay states
	sbrc 	r16, 0 		; Is bit 0 switched ON
	sbi 	RightChannelData, 0		
	call 	RelaySwitchingStdDelay
	sbrc 	r16, 1
	sbi 	RightChannelData, 1		
	call 	RelaySwitchingStdDelay
	sbrc 	r16, 2
	sbi 	RightChannelData, 2		
	call 	RelaySwitchingStdDelay
	sbrc 	r16, 3
	sbi 	RightChannelData, 3		
	call 	RelaySwitchingStdDelay
	sbrc 	r16, 4
	sbi 	RightChannelData, 4		
	call 	RelaySwitchingStdDelay
	sbrc 	r16, 5
	sbi 	RightChannelData, 5		
	call 	RelaySwitchingStdDelay
	sbrc 	r16, 6
	sbi 	RightChannelData, 6		
	call 	RelaySwitchingStdDelay
	
	ret

; Execute Relay Switching Strategy for SetLevel operation
; This function executes the strategy for switching relays to a new specified
; output level on a specified channel
; The function is typically called when Output Level is changed
; The Output Level to set is in r16 register and r17 contains 'LeftChannelData'
; for Left Channel and 'RightChannelData' for Right Channel
; The strategy rules are:
;  - Switch relays to the Mute level (about 1 millisec cycle)
;  - Switch relays to the UnMute level (about 1 millisec cycle)
RelaySetLevel:

	; Check if value must be applied on Left channel or on Right channel
	cpi 	r17, RightChannelData
	breq 	RelaySetLevel_RightChannel

	; Left channel specified
	call 	RelayMuteLeftChannel
	call 	RelayUnMuteLeftChannel
	rjmp 	RelaySetLevel_Exit

RelaySetLevel_RightChannel:
	; Update value on Right channel
	call 	RelayMuteRightChannel
	call 	RelayUnMuteRightChannel

RelaySetLevel_Exit:
	ret

; Wait the standard delay for relay switching
; The standard delay is 150 usec
; This gives total duration of 1050 usec for the 7 relay switch sequence
RelaySwitchingStdDelay:
	push 	r16		; 2 cycles

#ifdef CLOCK_FREQUENCY_1MHZ
	ldi 	r16, 15		; 1 cycle
#endif

#ifdef CLOCK_FREQUENCY_1_25MHZ
	ldi 	r16, 19		; 1 cycle
#endif

#ifdef CLOCK_FREQUENCY_4MHZ
	ldi 	r16, 59		; 1 cycle
#endif

#ifdef CLOCK_FREQUENCY_5MHZ
	ldi 	r16, 74		; 1 cycle
#endif

#ifdef CLOCK_FREQUENCY_8MHZ
	ldi 	r16, 118		; 1 cycle
#endif

#ifdef CLOCK_FREQUENCY_10MHZ
	ldi 	r16, 148		; 1 cycle
#endif

; 10 cycle loop
RelaySwitchingStdDelay_Loop:
	nop 			;1 cycle
	nop
	nop
	nop
	nop
	nop
	nop
	dec 	r16		; 1 cycle
	brne 	RelaySwitchingStdDelay_Loop	; ((10 * loop count) + 1) cycles
	
	pop 	r16     	; 2 cycles
	ret 			   ; 4 cycles

