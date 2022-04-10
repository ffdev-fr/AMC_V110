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
; File:	LCD.asm
;
; Author: F.Fargon
;
; Purpose: 
;  - DS1820 sensor low level functions
;  - Temperature measurement functions
;******************************************************************************


;******************************************************************************
; Automaton functions
;****************************************************************************** 

; Temperature measurement automaton main function
; This function is periodically invoked on timer interrupt in order to process
; the temperature measurement automaton
; The automaton is the following:
;  - For the current active sensor ('TemperatureCurrentSensor' variable)
;  - Assume that initial state is 'WAITING'
;     .. Increment the wait counter ('TemperatureWaitCounter' variable) until
;        it reaches the wait period value ('TemperatureWaitPeriod' constant)
;     .. Launch a new measurement on sensor and enter the 'MEASURING' state
;     .. Check and wait until measurement is done
;     .. Enter the 'MEASURED' state
;     .. Read the temperature value and store it
;        Display the value if changed since last measurement
;     .. Enter the 'WAITING' state
;
; NOTE: The automaton process function is protected against re-entry because
;       most of execution time is spent outside of critical section for 
;       performance purpose (i.e. temperature sensor interface requires a quite
;       long synchronization periods)
TemperatureProcess:

	; Check if re-entering the function
	; Re-entry semaphore accessed in non-interruptible section (i.e. mutex)
	ENTER_CRITICAL_SECTION
	push  r16
	lds   r16, TemperatureProcessEntered
	cpi   r16, 0x01
	breq  TemperatureProcess_FunctionReEntered
	
   ; Function entry allowed
   ldi   r16, 0x01                           ; Set entered flag
   sts   TemperatureProcessEntered, r16
   rjmp  TemperatureProcess_ProcessAllowed

TemperatureProcess_FunctionReEntered:
	; Exit re-entered call
	pop   r16
	LEAVE_CRITICAL_SECTION
	ret

TemperatureProcess_ProcessAllowed:

	LEAVE_CRITICAL_SECTION

   ; Process according to current state
   lds   r16, TemperatureMeasurementState
   cpi   r16, TEMPMEASUREMENT_STATE_WAITING
   breq  TemperatureProcess_WaitingState
   cpi   r16, TEMPMEASUREMENT_STATE_MEASURING
   breq  TemperatureProcess_MeasuringState
   cpi   r16, TEMPMEASUREMENT_STATE_MEASURED
   breq  TemperatureProcess_MeasuredState
   jmp   TemperatureProcess_Exit             ; Nothing to do in 'TERMINATED' or 'ERROR' state

TemperatureProcess_WaitingState:
   ; 'WAITING' state, check for end of wait period
   lds   r16, TemperatureWaitCounter
   inc   r16
   cpi   r16, TemperatureWaitPeriod
   breq  TemperatureProcess_LaunchMeasurement  ; End of wait reached
   sts   TemperatureWaitCounter, r16           ; Still waiting, update counter
   jmp   TemperatureProcess_Exit

TemperatureProcess_LaunchMeasurement:
   ; Launch a new measurement on current sensor
   push  r17                                   ; Result of launch command
   lds   r16, TemperatureCurrentSensor         ; Sensor to use
   call  TemperatureStartMeasurement           ; Ask for a new conversion on sensor
   mov   r16, r17
   pop   r17
   cpi   r16, 0x01                             ; Check if conversion launched
   brne  TemperatureProcess_EnterErrorState    ; Failed to launch conversion, enter 'ERROR' state
   ldi   r16, TEMPMEASUREMENT_STATE_MEASURING  ; Conversion launched, enter 'MEASURING' state
   sts   TemperatureMeasurementState, r16

TemperatureProcess_MeasuringState:
   ; 'MEASURING' state, check if conversion completed for current sensor
   push  r17                                   ; Result of completion check
   lds   r16, TemperatureCurrentSensor         ; Sensor to use
   call  TemperatureCheckReady                 ; Retrieve conversion status
   mov   r16, r17
   pop   r17
   cpi   r16, 0x01                             ; Check if conversion terminated
   brne  TemperatureProcess_Exit               ; Not ready yet
   ldi   r16, TEMPMEASUREMENT_STATE_MEASURED   ; Conversion terminated, enter 'MEASURED' state
   sts   TemperatureMeasurementState, r16
   jmp   TemperatureProcess_Exit

TemperatureProcess_MeasuredState:
   ; 'MEASURED' state, read new measurement and display it (if changed)
   push  r17                                   ; Result of conversion
   push  r18
   push  r19
   lds   r16, TemperatureCurrentSensor         ; Sensor to use
   call  TemperatureReadMeasurement            ; Read new temperature
   cpi   r17, 0x01                             ; Check if value read
   breq  TemperatureProcess_TemperatureReady
   pop   r19                                   ; Failed to read temperature, enter 'ERROR' state
   pop   r18
   pop   r17
   rjmp  TemperatureProcess_EnterErrorState
   
TemperatureProcess_TemperatureReady:                                              
   cpi   r19, 0x00                             ; Check for negative temperature 
   breq  TemperatureProcess_CheckTemperatureChange
   ldi   r18, 0x00                             ; Negative temperature set to 'undefined'

TemperatureProcess_CheckTemperatureChange:
   cpi   r16, 0x00                             ; Retrieve previous measurement for sensor
   brne  TemperatureProcess_LoadPrevLeftTemperature
   lds   r17, TemperatureRightValue
   rjmp  TemperatureProcess_CheckTemperatureChange2

TemperatureProcess_LoadPrevLeftTemperature:
   lds   r17, TemperatureLeftValue
                                              
TemperatureProcess_CheckTemperatureChange2:
   cp    r18, r17                               ; Is temperature changed?
   breq  TemperatureProcess_EnterWaitingState   ; Temperature unchanged, enter 'WAITNG' state

   ; Temperature changed, store new value and update display
   cpi   r16, 0x00                              ; According to current sensor
   brne  TemperatureProcess_StoreLeftTemperature
   sts   TemperatureRightValue, r18
   rjmp  TemperatureProcess_DisplayTemperature   

TemperatureProcess_StoreLeftTemperature:
   sts   TemperatureLeftValue, r18

TemperatureProcess_DisplayTemperature:
   ldi   r19, 0b00001000                        ; Update the 'State' screen (line 4)
   call  DisplayStateScreen                     
   rjmp  TemperatureProcess_EnterWaitingState   ; Temperature updated, enter 'WAITING' state
                                                        
TemperatureProcess_EnterErrorState:
   ; Enter the 'ERROR' state, update display and exit
   ldi   r16, TEMPMEASUREMENT_STATE_ERROR
   sts   TemperatureMeasurementState, r16
   push  r19                                    ; Update the 'State' screen (line 4)
   ldi   r19, 0b00001000
   call  DisplayStateScreen
   pop   r19                     
   rjmp  TemperatureProcess_Exit

TemperatureProcess_EnterWaitingState:
   ; Enter the 'WAITING' state (swap current sensor and reset wait counter)
   ; Note: This point is always reached from 'TemperatureProcess_MeasuredState' block
   ;       (i.e. pushed registers still on stack)
   ldi   r17, 0b00000001                       ; Swap current sensor
   eor   r16, r17                       
   sts   TemperatureCurrentSensor, r16
   ldi   r17, 0x00
   sts   TemperatureWaitCounter, r17           ; Reset wait counter
   ldi   r17, TEMPMEASUREMENT_STATE_WAITING
   sts   TemperatureMeasurementState, r17      ; 'WAITING' state
   pop   r19
   pop   r18
   pop   r17

TemperatureProcess_Exit:

   ; Clear re-entry flag
	ENTER_CRITICAL_SECTION
   ldi   r16, 0x00
   sts   TemperatureProcessEntered, r16
	LEAVE_CRITICAL_SECTION

   pop   r16
	ret

;******************************************************************************
; Temperature measurement functions
;****************************************************************************** 
	
; Launch a temperature measurement
; This function starts a 'Convert Temperature' transaction on a specified sensor
; After, the calling function must periodically invoke the 'TemperatureCheckReady'
; function in order to detect the end of temperature conversion (maximum conversion
; time is 500 ms)
; 
; The sensor to use is specified in r16 register (0 is 'right' and 1 is 'left')
; The function returns a status code in r17 register (0x01 if measurement is
; launched or 0x00 in case of error)
; 
; NOTE: This function enters some critical sections. The longest critical section
;       duration is 1 ms.
TemperatureStartMeasurement:

   ; Initialize transaction
   call  DS1820Reset              ; r16 already contains the sensor to use
   cpi   r17, 0x01
   brne  TemperatureStartMeasurement_Exit  ; Failed to reset DS1820

   ; Send 'Skip ROM' command
   ldi   r17, 0xCC
   call  DS1820SendByte

   ; Send 'Convert T' command
   ldi   r17, 0x44
   call  DS1820SendByte

   ; Measurement launched
   ldi   r17, 0x01

TemperatureStartMeasurement_Exit:
	ret

; Check for temperature measurement completion
; This function checks if the 'Convert Temperature' command is completed on a specified
; sensor
; This function must be periodically invoked after a call to 'TemperatureStartMeasurement'
; function in order to detect the end of 'Convert Temperature' transaction
; 
; The sensor to use is specified in r16 register (0 is 'right' and 1 is 'left')
; The function returns a status code in r17 register (0x01 if measurement is ready
; or 0x00 otherwise)
TemperatureCheckReady:

   ; Read busy flag 8 times
   call  DS1820ReceiveByte              ; r16 already contains the sensor to use
   cpi   r17, 0xFF                      ; Measurement ready if all bits are 1
   brne  TemperatureCheckReady_No      
   ldi   r17, 0x01                      ; Return code 'ready'
   ret   

TemperatureCheckReady_No:
   ldi   r17, 0x00                      ; Return code 'not ready'
	ret

; Obtain the last temperature measurement
; This function reads the last temperature measured by a specified sensor
; This function must be invoked only after a successful temperature conversion
; (i.e. functions 'TemperatureStartMeasurement' and 'TemperatureCheckReady')
; 
; The sensor to use is specified in r16 register (0 is 'right' and 1 is 'left')
; The function returns a status code in r17 register (0x01 if temperature value is
; returned or 0x00 in case of error)
; The temperature value is returned in r18 (LSB) and r19 (MSB) registers
TemperatureReadMeasurement:

   ; Initialize transaction
   call  DS1820Reset                      ; r16 already contains the sensor to use
   cpi   r17, 0x01
   brne  TemperatureReadMeasurement_Exit  ; Failed to reset DS1820

   ; Send 'Skip ROM' command
   ldi   r17, 0xCC
   call  DS1820SendByte

   ; Send 'Read Scratchpad' command
   ldi   r17, 0xBE
   call  DS1820SendByte

   ; Read the temperature bytes (the first ones in the scratchpad)
   call  DS1820ReceiveByte              ; Read temperature LSB
   mov   r18, r17
   call  DS1820ReceiveByte              ; Read temperature MSB
   mov   r19, r17

   ; Reset the DS1820 (for clean transaction end)
   call  DS1820Reset  

   ; Successful read
   ldi   r17, 0x01

TemperatureReadMeasurement_Exit:
	ret

;******************************************************************************
; DS1820 Driver Functions
;****************************************************************************** 

; Reset and presence of DS1820
; This function must be called each time a new transaction (typically command
; followed by data exchange)
; The function generates the 'reset' pulse and waits for the 'presence' pulse.
;
; The sensor to use is specified in r16 register (0 is 'right' and 1 is 'left')
; The function returns the result in r17 register (0x01 for sucess or 0x00 in 
; case of error)
; 
; NOTE: This function enters a critical section for whole sequence duration
;       The sequence duration (fixed by specification) is 1 ms
DS1820Reset:
   push  r18
   push  r19

   ; Critical section early entered because port is used for other purposes
   ENTER_CRITICAL_SECTION

   ; The 'master reset' pulse is a low level on bus for at least 480 usec
   in    r19, TemperatureSensePortDir         ; Read current DDR value (i.e. will retore Hi-Z after pulse)

   ; Set pin to low
   ; NOTE: In fact pin must already be 'low' (i.e. steady state is hi-Z = input DDR + 'low' PORT data)
   ; 
   ; According to specified sensor
   cpi  r16, 0x00
   brne DS1820Reset_SetLeftLow
   
   ; Right sensor
   cbi   TemperatureSensePortData, TemperatureSenseRight   ; Set low in output port (for right sensor)
   sbi   TemperatureSensePortDir, TemperatureSenseRight    ; Set direction for output
   jmp   DS1820Reset_WaitReset

DS1820Reset_SetLeftLow:
   ; Left sensor
   cbi   TemperatureSensePortData, TemperatureSenseLeft    ; Set low in output port (for left sensor)
   sbi   TemperatureSensePortDir, TemperatureSenseLeft     ; Set direction for output

DS1820Reset_WaitReset:
   ; Wait for 480 usec
   ldi   r18, 0x20                         ; Counter for 32 loops of 15 usec duration
                
DS1820Reset_ResetLoop:
   call  DS1820Wait15usecDelay              ; Wait for 15 usec
	dec   r18 
	brne  DS1820Reset_ResetLoop
                           
   ; Restore Hi-Z (i.e. the DS1820 will output the presence pulse)
   out   TemperatureSensePortDir, r19      ; Just restore pin direction to input 
                                           ; (i.e. port data already to low)

   ; Wait 15 usec to allow DS1820 to set the 'low' presence bit (i.e. time for bus
   ; to reach 'high' level via pull up resistor)
   ; NOTE: Measured delay for reaching 'hi' level after Hi-Z is less than 0.5 usec

   ; NOTE: The DS1820 waits 15-60 usec before setting 'low' and presence pulse has 
   ;       a duration of 60-240 usec
   ; NOTE: Measured delay for start of presence pulse is 30 usec
   call  DS1820Wait15usecDelay              ; Wait for 15 usec

   ; Wait and check presence bit for 90 usec
   ldi   r18, 0x06                          ; Counter for 6 loops of 15 usec duration
                
DS1820Reset_WaitPresenceLoop:
   call  DS1820Wait15usecDelay              ; Wait for 15 usec

   ; Read the presence bit value (should be 0)
   in    r19, TemperatureSensePins

   ; According to specified sensor
   cpi   r16, 0x00
   brne  DS1820Reset_ReadLeft

   andi  r19, 1 << TemperatureSenseRight   ; Check right sensor bus value
   breq  DS1820Reset_WaitForPulseEnd       ; Presence bit set
   rjmp  DS1820Reset_WaitPresenceLoopNext  ; Not ready yet

DS1820Reset_ReadLeft:
   andi  r19, 1 << TemperatureSenseLeft    ; Check left sensor bus value
   breq  DS1820Reset_WaitForPulseEnd       ; Presence bit set
   rjmp  DS1820Reset_WaitPresenceLoopNext  ; Not ready yet

DS1820Reset_WaitPresenceLoopNext:
	dec   r18 
	brne  DS1820Reset_WaitPresenceLoop

   ; Unable to detect presence bit from DS1820
   ldi   r17, 0x00                         ; Failure
   rjmp  DS1820Reset_Exit 

DS1820Reset_WaitForPulseEnd:
   ldi   r17, 0x01                         ; Set return code for sucess

   ; Total presence check must have at least 480 usec
   ; When reaching this point, the time spent for presence bit is:
   ;  - 15 usec for bus stabilization before looking for presence bit value
   ;  - (6 - r18) * 15 usec before detecting the 'low' level
   ldi   r19, 25                           ; r18 contains the remaining time not used for wait
                                           ; For 480 usec, 32 loops of 15 usec are required
                                           ; Simply add 32 - 7 = 25 to remaining value in r18
                                           ; Note: 7 is for stabilization (1) + whole wait (6)
   add   r18, r19

DS1820Reset_PulseEndWaitLoop:
   call  DS1820Wait15usecDelay             ; Wait for 15 usec
	dec   r18 
	brne  DS1820Reset_PulseEndWaitLoop

DS1820Reset_Exit:

   LEAVE_CRITICAL_SECTION

   pop   r19
   pop   r18
	ret
	
; Send a specified byte to DS1820
; This function sends a specified byte to a specified sensor
;
; The sensor to use is specified in r16 register (0 is 'right' and 1 is 'left')
; The byte to send is specified in r17 register
; 
; NOTE: The calling function must call 'DS1820Reset' before invoking the first
;       'DS1820SendByte' for a transaction
DS1820SendByte:
   push  r18

   ; Value to send in r18 (i.e. r17 used for parameter to 'DS1820WriteTimeslot' function
   mov   r18, r17

   ; Send bit0
   ldi   r17, 0x00
   sbrc  r18, 0x00
   inc   r17
   call  DS1820WriteTimeslot

   ; Send bit1
   ldi   r17, 0x00
   sbrc  r18, 0x01
   inc   r17
   call  DS1820WriteTimeslot

   ; Send bit2
   ldi   r17, 0x00
   sbrc  r18, 0x02
   inc   r17
   call  DS1820WriteTimeslot

   ; Send bit3
   ldi   r17, 0x00
   sbrc  r18, 0x03
   inc   r17
   call  DS1820WriteTimeslot

   ; Send bit4
   ldi   r17, 0x00
   sbrc  r18, 0x04
   inc   r17
   call  DS1820WriteTimeslot

   ; Send bit5
   ldi   r17, 0x00
   sbrc  r18, 0x05
   inc   r17
   call  DS1820WriteTimeslot

   ; Send bit6
   ldi   r17, 0x00
   sbrc  r18, 0x06
   inc   r17
   call  DS1820WriteTimeslot

   ; Send bit7
   ldi   r17, 0x00
   sbrc  r18, 0x07
   inc   r17
   call  DS1820WriteTimeslot

   mov   r17, r18            ; Restore original value in r17
   pop   r18
	ret

; Receive a byte sent by the DS1820
; This function receives a byte sent by a specified sensor
;
; The sensor to use is specified in r16 register (0 is 'right' and 1 is 'left')
; The received byte is returned in r17 register
; 
; NOTE: The calling function must have initiated a valid transaction in order to
;       expect data sent by the DS1820
DS1820ReceiveByte:
   push  r18

   ; Byte received in r18
   ldi   r18, 0x00
   
   ; Receive bit0
   call  DS1820ReadTimeslot
   sbrc  r17, 0x00
   ori   r18, 0b00000001

   ; Receive bit1
   call  DS1820ReadTimeslot
   sbrc  r17, 0x00
   ori   r18, 0b00000010

   ; Receive bit2
   call  DS1820ReadTimeslot
   sbrc  r17, 0x00
   ori   r18, 0b00000100

   ; Receive bit3
   call  DS1820ReadTimeslot
   sbrc  r17, 0x00
   ori   r18, 0b00001000

   ; Receive bit4
   call  DS1820ReadTimeslot
   sbrc  r17, 0x00
   ori   r18, 0b00010000

   ; Receive bit5
   call  DS1820ReadTimeslot
   sbrc  r17, 0x00
   ori   r18, 0b00100000

   ; Receive bit6
   call  DS1820ReadTimeslot
   sbrc  r17, 0x00
   ori   r18, 0b01000000

   ; Receive bit7
   call  DS1820ReadTimeslot
   sbrc  r17, 0x00
   ori   r18, 0b10000000

   mov   r17, r18            ; Set return value
   pop   r18
	ret

; Write a given bit on DS1820
; This function sends a given bit to the DS1820
; This is the elementary function for sending commands and data to DS1820 on
; the 1-wire interface.
; 
; The sensor to use is specified in r16 register (0 is 'right' and 1 is 'left')
; The bit value to send is indicated in r17 register (0 or 1)
; 
; NOTE: This function enters a critical section for whole sequence duration
;       The sequence duration (fixed by specification) is at least 65 usec
;       (60 usec min + 5 usec for delay between timeslots)
;       The duration between 2 timeslots is infinite. This allows handling
;       interrupts between 2 timeslots (i.e. critical section release at the 
;       end of timeslot)
DS1820WriteTimeslot:

   push  r18
   push  r19

   ; Critical section early entered because port is used for other purposes
   ENTER_CRITICAL_SECTION

   ; Sequence starts with and initial 'master' 'low' on the bus
   in    r19, TemperatureSensePortDir         ; Read current DDR value (i.e. will retore Hi-Z after pulse)

   ; Set pin to low
   ; NOTE: In fact pin must already be 'low' (i.e. steady state is hi-Z = input DDR + 'low' PORT data)
   ; 
   ; According to specified sensor
   cpi  r16, 0x00
   brne DS1820WriteTimeslot_SetLeftLow
   
   ; Right sensor
   cbi   TemperatureSensePortData, TemperatureSenseRight   ; Set low in output port (for right sensor)
   sbi   TemperatureSensePortDir, TemperatureSenseRight    ; Set direction for output
   jmp   DS1820WriteTimeslot_Wait

DS1820WriteTimeslot_SetLeftLow:
   ; Left sensor
   cbi   TemperatureSensePortData, TemperatureSenseLeft    ; Set low in output port (for left sensor)
   sbi   TemperatureSensePortDir, TemperatureSenseLeft     ; Set direction for output

DS1820WriteTimeslot_Wait:
   ; Duration for 'low' pulse according to bit value to send
   cpi   r17, 0x00
   brne  DS1820WriteTimeslot_WriteOne

   ; Write a '0' bit value
   ; The 'master' pin must be set low for at least 60 usec
   call  DS1820Wait15usecDelay   
   call  DS1820Wait15usecDelay   
   call  DS1820Wait15usecDelay   
   call  DS1820Wait15usecDelay   
   out   TemperatureSensePortDir, r19      ; Restore Hi-Z
                                           ; Just restore pin direction to input 
                                           ; (i.e. port data already to low)
   jmp   DS1820WriteTimeslot_WaitRecoveryDelay

DS1820WriteTimeslot_WriteOne:
   ; Write a '1' bit value
   ; The 'master' pin must be set back to high before 15 usec
   ; Set pin to '0' for 5 usec and then return to high Z (i.e. bus set to high
   ; by the pull up resistor)
   call  DS1820Wait5usecDelay   
   out   TemperatureSensePortDir, r19      ; Restore Hi-Z
                                           ; Just restore pin direction to input 
                                           ; (i.e. port data already to low)

   ; Give time to DS1820 for sampling data (i.e. minimum timeslot duration is 60 usec)
   call  DS1820Wait5usecDelay   
   call  DS1820Wait5usecDelay   
   call  DS1820Wait15usecDelay   
   call  DS1820Wait15usecDelay   
   call  DS1820Wait15usecDelay   

DS1820WriteTimeslot_WaitRecoveryDelay:
   ; Wait 5 usec for recovery delay between timeslots
   call  DS1820Wait5usecDelay   

   LEAVE_CRITICAL_SECTION

   pop   r19
   pop   r18
	ret

; Read a bit value on DS1820
; This function reads the bit value set by the DS1820
; This is the elementary function for receiving data from DS1820 on the 
; 1-wire interface.
; 
; The sensor to use is specified in r16 register (0 is 'right' and 1 is 'left')
; The received bit value is stored in r17 register (0 or 1)
; 
; NOTE: This function enters a critical section for whole sequence duration
;       The sequence duration (fixed by specification) is at least 65 usec
;       (60 usec min + 5 usec for delay between timeslots)
;       The duration between 2 timeslots is infinite. This allows handling
;       interrupts between 2 timeslots (i.e. critical section release at the 
;       end of timeslot)
DS1820ReadTimeslot:
   push  r18
   push  r19

   ; Critical section early entered because port is used for other purposes
   ENTER_CRITICAL_SECTION

   ; Sequence starts with and initial 'master' 'low' on the bus
   in    r19, TemperatureSensePortDir         ; Read current DDR value (i.e. will retore Hi-Z after pulse)

   ; Set pin to low
   ; NOTE: In fact pin must already be 'low' (i.e. steady state is hi-Z = input DDR + 'low' PORT data)
   ; 
   ; According to specified sensor
   cpi  r16, 0x00
   brne DS1820ReadTimeslot_SetLeftLow
   
   ; Right sensor
   cbi   TemperatureSensePortData, TemperatureSenseRight   ; Set low in output port (for right sensor)
   sbi   TemperatureSensePortDir, TemperatureSenseRight    ; Set direction for output
   jmp   DS1820ReadTimeslot_Wait

DS1820ReadTimeslot_SetLeftLow:
   ; Left sensor
   cbi   TemperatureSensePortData, TemperatureSenseLeft    ; Set low in output port (for left sensor)
   sbi   TemperatureSensePortDir, TemperatureSenseLeft     ; Set direction for output

DS1820ReadTimeslot_Wait:
   ; Minimum duration for 'low' pulse is 1 usec and read must be done before 15 usec
   call  DS1820Wait5usecDelay              ; Wait for 5 usec

   ; Restore Hi-Z (i.e. the DS1820 should output the bit value now)
   out   TemperatureSensePortDir, r19      ; Just restore pin direction to input 
                                           ; (i.e. port data already to low)

   ; Wait 5 usec level stabilization 
   call  DS1820Wait5usecDelay   

   ; Read the bit value (and store it in r17)
   in    r18, TemperatureSensePins

   ; According to specified sensor
   cpi   r16, 0x00
   brne  DS1820ReadTimeslot_ReadLeft

   andi  r18, 1 << TemperatureSenseRight   ; Check right sensor bus value
   breq  DS1820ReadTimeslot_LowValueRead
   rjmp  DS1820ReadTimeslot_HighValueRead 

DS1820ReadTimeslot_ReadLeft:
   andi  r18, 1 << TemperatureSenseLeft    ; Check left sensor bus value
   breq  DS1820ReadTimeslot_LowValueRead

DS1820ReadTimeslot_HighValueRead:
   ldi   r17, 0x01                         ; Set return value for 'high' read
   rjmp  DS1820ReadTimeslot_WaitForSlotDuration

DS1820ReadTimeslot_LowValueRead:
   ldi   r17, 0x00                         ; Set return value for 'low' read

DS1820ReadTimeslot_WaitForSlotDuration:
   ; Timeslot must have a minimum duration of 60 usec (10 usec elapsed when reaching this point)
   call  DS1820Wait15usecDelay   
   call  DS1820Wait15usecDelay   
   call  DS1820Wait15usecDelay   
   call  DS1820Wait15usecDelay   

   LEAVE_CRITICAL_SECTION

   pop   r19
   pop   r18
	ret

; Wait 5 micro seconds
; This function waits 5 usec (total 20 cycles with 4Mhz clock)
;
; NOTE: 
;  - This function must be called within a critical section
;  - Duration is rounded to upper value
DS1820Wait5usecDelay:
   
   ; Direct wait for low frequecies    
#ifdef CLOCK_FREQUENCY_1MHZ
   nop         ; 1 cycle
	ret 			; 4 cycles
#endif

#ifdef CLOCK_FREQUENCY_1_25MHZ
   nop         ; 1 cycle
   nop         ; 1 cycle
	ret 			; 4 cycles
#endif

   ; Loop used for higher frequecies
	push r16		; 2 cycles

#ifdef CLOCK_FREQUENCY_4MHZ
	ldi r16, 2		; 1 cycle
#endif

#ifdef CLOCK_FREQUENCY_5MHZ
	ldi r16, 3		; 1 cycle
#endif

#ifdef CLOCK_FREQUENCY_8MHZ
	ldi r16, 6		; 1 cycle
#endif

#ifdef CLOCK_FREQUENCY_10MHZ
	ldi r16, 8		; 1 cycle
#endif

; 5 cycle loop
DS1820Wait5usecDelay_Loop:
	nop 			;1 cycle
	nop
	dec r16	  	; 1 cycle
	brne DS1820Wait5usecDelay_Loop	; (5 * loop count) + 1 cycles
	
	pop r16     ; 2 cycles
	ret 			; 4 cycles
	
; Wait 15 micro seconds
; This function waits 15 usec (total 60 cycles with 4Mhz clock)
;
; NOTE: 
;  - This function must be called within a critical section
;  - Duration is rounded to upper value
DS1820Wait15usecDelay:
  
	push r16		; 2 cycles
 
#ifdef CLOCK_FREQUENCY_1MHZ
	ldi r16, 1		; 1 cycle
#endif

#ifdef CLOCK_FREQUENCY_1_25MHZ
	ldi r16, 2		; 1 cycle
#endif

#ifdef CLOCK_FREQUENCY_4MHZ
	ldi r16, 10		; 1 cycle
#endif

#ifdef CLOCK_FREQUENCY_5MHZ
	ldi r16, 13		; 1 cycle
#endif

#ifdef CLOCK_FREQUENCY_8MHZ
	ldi r16, 22		; 1 cycle
#endif

#ifdef CLOCK_FREQUENCY_10MHZ
	ldi r16, 28		; 1 cycle
#endif

; 5 cycle loop
DS1820Wait15usecDelay_Loop:
	nop 			;1 cycle
	nop
	dec r16	  	; 1 cycle
	brne DS1820Wait15usecDelay_Loop	; (5 * loop count) + 1 cycles
	
	pop r16     ; 2 cycles
	ret 			; 4 cycles

