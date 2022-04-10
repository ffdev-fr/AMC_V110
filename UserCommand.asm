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
; File:	UserCommand.asm
;
; Author: F.Fargon
;
; Purpose: 
;  - Executes User commands
;  - Typically, command execution is triggered by the 'User Input' interrupt
;    handler when the input is qualified for action.
;******************************************************************************
	  
; Vector array for jumps to command processing functions
UserCommand_DispatchArray:
	jmp 	UserCommand_ExecuteOnOff
	jmp 	UserCommand_ExecuteMute
	jmp 	UserCommand_ExecuteChangeVolume
	jmp 	UserCommand_ExecuteChangeBalance
	jmp 	UserCommand_ExecuteChangeBacklight
	jmp 	UserCommand_ExecuteChangeContrast


; Main function to call for execution of a specified User Command.
; The command is identified by its index in the 'UserCommand_DispatchArray' array
; Parameters:
;  - R16      = Index (0 based) of the command to execute
;  - R17..R20 = Parameters for the command processing function (depends on
;               called function)
UserCommand_ExecuteCommand:
	ldi	ZH, HIGH(UserCommand_DispatchArray)
	ldi	ZL, LOW(UserCommand_DispatchArray)
	lsl	r16		; Command index
	adc	ZL, r16
	brcc 	UserCommand_ExecuteCommandDoCall	
	inc	ZH

UserCommand_ExecuteCommandDoCall:
	icall
	ret 

; Function for processing 'On/Off' command
; Arguments:
;  - None
; Return:
;  - SREG and R16 are modified on exit
;
; The function implements the following behaviour:
;  - A positive pulse is generated on trigger softstart On/off input (this will switch power
;    on if power is off or switch power off if power is on)
;  - The amplifier output is Muted/Unmuted according to new power state.
;    This will avoid transients in loudspeakers on power off or provide sound on power on. 
;  - The amplifier power state is updated 
;  - The new power state is displayed on the LCD
; 
; Note: The On/Off command consists on a pulse on the trigger softstart	On/off input.
;       The pulse width also serves as a debouncing period for the On/Off button.
;       All the interrupts are masked during the processing because On/Off command 
;       is a high priority command.
; Note: The state update routine also record in EEPROM the current level if the
;       amplifier is powered off.
UserCommand_ExecuteOnOff:
	ENTER_CRITICAL_SECTION		; Disable interrupts
	push	r17
	push	r18

; DEBUG
;#message "TO DO: REMOVE DBG -> Entering this delayed function displayed on port D"
;ldi r16, 0x10
;out PORTD, r16
;
;ldi r17, 0xFF
;Debug_Loop:
;ldi r16, 0xFF
;; 10 cycle loop
;Debug_Loop2:
;	nop
;	nop
;	nop
;	nop
;	nop
;	nop
;	nop
;	dec r16
;	brne Debug_Loop2
;	dec r17
;	brne Debug_Loop
;
;ldi r16, 0x00
;out PORTD, r16
;
;;       pop 	r18
;;       pop 	r17
;;       sei		; Enable interrupts
;;       ret

;end debug

	; Read current amplifier power state
	lds 	r16, bAmplifierPowerState		

	; If the command is going to power the amplifier off, mute the amplifier output 
   ; (to avoid transient in loudspeakers)
	cpi	r16, AMPLIFIERSTATE_POWER_OFF
	breq	UserCommand_ExecuteOnOff_SendTriggerPulse

	; This is a power off command (i.e. current state POWER_ON or POWERING_ON), make sure 
   ; that output is muted:
   ;  - Trigger mute sense must be 'Muted' (i.e. not an 'Unmute' command pending)
   in    r16, InternalStatusPins
   andi  r16, 1 << MuteInternalStatusPinNum
   breq  UserCommand_ExecuteOnOff_SendTriggerPulse

	; Mute the output (= generate a positive pulse on the softstart trigger command pin to
	; invert the current Mute/Unmute state)
	ldi	r16, 0x01                          ; R16 set to 0x01 = Mute/Unmute trigger command
	call	UserCommand_GenerateTriggerPulse   

	; Wait a moment before powering off (switching delay of output relays)
	; 256 * 256 loops of 20 cycles (131 ms with 10Mhz clock)
	ldi 	r17, 0xFF

UserCommand_ExecuteOnOff_RelayOffDelayLoop:
	ldi 	r16, 0xFF

UserCommand_ExecuteOnOff_RelayOffDelayLoop2:
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	dec 	r16
	brne 	UserCommand_ExecuteOnOff_RelayOffDelayLoop2
	dec 	r17
	brne 	UserCommand_ExecuteOnOff_RelayOffDelayLoop
	   
	; Toggle the On/Off state (= generate a positive pulse on the softstart trigger command pin to
	; invert the current On/Off state)
UserCommand_ExecuteOnOff_SendTriggerPulse:
	ldi	r16, 0x00			   ; R16 set to 0x00 = On/Off trigger command
	call	UserCommand_GenerateTriggerPulse   

	; Update amplifier state variables
   call	UpdateInternalStatus

UserCommand_ExecuteOnOff_Exit:
	; Exit
	pop 	r18
	pop 	r17
	LEAVE_CRITICAL_SECTION		; Enable interrupts
	ret

; Function for processing 'Mute' command
; Arguments:
;  - None
; Return:
;  - SREG and R16 are modified on exit
;
; The function implements the following behaviour:
;  - A positive pulse is generated on trigger softstart Mute/Unmute input (this will toggle the
;    amplifier output state)
;  - The command is allowed only if the amplifier is powered on.
;  - The amplifier mute state is updated 
;  - The new mute state is displayed on the LCD
; 
; Note: The Mute/Unmute command consists on a pulse on the trigger softstart Mute/Unmute input.
;       The pulse width also serves as a debouncing period for the Mute/Unmute button.
;       All the interrupts are masked during the processing because Mute/Unmute command 
;       is a high priority command.
UserCommand_ExecuteMute:
	ENTER_CRITICAL_SECTION	; Disable interrupts

	; Read current amplifier power state
	lds 	r16, bAmplifierPowerState		

	; Command allowed only if amplifier is powered on
	cpi	r16, AMPLIFIERSTATE_POWER_ON
	brne	UserCommand_ExecuteMute_Exit

	; Toggle the amplifier output		      
	ldi	r16, 0x01                     ; R16 set to 0x01 = Mute/Unmute trigger command
	call	UserCommand_GenerateTriggerPulse   

	; Update amplifier state variables
   call	UpdateInternalStatus

UserCommand_ExecuteMute_Exit:
	; Exit
	LEAVE_CRITICAL_SECTION	; Enable interrupts
	ret


; Function for processing 'Change Volume' command
; Arguments:
;  - R18 = Number of 'Step' for the Volume Change (positive or negative value)
; Return:
;  - SREG and R16 are modified on exit
UserCommand_ExecuteChangeVolume:
	push	r17
	push	r18

; Debug -  Display step value
;sts   PORTL, r18
; End debug


	; Compute the new output level value (i.e. add memorized steps to current value)
	cpi 	r18, 0x00		; Is negative value (backward steps)
	brlt	UserCommand_ExecuteChangeVolume_NegativeSteps

	; Steps are positive, check if maximum value not reached with add
	ldi	r16, 0x7F		; Check for clipping 
					; 'bCurrentLevel' maximum value is 0x7F
	lds	r17, bCurrentLevel
	sub	r16, r17
	cp	r18, r16
	brlo	UserCommand_ExecuteChangeVolume_AddSteps

	; Clip to maximum value
	ldi	r18, 0x7F
	rjmp	UserCommand_ExecuteChangeVolume_SetValue

UserCommand_ExecuteChangeVolume_AddSteps:
	add	r18, r17			; Add steps to current value
	rjmp	UserCommand_ExecuteChangeVolume_SetValue
 
UserCommand_ExecuteChangeVolume_NegativeSteps:
	; Steps are negative, check if minimum value not reached with substract
	lds 	r16, bCurrentLevel
	mov	r17, r18
	neg	r17
	cp	r17, r16	; Check for clipping
	brlo	UserCommand_ExecuteChangeVolume_SubstractSteps

	; Clip to minimum value
	ldi	r18, 0x00
	rjmp	UserCommand_ExecuteChangeVolume_SetValue

UserCommand_ExecuteChangeVolume_SubstractSteps:
	mov	    r18, r16		; Substract steps to current value
	sub	    r18, r17

UserCommand_ExecuteChangeVolume_SetValue:
	; Apply the new value on outputs
	; Check before if really need to apply (typically value already clipped)
	lds	r17, bCurrentLevel
	cp	r17, r18	  
	breq	UserCommand_ExecuteChangeVolume_Exit
	sts 	bCurrentLevel, r18  	; Store new current value
	call 	SetOutputValue		; Update output relay states

UserCommand_ExecuteChangeVolume_Exit:
	pop	r18
	pop	r17
	ret

; Function for processing 'Change Balance' command
UserCommand_ExecuteChangeBalance:
	ret

; Function for processing 'Change Backlight' command
; Arguments:
;  - R18 = Number of 'Step' for the Backlight Change (positive or negative value)
; Return:
;  - SREG and R16 are modified on exit
UserCommand_ExecuteChangeBacklight:
   push	r17
   push	r18

   ; Compute the new bqcklight level value (i.e. add memorized steps to current value)
   cpi 	r18, 0x00		; Is negative value (backward steps)
   brlt	UserCommand_ExecuteChangeBacklight_NegativeSteps

   ; Steps are positive, check if maximum value not reached with add
   ldi	r16, 0xFF		; Check for clipping
                        ; 'bCurrentLCDBacklight' maximum value is 0xFF
   lds	r17, bCurrentLCDBacklight
   sub	r16, r17
   cp	   r18, r16
   brlo	UserCommand_ExecuteChangeBacklight_AddSteps

   ; Clip to maximum value
   ldi	r18, 0xFF
   rjmp	UserCommand_ExecuteChangeBacklight_SetValue

UserCommand_ExecuteChangeBacklight_AddSteps:
   add	r18, r17			; Add steps to current value
   rjmp	UserCommand_ExecuteChangeBacklight_SetValue

UserCommand_ExecuteChangeBacklight_NegativeSteps:
   ; Steps are negative, check if minimum value not reached with substract
   lds 	r16, bCurrentLCDBacklight
   mov	r17, r18
   neg	r17
   cp	   r17, r16	; Check for clipping
   brlo	UserCommand_ExecuteChangeBacklight_SubstractSteps

   ; Clip to minimum value
   ldi	r18, 0x00
   rjmp	UserCommand_ExecuteChangeBacklight_SetValue

UserCommand_ExecuteChangeBacklight_SubstractSteps:
   mov	    r18, r16		; Substract steps to current value
   sub	    r18, r17

UserCommand_ExecuteChangeBacklight_SetValue:
   ; Apply the new value on LCD backlight potentiometer
   ; Check before if really need to apply (typically value already clipped)
   lds	r16, bCurrentLCDBacklight
   cp	   r16, r18
   breq	UserCommand_ExecuteChangeBacklight_Exit
   sts 	bCurrentLCDBacklight, r18  	; Store new current value
   call  LCDDriverAdjustBacklight      ; Update LCD backlight (new value specified in R16)                               

UserCommand_ExecuteChangeBacklight_Exit:
   pop	r18
   pop	r17
	ret

; Function for processing 'Change Contrast' command
; Arguments:
;  - R18 = Number of 'Step' for the Contrast Change (positive or negative value)
; Return:
;  - SREG and R16 are modified on exit
UserCommand_ExecuteChangeContrast:
   push	r17
   push	r18

   ; Compute the new contrast level value (i.e. add memorized steps to current value)
   cpi 	r18, 0x00		; Is negative value (backward steps)
   brlt	UserCommand_ExecuteChangeContrast_NegativeSteps

   ; Steps are positive, check if maximum value not reached with add
   ldi	r16, 0xFF		; Check for clipping
                        ; 'bCurrentLCDContrast' maximum value is 0x7F
   lds	r17, bCurrentLCDContrast
   sub	r16, r17
   cp	   r18, r16
   brlo	UserCommand_ExecuteChangeContrast_AddSteps

   ; Clip to maximum value
   ldi	r18, 0xFF
   rjmp	UserCommand_ExecuteChangeContrast_SetValue

UserCommand_ExecuteChangeContrast_AddSteps:
   add	r18, r17			; Add steps to current value
   rjmp	UserCommand_ExecuteChangeContrast_SetValue

UserCommand_ExecuteChangeContrast_NegativeSteps:
   ; Steps are negative, check if minimum value not reached with substract
   lds 	r16, bCurrentLCDContrast
   mov	r17, r18
   neg	r17
   cp	   r17, r16	; Check for clipping
   brlo	UserCommand_ExecuteChangeContrast_SubstractSteps

   ; Clip to minimum value
   ldi	r18, 0x00
   rjmp	UserCommand_ExecuteChangeContrast_SetValue

UserCommand_ExecuteChangeContrast_SubstractSteps:
   mov	    r18, r16		; Substract steps to current value
   sub	    r18, r17

UserCommand_ExecuteChangeContrast_SetValue:
   ; Apply the new value on LCD contrast potentiometer
   ; Check before if really need to apply (typically value already clipped)
   lds	r16, bCurrentLCDContrast
   cp	   r16, r18
   breq	UserCommand_ExecuteChangeContrast_Exit
   sts 	bCurrentLCDContrast, r18  	; Store new current value
   call  LCDDriverAdjustContrast    ; Update LCD contrast (new value specified in R16)                               

UserCommand_ExecuteChangeContrast_Exit:
   pop	r18
   pop	r17
	ret


; Utility function for generation of a positive pulse on one of the softstart trigger input
; (On/Off or Mute/Unmute command pin)
; Arguments:
;  - R16: Indicates trigger command pin (0x00 = On/Off command, 0x01 = Mute/Unmute command)
;
; Note: 
;  The positive pulse is required for 'AmplifierProt' V3.1 hardware.
;  Later versions (or modified V3.1) have the command pin located after the softstart trigger logic
;  (i.e. directly connected to relais command).
;  For this 'AmplifierProt' versions, the 'UserCommand_GenerateTriggerPulse' is still called but
;  function must toggle current pin state rather than generate a pulse.
UserCommand_GenerateTriggerPulse:
	push	r17
	push 	r18

#ifdef AMPLIFIERPROT_V31_TRIGGER

	; Generate a positive pulse on the softstart trigger command pin
	; This pulse will invert the corresponding output state

	; Pulse duration is about 10ms (mainly for debouncing purpose):
	;  - Loop with 4 cycles	(+ 3 cycles every 1000 cycles) 
	;  - Clock at 4 MHz (i.e. one microsecond for 1 cycle)
	;  - 10000 loop iterations
	cpi	r16, 0x00
	brne 	UserCommand_GenerateTriggerPulse_SetMutePin
	sbi	InternalCtrlPortData, OnOffInternalCtrlPinNum	; Set On/Off pin state to 1  
	rjmp	UserCommand_GenerateTriggerPulse_InitPulseLoop

UserCommand_GenerateTriggerPulse_SetMutePin:
	sbi	InternalCtrlPortData, MuteInternalCtrlPinNum	; Set Mute/Unmute pin state to 1  

UserCommand_GenerateTriggerPulse_InitPulseLoop:
;#message "TO DO: REMOVE DBG -> Trigger On/Off pulse also on port D pin 3"
;;for debug, same pulse on PortD pin 3 (i.e. for pulldown resistor on bigAVR)
;	sbi	PORTD, PORTE3	; Set pin state to 1  
;; end debug


	ldi 	r17, 250	; Counters for pulse duration (250 microseconds)
;        ldi	r18, 40		; 40 * 250 microseconds = 10ms
	ldi	    r18, 240	; 240 * 250 microseconds = 60ms

UserCommand_GenerateTriggerPulse_PulseLoop:
	nop  	; Original 2 nop = 4 cycles
	nop
	nop
	nop
	nop
	nop
	dec	r17
	brne	UserCommand_GenerateTriggerPulse_PulseLoop
	ldi	r17, 250
	dec	r18
	brne	UserCommand_GenerateTriggerPulse_PulseLoop

	; Clear pin
	cpi	r16, 0x00
	brne 	UserCommand_GenerateTriggerPulse_ClearMutePin
	cbi	InternalCtrlPortData, OnOffInternalCtrlPinNum	; Set On/Off pin state to 0  
	rjmp	UserCommand_GenerateTriggerPulse_Exit

UserCommand_GenerateTriggerPulse_ClearMutePin:
	cbi	InternalCtrlPortData, MuteInternalCtrlPinNum	; Set Mute/Unmute pin state to 0  

#else

	; Command pin directly connected (i.e. trigger bypassed)
   ; Invert current state of command pin

	cpi	r16, 0x00
	brne 	UserCommand_GenerateTriggerPulse_ToggleMutePin
	sbi	InternalCtrlPortPin, OnOffInternalCtrlPinNum     ; Toggle On/off pin state
                                                          ; Note: Writing 1 on PIN port toggles the value on DATA port
	rjmp	UserCommand_GenerateTriggerPulse_Exit

UserCommand_GenerateTriggerPulse_ToggleMutePin:
	sbi	InternalCtrlPortPin, MuteInternalCtrlPinNum     ; Toggle Mute/Unmute pin state
                                                          ; Note: Writing 1 on PIN port toggles the value on DATA port

#endif

UserCommand_GenerateTriggerPulse_Exit:
	pop	r18
	pop	r17
	ret
