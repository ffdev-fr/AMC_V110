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
; File:	AMC.asm
;
; Author: F.Fargon
;
; Purpose:
;  - Main program
;  - Interrupt driven event loop
;******************************************************************************

#include "Build.asm"
#include "Definitions.asm"
#include "Globals.asm"


;******************************************************************************
; Interrupt vectors
;******************************************************************************

.CSEG
.ORG	0x0000

#if (defined ANALOG_INPUTLEVEL)

	 jmp main			       ;Reset	
    jmp NotHandledInt       ; External Interrupt Request 0
    jmp NotHandledInt       ; External Interrupt Request 1
    jmp NotHandledInt       ; External Interrupt Request 2
    jmp NotHandledInt       ; External Interrupt Request 3
    jmp TCPIPSocketEvent    ; External Interrupt Request 4
    jmp RC5FrameStartEvent  ; External Interrupt Request 5
    jmp OnOffButtonEvent    ; External Interrupt Request 6
    jmp MuteButtonEvent     ; External Interrupt Request 7
    jmp NotHandledInt       ; Pin Change Interrupt Request 0
    jmp NotHandledInt       ; Pin Change Interrupt Request 1
    jmp NotHandledInt       ; Pin Change Interrupt Request 2
    jmp NotHandledInt       ; Watchdog Time-out Interrupt
    jmp UserInputTimerEvent ; Timer/Counter2 Compare Match A
    jmp NotHandledInt       ; Timer/Counter2 Compare Match B
    jmp NotHandledInt       ; Timer/Counter2 Overflow
    jmp NotHandledInt       ; Timer/Counter1 Capture Event
    jmp RC5FrameTimerEvent  ; Timer/Counter1 Compare Match A
    jmp NotHandledInt       ; Timer/Counter1 Compare Match B
    jmp NotHandledInt       ; Timer/Counter1 Compare Match C
    jmp NotHandledInt       ; Timer/Counter1 Overflow
    jmp InputPollingTimerEvent ; Timer/Counter0 Compare Match A
    jmp NotHandledInt       ; Timer/Counter0 Compare Match B
    jmp NotHandledInt       ; Timer/Counter0 Overflow
    jmp NotHandledInt       ; SPI Serial Transfer Complete
    jmp NotHandledInt       ; USART0, Rx Complete
    jmp NotHandledInt       ; USART0 Data register Empty
    jmp NotHandledInt       ; USART0, Tx Complete
    jmp NotHandledInt       ; Analog Comparator
    jmp ADConvDoneEvent     ; ADC Conversion Complete
    jmp NotHandledInt       ; EEPROM Ready
    jmp NotHandledInt       ; Timer/Counter3 Capture Event
    jmp NotHandledInt       ; Timer/Counter3 Compare Match A
    jmp NotHandledInt       ; Timer/Counter3 Compare Match B
    jmp NotHandledInt       ; Timer/Counter3 Compare Match C
    jmp NotHandledInt       ; Timer/Counter3 Overflow
    jmp NotHandledInt       ; USART1, Rx Complete
    jmp NotHandledInt       ; USART1 Data register Empty
    jmp NotHandledInt       ; USART1, Tx Complete
    jmp NotHandledInt       ; 2-wire Serial Interface
    jmp NotHandledInt       ; Store Program Memory Read
    jmp NotHandledInt       ; Timer/Counter4 Capture Event
    jmp NotHandledInt       ; Timer/Counter4 Compare Match A
    jmp NotHandledInt       ; Timer/Counter4 Compare Match B
    jmp NotHandledInt       ; Timer/Counter4 Compare Match C
    jmp NotHandledInt       ; Timer/Counter4 Overflow
    jmp NotHandledInt       ; Timer/Counter5 Capture Event
    jmp NotHandledInt       ; Timer/Counter5 Compare Match A
    jmp NotHandledInt       ; Timer/Counter5 Compare Match B
    jmp NotHandledInt       ; Timer/Counter5 Compare Match C
    jmp NotHandledInt       ; Timer/Counter5 Overflow
    jmp NotHandledInt       ; USART2, Rx Complete
    jmp NotHandledInt       ; USART2 Data register Empty
    jmp NotHandledInt       ; USART2, Tx Complete
    jmp NotHandledInt       ; USART3, Rx Complete
    jmp NotHandledInt       ; USART3 Data register Empty
    jmp NotHandledInt       ; USART3, Tx Complete

#else
  #if (defined ENCODER_INPUTLEVEL || defined IR_INPUTLEVEL)

	 jmp main			       ;Reset	
    jmp NotHandledInt       ; External Interrupt Request 0
    jmp NotHandledInt       ; External Interrupt Request 1
    jmp NotHandledInt       ; External Interrupt Request 2
    jmp NotHandledInt       ; External Interrupt Request 3
    jmp TCPIPSocketEvent    ; External Interrupt Request 4
    jmp RC5FrameStartEvent  ; External Interrupt Request 5
    jmp OnOffButtonEvent    ; External Interrupt Request 6
    jmp MuteButtonEvent     ; External Interrupt Request 7
    jmp NotHandledInt       ; Pin Change Interrupt Request 0
    jmp NotHandledInt       ; Pin Change Interrupt Request 1
    jmp NotHandledInt       ; Pin Change Interrupt Request 2
    jmp NotHandledInt       ; Watchdog Time-out Interrupt
    jmp UserInputTimerEvent ; Timer/Counter2 Compare Match A
    jmp NotHandledInt       ; Timer/Counter2 Compare Match B
    jmp NotHandledInt       ; Timer/Counter2 Overflow
    jmp NotHandledInt       ; Timer/Counter1 Capture Event
    jmp RC5FrameTimerEvent  ; Timer/Counter1 Compare Match A
    jmp NotHandledInt       ; Timer/Counter1 Compare Match B
    jmp NotHandledInt       ; Timer/Counter1 Compare Match C
    jmp NotHandledInt       ; Timer/Counter1 Overflow
    jmp InputPollingTimerEvent ; Timer/Counter0 Compare Match A
    jmp NotHandledInt       ; Timer/Counter0 Compare Match B
    jmp NotHandledInt       ; Timer/Counter0 Overflow
    jmp NotHandledInt       ; SPI Serial Transfer Complete
    jmp NotHandledInt       ; USART0, Rx Complete
    jmp NotHandledInt       ; USART0 Data register Empty
    jmp NotHandledInt       ; USART0, Tx Complete
    jmp NotHandledInt       ; Analog Comparator
    jmp NotHandledInt       ; ADC Conversion Complete
    jmp NotHandledInt       ; EEPROM Ready
    jmp NotHandledInt       ; Timer/Counter3 Capture Event
    jmp NotHandledInt       ; Timer/Counter3 Compare Match A
    jmp NotHandledInt       ; Timer/Counter3 Compare Match B
    jmp NotHandledInt       ; Timer/Counter3 Compare Match C
    jmp NotHandledInt       ; Timer/Counter3 Overflow
    jmp NotHandledInt       ; USART1, Rx Complete
    jmp NotHandledInt       ; USART1 Data register Empty
    jmp NotHandledInt       ; USART1, Tx Complete
    jmp NotHandledInt       ; 2-wire Serial Interface
    jmp NotHandledInt       ; Store Program Memory Read
    jmp NotHandledInt       ; Timer/Counter4 Capture Event
    jmp NotHandledInt       ; Timer/Counter4 Compare Match A
    jmp NotHandledInt       ; Timer/Counter4 Compare Match B
    jmp NotHandledInt       ; Timer/Counter4 Compare Match C
    jmp NotHandledInt       ; Timer/Counter4 Overflow
    jmp NotHandledInt       ; Timer/Counter5 Capture Event
    jmp NotHandledInt       ; Timer/Counter5 Compare Match A
    jmp NotHandledInt       ; Timer/Counter5 Compare Match B
    jmp NotHandledInt       ; Timer/Counter5 Compare Match C
    jmp NotHandledInt       ; Timer/Counter5 Overflow
    jmp NotHandledInt       ; USART2, Rx Complete
    jmp NotHandledInt       ; USART2 Data register Empty
    jmp NotHandledInt       ; USART2, Tx Complete
    jmp NotHandledInt       ; USART3, Rx Complete
    jmp NotHandledInt       ; USART3 Data register Empty
    jmp NotHandledInt       ; USART3, Tx Complete

  #endif
#endif


;******************************************************************************
; Interrupt handlers
;******************************************************************************

; Interrupt handler for not handled interrupts
; These interrupts should not occur in normal operation
NotHandledInt:
	reti

; Interrupt handler for Input Polling timer interrupt
; This timer interrupt is used for polling input devices. It provides stable
; (debounced) states of input devices.
; The timer period is depending on the input devices used by the hardware:
;  - For Encoder input device the period is typicaly near 1 msec (about 1000 scans
;    per second)
;  - For potentiometer input device the period is around 7.50 msec (about 133 scans
;    per second)
; The function manages the following operations:
;  - Encoder state debouncing: updates a 'Debounced State' variable if Encoder
;    'signal' line is unchanged for a given period (i.e. the current 'Debounced
;    State' is unchanged until a new stable state is dectected). When the
;    'Debounced	State' is updated, the Encoder 'Steps' information is also
;    updated.
;  - AD conversion launching: periodicaly launches AD conversions (i.e. not at
;    each interrupt because timer period is too near from conversion max time). 
;    The AD conversion debounce is done on 'ConversionDone' event.
;  - Internal status update: updates the status variables according to information
;    read on 'InternalStatusPortData' port.
;  - RC5 instruction debouncing: updates a 'Debounced RC5 Instruction' variable	if
;    the same instruction is fired in a given number of frames.
;  - Temperature measurement: periodically invoked the temperature measurement
;    automaton (i.e. when the interrupt counter reaches the value for the automaton
;    polling period) 
InputPollingTimerEvent:
	push	r16
	in	r16, SREG
	push	r16
	push	r17
	push 	r18

   ; Process inputs according to amplifier control mode (standalone or remote)
   lds  r16, bAmplifierRemoteMode
   cpi  r16, 0x01
   brne InputPollingTimerEvent_StandaloneAmplifier
   jmp InputPollingTimerEvent_RemoteAmplifier

InputPollingTimerEvent_StandaloneAmplifier:

#ifdef ENCODER_INPUTLEVEL

	; Read Encoder0 pins
	in 	    r16, EncoderInputPins		; Pins state on port
	andi 	r16, EncoderInputMask0		; Mask for Encoder0 pins

	; Check if it is the same state than on previous interrupt
	lds 	r17, InputPollingLastEncoderState
	cp 	    r16, r17
 	breq 	InputPollingTimerEvent_EncoderStateUnchanged

	; Encoder outputs state changed, reset debounce variables
	sts 	InputPollingLastEncoderState, r16
	ldi 	r17, InputPollingEncoderDebouncePeriod

	; If no debouncing configured, check the Encoder0 pins state
        cpi	    r17, 0x00
        brne	InputPollingTimerEvent_UpdateEncoderStateCounter

	; Wait a few microsec before reading pins state again
        ldi	    r18, 0xFF
InputPollingTimerEvent_EncoderLoop:
        dec	    r18
        brne	InputPollingTimerEvent_EncoderLoop
        in 	    r18, EncoderInputPins		; Pins state on port
        andi 	r18, EncoderInputMask0		; Mask for Encoder0 pins

        ; Should have the same pins state
        ; If not, it is probably a bounce.
        cp	r16, r18
        breq	InputPollingTimerEvent_EncoderChangeDetected 	 ; State change confirmed and debouncing period
        						         ; elapsed (in fact no debouncing), update the
        						         ; debounced variables

	; Not a stable change, ignore it:
	; - Save the read pins state as the current value
	; - This is done on a code location in the critical section (critical section not
	;   required for current pins state variable update but the code will execute the
	;   exit of the critical section)
	mov	r16, r18
	ENTER_CRITICAL_SECTION
   jmp   InputPollingTimerEvent_EncoderSaveDebouncedState 

InputPollingTimerEvent_EncoderStateUnchanged: 
	; Encoder outputs state unchanged, check if stable period is long 
	; enough to update the 'Debounced' state
	lds 	r17, InputPollingEncoderStateCounter

	; If 'InputPollingEncoderStateCounter' is zero, there was no previous change
	; detected
	cpi 	r17, 0x00
	breq 	InputPollingTimerEvent_EncoderPollingDone	; No change, nothing to do

	; If 'InputPollingEncoderStateCounter' is not zero, check if debounce loop
	; is terminated
	dec 	r17
	brne 	InputPollingTimerEvent_UpdateEncoderStateCounter
	
InputPollingTimerEvent_EncoderChangeDetected:
	; The modified encoder outputs state is stable, update the 'Debounced' variables
	; and reset for a new change detection
	; Compute the direction of the step according to previous debounced state
	; The step direction is retrieved with a map  'LastDebouncedPinState|NewDebouncedPinState' 
	; to 'StepDirection'
	push 	ZL
	push 	ZH

	ldi 	ZL, LOW(EncoderDirectionMap) 	    ; Load map base address
	ldi 	ZH, HIGH(EncoderDirectionMap)
	lds     r17, InputPollingLastDebouncedEncoderState
	clc
	rol     r17
	rol     r17
	or 	    r17, r16   	; r17 is map key ('LastDebouncedPinState|NewDebouncedPinState')
	add     ZL, r17		; Apply map key (offset) to map base address
	ldi     r17,0x00
	adc     ZH, r17
	ld      r17, Z		; Load map value for the key
                        ; Map value indicates step direction: 
				        ;  - 0x00 = invalid change (no step)
				        ;  - 0x01 = step in forward direction
				        ;  - 0xFF = step in backward direction
	pop	    ZH
	pop	    ZL

	ENTER_CRITICAL_SECTION	; Access to 'DebouncedEncoderSteps' variable in a critical section
				                  ; (this variable is also read and reset by 'User Input' interrupt)
       		   
	cpi	    r17,0X01      	 	; Check if forward step
	brne	InputPollingTimerEvent_EncoderCheckForwardStep
	lds	    r17, DebouncedEncoderSteps
	cpi	    r17, 0x7F		; Is maximum positive value reached?
	breq	InputPollingTimerEvent_EncoderSaveDebouncedState
	inc 	r17
	rjmp	InputPollingTimerEvent_EncoderSaveEncoderSteps

InputPollingTimerEvent_EncoderCheckForwardStep:
	cpi	    r17,0xFF		; Check if backward step
	brne	InputPollingTimerEvent_EncoderSaveDebouncedState   	; If the transition is not valid, save current
			                            						; state as the new debounced state

	lds	    r17, DebouncedEncoderSteps
	cpi	    r17, 0x80	; Is maximum negative value reached?
	breq	InputPollingTimerEvent_EncoderSaveDebouncedState
	dec 	r17

InputPollingTimerEvent_EncoderSaveEncoderSteps:
	; Save the new 'DebouncedEncoderSteps' value
	; This variable will be used by 'User Input' interrupt to update the
	; relay states.
	; The  'User Input' interrupt will also reset the variable.
	sts 	DebouncedEncoderSteps, r17

InputPollingTimerEvent_EncoderSaveDebouncedState:
	; Save new debounced encoder pin state (for detection of next change)
	sts	    InputPollingLastDebouncedEncoderState, r16
	
InputPollingTimerEvent_EncoderNextDebouncePeriod:
	; Exit critical section
	LEAVE_CRITICAL_SECTION

	; Not start a new debounce period:
	;  - The 'DebouncedEncoderSteps' has been updated
	;  - The next debounce period will be started when Encoder state change will be detected
	ldi 	r17, 0x00
	
InputPollingTimerEvent_UpdateEncoderStateCounter:
	sts 	InputPollingEncoderStateCounter, r17

InputPollingTimerEvent_EncoderPollingDone:
	; Exit of the Encoder polling routine

#elif ANALOG_INPUTLEVEL

	; Check if a new AD conversion must be started
	lds 	r16, InputPollingADCLaunchCounter
	dec 	r16
	brne 	InputPollingTimerEvent_UpdateADCLaunchCounter
	
	; Start a new AD conversion and set for a new counter period
	in 	    r16, ADCSR 
	ori 	r16, 0b01000000		; bit6: start AD conversion
	out 	ADCSR, r16
	ldi 	r16, InputPollingADCLaunchPeriod
	
InputPollingTimerEvent_UpdateADCLaunchCounter:
	sts 	InputPollingADCLaunchCounter, r16

#endif


   ; Debounce RC5 instruction
   ; The processing for RC5 is not really a debouncing algorythm because the first instruction change must 
   ; launch the action.
   ; If one or more instruction occurences are waiting, the following is applied:
   ;  - The new instruction is transmitted to the 'User Input' interrupt as a debounced instruction.
   ;  - The number of waiting instruction occurences is set to 0.
   ; 
   ; NOTE: The period between 2 instructions in RC5 stream is 114ms and the typical period of the 'User Input'
   ;       interrupt is 20ms (the instruction auto-repeat will be processed by 'User Input' interrupt).
   ENTER_CRITICAL_SECTION                     ; Access to shared variables within a critical section
   lds     r16, InputPollingRC5InstructionCount    ; Is instruction waiting?
   cpi     r16, 0x00
   breq    InputPollingTimerEvent_UpdateInternalStatus
   clr     r16
   sts     InputPollingRC5InstructionCount, r16        ; Clear instruction count
   lds     r16, InputPollingLastRC5Instruction         ; Transmit instruction to 'User Input' interrupt
   sts     InputPollingLastDebouncedRC5Instruction, r16

InputPollingTimerEvent_UpdateInternalStatus:
	; Update internal status variables
   call 	UpdateInternalStatus   ; 'UpdateInternalStatus' must be called in critical section
   LEAVE_CRITICAL_SECTION   ; Exit critical section

   ; End of input processing for 'standalone' amplifier, check temperature
   jmp     InputPollingTimerEvent_CheckTemperature

InputPollingTimerEvent_RemoteAmplifier:
   ; Input processing for 'Remote' amplifier

   ; If the amplifier acts as IR detector in 'remote' mode, transmit RC5 instruction
   ; to the 'User Input' interrupt
   lds   r16, bRemoteModeIRDetector
   cpi   r16, 0x00
   breq  InputPollingTimerEvent_CheckTCPIP

   ; IR detector enabled, process RC5 input (if any)
   ; NOTE: The period between 2 instructions in RC5 stream is 114ms and the typical period of the 'User Input'
   ;       interrupt is 20ms (the instruction auto-repeat will be processed by 'User Input' interrupt).
   ENTER_CRITICAL_SECTION                          ; Access to shared variables within a critical section
   lds     r16, InputPollingRC5InstructionCount    ; Is instruction waiting?
   cpi     r16, 0x00
   breq    InputPollingTimerEvent_RemoteAmpNoRC5Waiting
   clr     r16
   sts     InputPollingRC5InstructionCount, r16        ; Clear instruction count
   lds     r16, InputPollingLastRC5Instruction         ; Transmit instruction to 'User Input' interrupt
   sts     InputPollingLastDebouncedRC5Instruction, r16

InputPollingTimerEvent_RemoteAmpNoRC5Waiting:
   LEAVE_CRITICAL_SECTION   ; Exit critical section

InputPollingTimerEvent_CheckTCPIP:
   ; Check if the master connection has been lost
   ; In this case do the following:
   ;  - The amplifier is switched to a safe state (i.e. a PowerOff command is issued)
   ;  - The TCPIP server is restarted (i.e. the 'DISCONNECTED' state for the TCPIP
   ;    server is a terminated state)
   call  TCPIPCheckServerDisconnected
   cpi   r16, 0x01
   brne  InputPollingTimerEvent_CheckACPCommand   ; Connection OK, check ACP commands

   ; The master connection is lost
	lds	r16, bAmplifierPowerState        ; Switch off amplifier power (if not already off)
   cpi   r16, AMPLIFIERSTATE_POWER_OFF
   breq  InputPollingTimerEvent_RestartTCPIP

	ldi 	r16, USER_COMMAND_ONOFF			   ; Power Off launched with a standard User Command
	call 	UserCommand_ExecuteCommand		   ; Execute User Command

InputPollingTimerEvent_RestartTCPIP:
   ldi   r16, 0x00                        ; Reset 'TCPIPFailedNotifications' shared variable
                                          ; Note: In current version 'TCPIPFailedNotifications'
                                          ;       is not used (i.e. back to safe state on first
                                          ;       heartbeat error)
   ENTER_CRITICAL_SECTION
   sts   TCPIPFailedNotifications, r16    ; Critical section for shared variable
   LEAVE_CRITICAL_SECTION
   call  TCPIPRestartServer               ; Restart TCPIP server (i.e. ready to accept the
                                          ; next master session)

	; Update internal status variables
   ENTER_CRITICAL_SECTION   ; 'UpdateInternalStatus' must be called in critical section
   call 	UpdateInternalStatus
   LEAVE_CRITICAL_SECTION   ; Exit critical section

   jmp   InputPollingTimerEvent_CheckTemperature

InputPollingTimerEvent_CheckACPCommand:
   ; Check and process ACP remote command
   ; If a 'User' command is received via ACP, it is transfered in the 'InputPollingLastACPCommand'
   ; variable.
   ; Note: 
   ;  - The ACP 'User' command is not really processed, the actual processing will be done
   ;    on next 'UserInput' interrupt (asynchroneous).
   ;  - 'User' ACP commands are processed via standard 'InputPolling' and 'UserInput' interrupts
   ;    because they are similar to 'local' user input (button, encoder, IR).
   ;  - 'Master' ACP commands are actually processed here (synchroneously in 'ACPCheckProcessCommand'
   ;    function).
   ; 
   ; TO DO: 
   ;  - No RC5 and buttons in Remote mode
   ;  - Input polling period for remote mode
   call    ACPCheckProcessCommand

	; Update internal status variables
   ENTER_CRITICAL_SECTION   ; 'UpdateInternalStatus' must be called in critical section
   call 	UpdateInternalStatus
   LEAVE_CRITICAL_SECTION   ; Exit critical section

   ; Process next eventual postponed notification
   ; Note: 
   ;  - This is done after the update of the internal status in order to send the notifications 
   ;    with the most up to date status
   ;  - The 'InputPolling' timer period is OK for notification send process (timer period is 7.5ms
   ;    and a notification is typically sent in less than 1ms)
   call  ACPCheckSendPostponedNotif

   ; Send 'heartbeat' notification
   ; Notes: 
   ;  - The 'heartbeat' period is 1000ms
   ;  - If a postponed notification has just been sent, skip the 'heartbeat' for this time
   cpi   r16, 0x01                             ; 'ACPCheckSendPostponedNotif' result in r16
   breq  InputPollingTimerEvent_CheckTemperature  ; A postponed notification has just been sent
                                                  ; Check for temperature measurement

   lds   r16, ACPHeatbeatNoficationTimerCount  ; Increment 'heartbeat' timer tick count
   inc   r16
   cpi   r16, ACPHeatbeatNoficationTimerTicks
   brne  InputPollingTimerEvent_UpdateHeartbeatTimerCount
   ldi   r16, ACP_NOTIFICATION_HEARTBEAT      ; Send the 'Heartbeat' notification
   call  ACPSendNotification
   ldi   r16, 0x00                    ; Reset 'ACPHeatbeatNoficationTimerCount' for a new period

InputPollingTimerEvent_UpdateHeartbeatTimerCount:
   sts   ACPHeatbeatNoficationTimerCount, r16

InputPollingTimerEvent_CheckTemperature:
   ; Check if temperature measurement processing function must be called
   lds   r16, TemperaturePollingCounter  ; Increment automaton polling timer tick count
   inc   r16
   cpi   r16, TemperaturePollingPeriod
   brne  InputPollingTimerEvent_UpdateTempMeasPollingCounter
   call  TemperatureProcess           ; Invoke the temperature measurement automaton
   ldi   r16, 0x00                    ; Reset 'TemperaturePollingCounter' for a new period

InputPollingTimerEvent_UpdateTempMeasPollingCounter:
   sts   TemperaturePollingCounter, r16

#if (!defined BUTTON_LESS)

	ENTER_CRITICAL_SECTION                  ; Shared access to 'bExternalInterruptMask' variable

   ; Debounce On/Off button 
   ; Adjust debounce counter if required
   lds   r16, InputPollingOnOffButtonDebounceL
   cpi   r16, 0x00
   brne  InputPollingTimerEvent_OnOffDebounceCountDown
   lds   r16, InputPollingOnOffButtonDebounceH
   cpi   r16, 0x00
   breq  InputPollingTimerEvent_CheckMuteDebounce
   dec   r16
   sts   InputPollingOnOffButtonDebounceH, r16
   cpi   r16, 0x00
   brne  InputPollingTimerEvent_OnOffDebounceCountDown2

InputPollingTimerEvent_OnOffDebounceCountDown:
   dec   r16
   jmp  InputPollingTimerEvent_OnOffDebounceCountUpdateL

InputPollingTimerEvent_OnOffDebounceCountDown2:
   ldi   r16, 0xFF

InputPollingTimerEvent_OnOffDebounceCountUpdateL:
   sts   InputPollingOnOffButtonDebounceL, r16

InputPollingTimerEvent_CheckMuteDebounce:
   ; Debounce Mute button
   ; Adjust debounce counter if required
   lds   r16, InputPollingMuteButtonDebounceL
   cpi   r16, 0x00
   brne  InputPollingTimerEvent_MuteDebounceCountDown
   lds   r16, InputPollingMuteButtonDebounceH
   cpi   r16, 0x00
   breq  InputPollingTimerEvent_ExternalButtonDebounceDone
   dec   r16
   sts   InputPollingMuteButtonDebounceH, r16
   cpi   r16, 0x00
   brne  InputPollingTimerEvent_MuteDebounceCountDown2

InputPollingTimerEvent_MuteDebounceCountDown:
   dec   r16
   jmp  InputPollingTimerEvent_MuteDebounceCountUpdateL

InputPollingTimerEvent_MuteDebounceCountDown2:
   ldi   r16, 0xFF

InputPollingTimerEvent_MuteDebounceCountUpdateL:
   sts   InputPollingMuteButtonDebounceL, r16

InputPollingTimerEvent_ExternalButtonDebounceDone:
   LEAVE_CRITICAL_SECTION 

#endif

InputPollingTimerEvent_Exit:
	pop	r18
	pop 	r17
	pop 	r16
	out 	SREG, r16
	pop 	r16
	reti

; Interrupt handler for AD conversion result ready interrupt
; The new value is read and processed for average calculation:
;  - If more samples are required for average calculation, the value is summed
;  - If all samples are collected, the average is computed and the 'stable'
;    value is updated.
ADConvDoneEvent:
	push 	r16
	in	r16, SREG
	push	r16
	push 	r17
	push 	r18

	; Obtain and compute new input level
	lds	    r16, ADCL	; Obtain 10 bit AD conversion result
	lds	    r18, ADCH

; DEBUG: Simulation of non zero conversion value
;       ldi r16, 0xff	;DEBUG -> 3ff = should result in 0x7F value (7 relays on)
;       ldi r18, 0x03

	lsr 	r16	       	; Round to the 8 most significant bits
	lsr 	r16
	lsl 	r18
	lsl 	r18
	lsl 	r18
	lsl 	r18
	lsl 	r18
	lsl 	r18
	or 	    r18, r16    	; New value stored in r18

	; Add the new value in current sum for average
	; Note: Sum stored in r17:r16
	lds 	r16, ADConversionSampleSumLow
	lds 	r17, ADConversionSampleSumHigh
	add 	r16, r18
	ldi 	r18, 0x00
	adc 	r17, r18

	; Increment sample number and check if all samples are collected
	lds 	r18, ADConversionSampleCounter
	inc 	r18
	cpi 	r18, ADConversionSampleNumber
	brne 	ADConvDoneEvent_UpdateAndExit

	; Compute the average
	; By design the average is computed by right shifts
	; Look if average is used
	cpi	    r18, 0x01	; No average if ADConversionSampleNumber is 1
	breq	ADConvDoneEvent_AverageReady

ADConvDoneEvent_AverageLoop:
	; Divide the average value (r17:r16) by 2
	clc
	ror 	r17
	ror 	r16

	; Divide the 'ADConversionSampleNumber' by 2
	; - If sample number is 2: average must be divided by 2 one time
	; - If sample number is 4: average must be divided by 2 two times
	; - If sample number is 8: average must be divided by 2 three times
	; - ...
	clc
	ror 	r18
	cpi	    r18, 0x01	; One reached when last required divide done
	breq 	ADConvDoneEvent_AverageReady

	rjmp 	ADConvDoneEvent_AverageLoop

ADConvDoneEvent_AverageReady:
	; Average is computed (in r16)
	; This is a 8 bit value, divide by 2 one more time to obtain the 7 bit value
    clc
    ror 	r16
	
	; Update the stable ADC input value
	sts 	AveragedADCValue, r16

	; Reset sum and ADConversionSampleCounter
	ldi 	r16, 0x00
	ldi 	r17, 00
	ldi 	r18, 00

ADConvDoneEvent_UpdateAndExit:
	; Update sum and sample counter
	sts 	ADConversionSampleSumLow, r16
	sts 	ADConversionSampleSumHigh, r17
	sts 	ADConversionSampleCounter, r18

ADConvDoneEvent_Exit:
	pop 	r18
	pop 	r17
	pop 	r16
	out 	SREG, r16
	pop 	r16
	reti

; User Input Timer event
; This timer interrupt is for user input polling.
; The typical timer period is 20 msec (50 scans per second for user commands)
; The function manages the following operations:
;  - Input Level change detection: when the Input Level is changed the Output
;    Level relay states are updated
;  - Remote Control instruction processing: when an RC5 instruction is received
;    the corresponding User Command is issued.
;  - ACP command processing: when an ACP command is received the corresponding 
;    User Command is issued
; Note: 
;  - This function works with 'stable' user input information (i.e. info
;    computed by the 'Input Polling' and 'AD Conversion' interrupt handlers)
;  - The time for processing the User Input may be greater than user input timer
;    period (typically volume change). For this reason user input timer interrupt
;    is masked during the processing (i.e. protection against re-entry of
;    interrupt handler).
UserInputTimerEvent:
	push 	r16
	in	r16, SREG
	push	r16
	push 	r17
	push 	r18
	push 	r19
	push 	r20
	
   ; Mask User Input timer interrupt (i.e. re-entry not allowed)
   ENTER_CRITICAL_SECTION
	lds	r16, UserInputTimerIntMask
   push  r16                            ; Current 'UserInputTimerIntMask' stored on stack  
   ldi   r16, 0x00
	sts 	UserInputTimerIntMask, r16
   LEAVE_CRITICAL_SECTION 

	; Detect change in Level User Input Value (ADC or Encoder) and adjust 
	; current Output Level (i.e. relay states) if necessary

#ifdef	ANALOG_INPUT

	; Check if ADC average value is different from current Level
 	lds 	r18, AveragedADCValue
	lds 	r16, bCurrentLevel
	cp 	    r18, r16
	breq 	UserInputTimerEvent_ADCUnchanged

	; Value changed, check if new value must be applied
	lds 	r16, bADCLevelChangeCount
	inc 	r16
	lds 	r17, bLevelChangedCount
	cp  	r16, r17		; Carry set if r17 > r16
	brcc 	UserInputTimerEvent_SetValue

	; Not apply new value now, store incremented 'bADCLevelChangeCount'
	sts 	bADCLevelChangeCount, r16
	rjmp 	UserInputTimerEvent_CheckRemoteControl

UserInputTimerEvent_SetValue:
	; Apply the new value on outputs
	sts 	bCurrentLevel, r18     	; Store new current value
	call 	SetOutputValue		; Update output relay states

	; Fallthrough: reset the 'bADCLevelChangeCount' for a new cycle

UserInputTimerEvent_ADCUnchanged:
	; Value not changed, reset 'bADCLevelChangeCount'
	ldi     r16, 0
	sts     bADCLevelChangeCount, r16

#else

	; Check for a non zero Encoder 'Step' count
	; Set the output level if the step count is not zero and LevelChangeCount 
	; threshold reached
	; 'DebouncedEncoderSteps' shared variable must be accessed in critical section
	ENTER_CRITICAL_SECTION
	lds     r18, DebouncedEncoderSteps
	cpi     r18, 0x00
	brne	UserInputTimerEvent_EncoderSteps
	LEAVE_CRITICAL_SECTION				; Exit critical section
	rjmp	UserInputTimerEvent_NoEncoderSteps

UserInputTimerEvent_EncoderSteps:
	; Encoder steps memorized, check if new value must be applied
	lds 	r16, bEncoderLevelChangeCount
	inc 	r16
	lds 	r17, bLevelChangedCount
	cp 	    r16, r17		; Carry set if r17 > r16
	brcc 	UserInputTimerEvent_ComputeValue

	; Not apply new value now, store incremented 'bEncoderLevelChangeCount'
	LEAVE_CRITICAL_SECTION				; Exit critical section
	sts 	bEncoderLevelChangeCount, r16
	rjmp 	UserInputTimerEvent_CheckRemoteControl

UserInputTimerEvent_ComputeValue:
	; New value will be applied, clear 'DebouncedEncoderSteps' shared variable
	; and exit critical section
	ldi	r16, 0x00
	sts	DebouncedEncoderSteps, r16
	LEAVE_CRITICAL_SECTION			   

	; Compute the new output level value (i.e. add memorized steps to current value)
	cpi 	r18, 0x00		; Is negative value (backward steps)
	brlt	UserInputTimerEvent_NegativeSteps					     ; REPORTED in User commmnd

	; Steps are positive, check if maximum value not reached with add
	ldi	r16, 0x7F		; Check for clipping 
					; 'bCurrentLevel' maximum value is 0x7F
	lds	r17, bCurrentLevel
	sub	r16, r17
	cp	r18, r16
	brlo	UserInputTimerEvent_AddSteps

	; Clip to maximum value
	ldi	    r18, 0x7F
	rjmp	UserInputTimerEvent_SetValue

UserInputTimerEvent_AddSteps:
	add	    r18, r17			; Add steps to current value
	rjmp	UserInputTimerEvent_SetValue
 
UserInputTimerEvent_NegativeSteps:
	; Steps are negative, check if minimum value not reached with substract
	lds 	r16, bCurrentLevel
	mov	r17, r18
	neg	r17
	cp	r17, r16	; Check for clipping
	brlo	UserInputTimerEvent_SubstractSteps

	; Clip to minimum value
	ldi	r18, 0x00
	rjmp	UserInputTimerEvent_SetValue

UserInputTimerEvent_SubstractSteps:
	mov	    r18, r16		; Substract steps to current value
	sub	    r18, r17

UserInputTimerEvent_SetValue:
	; Apply the new value on outputs
	; Check before if really need to apply (typically value already clipped)
	lds	r17, bCurrentLevel
	cp	r17, r18	  
	breq	UserInputTimerEvent_NoEncoderSteps
	sts 	bCurrentLevel, r18  	; Store new current value  
	call 	SetOutputValue		; Update output relay states

	; Fallthrough: reset the 'bEncoderLevelChangeCount' for a new cycle

UserInputTimerEvent_NoEncoderSteps:
	; No Encoder steps, reset 'bEncoderLevelChangeCount'
	ldi     r16, 0
	sts     bEncoderLevelChangeCount, r16

#endif
	

UserInputTimerEvent_CheckRemoteControl:
	; Detect user action on Remote Control device and apply action if required
	ENTER_CRITICAL_SECTION 	; Shared access to 'Input Polling' variable
	lds	r16, InputPollingLastDebouncedRC5Instruction  ; Debounced RC5 code
	lds	r19, InputPollingRC5KeyPressed	             ; Current key pressed state

   ;The debounced instruction' variable has been read, reset it
   ldi	r17, 0xFF                           
	sts	InputPollingLastDebouncedRC5Instruction, r17  
	LEAVE_CRITICAL_SECTION

	; Check/update repeat counter for the instruction
	lds	r17, UserInputRC5LastInstruction
	lds	r18, UserInputRC5LastInstructionDuration

	cpi	r16, 0xFF	; Is debounced instruction valid? (6 bit value, 0xFF means undefined)
	brne	UserInputTimerEvent_DebouncedInstructionValid

	; The debounced instruction is not valid (typically 'UserInput' sample located between 2 RC5 frames)
	; Increment the 'UserInputRC5LastInstructionDuration'
	; If the 'UserInputRC5LastInstructionDuration' reaches the max counter value (255 * 20 = 5100ms),
	; reset the 'UserInputRC5LastInstruction' (= the current instruction is definitively 'undefined').
   ; In this case the next significant debounced instruction will launch the action.

	cpi	r17, 0xFF		; If last instruction is not defined, it is not
								; the case of sampling located between 2 frames
								; (i.e. no current instruction to process)
	brne	UserInputTimerEvent_RCUpdateInstructionDuration
	jmp	UserInputTimerEvent_ACPCheckCommand                ; No RC5 command, check now ACP command

UserInputTimerEvent_RCUpdateInstructionDuration:

   ; Increment the 'UserInputRC5LastInstructionDuration' variable if the key is still pressed
   ; (i.e. repeating)
   ; If the key is released, reset 'LastInstruction' duration variables
   cpi   r19, 0x01
   brne  UserInputTimerEvent_RCLastInstructionUndef
	inc 	r18	  
   sts	UserInputRC5LastInstructionDuration, r18   	   ; Store new instruction time
	cpi	r18, 0x00
	breq    UserInputTimerEvent_RCLastInstructionUndef  	; Is counter overflow?
	lds	r20, UserInputRC5LastKeyPressDuration	      	; Key currently pressed, increment KeyPressed duration
	inc 	r20
	sts	UserInputRC5LastKeyPressDuration, r20
	jmp   UserInputTimerEvent_ACPCheckCommand             ; No action for RC5 command, check now ACP command
                                                    
UserInputTimerEvent_RCLastInstructionUndef:                                                    
	sts 	UserInputRC5LastInstruction, r16	      ; Last instruction 'Undefined'
	ldi	r16, 0x00				                  ; Reset 'KeyPress' duration    
	sts	UserInputRC5LastKeyPressDuration, r16
   sts	UserInputRC5LastInstructionDuration, r16
	jmp   UserInputTimerEvent_ACPCheckCommand    ; No action for RC5 command, check now ACP command

UserInputTimerEvent_DebouncedInstructionValid:
	; The debounced instruction is valid, check if it is a repeat of previous instruction
	cp	r16, r17				; Is last instruction repeated
	brne	UserInputTimerEvent_RCNewInstruction
	inc 	r18					; Instruction repeated, update elapsed time
	rjmp	UserInputTimerEvent_RCUpdateInstructionTime

UserInputTimerEvent_RCNewInstruction:
	sts 	UserInputRC5LastInstruction, r16	; Store new instruction
	ldi	r18, 0x00				; Instruction is new so elapsed time is 0

UserInputTimerEvent_RCUpdateInstructionTime:
	sts	UserInputRC5LastInstructionDuration, r18	; Store new instruction time

	; The instruction is valid, update 'UserInputRC5LastKeyPressDuration'
	ldi	r20, 0x00		; r20 contains 'UserInputRC5LastKeyPressDuration'
	cpi	r18, 0x00		; If new instruction, 'KeyPress' duration is 0
	breq	UserInputTimerEvent_RCUpdateKeyPressDuration2
	cpi	r19, 0x00					; Is current key pressed?
	breq	UserInputTimerEvent_RCUpdateKeyPressDuration2
	lds	r20, UserInputRC5LastKeyPressDuration	      	; Key currently pressed, increment KeyPressed duration
	inc 	r20

UserInputTimerEvent_RCUpdateKeyPressDuration2:
	sts	UserInputRC5LastKeyPressDuration, r20

	; Retrieve the REMOTECONTROL_INSTRUCTION associated with the RC5 code
	ldi	ZH, HIGH(RemoteControlInstructionMap)	; Use 'RemoteControlInstructionMap' for mapping
	ldi	ZL, LOW(RemoteControlInstructionMap)	
	add	ZL, r16
	clr	r16
	adc	ZH, r16
	ld	r16, Z 

	; Process Remote Control instruction
	; Each instruction has the ability to decide how to use the repeat counter.
	; The typical cases are:
	;  - Autorepeat = Instruction is repeated when the configured 'click' duration has elapsed
	;  - Single shot = The instruction triggers an action only on the first occurence
	;  - Delayed action = The action is launched only if the instruction is persisting for a
	;    given time (typicaly On/Off instruction).
	;    Max value is 255 * User Input timer period (= 5100ms).
	; 
	; When reaching this point:
	;  - r16 = REMOTECONTROL_INSTRUCTION_xxx
	;  - r18 = UserInputRC5LastInstructionDuration
	;  - r20 = UserInputRC5LastKeyPressDuration
    ;
    ; NOTE: If the IR detector is used in 'Remote' mode, the 'USER_COMMAND' is not launched
    ;       directly. In this case, an ACP Notification is sent to the ACC program to
    ;       transmit the action request. The ACC program will then send an ACP Command 
    ;       to all the amplifiers connected on the platform (i.e. the 'USER_COMMAND' is
    ;       propagated to all amplifiers)
	cpi	r16, REMOTECONTROL_INSTRUCTION_ONOFF
	brne	UserInputTimerEvent_RCCheckMuteInstruction
	call	IsRemoteControlDelayedActionNow		   ; 'REMOTECONTROL_INSTRUCTION_ONOFF' is a
							                           ; standard delayed instruction
	cpi	r17, 0x00
 	brne	UserInputTimerEvent_RCApplyOnOffCommand
	jmp	UserInputTimerEvent_Exit

UserInputTimerEvent_RCApplyOnOffCommand:
	ldi 	r16, USER_COMMAND_ONOFF			   ; Translate RC instruction in User Command
	jmp	    UserInputTimerEvent_RCApplyCommand

UserInputTimerEvent_RCCheckMuteInstruction:
	cpi	r16, REMOTECONTROL_INSTRUCTION_MUTE

   ; RC5 VOLUMEPLUS and VOLUMEMINUS commands not allowed if Input Level controled by
   ; potentiomer or encoder
#if (defined ENCODER_INPUTLEVEL || defined ANALOG_INPUTLEVEL)
	brne	UserInputTimerEvent_ACPCheckCommand
#else
	brne	UserInputTimerEvent_RCCheckVolPlusInstruction
#endif   
	call	IsRemoteControlSingleShotNow		   ; 'REMOTECONTROL_INSTRUCTION_MUTE' is a
							                       ; standard single shot instruction
	cpi	r17, 0x00
	brne	UserInputTimerEvent_RCApplyMuteCommand
	jmp	UserInputTimerEvent_Exit
						   
UserInputTimerEvent_RCApplyMuteCommand:
	ldi 	r16, USER_COMMAND_MUTE                     ; Translate RC instruction in User Command 
	jmp	    UserInputTimerEvent_RCApplyCommand         ; Launch command execution

UserInputTimerEvent_RCCheckVolPlusInstruction:
	cpi	    r16, REMOTECONTROL_INSTRUCTION_VOLUMEPLUS
	brne	UserInputTimerEvent_RCCheckVolMinusInstruction

	call	IsRemoteControlAutoRepeatNow		   ; 'REMOTECONTROL_INSTRUCTION_VOLUMEPLUS' is a
							                       ; standard auto repeated instruction
	cpi	    r17, 0x00
	brne	UserInputTimerEvent_RCApplyVolPlusCommand
	jmp	    UserInputTimerEvent_Exit
						   
UserInputTimerEvent_RCApplyVolPlusCommand:
	ldi 	r16, USER_COMMAND_CHANGEVOLUME             ; Translate RC instruction in User Command 
	ldi	    r18, 0x01				                   ; Add one volume 'Step'
	jmp	    UserInputTimerEvent_RCApplyCommand         ; Launch command execution

UserInputTimerEvent_RCCheckVolMinusInstruction:
	cpi   r16, REMOTECONTROL_INSTRUCTION_VOLUMEMINUS
	brne	UserInputTimerEvent_RCCheckBacklightPlusInstruction

	call	IsRemoteControlAutoRepeatNow		   ; 'REMOTECONTROL_INSTRUCTION_VOLUMEMINUS' is a
							                       ; standard auto repeated instruction
	cpi	    r17, 0x00
	brne	UserInputTimerEvent_RCApplyVolMinusCommand
	jmp	    UserInputTimerEvent_Exit

UserInputTimerEvent_RCApplyVolMinusCommand:
	ldi 	r16, USER_COMMAND_CHANGEVOLUME             ; Translate RC instruction in User Command 
	ldi	    r18, 0xFF				                   ; Substract one volume 'Step'
	jmp	    UserInputTimerEvent_RCApplyCommand         ; Launch command execution

UserInputTimerEvent_RCCheckBacklightPlusInstruction:
	cpi	    r16, REMOTECONTROL_INSTRUCTION_BACKLIGHTPLUS
	brne	UserInputTimerEvent_RCCheckBacklightMinusInstruction

	call	IsRemoteControlAutoRepeatNow		   ; 'REMOTECONTROL_INSTRUCTION_BACKLIGHTPLUS' is a
							                       ; standard auto repeated instruction
	cpi	    r17, 0x00
	brne	UserInputTimerEvent_RCApplyBacklightPlusCommand
	jmp	    UserInputTimerEvent_Exit
						   
UserInputTimerEvent_RCApplyBacklightPlusCommand:
	ldi 	r16, USER_COMMAND_CHANGEBACKLIGHT          ; Translate RC instruction in User Command 
	ldi	    r18, 0x01				                   ; Add one backlight 'Step'
	jmp	    UserInputTimerEvent_RCApplyCommand         ; Launch command execution

UserInputTimerEvent_RCCheckBacklightMinusInstruction:
	cpi	    r16, REMOTECONTROL_INSTRUCTION_BACKLIGHTMINUS
	brne	UserInputTimerEvent_RCCheckContrastPlusInstruction

	call	IsRemoteControlAutoRepeatNow		   ; 'REMOTECONTROL_INSTRUCTION_BACKLIGHTMINUS' is a
							                       ; standard auto repeated instruction
	cpi	    r17, 0x00
	brne	UserInputTimerEvent_RCApplyBacklightMinusCommand
	jmp	    UserInputTimerEvent_Exit
						   
UserInputTimerEvent_RCApplyBacklightMinusCommand:
	ldi 	r16, USER_COMMAND_CHANGEBACKLIGHT          ; Translate RC instruction in User Command 
	ldi	    r18, 0xFF				                   ; Substract one backlight 'Step'
	jmp	    UserInputTimerEvent_RCApplyCommand         ; Launch command execution

UserInputTimerEvent_RCCheckContrastPlusInstruction:
	cpi	    r16, REMOTECONTROL_INSTRUCTION_CONTRASTPLUS
	brne	UserInputTimerEvent_RCCheckContrastMinusInstruction

	call	IsRemoteControlAutoRepeatNow		   ; 'REMOTECONTROL_INSTRUCTION_CONTRASTPLUS' is a
							                       ; standard auto repeated instruction
	cpi	    r17, 0x00
	brne	UserInputTimerEvent_RCApplyContrastPlusCommand
	jmp	    UserInputTimerEvent_Exit
						   
UserInputTimerEvent_RCApplyContrastPlusCommand:
	ldi 	r16, USER_COMMAND_CHANGECONTRAST           ; Translate RC instruction in User Command 
	ldi	    r18, 0xFF				                   ; Add one contrast 'Step'
                                                       ; Note: One step up in contrast is one step
                                                       ;       down on potentiometer
	jmp	    UserInputTimerEvent_RCApplyCommand         ; Launch command execution

UserInputTimerEvent_RCCheckContrastMinusInstruction:
	cpi	    r16, REMOTECONTROL_INSTRUCTION_CONTRASTMINUS
	brne	UserInputTimerEvent_ACPCheckCommand

	call	IsRemoteControlAutoRepeatNow		   ; 'REMOTECONTROL_INSTRUCTION_CONTRASTMINUS' is a
							                       ; standard auto repeated instruction
	cpi	    r17, 0x00
	brne	UserInputTimerEvent_RCApplyContrastMinusCommand
	jmp	    UserInputTimerEvent_Exit
						   
UserInputTimerEvent_RCApplyContrastMinusCommand:
	ldi 	r16, USER_COMMAND_CHANGECONTRAST           ; Translate RC instruction in User Command 
	ldi	    r18, 0x01				                   ; Substract one contrast 'Step'
                                                       ; Note: One step down in contrast is one step
                                                       ;       up on potentiometer
	jmp	    UserInputTimerEvent_RCApplyCommand         ; Launch command execution


UserInputTimerEvent_RCApplyCommand:
    ; 'USER_COMMAND' has been validated and is ready in r16 (optional parameter in r18)
    ; Check if command must be launched directly or transmited as ACP Notification
    lds     r17, bRemoteModeIRDetector
    cpi     r17, 0x00
    brne    UserInputTimerEvent_RCNotifyCommand
	call 	UserCommand_ExecuteCommand		        ; Execute User Command now
	jmp	UserInputTimerEvent_Exit
                                  
UserInputTimerEvent_RCNotifyCommand:
    ; Propagate the command request to all amplifiers via ACP Notification 
    ; (i.e. this amplifier is IR detector on a platform configured in 'Remote' mode)
    ; 
    ; Note: The 'USER_COMMAND_xxx' value is identical to the 'ACP_COMMAND_USER_xxx'
    ;       value. The notified 'ACP_COMMAND_USER_' value will be send back unchanged
    ;       by the ACC program in the ACP Command.
    sts   UserInputRemoteModeIRCommand, r16        ; Notification parameters
    sts   UserInputRemoteModeIRCommandParam, r18
    ldi   r16, ACP_NOTIFICATION_IRUSERCOMMAND      ; Send the 'IRUserCommand' notification
    call  ACPSendNotification
	jmp	    UserInputTimerEvent_Exit


UserInputTimerEvent_ACPCheckCommand:

   ; If amplifier is in 'Remote' configuration, check if an ACP command is waiting
	ENTER_CRITICAL_SECTION              ; Shared access to 'Input Polling' variable
   lds   r16, InputPollingLastACPCommand
   cpi   r16, 0xFF
   LEAVE_CRITICAL_SECTION
   breq  UserInputTimerEvent_Exit                    ; No ACP command waiting

   ; ACP command waiting
   ; r16 contains a USER_COMMAND_xx value
   ; Note: 
   ;  - The 'InputPollingLastACPCommand' has already been validated
   ;  - Arguments for USER_COMMAND_xx are transmited with r18, r19 and r20
   lds   r18, InputPollingLastACPCommandParam0    ; Load arguments for User Command (in case of any)
   lds   r19, InputPollingLastACPCommandParam1    
   lds   r20, InputPollingLastACPCommandParam2    

   ; The ACP Command is going to be processed, clear 'Input Polling' shared variable
   ; This allows reception of a new command during processing of current command
   ENTER_CRITICAL_SECTION
   ldi  r17, 0xFF                        ; No ACP command waiting (i.e. currently processed)
   sts  InputPollingLastACPCommand, r17
   LEAVE_CRITICAL_SECTION

	call 	UserCommand_ExecuteCommand		           ; Execute User Command

UserInputTimerEvent_Exit:

   ; Restore User Input timer interrupt 
   ; 'UserInputTimerIntMask' stored on stack when function entered
   ENTER_CRITICAL_SECTION
   pop   r16
	sts 	UserInputTimerIntMask, r16
   LEAVE_CRITICAL_SECTION 

	pop 	r20
	pop 	r19
	pop 	r18
	pop 	r17
	pop 	r16
	out 	SREG, r16
	pop 	r16
	reti

; Interrupt handler for On/Off button pressed event
; The 'USER_COMMAND_ONOFF' command is invoked to process the action.
; The amplifier power state is inverted by generating a positive pulse on trigger softstart
; On/off input.
; See 'USER_COMMAND_ONOFF' command for details.
OnOffButtonEvent:

#if (!defined BUTTON_LESS)
	push	r16
	in    r16, SREG
	push	r16

   ; Debounce button
   ; Note: Not possible to simply mask the interrupt during debounce period because if interrupt
   ;       is raised during this period, the handler is invoked when the interrupt mask is cleared
	ENTER_CRITICAL_SECTION                       ; Shared access to 'bExternalInterruptMask' variable
   lds   r16, InputPollingOnOffButtonDebounceL  ; Check if interrupt raised while in debounce period
   cpi   r16, 0x00
   brne  OnOffButtonEvent_DebouncePending
   lds   r16, InputPollingOnOffButtonDebounceH
   cpi   r16, 0x00
   brne  OnOffButtonEvent_DebouncePending

   ; Interrupt accepted
   ; Note: Mute button is also disabled during power ON/OFF sequence (i.e. mute controlled by power ON/OFF)
   ldi   r16, ExternalButtonInterruptTimerTicksL  ; Enter debounce period on On/Off and Mute buttons
   sts   InputPollingOnOffButtonDebounceL, r16
   sts   InputPollingMuteButtonDebounceL, r16
   ldi   r16, ExternalButtonInterruptTimerTicksH 
   sts   InputPollingOnOffButtonDebounceH, r16
   sts   InputPollingMuteButtonDebounceH, r16
   LEAVE_CRITICAL_SECTION 

   ; Process On/Off command
   ldi 	r16, USER_COMMAND_ONOFF			   ; Translate RC instruction in User Command
   call 	UserCommand_ExecuteCommand		   ; Execute User Command
   jmp   OnOffButtonEvent_Exit

OnOffButtonEvent_DebouncePending:
   LEAVE_CRITICAL_SECTION 

OnOffButtonEvent_Exit:
	; Exit
	pop 	r16
	out 	SREG, r16
	pop 	r16
#endif

	reti

; Interrupt handler for Mute/Unmute button pressed event
; The 'USER_COMMAND_MUTE' command is invoked to process the action.
; The amplifier output mute state is inverted by generating a positive pulse on trigger
; softstart Mute/Unmute input.
; See 'USER_COMMAND_MUTE' command for details.
; 
; The function implements the following behaviour:
;  - The audio output relay is inverted
;  - The audio output state is updated
;  - The new audio output state is displayed on the LCD
MuteButtonEvent:

#if (!defined BUTTON_LESS)
	push	r16
	in    r16, SREG
	push	r16

   ; Debounce button
   ; Note: Not possible to simply mask the interrupt during debounce period because if interrupt
   ;       is raised during this period, the handler is invoked when the interrupt mask is cleared
	ENTER_CRITICAL_SECTION                       ; Shared access to 'bExternalInterruptMask' variable
   lds   r16, InputPollingMuteButtonDebounceL   ; Check if interrupt raised while in debounce period
   cpi   r16, 0x00
   brne  MuteButtonEvent_DebouncePending
   lds   r16, InputPollingMuteButtonDebounceH
   cpi   r16, 0x00
   brne  MuteButtonEvent_DebouncePending

   ; Interrupt accepted
   ldi   r16, ExternalButtonInterruptTimerTicksL  ; Enter debounce period
   sts   InputPollingMuteButtonDebounceL, r16
   ldi   r16, ExternalButtonInterruptTimerTicksH 
   sts   InputPollingMuteButtonDebounceH, r16
   LEAVE_CRITICAL_SECTION 

   ; Process Mute command
   ldi 	r16, USER_COMMAND_MUTE			   ; Translate RC instruction in User Command
   call 	UserCommand_ExecuteCommand		   ; Execute User Command
   jmp   MuteButtonEvent_Exit

MuteButtonEvent_DebouncePending:
   LEAVE_CRITICAL_SECTION 

MuteButtonEvent_Exit:
	; Exit
	pop 	r16
	out 	SREG, r16
	pop 	r16
#endif

	reti


; Interrupt handler for RC5 frame start event
; The interrupt occurs on the falling edge of the IR detector signal:
;  - Typically this falling edge indicates the start of a new frame (the value of 2 first bits 
;    of the frame is 1).
;  - Once this falling edge is detected, the interrupt is masked until the frame duration is elapsed.
;    This means that only the first falling edge (= frame start) calls this interrupt handler.
; 
; The function behaves as follows:
;  - The 'RC5FrameDetection' interrupt is masked
;  - The 'RC5FrameTimer' interrupt is enabled and the timer is started (in FAST mode)
;  - The frame decoding function is called
;  - If the frame decoding is completed:
;     .. The 'RC5FrameTimer' period is changed to 1 millisec (SLOW mode)
;     .. The 'RC5FrameTimer' is used to wait for inter frame period (key release detection)
;     .. The 'RC5FrameDetection' interrupt is enabled back
;  - Else:
;     .. The 'RC5FrameTimer' period is changed to 1 millisec (SLOW mode)
;     .. The 'RC5FrameTimer' is used to wait for the end of frame period
;     .. When the end of frame is reached (according to 'RC5FrameTimer' tick count):
;        ... The 'RC5FrameDetection' interrupt is enabled back
;        ... The counting for inter frame period is started
;     .. When the end of inter frame period is reached
;        ... The 'RC5FrameTimer' interrupt is masked
;  
; Notes: 
;  - The 'RC5FrameTimer' interrupt increments the real time counters required to acquire 
;    frame data.
;  - The frame duration count always enable back this interrupt between to frames 
;    (frame duration: 25ms, time between 2 frames: 89ms).
;  - In fact, all external interrupts and timer interrupts (excepted 'RC5FrameTimer' interrupt) 
;    are masked during frame decoding.
RC5FrameStartEvent:
	ENTER_CRITICAL_SECTION			; Disable interrupts
	push	r16
	in	r16, SREG
	push	r16
	push	r17
	push	r18

	; The begining of a frame is detected
	; Mask all external interrupts
	; The RC5 Frame Start is also masked to not be triggered again during frame decoding
	ldi 	r16, 0x00
	out 	EIMSK, r16

	; Mask Input Polling and User Polling timer interrupts
	; Note: The timers are not stopped (nor resetted afterward) because these timings are not
	;       critical. The RC5 decoding is also related to user input.
	sts 	InputPollingTimerIntMask, r16
	sts 	UserInputTimerIntMask, r16

	; Reset Frame decoding variables
	sts	RC5BitDurationCounter, r16
	sts	RC5BitMeasuredDuration, r16
	sts	RC5FrameDurationCounter, r16

	; Start RC5 Frame Timer in FAST mode
    ; The RC5 Frame Timer may run in SLOW mode if this interrupt occurs when waiting for
    ; inter frame duration
    lds     r16, RC5InterFrameDurationCounter
    cpi     r16, 0xFF
    breq    RC5FrameStartEvent_StartRC5FrameTimer
	ldi 	r16, 0x00		            ; Stop counting
	sts 	RC5FrameTimerCtrlB, r16 
	ldi	    r16, 1 << InputPollingTimerCompIntEnable
	sts 	InputPollingTimerIntMask, r16
	ldi	    r16, 1 << UserInputTimerCompIntEnable
	sts 	UserInputTimerIntMask, r16
    ldi     r16, 0xFF
    sts     RC5InterFrameDurationCounter, r16

RC5FrameStartEvent_StartRC5FrameTimer:
   ldi   r16, 0x00
	sts	RC5FrameDurationDividerCount, r16   ; In FAST mode a divider is used for Frame duration counter
	ldi	r17, 20
	sts	RC5FrameDurationDivider, r17

	sts	RC5FrameTimerCounterH, r16	; Clear timer counter
	sts	RC5FrameTimerCounterL, r16	; Writting the low byte triggers the 16 bit write
	ldi	r17, RC5FrameTimerFastPeriodH	; Set compare value for 50 µsec period
	ldi	r16, RC5FrameTimerFastPeriodL
	sts	RC5FrameTimerCompH, r17
	sts	RC5FrameTimerCompL, r16

	ldi 	r16, 0b00001001	    	; Start counting
					; Set timer mode and prescaler (Timer 1 Control Register B)
					; No prescaler (bits 0-2 set to '001')
					; CTC = Clear Timer on Compare match mode (bit 3 set to 1)
	sts 	RC5FrameTimerCtrlB, r16 ; Note: Nothing to set in RC5FrameTimerCtrlA 
                                        ;       (i.e. must be 0x00)

	; Enable RC5 Frame Timer interrupt
	ldi 	r16, 1 << RC5FrameTimerCompIntEnable
	sts 	RC5FrameTimerIntMask, r16
	LEAVE_CRITICAL_SECTION				; Enable interrupts 

	; Start frame decoding
	; Note: 
	;  - The function is called with interrupts enabled and returns in the same state  
	;  - On return, the r16 register contains the result of the operation
	call 	RemoteControl_DecodeFrame
	ENTER_CRITICAL_SECTION

	; Mask the RC5 Frame Timer interrupts.
    ; The RC5 Frame Timer mode will be changed to SLOW:
	;  - If the frame is fully decoded, the timer will detect the end of the inter frame duration
	;  - If the frame is not decoded, the timer will detect the end of frame and then count for
    ;    the inter frame duration 
	ldi 	r17, 0x00
	sts 	InputPollingTimerIntMask, r17
	sts 	UserInputTimerIntMask, r17
	
	; Stop the counter (i.e. no clock on input):
	;  - The counter is started only when needed for decoding frames
	;  - It is not recommended to change the Output Compare register (16 bit) in CTC mode without
	;    prescaler (in CTC access to the 16 bit register is not atomic)
	sts 	RC5FrameTimerCtrlB, r17 

	; Check the status of the decoding operation (value available in r16):
	;  - 0x00 = The frame is fully decoded.
	;           In this case, no more transition is expected on the IR detector pin	and the
	;           external interrupt for RC5 Frame detection can be enabled back.
	;  - 0x01 = The	frame is not terminated but the toggle has not changed.
	;           This means that the key detected before is still pushed.
	;           The external interrupt for RC5 Frame detection cannot be enabled back yet.
	;  - 0xFE = The frame is addressed to an other terminal.
	;           The external interrupt for RC5 Frame detection will be enabled back when
	;           frame duration will be elapsed.
	;  - 0xFF = An error occurs during frame decoding.
	;           The external interrupt for RC5 Frame detection will be enabled back when
	;           frame duration will be elapsed.
	
 	; Note:
	;  - The data decoded from the frame has been written in the Input Polling shared variables.
	;  - The corresponding action will be applied by the Input Polling and User Input interrupt
	;    functions.


	; Configure the RC5 Frame Timer in SLOW mode for waiting the end of frame duration or the
    ; inter frame duration
	ldi	r18, RC5FrameTimerSlowPeriodH	; Set compare value for 1000 µsec period
	ldi	r17, RC5FrameTimerSlowPeriodL
	sts	RC5FrameTimerCompH, r18
	sts	RC5FrameTimerCompL, r17
	ldi	r17, 0x00			    ; No divider for Frame duration counter in SLOW mode
	sts	RC5FrameDurationDividerCount, r17   
	ldi	r17, 1
	sts	RC5FrameDurationDivider, r17

	ldi 	r17, 0b00001001	    	; Start counting
					                ; Set timer mode and prescaler (Timer 1 Control Register B)
					                ; No prescaler (bits 0-2 set to '001')
					                ; CTC = Clear Timer on Compare match mode (bit 3 set to 1)
	sts 	RC5FrameTimerCtrlB, r17 

	; Adjust RC5 Frame timer behaviour according to frame decoding function result
	cpi	    r16, 0x00
	breq	RC5FrameStartEvent_RestoreStdExternalInt    ; Frame fully decoded, restore standard
							                            ; external interrupts and exit

	; Repeat key, other address or error, the frame duration is not elapsed
	; Frame not terminated, RC5 Frame Timer interrupt is used for waiting end of frame
	; Other timer interrupts also enabled when waiting for the end of current RC5 frame
    ldi     r17, 0xFF                               ; Not counting for inter frame duration
    sts     RC5InterFrameDurationCounter, r17
	ldi	    r16, 1 << InputPollingTimerCompIntEnable
	sts 	InputPollingTimerIntMask, r16
	ldi	    r16,  1 << UserInputTimerCompIntEnable
	sts 	UserInputTimerIntMask, r16
	ldi	    r16, 1 << RC5FrameTimerCompIntEnable
	sts 	RC5FrameTimerIntMask, r16
	ldi 	r16, 0b11000000			; Enable external interrupts int6 and int7
						            ; Int5 not enabled until current RC5 frame terminated
	rjmp	RC5FrameStartEvent_SetIntMask

RC5FrameStartEvent_RestoreStdExternalInt:
	; Frame fully decoded, RC5 Frame Timer interrupt is used for inter frame duration counting
    ldi     r17, 0xFF                               ; Not counting for frame duration
    sts     RC5FrameDurationCounter, r17
    ldi     r17, 0x00
    sts     RC5InterFrameDurationCounter, r17       ; But counting for inter frame duration
	ldi	    r16, 1 << InputPollingTimerCompIntEnable
	sts 	InputPollingTimerIntMask, r16
	ldi	    r16,  1 << UserInputTimerCompIntEnable
	sts 	UserInputTimerIntMask, r16
	ldi	    r16, 1 << RC5FrameTimerCompIntEnable
	sts 	RC5FrameTimerIntMask, r16
   lds  r16, bExternalInterruptMask   ; Enable external interrupts
					                       ; Int5 will detect next RC5 frame

RC5FrameStartEvent_SetIntMask:
	out 	EIMSK, r16
	
	; Exit
	pop 	r18
	pop 	r17
	pop 	r16
	out 	SREG, r16
	pop 	r16
	LEAVE_CRITICAL_SECTION		; Enable interrupts
	reti

; Interrupt handler for RC5 frame decoding timer
; The interrupt occurs on RC5 Frame Timer output compare match.
; The timer generates real time interrupts for 2 periods:
;  - In FAST mode the interrupt period is 50µs. Typically this mode is used to decode bits in the
;    RC5 frame.
;  - In SLOW mode interrupts are occuring each millisec. The slow mode is used to detect the end
;    of the frame and the end of inter frame period.
; This function increments the 'RC5BitDurationCounter', 'RC5FrameDurationCounter' and 
; 'RC5InterFrameDurationCounter' variables.
; In SLOW mode, the function also detects the end of frame period and inter frame period. 
; When the inter frame period is elapsed, the function stops the timer.
RC5FrameTimerEvent:
	ENTER_CRITICAL_SECTION		; Disable interrupts
	push	r16
	in      r16, SREG
	push	r16
	push	r17

	; Look for current timer mode (FAST or SLOW)
	lds     r17, RC5FrameDurationDivider
	cpi     r17, 20
	brne    RC5FrameTimerEvent_SlowMode

	; Running in FAST mode, increment 'RC5BitDurationCounter'
	lds     r16, RC5BitDurationCounter
	inc     r16
	sts     RC5BitDurationCounter, r16

;#message "TO DO: REMOVE DBG -> RC5BitDurationCounter value displayed on port L"
;sts PORTL, r16
;end debug

	; In FAST mode the divider must be applied for incrementing 'RC5FrameDurationCounter' 
	lds     r16, RC5FrameDurationDividerCount
	inc     r16
	sts	    RC5FrameDurationDividerCount, r16	; Update divider
	cp      r16, r17
	brne    RC5FrameTimerEvent_Exit         ; Divider count not reached

	; Divider count reached, 'RC5FrameDurationCounter' must be incremented
	lds     r16, RC5FrameDurationCounter
	inc     r16
	sts     RC5FrameDurationCounter, r16
	ldi     r16, 0x00                             ; Reset divider
	sts     RC5FrameDurationDividerCount, r16
	jmp     RC5FrameTimerEvent_Exit

RC5FrameTimerEvent_SlowMode:
	; Running in SLOW mode. 
    ; Only increment 'RC5FrameDurationCounter' or 'RC5InterFrameDurationCounter'
    ; counters
	lds     r16, RC5FrameDurationCounter
    cpi     r16, 0xFF       ; Check if end of frame has already been detected
    breq    RC5FrameTimerEvent_InterFrameDuration

    ; Waiting for end of frame, check if the frame duration is elapsed
	inc     r16
	sts     RC5FrameDurationCounter, r16
	cpi	    r16, RC5FrameDurationTimerTicks
	brlo	RC5FrameTimerEvent_Exit

	; The frame duration elapsed:
    ;  - Keep the RC5 Frame timer running
    ;  - Update 'RC5FrameDurationTimerTicks' variable for end of frame detected
    ;  - Start counting for inter frame duration
	;  - Enable back external interrupts
    ldi     r16, 0xFF
	sts     RC5FrameDurationCounter, r16
    ldi     r16, 0x00
	sts     RC5InterFrameDurationCounter, r16
   lds   r16, bExternalInterruptMask   ; Enable external interrupts
					                        ; Int5 will detect next RC5 frame and stop 
                                       ; inter frame duration counting
	out 	EIMSK, r16
	rjmp    RC5FrameTimerEvent_Exit

RC5FrameTimerEvent_InterFrameDuration:
    ; Waiting for inter frame duration, check if duration is elapsed
	lds     r16, RC5InterFrameDurationCounter
	inc     r16
	sts     RC5InterFrameDurationCounter, r16
	cpi	    r16, RC5InterFrameDurationTimerTicks
	brlo	RC5FrameTimerEvent_Exit

    ; The inter frame duration elapsed:
    ;  - Stop the RC5 Frame timer and mask RC5 Frame timer interrupt
    ;  - Update the 'InputPollingRC5KeyPressed' variable
    ;  - Update 'RC5FrameDurationTimerTicks' variable for no counting running
	ldi 	r16, 0x00		            ; Stop counting
	sts 	RC5FrameTimerCtrlB, r16 
	ldi	    r16, 1 << InputPollingTimerCompIntEnable
    sts     InputPollingTimerIntMask, r16
	ldi	    r16, 1 << UserInputTimerCompIntEnable
    sts     UserInputTimerIntMask, r16
    ldi     r16, 0x00
    sts     InputPollingRC5KeyPressed, r16
    ldi     r16, 0xFF
	sts     RC5InterFrameDurationCounter, r16

RC5FrameTimerEvent_Exit:

; DEBUG
;#message "TO DO: REMOVE DBG -> InputPollingRC5KeyPressed value displayed on port D"
;lds r16, InputPollingRC5KeyPressed
;out PORTD, r16
;end debug

	; Exit
	pop 	r17
	pop 	r16
	out 	SREG, r16
	pop 	r16
	LEAVE_CRITICAL_SECTION		; Enable interrupts
	reti

;******************************************************************************
; Main
;******************************************************************************

; Main entry point:
;  - Initializes the resources according to hardware configuration
;  - Restores persistent level
;  - Enters the interrupt driven operating mode
main:
	; Step 1 - Reset hardware

	; Initialize Stack Pointer
	ldi 	r16, HIGH(RAMEND)
	out 	SPH, r16
	ldi 	r16, LOW(RAMEND)
	out 	SPL, r16

   ; Set clock frequency
   ; Adjust clock prescaler
   ; Note: Defined clock frequency validity has been checked by '#define' consistency 
   ;       check
#ifdef CLOCK_FREQUENCY_1MHZ
   ldi   r16, 0b00000011          ; 8MHz oscillator divided by 8
#endif

#ifdef CLOCK_FREQUENCY_1_25MHZ
   ldi   r16, 0b00000011          ; 10MHz oscillator divided by 8
#endif

#ifdef CLOCK_FREQUENCY_4MHZ
   ldi   r16, 0b00000001          ; 8MHz oscillator divided by 2
#endif

#ifdef CLOCK_FREQUENCY_5MHZ
   ldi   r16, 0b00000001          ; 10MHz oscillator divided by 2
#endif

#ifdef CLOCK_FREQUENCY_8MHZ
   ldi   r16, 0x00                ; 8MHz oscillator without divider
#endif

#ifdef CLOCK_FREQUENCY_10MHZ
   ldi   r16, 0x00                ; 10MHz oscillator without divider
#endif

   ldi   r17, 0b10000000          ; Specific write timings (interrupts are already disabled)
   sts   CLKPR, r17
   sts   CLKPR, r16

	; Set port directions
	; Port directions are set at startup and never change (fixed port mappping/use)
	ldi 	r16, DDRAValue
	out 	DDRA, r16
	ldi 	r16, DDRBValue
	out 	DDRB, r16
	ldi 	r16, DDRCValue
	out 	DDRC, r16
	ldi 	r16, DDRDValue
	out 	DDRD, r16
	ldi 	r16, DDREValue
	out 	DDRE, r16
	ldi 	r16, DDRFValue
	sts   DDRF, r16
	ldi 	r16, DDRGValue
	out 	DDRG, r16
	ldi 	r16, DDRHValue
	sts 	DDRH, r16
	ldi 	r16, DDRJValue
	sts 	DDRJ, r16
	ldi 	r16, DDRKValue
	sts 	DDRK, r16
	ldi 	r16, DDRLValue
	sts 	DDRL, r16

	; Set internal pull up for input pins
	; Pull ups are set at startup and never change
	; Note: By default on processor reset all pins are in high impedance for security
	;       (i.e. no pull ups = PORTX value at 0).
	; 
	; Pull up required for RC5 input pin
	; Note: 
	;  - On TSOP2236 high level is for idle state (= active state is low)
	;  - Generaly, it is preferable to use discrete pullup (10k resistor to +5V)
	;  - Uncomment the 2 following lines if there is no discrete pullup wired on the
	;    output pin of the TSOP2236
;   	ldi	r16, PORTEPullupValue
;   	out	PORTE, r16

   ; Current program state is 'Initializing'
   ; NOTE: In this state interrupts are disabled (i.e. the 'LeaveCriticalSection' does
   ;       not enable interrupts)
   ldi   r16, 0x00
   sts   bOperatingState, r16
   sts   bNestedCriticalSectionCount, r16

	; Set initial value in amplifier state variables 
	ldi	    r16, AMPLIFIERSTATE_POWER_OFF
	sts	    bAmplifierPowerState, r16						
	ldi	    r16, AMPLIFIERSTATE_OUTPUT_MUTED
	sts	    bAmplifierOutputState, r16						
	ldi	    r16, DCPROTECTION_STATE_OFF
	sts	    bDCProtectionState, r16						
	ldi	    r16, 0x00
	sts	    bAmplifierInputOn, r16						

	; Configure Input Polling Timer
	; Set timer mode and prescaler (Timer 0 Control Register A and B) 
	ldi 	r16, 0b00000010		        ; Clear Timer on Compare match A 
					                    ; (mode 2 = bit 1 set to 1)
    out     InputPollingTimerCtrlA, r16
    ldi     r16, 0b00000101             ; Prescaler set to 1024 (bits 0-2 set to 101)                 
    out     InputPollingTimerCtrlB, r16

	; Set counter compare for timer period
	ldi 	r16, InputPollingTimerPeriod
	out 	InputPollingTimerComp, r16

	; Configure User Input Timer
	; Set timer mode and prescaler (Timer 2 Control Register A and B)
	ldi 	r16, 0b00000010		        ; Clear Timer on Compare match A 
					                    ; (mode 2 = bit 1 set to 1)
    sts     UserInputTimerCtrlA, r16
    ldi     r16, 0b00000111             ; Prescaler set to 1024 (bits 0-2 set to 111)                 
    sts     UserInputTimerCtrlB, r16

	; Set counter compare for timer period
	ldi 	r16, UserInputTimerPeriod
	sts 	UserInputTimerComp, r16

   ; Retrieve the amplifier hardware configuration
   ; Read configuration DIP switches
	in 	r19, AmplifierConfigPins
   andi  r19, ConfigSwitchInputMask

	; Set amplifier working mode variable ('bAmplifierRemoteMode')
	mov   r17, r19
	andi 	r17, 1 << ModeAmplifierConfigPinNum
	brne	main_RemoteAmplifierMode
   ldi   r17, 0b11100000		        ; External interrupts mask for 'Standalone' mode
                                        ;  - Enabled: int5, int6 and int7
                                        ;  - Disabled: int 4 (no TCP/IP)
   sts   bExternalInterruptMask, r17
   ldi   r17, 0x00                    ; 'Standalone' mode
   rjmp  main_SetAmplifierMode

main_RemoteAmplifierMode:
   ldi   r17, 0b11010000		      ; External interrupts mask for 'Remote' mode
                                      ;  - Enabled: int4, int6 and int7
                                      ;  - Disabled: int 5 (no IR by default)
   sts   bExternalInterruptMask, r17
   ldi   r17, 0x01                    ; 'Remote' mode

main_SetAmplifierMode:
   sts   bAmplifierRemoteMode, r17

   ; Other configuration settings (RDP control) can be from DIP switch or EEPROM memory
   ; This information is obtained from switch located at 'MemoryAmplifierConfigPinNum'
	mov   r17, r19
	andi 	r17, 1 << MemoryAmplifierConfigPinNum
	brne	main_MemoryConfiguration

   ; RDP control settings also from DIP switches
	mov   r17, r19                      ; r17 contains configuration
   rjmp  main_SetCurrentConfiguration

main_MemoryConfiguration:
   ; RDP control settings are located in EEPROM
	ldi 	r17, LOW(bPersistentRDPControlConfig)		; Pointer to ESEG address
	ldi 	r18, HIGH(bPersistentRDPControlConfig)
	call 	ReadPersistentByte
   lsl   r16                      ; DIP switches bits 0-1 not memorized in EEPROM
   lsl   r16      
   mov   r17, r19
   or    r17, r16                 ; r17 contains configuration
    
main_SetCurrentConfiguration:
   ; Store current configuration in 'bAmplifierCurrentConfig' variable (typically
   ; state info for user display)
   sts   bAmplifierCurrentConfig, r17

   ; Set RDP working mode according to current configuration
   lsr   r17                            ;  RDP control bits are bit 0-2
   lsr   r17
   out   RDPCtrlPortData, r17           ; Port direction already set (and never changes)

   ; By default amplifier has no IR detector in 'remote' mode
   ldi  r16, 0x00                      
   sts  bRemoteModeIRDetector, r16     ; Will be enabled by ACC program if necessary

; DEBUG -> TO REMOVE
;ldi  r16, 0x01
;sts  bRemoteModeIRDetector, r16
;
;lds r16, bExternalInterruptMask        ; Enable Int 5 (IR)
;ori r16, 0b00100000
;sts bExternalInterruptMask, r16
; END DEBUG

   ; Display static amplifier name while ACC not connected
   sts  AmplifierDisplayName, r16 
   
	; Configuration for the RC5 Frame Timer
	;  - The RC5 Frame Timer will be started only when required for frame decoding
	;  - The RC5 Frame Timer will run without prescaler in CTC mode

	; Set interrupt signal mode for external interrupts int4, int5, int6 and int7:
	;  - Interrupt generated on falling edge for external buttons (int 6 and int7)
	;  - Interrupt generated on falling edge for TCP/IP and IR (int4 and int 5)
;	ldi 	r16, 1 << ISC41 | 1 << ISC51 | 1 << ISC60 | 1 << ISC61 | 1 << ISC70 | 1 << ISC71
	ldi 	r16, 1 << ISC41 | 1 << ISC51 | 1 << ISC61 | 1 << ISC71
	sts 	EICRB, r16
   lds   r16, bExternalInterruptMask	; Enable external interrupts (mask set according to
                                       ; 'Remote/Standalone' mode
	out 	EIMSK, r16
	
	; Enable interrupt on counter compare match for InputPolling and UserPolling timers
	ldi	    r16, 1 << InputPollingTimerCompIntEnable
    sts     InputPollingTimerIntMask, r16
	ldi	    r16, 1 << UserInputTimerCompIntEnable
    sts     UserInputTimerIntMask, r16

   ; Initialize counter for external button interrupt debounce
   ldi   r16, 0x00
   sts   InputPollingOnOffButtonDebounceL, r16
   sts   InputPollingOnOffButtonDebounceH, r16
   sts   InputPollingMuteButtonDebounceL, r16
   sts   InputPollingMuteButtonDebounceH, r16

	; Configure level input resource (depends on hardware configuration)
#ifdef ANALOG_INPUTLEVEL

	; Configure ADC resource
	ldi 	r16, AnalogInputADCInput	; Set multiplexer input
	out 	ADMUX, r16
	ldi 	r16, 0b10001100		; bit7: ADC enabled
				       	        ; bit3: interrupt enabled
				       	        ; bit2-0 : prescaler 16 (4 usec period)
	out 	ADCSR, r16

#elif ENCODER_INPUTLEVEL

	; Configure input pins on Encoder port for Encoder pins A and B
	cbi 	EncoderInputPins, EncoderInputPinA0
	cbi 	EncoderInputPins, EncoderInputPinB0
; If required, activate pull up resistor
;	sbi EncoderInputData, EncoderInputStepInfo
;	sbi EncoderInputData, EncoderInputDirInfo
#message "Encoder input pins: high impedence"


#endif

   ; Initialize the TCPIP Driver (if running in remote configuration)
   lds   r16, bAmplifierRemoteMode
   cpi   r16, 0x01
   brne  main_InitGlobalVariables
   call  TCPIPInitW5100

	; Step 2 - Set global variables and restore persistant level

main_InitGlobalVariables:

#ifdef ANALOG_INPUTLEVEL

	; Current level set to 0
	; The first AD conversion will adjust the value to current analog input
	; position
	ldi 	r16, 0
	sts 	bCurrentLevel, r16
	ldi 	r16, InputLevelThreshold
	sts 	bLevelChangedCount, r16
	dec 	r16
	sts 	bADCLevelChangeCount, r16

#elif (defined ENCODER_INPUTLEVEL || defined IR_INPUTLEVEL)

#if ENCODER_INPUTLEVEL

	; Read current Encoder outputs state and store it as initial state for
	; debounce algorythm
	; NOTE: No debouncing for this initial value. In case of error it will be
	;       reset on the first Input Polling Interrupt
	in 	r16, EncoderInputPins			; Pins state on port
	andi 	r16, EncoderInputMask0			; Mask for Encoder0 pins
	sts	InputPollingLastEncoderState, r16
	sts     InputPollingLastDebouncedEncoderState, r16

	; Reset change count variable
	ldi 	r16, 0
	sts 	bEncoderLevelChangeCount, r16
	ldi 	r16, InputLevelThreshold	    ; Change count threshold (configuration)
	sts 	bLevelChangedCount, r16

	; Populate the 'EncoderDirectionMap' map (in DSEG) with corresponding 
	; constants
	ldi 	ZL, LOW(EncoderDirectionMap) 	    ; Load map base address
	ldi 	ZH, HIGH(EncoderDirectionMap)
	ldi 	r16, EncoderMapIndex0		    ; Store constants
	st	Z+, r16
	ldi 	r16, EncoderMapIndex1
	st	Z+, r16
	ldi 	r16, EncoderMapIndex2
	st	Z+, r16
	ldi 	r16, EncoderMapIndex3
	st	Z+, r16
	ldi 	r16, EncoderMapIndex4
	st	Z+, r16
	ldi 	r16, EncoderMapIndex5
	st	Z+, r16
	ldi 	r16, EncoderMapIndex6
	st	Z+, r16
	ldi 	r16, EncoderMapIndex7
	st	Z+, r16
	ldi 	r16, EncoderMapIndex8
	st	Z+, r16
	ldi 	r16, EncoderMapIndex9
	st	Z+, r16
	ldi 	r16, EncoderMapIndex10
	st	Z+, r16
	ldi 	r16, EncoderMapIndex11
	st	Z+, r16
	ldi 	r16, EncoderMapIndex12
	st	Z+, r16
	ldi 	r16, EncoderMapIndex13
	st	Z+, r16
	ldi 	r16, EncoderMapIndex14
	st	Z+, r16
	ldi 	r16, EncoderMapIndex15
	st	Z, r16

#endif

	; Current level retrieved from persistent storage (EEPROM)
	ldi 	r17, LOW(bPersistentInputLevel)		; Pointer to ESEG address
	ldi 	r18, HIGH(bPersistentInputLevel)
	call 	ReadPersistentByte
	sts     bCurrentLevel, r16                  ; Read persistent value is in r16

#endif

	; Initialize RC5 variables
	ldi 	r17, 0xFF				; Toggle bit state undefined until first RC5 frame decoded
	sts	    RC5LastToggleBitState, r17
	sts	    InputPollingLastRC5Instruction, r17		; Invalid instruction (instruction are 6 bit values)
	ldi 	r17, 0x00			    	            ; No instruction received
	sts	    InputPollingRC5InstructionCount, r17
	ldi	    r17, RC5ConfiguredTerminalAddress       ; Use configured value for RC5 terminal address
	sts 	RC5TerminalAddress, r17
    ldi 	r17, 0x00
    sts     RC5FrameDurationCounter, r17
    ldi 	r17, 0xFF                               ; Inter frame duration counting not running    
    sts     RC5InterFrameDurationCounter, r17

	ldi	    ZH, HIGH(RemoteControlInstructionMap)	; Populate the 'RemoteControlInstructionMap'
	ldi	    ZL, LOW(RemoteControlInstructionMap)	; This block of code must be replaced by a loop for initialization
			                        				; with persistent values stored in EEPROM
						                            ; For the time being, hard coded values are used

	ldi	    r16, 0xFF				; Clear the array (0xFF means undefined instruction)		
	ldi	    r17, 0x00				; r17 is loop counter	

main_InitInstructionMap:
	st	Z+, r16
	inc	r17
	cpi	r17, 64					; Array contains 64 values
	brlo	main_InitInstructionMap

	ldi	ZH, HIGH(RemoteControlInstructionMap)	; For the time being, hard coded values are used
	ldi	ZL, LOW(RemoteControlInstructionMap)	
	     
	ldi	r17, REMOTECONTROL_INSTRUCTION_ONOFF   	; index 12
	std	Z+12, r17
	ldi	r17, REMOTECONTROL_INSTRUCTION_MUTE   	; index 13
	std	Z+13, r17
	ldi	r17, REMOTECONTROL_INSTRUCTION_VOLUMEPLUS   	; index 16
	std	Z+16, r17
	ldi	r17, REMOTECONTROL_INSTRUCTION_VOLUMEMINUS   	; index 17
	std	Z+17, r17
	ldi	r17, REMOTECONTROL_INSTRUCTION_BACKLIGHTPLUS   	; index 18
	std	Z+18, r17
	ldi	r17, REMOTECONTROL_INSTRUCTION_BACKLIGHTMINUS  	; index 19
	std	Z+19, r17
	ldi	r17, REMOTECONTROL_INSTRUCTION_CONTRASTPLUS   	; index 28
	std	Z+28, r17
	ldi	r17, REMOTECONTROL_INSTRUCTION_CONTRASTMINUS   	; index 29
	std	Z+29, r17
   
	; Initialize the ACP variables
   ldi   ZL, LOW(ACPPostponedNotifications)    ; Initialize Postponed notifications array
  	ldi   ZH, HIGH(ACPPostponedNotifications)
	ldi   r17, 0x00	      		              ; r17 is loop counter	
   ldi   r16, 0x00
   				 
main_InitPostponedNotifArray:
   st    Z+, r16
   inc   r17
   cpi   r17, ACP_NOTIFICATION_NUMBER
   brlo  main_InitPostponedNotifArray 			 
	sts 	ACPNextPostponedNotifToCheck, r16
   sts   ACPHeatbeatNoficationTimerCount, r16
     
	; Intialize debouncing and user input variables
	ldi 	r17, 0x00
	sts 	InputPollingLastEncoderState, r17
	ldi 	r16, InputPollingEncoderDebouncePeriod
	sts 	InputPollingEncoderStateCounter, r16
	ldi 	r16, InputPollingADCLaunchPeriod
	sts 	InputPollingADCLaunchCounter, r16
	sts 	ADConversionSampleCounter, r17
	sts 	ADConversionSampleSumLow, r17
	sts 	ADConversionSampleSumHigh, r17
	sts 	AveragedADCValue, r17			  ; Input polling result variable for ADC
	sts 	DebouncedEncoderSteps, r17		  ; Input polling result variable for Encoder

	sts 	UserInputRC5LastInstructionDuration, r17
	sts    	UserInputRC5LastKeyPressDuration, r17

	ldi	r16, 0xFF
	sts	InputPollingLastDebouncedRC5Instruction, r16  	; Reset RC5 debounced instruction
	sts	UserInputRC5LastInstruction, r16		; 0xFF is 'undefined' RC5 instruction
   sts   InputPollingLastACPCommand, r16     ; Reset ACP last command

	; Intialize temperature measurement variables
	ldi	r16, 0x00
   sts   TemperaturePollingCounter, r16
   sts   TemperatureWaitCounter, r16
   sts   TemperatureCurrentSensor, r16
   sts   TemperatureRightValue, r16
   sts   TemperatureLeftValue, r16
   sts   TemperatureProcessEntered, r16
	ldi	r16, TEMPMEASUREMENT_STATE_WAITING
   sts   TemperatureMeasurementState, r16

	; Retrieve Left Channel Offset from persistent storage and synchronize 
	; 'bCurrentLeftChannelOffset' DSEG variable
	ldi 	r17, LOW(bPersistentLeftChannelOffset)		; Pointer to ESEG address
	ldi 	r18, HIGH(bPersistentLeftChannelOffset)
	call 	ReadPersistentByte
	sts 	bCurrentLeftChannelOffset, r16

	; Retrieve Right Channel Offset from persistent storage and synchronize 
	; 'bCurrentRightChannelOffset' DSEG variable
	ldi 	r17, LOW(bPersistentRightChannelOffset)		; Pointer to ESEG address
	ldi 	r18, HIGH(bPersistentRightChannelOffset)
	call 	ReadPersistentByte
	sts 	bCurrentRightChannelOffset, r16

    ; Switch LCD on
	; Current contrast and backlight levels are retrieved from persistent storage (EEPROM)
	ldi 	r17, LOW(bPersistentLCDContrast)		; Pointer to ESEG address
	ldi 	r18, HIGH(bPersistentLCDContrast)
	call 	ReadPersistentByte
	sts   bCurrentLCDContrast, r16             ; Read persistent value is in r16
   call  LCDDriverAdjustContrast                                           
	ldi 	r17, LOW(bPersistentLCDBacklight) 	 ; Pointer to ESEG address
	ldi 	r18, HIGH(bPersistentLCDBacklight)
	call 	ReadPersistentByte
	sts   bCurrentLCDBacklight, r16            ; Read persistent value is in r16
   call  LCDDriverAdjustBacklight
   call  LCDDriverPowerOn

	; Initialize LCD Driver
	call  LCDDriverInitializeHD
   call  LCDClearDeviceBuffer


; DEBUG: Backlight and contrast calibration (i.e. not available yet as User Commands)

;  ldi   r16, 0x00                       ; 5mA
;  call  LCDDriverAdjustBacklight                                           
;  ldi   r16, 0x10                       ; 8mA
;  call  LCDDriverAdjustBacklight
;  ldi   r16, 0x20                       ; 13mA
;  call  LCDDriverAdjustBacklight
;  ldi   r16, 0x40                       ; 23mA
;  call  LCDDriverAdjustBacklight
;  ldi   r16, 0x80                       ; 45mA
;  call  LCDDriverAdjustBacklight
;  ldi   r16, 0xFF                       ; 90mA
;  call  LCDDriverAdjustBacklight

;  ldi   r16, 0x00
;  call  LCDDriverAdjustContrast                                           
; ldi   r16, 0x10
; call  LCDDriverAdjustContrast
;  ldi   r16, 0x20
;  call  LCDDriverAdjustContrast
;  ldi   r16, 0x40
;  call  LCDDriverAdjustContrast
;  ldi   r16, 0x80
;  call  LCDDriverAdjustContrast
;  ldi   r16, 0xA0
;  call  LCDDriverAdjustContrast
;  ldi   r16, 0xC0
;  call  LCDDriverAdjustContrast
;  ldi   r16, 0xFF
;  call  LCDDriverAdjustContrast

; END DEBUG


	; Intialize LCD display variables
	ldi 	r16, 0
	sts 	LCDAppBufferModifiedLines, r16
	sts 	LCDUpdateDisplayCalled, r16
	sts 	LCDUpdateDisplayReEntered, r16
	sts 	LCDUpdateDisplayLinesToUpdate, r16

	; Main Menu option set to 'STATE' (display current state)
	; When the operating mode is entered the 'STATE' screen is displayed.
	; The screen will be updated on input level change or Main Menu option selection.
	ldi 	r16, MAIN_MENU_STATE
	sts 	bCurrentMainMenuOption, r16

    ; Initialize variables used for display
    ldi     r16, 0x00
    sts     bStateScreenDisplayedLevel, r16

    ; For encoder or IR input level configurations, restore ouput relay states
    ; Note: For Potentiometer configuration, initial level will be set by the first AD
    ;       conversion result
#if (defined ENCODER_INPUTLEVEL || defined IR_INPUTLEVEL)
    call 	SetOutputValue 
#endif

	; Step 3 - Enable interrupts and enter operating mode
     
	; Update the LCD display according to current state (i.e. initial display)
    ldi     r19, 0b00001111         ; The 4 lines on screen must be updated
    call 	DisplayStateScreen

    ; Current program state is switched to 'Operating'
    ldi   r16, 0x01               
    sts   bOperatingState, r16

	sei	     ; Interrupt driven mode starts here

   ; If running in remote configuration, start the TCPIP server
   ; The master (client) will detect the server and will send commands
   ; The current state will change from 'No Master' to 'Master Connected' when the 
   ; connection is established
   lds  r16, bAmplifierRemoteMode
   cpi  r16, 0x01
   brne WaitEvent
   call TCPIPStartServer

WaitEvent:
	; Infinite wait loop
	; TO DO: Maybe use the watchdog feature for crash detection
	nop
	nop
	nop
	rjmp	WaitEvent


;******************************************************************************
; Functions
;******************************************************************************

; Update internal status variables
; This function is called on 'InputPollingTimerEvent' interrupt and also when an internal 
; control action has explicitly changed the internal status
; 
; NOTE: This function must be called in critical section because it checks/updates amplifier
;       status variables and audio input relays
UpdateInternalStatus:
	push 	r16
	push 	r17
	push 	r18
   push  r19

   ; r19 is used as a flag for LCD screen update at the end of the function (i.e. state changed)
   ldi   r19, 0x00       ; No screen update by default

	; Read current status on internal status pins
	in 	r16, InternalStatusPins

	; Check/Update 'bAmplifierOutputState' variable
	mov   r17, r16
	andi 	r17, 1 << DCProtMuteInternalStatusPinNum
	brne	UpdateInternalStatus_OutputUnmuted

	; Output is off (muted)
	ldi	r17, AMPLIFIERSTATE_OUTPUT_MUTED                           
	rjmp	UpdateInternalStatus_SetAmplifierOutputState

UpdateInternalStatus_OutputUnmuted:
	; Output is unmuted, check if DCProt is waiting (in this case output is muted)
	mov   r17, r16
	andi 	r17, 1 << DCProtWaitInternalStatusPinNum
	brne	UpdateInternalStatus_OutputOn
	ldi	r17, AMPLIFIERSTATE_OUTPUT_MUTED              ; DCProt is waiting             
	rjmp	UpdateInternalStatus_SetAmplifierOutputState

UpdateInternalStatus_OutputOn:
	; Output is on (unmuted and not waiting)
	ldi	r17, AMPLIFIERSTATE_OUTPUT_PLAYING                           

UpdateInternalStatus_SetAmplifierOutputState:
	; Update bAmplifierOutputState variable
   lds   r18, bAmplifierOutputState              
	sts	bAmplifierOutputState, r17
	cp    r17, r18                                ; Is it a state change?
   breq  UpdateInternalStatus_CheckAmplifierPowerState
   ldi   r19, LCDStateScreenUpdateState           ; LCD screen update required (for status)

UpdateInternalStatus_CheckAmplifierPowerState:
	; Check/Update 'bAmplifierPowerState' variable
	mov   r17, r16
	andi 	r17, 1 << OnOffInternalStatusPinNum
	brne	UpdateInternalStatus_AmplifierOn

	; Amplifier is off
   ; Check if previous state was on
   ; In this case, store current input level in EEPROM
	lds	r16, bAmplifierPowerState
   cpi   r16, AMPLIFIERSTATE_POWER_ON
   brne  UpdateInternalStatus_AmplifierOff

   ; Amplifier output stage just switched off:
	;  - Store Input Level in persistent storage (EEPROM) when input level is
   ;    controled by encoder or IR
	;  - Store LCD contrast and backlight levels in persistent storage (EEPROM)
   ;  - Power off other modules (RDP supply, UGS supply and Delayed VAC)
#if (defined ENCODER_INPUTLEVEL || defined IR_INPUTLEVEL)
	lds 	r16, bCurrentLevel			        ; Value to write
	ldi 	r17, LOW(bPersistentInputLevel)	  ; Pointer to ESEG address
	ldi 	r18, HIGH(bPersistentInputLevel)
	call 	WritePersistentByte
#endif

	lds 	r16, bCurrentLCDContrast			  ; Value to write
	ldi 	r17, LOW(bPersistentLCDContrast)	  ; Pointer to ESEG address
	ldi 	r18, HIGH(bPersistentLCDContrast)
	call 	WritePersistentByte
	lds 	r16, bCurrentLCDBacklight	        ; Value to write
	ldi 	r17, LOW(bPersistentLCDBacklight)  ; Pointer to ESEG address
	ldi 	r18, HIGH(bPersistentLCDBacklight)
	call 	WritePersistentByte

UpdateInternalStatus_AmplifierOff:
   cpi   r16, AMPLIFIERSTATE_POWER_OFF          ; Check if state update is required
   breq  UpdateInternalStatus_CheckInputState
	ldi	r17, AMPLIFIERSTATE_POWER_OFF     ; Update bAmplifierPowerState variable
	sts	bAmplifierPowerState, r17
   ldi   r19, LCDStateScreenUpdateState           ; LCD screen update required (for status)
   ldi   r17, DCPROTECTION_STATE_OFF       ; DCProt module is going to be switched off
   sts   bDCProtectionState, r17
	ldi 	r17, 0x00                         ; Pins 0-3 of 'SupplyCtrlPortData' are 'Supply' commands
                                           ; (other pins are input)
   out   SupplyCtrlPortData, r17
	rjmp	UpdateInternalStatus_CheckInputState

UpdateInternalStatus_AmplifierOn:
	; Amplifier is 'on' or 'powering up' (i.e. trigger sense detected on)
	mov   r17, r16                                        ; Read softstart delay sense
	andi 	r17, 1 << SoftStartDelayInternalStatusPinNum
	brne	UpdateInternalStatus_AmplifierPoweringUp

   ; Softstart delay sense not set, check if 'PoweringUp' state has just changed
	lds	r16, bAmplifierPowerState
   cpi   r16, AMPLIFIERSTATE_POWERING_UP
   brne  UpdateInternalStatus_CheckInputState        ; No change, 'PoweringUp' end already detected

   ; Amplifier power stage 'PoweringUp' state has just changed to 'ON', power up other modules
   ; (RDP supply, UGS supply and Delayed VAC)
	ldi	r17, AMPLIFIERSTATE_POWER_ON
	sts	bAmplifierPowerState, r17
   ldi   r19, LCDStateScreenUpdateState           ; LCD screen update required (for status)

; DCProt module is not plugged (used) when debugging (relay switches freeze JTAGICE!!!)
#if (!defined DBG_DCPROT_NOT_PLUGGED)
	ldi 	r17, (1 << DelayedVacSupplyCtrlPinNum) | (1 << RDPSupplyCtrlPinNum) | (1 << UGSSupplyCtrlPinNum) | (1 << FrontLedSupplyCtrlPinNum)

; Relay switch is OK now with revised Amplifier Prot board (low voltage switch rather than 220V)
; 
;DBG
;ldi 	r17, (1 << DelayedVacSupplyCtrlPinNum) | (1 << FrontLedSupplyCtrlPinNum)


   out   SupplyCtrlPortData, r17

   ; Wait until the WAIT state is detected on DCProt (i.e. PowerOn state reached
   ; on DCProt)
UpdateInternalStatus_DCProtPoweringUp:
   nop
   nop
   nop
   nop
   nop
	in 	r16, InternalStatusPins
	andi 	r16, 1 << DCProtWaitInternalStatusPinNum    ; Bit set to 0 if waiting
	brne	UpdateInternalStatus_DCProtPoweringUp
	ldi	r16, DCPROTECTION_STATE_WAITSTARTED         ; DCProt WAIT is started
	sts	bDCProtectionState, r16						
   rjmp  UpdateInternalStatus_CheckInputState
   
#else
   
   ; Not switch 220V (= the reason of JTAGICE crash)
;	ldi 	r17, (1 << RDPSupplyCtrlPinNum) | (1 << UGSSupplyCtrlPinNum) | (1 << FrontLedSupplyCtrlPinNum)
;  ldi 	r17, (1 << DelayedVacSupplyCtrlPinNum) | (1 << UGSSupplyCtrlPinNum) | (1 << FrontLedSupplyCtrlPinNum)
;  out   SupplyCtrlPortData, r17


	ldi	r16, DCPROTECTION_STATE_WAITDONE  
	sts	bDCProtectionState, r16						
   rjmp  UpdateInternalStatus_CheckInputState

#endif
   
UpdateInternalStatus_AmplifierPoweringUp:
	ldi	r17, AMPLIFIERSTATE_POWERING_UP
	sts	bAmplifierPowerState, r17	
    ldi   r19, LCDStateScreenUpdateState           ; LCD screen update required (for status)

UpdateInternalStatus_CheckInputState:

	; Amplifier Input is automatically switched ON/OFF according to Amplifier Power state
	lds	r16, bAmplifierInputOn
	lds	r17, bAmplifierPowerState
	cpi   r16, 0x00
   brne  UpdateInternalStatus_CheckInputStateOn

	; Amplifier Input is OFF, unmute it if amplifier state is AMPLIFIERSTATE_POWER_ON
	cpi   r17, AMPLIFIERSTATE_POWER_ON
   brne  UpdateInternalStatus_CheckDCProtState
	call	UnMuteAmplifierInput		; Amplifier is POWER_ON, unmute input
	ldi   r17, 0x01
	rjmp 	UpdateInternalStatus_UpdateInputState

UpdateInternalStatus_CheckInputStateOn:
	; Amplifier Input is ON, mute it if amplifier state not is AMPLIFIERSTATE_POWER_ON
   ; (input is muted when powering up)
	cpi   r17, AMPLIFIERSTATE_POWER_ON
   breq  UpdateInternalStatus_CheckDCProtState
	call	MuteAmplifierInput		; Amplifier is POWER_OFF or POWERING_UP, mute input
	ldi   r17, 0x00
 
UpdateInternalStatus_UpdateInputState:
    ; Input state now synchronized with Amplifier state
	sts	bAmplifierInputOn, r17						

UpdateInternalStatus_CheckDCProtState:

; DCProt module is not plugged (used) when debugging (relay switches freeze JTAGICE!!!)
#if (!defined DBG_DCPROT_NOT_PLUGGED)

   ; Check if DCProt WAIT is terminated
	in 	r16, InternalStatusPins
   lds   r17, bDCProtectionState
   cpi   r17, DCPROTECTION_STATE_WAITSTARTED
   brne  UpdateInternalStatus_CheckDCProtStateNotWaiting

   ; Current DCProt state is 'WAITSTARTED', check if waiting is finished
   mov   r17, r16
	andi 	r17, 1 << DCProtWaitInternalStatusPinNum    ; Bit set to 1 if not waiting
   breq  UpdateInternalStatus_CheckCurrentLevel      ; Still waiting

   ; Wait is finished, make sure that ouput is unmuted 
   ldi   r17, DCPROTECTION_STATE_WAITDONE         ; Update DCProt state
   sts   bDCProtectionState, r17                  
   lds 	r17, bAmplifierPowerState	              ; Read current amplifier power state
   cpi	r17, AMPLIFIERSTATE_POWER_ON
   brne	UpdateInternalStatus_CheckCurrentLevel

   ; The amplifier is on, check mute state:
   ;  - Trigger mute sense must be 'Unmuted' (i.e. DCProt command for Unmute)
   mov   r17, r16
   andi  r17, 1 << MuteInternalStatusPinNum
   brne	UpdateInternalStatus_CheckCurrentLevel

   ; Unmute the amplifier output
   ; Note: Direct trigger command rather than a standard 'UserCommand' to avoid
   ;       re-entering the 'UpdateInternalStatus' function (= this)
   ldi	r16, 0x01                     ; R16 set to 0x01 = Mute/Unmute trigger command
   call	UserCommand_GenerateTriggerPulse
   rjmp  UpdateInternalStatus_CheckCurrentLevel

UpdateInternalStatus_CheckDCProtStateNotWaiting:
   ; Look if an error has been detected in 'WAITDONE' state
   cpi   r17, DCPROTECTION_STATE_WAITDONE
   brne  UpdateInternalStatus_CheckDCProtStateNotWaitDone
   mov   r17, r16
	andi 	r17, 1 << DCProtErrorInternalStatusPinNum   ; Bit set to 1 if no error
   brne  UpdateInternalStatus_CheckCurrentLevel      ; Everything is OK for DCProt

   ; A DCProt error just detected, update DCProt state and switch Amplifier Power off
   ldi   r17, DCPROTECTION_STATE_ERROR         ; Update DCProt state
   sts   bDCProtectionState, r17

   ; Switch the amplifier power off
   ; Note: Direct trigger command rather than a standard 'UserCommand' to avoid
   ;       re-entering the 'UpdateInternalStatus' function (= this).
   ;       Also, state must be adjusted specificaly (must keep the 'error' state)
   ldi	r16, 0x00                     ; R16 set to 0x00 = On/Off trigger command
   call	UserCommand_GenerateTriggerPulse
   ldi 	r17, 0x00                         ; Pins 0-3 of 'SupplyCtrlPortData' are 'Supply' commands
                                           ; (other pins are input)
   out   SupplyCtrlPortData, r17
   ldi	r17, AMPLIFIERSTATE_POWER_OFF     ; Update bAmplifierPowerState variable
   sts	bAmplifierPowerState, r17
   ldi   r19, LCDStateScreenUpdateState           ; LCD screen update required (for status)
   rjmp  UpdateInternalStatus_CheckCurrentLevel

UpdateInternalStatus_CheckDCProtStateNotWaitDone:
   ; Look if the error is still present in 'ERROR' state
   cpi   r17, DCPROTECTION_STATE_ERROR
   brne  UpdateInternalStatus_CheckCurrentLevel
   mov   r17, r16
	andi 	r17, 1 << DCProtErrorInternalStatusPinNum   ; Bit set to 1 if no error
   breq  UpdateInternalStatus_CheckCurrentLevel      ; Error still present
   ldi   r17, DCPROTECTION_STATE_OFF        ; Error has disappeared, update DCProt state
   sts   bDCProtectionState, r17                  

#endif

UpdateInternalStatus_CheckCurrentLevel:
   ; If the 'STATE' screen is currently displayed, check that current 
   ; 'InputLevel' has not changed
   lds   r16, bStateScreenDisplayedLevel
   lds   r17, bCurrentLevel
   cp    r16, r17
   breq  UpdateInternalStatus_CheckUpdateScreen
   ori   r19, LCDStateScreenUpdateLevel           ; Level line must be updated
   sts   bStateScreenDisplayedLevel, r17

UpdateInternalStatus_CheckUpdateScreen:
   ; Update LCD screen if state changed
   cpi   r19, 0x00
   breq  UpdateInternalStatus_Exit
   call 	DisplayStateScreen

UpdateInternalStatus_Exit:
   pop   r19
	pop 	r18
	pop 	r17
	pop 	r16
	ret
	
; Check if the standard autorepeat applies for the current RC5 instruction
; This function is called on 'UserInputTimerEvent' interrupt to check if the current RC5 instruction
; must trigger the command according to standard autorepeat rules.
; The rules are:
;  - If 'UserInputRC5LastInstructionDuration' is 0, the instruction is new and it always launches the
;    command
;  - Else, if the command is launched only if the 'UserInputRC5LastInstructionDuration' is equal to
;    'UserInputRC5ClickDuration' duration
; Arguments:
;  - R18 = 'UserInputRC5LastInstructionDuration'
; Return:
;  - R17 = Result (0x00 for not launch command, 0x01 for launch command)
IsRemoteControlAutoRepeatNow:	
	cpi 	r18, 0x00			     	; Is new instruction?
	breq	IsRemoteControlAutoRepeatNow_Yes

	cpi	r18, UserInputRC5ClickDuration		; Is click duration reached?
	brlo	IsRemoteControlAutoRepeatNow_No

	clr	r17					; Instruction repeated, reset elapsed time counter
	sts	UserInputRC5LastInstructionDuration, r17
	
IsRemoteControlAutoRepeatNow_Yes:
	ldi	r17, 0x01
	rjmp	IsRemoteControlAutoRepeatNow_Exit

IsRemoteControlAutoRepeatNow_No:
	ldi	r17, 0x00

IsRemoteControlAutoRepeatNow_Exit:
	ret

; Check if the standard single shot scheme applies for the current RC5 instruction
; This function is called on 'UserInputTimerEvent' interrupt to check if the current RC5 instruction
; must trigger the command according to standard single shot rules.
; The rules are:
;  - If 'UserInputRC5LastKeyPressDuration' is 0, the instruction is new and it is a single shot
; Arguments:
;  - R20 = 'UserInputRC5LastKeyPressDuration'
; Return:
;  - R17 = Result (0x00 for not launch command, 0x01 for launch command)
IsRemoteControlSingleShotNow:	
   cpi 	r20, 0x00			     	; Is new instruction?
	breq	IsRemoteControlSingleShotNow_Yes
	ldi	r17, 0x00
	rjmp	IsRemoteControlSingleShotNow_Exit

IsRemoteControlSingleShotNow_Yes:
	ldi	r17, 0x01

IsRemoteControlSingleShotNow_Exit:
	ret

; Check if the standard delayed action time is elapsed for the currently pressed RC5 key.
; This function is called on 'UserInputTimerEvent' interrupt to check if the current RC5 key
; is pressed for more than 'UserInputRC5DelayedActionTicks' ticks.
; The rules are:
;  - If 'UserInputRC5LastKeyPressDuration' is equal to 'UserInputRC5DelayedActionTicks', 
;    the action for the last RC5 instruction must be applied.
; Arguments:
;  - R20 = 'UserInputRC5LastKeyPressDuration'
; Return:
;  - R17 = Result (0x00 for not launch command, 0x01 for launch command)
IsRemoteControlDelayedActionNow:  
      
; DEBUG
;#message "TO DO: REMOVE DBG -> UserInputRC5LastKeyPressDuration value in IsRemoteControlDelayedActionNow displayed on port D"
;sts PORTL, r20
;end debug
      
	cpi	r20, 0x00				; If 'UserInputRC5LastKeyPressDuration' value is 0, 
							; this means that key is not pressed
	breq	IsRemoteControlDelayedActionNow_No

	cpi 	r20, UserInputRC5DelayedActionTicks    	; Is KeyPressed delay elapsed?
	brlo	IsRemoteControlDelayedActionNow_ClearActionDone

	; Action must be launched if not already done (i.e. single shot)
	lds	r17, UserInputRC5DelayedActionDone
	cpi	r17, 0x01
	breq	IsRemoteControlDelayedActionNow_No    	; Already launched
	ldi	r17, 0x01				; Action launched now
	sts	UserInputRC5DelayedActionDone, r17     
	rjmp	IsRemoteControlDelayedActionNow_Exit

IsRemoteControlDelayedActionNow_ClearActionDone:
	ldi	r17, 0x00				; Make sure that flag for 'ActionDone' is
	sts	UserInputRC5DelayedActionDone, r17	; not set
	rjmp	IsRemoteControlDelayedActionNow_Exit

IsRemoteControlDelayedActionNow_No:
	ldi	r17, 0x00
	rjmp	IsRemoteControlDelayedActionNow_Exit

IsRemoteControlDelayedActionNow_Exit:
	ret


#include "Version.asm"
#include "Utilities.asm"
;#include "IO.asm"
#include "Menu.asm"
#include "Output.asm"
#include "RemoteControl.asm"
#include "UserCommand.asm"
#include "TCPIP.asm"
#include "ACP.asm"
#include "Temperature.asm"

