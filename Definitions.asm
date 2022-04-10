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
; File:	Definitions.asm
;
; Author: F.Fargon
; 
; Purpose:
;  - Program definitions for hardware and software configuration
;  - Program definitions for builtin user configuration
;  - Program definitions for hardware resources
;******************************************************************************

;******************************************************************************
; Microcontroller definitions
;******************************************************************************

#include <m1280def.inc>

;******************************************************************************
; Temporary: Debug of critical section
;******************************************************************************

;#define ENTER_CRITICAL_SECTION  cli
#define ENTER_CRITICAL_SECTION  call EnterCriticalSection
;#define LEAVE_CRITICAL_SECTION  sei
#define LEAVE_CRITICAL_SECTION  call LeaveCriticalSection


;******************************************************************************
; Specific defines for debug
; 
; MUST NOT BE SET ON FINAL RELEASE
;******************************************************************************

; DCProt module is not plugged (used) when debugging (relay switches freeze JTAGICE!!!)
;#define DBG_DCPROT_NOT_PLUGGED

#if (defined DBG_DCPROT_NOT_PLUGGED)

#message "WARNING: DEBUG BUILD (NOT FOR RELEASE) -> Remove debug defines for release"

#endif


;******************************************************************************
; Hardware Configuration
;******************************************************************************

; These definitions must be adjusted for targeting the different hardware
; configurations

; ATMEL configuration
; -------------------

; Oscillator frequency (crystal)
;#define	OSCILLATOR_FREQUENCY_8MHZ
#define	OSCILLATOR_FREQUENCY_10MHZ          
;#define	OSCILLATOR_FREQUENCY_16MHZ          

; Clock frequency (device clock, for real time counters)
;#define	CLOCK_FREQUENCY_1MHZ
;#define	CLOCK_FREQUENCY_1_25MHZ
;#define	CLOCK_FREQUENCY_4MHZ
;#define	CLOCK_FREQUENCY_5MHZ
;#define	CLOCK_FREQUENCY_8MHZ          
#define	CLOCK_FREQUENCY_10MHZ
;#define	CLOCK_FREQUENCY_16MHZ

; AMPLIFIER configuration
; -----------------------
; 
; The supported amplifier operating modes are:
;  - 'Standalone' = Amplifier is controled by buttons and/or IR remote control
;  - 'Remote'     = Amplifier is controled by TCP/IP (via the ACC program).
;                   The IR remote control of one of the amplifiers present on the
;                   platform can be used to control the whole platform (via the 
;                   ACC program). 
;
; 'Standalone' mode:
;  - The On/Off and Mute/Unmute actions can be controled by buttons or IR or both.
;    The use of buttons is hardcoded in the firmware.
;  - The input level setting (volume) can be made by potentiometer or encoder or IR 
;    (exclusive).
;    The type of input level control is hardcoded in the firmware.
;  - The UGS On/Off, Balanced/Unbalanced and Bypass settings can be defined by
;    switches or program (firmware if no IR, configuration if IR)  
;
; 'Remote' mode:
;  - The On/Off, Mute/Unmute and volume are remotly controled by the ACC program.
;  - If the IR remote control detector is activated for a 'Remote' amplifier, the
;    IR command is transmited to the ACC program. The ACC program sends back the
;    command to all connected amplifiers.
;  - The UGS On/Off, Balanced/Unbalanced and Bypass settings can be defined by
;    switches or program (ACC command if program setting is used).
; 
; Notes: 
;  - The typical amplifier is working in 'Remote' mode and is equiped with an IR
;    device. This allows to switch in 'Standalone' mode if the amplifier must be 
;    connected to a standard audio platform. Also, the amplifier can act as the IR
;    remote control detector for the ACC program in the 'Remote' configuration.
;  - The 'switch' or 'program' mode of control for UGS/Balance/Bypass is selected by
;    a dip switch on the AMC board.
;  - The amplifier can be stereo or mono

; Use of buttons for On/Off and Mute/Unmute functions
; Enable this for amplifier without buttons
; Note: 'ButtonLess' hardware is allowed only if IR Remote Control is activated
;       (i.e. even if amplifier is controlled by ACC = to allow occasional switch
;       to 'Standalone' mode)
;#define BUTTON_LESS

; Level input control device
; Enable this for level input with incremental encoder
;#define ENCODER_INPUTLEVEL

; Enable this for level input with analog potentiometer
; NOTE: If this input mode is used, only one temperature sensor is available
;       (right sensor)
;#define	ANALOG_INPUTLEVEL

; Enable this for level input with IR
#define	IR_INPUTLEVEL


; LCD module configuration
; ------------------------
 
; Enable this for the LM1602A module (2 lines * 16 chars)
;#define LCD_MODULE_LM1602A

; Enable this for the WH2004A module (4 lines * 20 chars)
#define LCD_MODULE_WH2004A 


; Hardware configuration consistency check
;-----------------------------------------

#if (!defined ANALOG_INPUTLEVEL && !defined ENCODER_INPUTLEVEL && !defined IR_INPUTLEVEL) || (defined ANALOG_INPUTLEVEL && defined ENCODER_INPUTLEVEL) || (defined ANALOG_INPUTLEVEL && defined IR_INPUTLEVEL) || (defined ENCODER_INPUTLEVEL && defined IR_INPUTLEVEL)
 
; Unspecified hardware configuration definition: invalid build
#error "Unknown hardware configuration: check configuration defines (Input device)"

#endif

#if (defined BUTTON_LESS && !defined IR_INPUTLEVEL)
 
; Buttons are required if amplifier is not controlled by IR remote control
#error "Unknown hardware configuration: check configuration defines (Input device)"

#endif 

#if (!defined OSCILLATOR_FREQUENCY_8MHZ && !defined OSCILLATOR_FREQUENCY_10MHZ && !defined OSCILLATOR_FREQUENCY_16MHZ)
 
; Unspecified hardware configuration definition: invalid build
#error "Unknown hardware configuration: check configuration defines (oscillator frequency)"

#endif

#if (!defined CLOCK_FREQUENCY_1MHZ && !defined CLOCK_FREQUENCY_1_25MHZ && !defined CLOCK_FREQUENCY_4MHZ && !defined CLOCK_FREQUENCY_5MHZ && !defined CLOCK_FREQUENCY_8MHZ && !defined CLOCK_FREQUENCY_10MHZ && !defined CLOCK_FREQUENCY_16MHZ)
 
; Unspecified hardware configuration definition: invalid build
#error "Unknown hardware configuration: check configuration defines (clock frequency)"

#endif

#if (defined CLOCK_FREQUENCY_1MHZ && (defined CLOCK_FREQUENCY_1_25MHZ || defined CLOCK_FREQUENCY_4MHZ || defined CLOCK_FREQUENCY_5MHZ || defined CLOCK_FREQUENCY_8MHZ || defined CLOCK_FREQUENCY_10MHZ || defined CLOCK_FREQUENCY_16MHZ))
 
; Unspecified hardware configuration definition: invalid build
#error "Unknown hardware configuration: check configuration defines (clock frequency)"

#endif

#if (defined CLOCK_FREQUENCY_1_25MHZ && (defined CLOCK_FREQUENCY_1MHZ || defined CLOCK_FREQUENCY_4MHZ || defined CLOCK_FREQUENCY_5MHZ || defined CLOCK_FREQUENCY_8MHZ || defined CLOCK_FREQUENCY_10MHZ || defined CLOCK_FREQUENCY_16MHZ))
 
; Unspecified hardware configuration definition: invalid build
#error "Unknown hardware configuration: check configuration defines (clock frequency)"

#endif

#if (defined CLOCK_FREQUENCY_4MHZ && (defined CLOCK_FREQUENCY_1MHZ || defined CLOCK_FREQUENCY_1_25MHZ || defined CLOCK_FREQUENCY_5MHZ || defined CLOCK_FREQUENCY_8MHZ || defined CLOCK_FREQUENCY_10MHZ || defined CLOCK_FREQUENCY_16MHZ))
 
; Unspecified hardware configuration definition: invalid build
#error "Unknown hardware configuration: check configuration defines (clock frequency)"

#endif

#if (defined CLOCK_FREQUENCY_5MHZ && (defined CLOCK_FREQUENCY_1MHZ || defined CLOCK_FREQUENCY_1_25MHZ || defined CLOCK_FREQUENCY_4MHZ || defined CLOCK_FREQUENCY_8MHZ || defined CLOCK_FREQUENCY_10MHZ || defined CLOCK_FREQUENCY_16MHZ))
 
; Unspecified hardware configuration definition: invalid build
#error "Unknown hardware configuration: check configuration defines (clock frequency)"

#endif

#if (defined CLOCK_FREQUENCY_8MHZ && (defined CLOCK_FREQUENCY_1MHZ || defined CLOCK_FREQUENCY_1_25MHZ || defined CLOCK_FREQUENCY_4MHZ || defined CLOCK_FREQUENCY_5MHZ || defined CLOCK_FREQUENCY_10MHZ || defined CLOCK_FREQUENCY_16MHZ))
 
; Unspecified hardware configuration definition: invalid build
#error "Unknown hardware configuration: check configuration defines (clock frequency)"

#endif

#if (defined CLOCK_FREQUENCY_10MHZ && (defined CLOCK_FREQUENCY_1MHZ || defined CLOCK_FREQUENCY_1_25MHZ || defined CLOCK_FREQUENCY_4MHZ || defined CLOCK_FREQUENCY_5MHZ || defined CLOCK_FREQUENCY_8MHZ || defined CLOCK_FREQUENCY_16MHZ))
 
; Unspecified hardware configuration definition: invalid build
#error "Unknown hardware configuration: check configuration defines (clock frequency)"

#endif

#if (defined CLOCK_FREQUENCY_16MHZ && (defined CLOCK_FREQUENCY_1MHZ || defined CLOCK_FREQUENCY_1_25MHZ || defined CLOCK_FREQUENCY_4MHZ || defined CLOCK_FREQUENCY_5MHZ || defined CLOCK_FREQUENCY_8MHZ || defined CLOCK_FREQUENCY_10MHZ))
 
; Unspecified hardware configuration definition: invalid build
#error "Unknown hardware configuration: check configuration defines (clock frequency)"

#endif

#if (defined CLOCK_FREQUENCY_1MHZ && (defined OSCILLATOR_FREQUENCY_10MHZ))
 
; Unspecified hardware configuration definition: invalid build
#error "Unknown hardware configuration: check configuration defines (oscillator/clock frequency ratio)"

#endif

#if (defined CLOCK_FREQUENCY_1_25MHZ && (defined OSCILLATOR_FREQUENCY_8MHZ || defined OSCILLATOR_FREQUENCY_16MHZ))
 
; Unspecified hardware configuration definition: invalid build
#error "Unknown hardware configuration: check configuration defines (oscillator/clock frequency ratio)"

#endif

#if (defined CLOCK_FREQUENCY_4MHZ && (defined OSCILLATOR_FREQUENCY_10MHZ))
 
; Unspecified hardware configuration definition: invalid build
#error "Unknown hardware configuration: check configuration defines (oscillator/clock frequency ratio)"

#endif

#if (defined CLOCK_FREQUENCY_5MHZ && (defined OSCILLATOR_FREQUENCY_8MHZ || defined OSCILLATOR_FREQUENCY_16MHZ))
 
; Unspecified hardware configuration definition: invalid build
#error "Unknown hardware configuration: check configuration defines (oscillator/clock frequency ratio)"

#endif

#if (defined LCD_MODULE_LM1602A && defined LCD_MODULE_WH2004A)

; Ambiguous LCD module hardware configuration definition: invalid build
#error "Unknown hardware configuration: check configuration defines (LCD_MODULE)"

#endif

#if (!defined LCD_MODULE_LM1602A && !defined LCD_MODULE_WH2004A)

; Undefined LCD module hardware configuration definition: invalid build
#error "Unknown hardware configuration: check configuration defines (LCD_MODULE)"

#endif

;******************************************************************************
; Built in User Configuration
;******************************************************************************

; Display mode for Volume value on 'STATE' screen
;#define USERDISPLAY_LEVEL_DB          ; Output level expressed in dB
#define USERDISPLAY_LEVEL_VALUE       ; Output level expressed in potentiometer
                                      ; position (xxx/127)

;******************************************************************************
; Software Configuration
;******************************************************************************

; Input Polling Timer period
; Timer tick duration in timer unit.
; The timer unit depends on prescale value, see 'InputPollingTimerCtrl' 
; prescale value.
; By design, program uses a prescaler set to 1024.
; 
; Input level control by encoder or IR requires an higher polling rate
#ifdef CLOCK_FREQUENCY_1MHZ
#if (defined ENCODER_INPUTLEVEL || defined IR_INPUTLEVEL)
.EQU	InputPollingTimerPeriod = 1	; Timer period = 1.024 ms
#else				
.EQU	InputPollingTimerPeriod = 8	; Timer period = 7.68 ms
#endif
#endif

#ifdef CLOCK_FREQUENCY_1_25MHZ
#if (defined ENCODER_INPUTLEVEL || defined IR_INPUTLEVEL)
.EQU	InputPollingTimerPeriod = 1	; Timer period = 1.024 ms
#else				
.EQU	InputPollingTimerPeriod = 8	; Timer period = 7.68 ms
#endif
#endif

#ifdef CLOCK_FREQUENCY_4MHZ
#if (defined ENCODER_INPUTLEVEL || defined IR_INPUTLEVEL)
.EQU	InputPollingTimerPeriod = 4	; Timer period = 1.024 ms
#else				
.EQU	InputPollingTimerPeriod = 30	; Timer period = 7.68 ms
#endif
#endif

#ifdef CLOCK_FREQUENCY_5MHZ
#if (defined ENCODER_INPUTLEVEL || defined IR_INPUTLEVEL)
.EQU	InputPollingTimerPeriod = 5	; Timer period = 1.024 ms
#else				
.EQU	InputPollingTimerPeriod = 37	; Timer period = 7.68 ms
#endif
#endif

#ifdef CLOCK_FREQUENCY_8MHZ
#if (defined ENCODER_INPUTLEVEL || defined IR_INPUTLEVEL)
.EQU	InputPollingTimerPeriod = 8	; Timer period = 1.024 ms
#else				
.EQU	InputPollingTimerPeriod = 60	; Timer period = 7.68 ms
#endif
#endif

#ifdef CLOCK_FREQUENCY_10MHZ
#if (defined ENCODER_INPUT || defined IR_INPUTLEVEL)
.EQU	InputPollingTimerPeriod = 10	; Timer period = 1.00 ms
#else				
.EQU	InputPollingTimerPeriod = 75	; Timer period = 7.50 ms
#endif
#endif


; User Input Timer period
; Timer tick duration in timer unit.
; The timer unit depends on prescale value, see 'UserInputTimerCtrl' 
; prescale value.
; By design, program uses a prescaler set to 1024.
#ifdef CLOCK_FREQUENCY_1MHZ
.EQU	UserInputTimerPeriod = 20	; Timer period = 20 ms
#endif

#ifdef CLOCK_FREQUENCY_1_25MHZ
.EQU	UserInputTimerPeriod = 25	; Timer period = 20 ms
#endif

#ifdef CLOCK_FREQUENCY_4MHZ
.EQU	UserInputTimerPeriod = 80	; Timer period = 20 ms
#endif

#ifdef CLOCK_FREQUENCY_5MHZ
.EQU	UserInputTimerPeriod = 100	; Timer period = 20 ms
#endif

#ifdef CLOCK_FREQUENCY_8MHZ
.EQU	UserInputTimerPeriod = 160	; Timer period = 20 ms
#endif

#ifdef CLOCK_FREQUENCY_10MHZ
.EQU	UserInputTimerPeriod = 200	; Timer period = 20 ms
#endif

; Input level changed threshold (hysteresis on Input Level button for minimizing
; relay switching on short period)
.EQU	InputLevelThreshold = 5

; Number of Input Polling Timer periods for Encoder debounce
; The Encoder change event is generated if the Encoder state is modified for at
; least 'InputPollingEncoderDebouncePeriod' timer ticks.
.EQU	InputPollingEncoderDebouncePeriod = 1	   ; Spec. Toshiba = max bounce is 5ms

; Number of Input Polling Timer periods for launching AD Conversion
; The AD Conversion is launched on each 'InputPollingADConversionLaunchPeriod'
; timer ticks.
; This is a simple divider for launching AD conversions.
.EQU	InputPollingADCLaunchPeriod = 2

; Number of AD conversion results for Analog Input Value noice cancelation
; The Analog Input Value is averaged using 'ADConversionSampleNumber'
; conversions
; Note: The valid values are: 1, 2, 4, 8, 16, 32, 64
.EQU	ADConversionSampleNumber = 4

; Values for RC5 Frame Timer Output Compare Register according to clock frequency
; The RC5 Frame Timer is used for real time timing.
; The timer period does not depend on CPU clock frequency
; Two periods are used with this timer: 50 탎ec and 1000 탎ec
; Compare match numbers are 16 bit values

#ifdef CLOCK_FREQUENCY_1MHZ
; At 1MHz: 50탎 = 50 periods, 1000탎 = 1000 periods
.EQU	RC5FrameTimerFastPeriodL = 0x32		; Low byte for fast timing (50탎)
.EQU	RC5FrameTimerFastPeriodH = 0x00		; High byte for fast timing (50탎)
.EQU	RC5FrameTimerSlowPeriodL = 0xE8		; Low byte for slow timing (1000탎)
.EQU	RC5FrameTimerSlowPeriodH = 0x03		; High byte for slow timing (1000탎)
#endif

#ifdef CLOCK_FREQUENCY_1_25MHZ
; At 1.25MHz: 50탎 = 62 periods, 1000탎 = 1250 periods
.EQU	RC5FrameTimerFastPeriodL = 0x3E		; Low byte for fast timing (50탎)
.EQU	RC5FrameTimerFastPeriodH = 0x00		; High byte for fast timing (50탎)
.EQU	RC5FrameTimerSlowPeriodL = 0xE2		; Low byte for slow timing (1000탎)
.EQU	RC5FrameTimerSlowPeriodH = 0x04		; High byte for slow timing (1000탎)
#endif

#ifdef CLOCK_FREQUENCY_4MHZ
; At 4MHz: 50탎 = 200 periods, 1000탎 = 4000 periods
.EQU	RC5FrameTimerFastPeriodL = 0xC8		; Low byte for fast timing (50탎)
.EQU	RC5FrameTimerFastPeriodH = 0x00		; High byte for fast timing (50탎)
.EQU	RC5FrameTimerSlowPeriodL = 0xA0		; Low byte for slow timing (1000탎)
.EQU	RC5FrameTimerSlowPeriodH = 0x0F		; High byte for slow timing (1000탎)
#endif
 
#ifdef CLOCK_FREQUENCY_5MHZ
; At 5MHz: 50탎 = 250 periods, 1000탎 = 5000 periods
.EQU	RC5FrameTimerFastPeriodL = 0xFA		; Low byte for fast timing (50탎)
.EQU	RC5FrameTimerFastPeriodH = 0x00		; High byte for fast timing (50탎)
.EQU	RC5FrameTimerSlowPeriodL = 0x88		; Low byte for slow timing (1000탎)
.EQU	RC5FrameTimerSlowPeriodH = 0x13		; High byte for slow timing (1000탎)
#endif

#ifdef CLOCK_FREQUENCY_8MHZ
; At 8MHz: 50탎 = 400 periods, 1000탎 = 8000 periods
.EQU	RC5FrameTimerFastPeriodL = 0x90		; Low byte for fast timing (50탎)
.EQU	RC5FrameTimerFastPeriodH = 0x01		; High byte for fast timing (50탎)
.EQU	RC5FrameTimerSlowPeriodL = 0x40		; Low byte for slow timing (1000탎)
.EQU	RC5FrameTimerSlowPeriodH = 0x1F		; High byte for slow timing (1000탎)
#endif
 
#ifdef CLOCK_FREQUENCY_10MHZ
; At 10MHz: 50탎 = 500 periods, 1000탎 = 10000 periods
.EQU	RC5FrameTimerFastPeriodL = 0xF4		; Low byte for fast timing (50탎)
.EQU	RC5FrameTimerFastPeriodH = 0x01		; High byte for fast timing (50탎)
.EQU	RC5FrameTimerSlowPeriodL = 0x10		; Low byte for slow timing (1000탎)
.EQU	RC5FrameTimerSlowPeriodH = 0x27		; High byte for slow timing (1000탎)
#endif

#ifdef CLOCK_FREQUENCY_16MHZ
; At 16MHz: 50탎 = 800 periods, 1000탎 = 16000 periods
.EQU	RC5FrameTimerFastPeriodL = 0x20		; Low byte for fast timing (50탎)
.EQU	RC5FrameTimerFastPeriodH = 0x03		; High byte for fast timing (50탎)
.EQU	RC5FrameTimerSlowPeriodL = 0x80		; Low byte for slow timing (1000탎)
.EQU	RC5FrameTimerSlowPeriodH = 0x3E		; High byte for slow timing (1000탎)
#endif

; Number of RC5 Frame Timer ticks in fast mode for the duration of 1 RC5 bit
; Note: The tick period is 50탎 and the bit duration is 1778탎
.EQU	RC5BitDurationTimerTicks = 36

; Number of RC5 Frame Timer ticks in slow mode for the duration of 1 RC5 frame
; Note: The tick period is 1000탎 and the RC5 frame duration is 24.889ms
.EQU	RC5FrameDurationTimerTicks = 25

; Number of RC5 Frame Timer ticks in slow mode for the duration between 2 RC5 
; frames when the key is pressed.
; Note: The tick period is 1000탎 and the inter frame duration is 88.889ms
.EQU	RC5InterFrameDurationTimerTicks = 100     ; More than theorical value for safety

; Configured RC5 terminal address
; NOTE: In the future, replace this constant with a user configuration value 
.EQU	RC5ConfiguredTerminalAddress = 0x00

; Number of User Input Timer periods for RC5 instruction auto repeat
; Typically the value must be more than one RC5 frame period for echo cancelation.
; For a good user experience use values between 120ms and 400ms (i.e. time between
; 2 clicks).
; Note: 
;  - This also acts as instruction echo cancelation (the RC5 protocol send
;    about 8 frames per second = typicaly 4 frames during a user clic) 
;  - The click duration cannot be lower than RC5 frame period (typicaly greater
;    than 125ms)
.EQU	UserInputRC5ClickDuration = 10

; Number of User Input Timer periods for triggering an RC5 delayed instruction.
; Typical value is around 0.6 sec
.EQU	UserInputRC5DelayedActionTicks = 30

; TCP/IP Retry Time Value
; Timeout before retransmitting data (default is 200ms)
; The unit is 100탎
.EQU  TCPIPRetryTimeValue   = 0x07D0      ; 200 ms

; TCP/IP Retry Count
; Number of re-transmission before socket timeout (default is 8)
.EQU  TCPIPRetryCount = 0x08

; Number of 'InputPolling' timer ticks between 2 'Heartbeat' notifications
; Typical value is 133 (133 x 7.5 = 997ms)
.EQU  ACPHeatbeatNoficationTimerTicks = 133

; Number of 'InputPolling' timer ticks before enabling back external buttons
; interrupts (i.e. On/Off and Mute Buttons)
; Typical value is about 1000ms)
#if (defined ENCODER_INPUTLEVEL || defined IR_INPUTLEVEL)
; Timer tick period is 1.024 ms
.EQU	ExternalButtonInterruptTimerTicksL = 255
.EQU	ExternalButtonInterruptTimerTicksH = 4
#else
; Timer tick period is 7.5 ms
.EQU	ExternalButtonInterruptTimerTicksL = 133
.EQU	ExternalButtonInterruptTimerTicksH = 0
#endif

;******************************************************************************
; Resource definitions  ***** OLD *****
; 
; NOTE: Port use:
; 	 - Port A = Left Audio Channel Relays (8 pins output)
;
; 	 - Port B = Right Audio Channel Relays (8 pins output)
; 
; 	 - Port C = Keyboard Buttons (8 pins input)
; 
; 	 - Port D = LCD Data (8 pins ouput)
; 
; 	 - Port E = LCD Control (pins 0-2 ouput)
; 		    Internal Control for on/off and mute output commands (pins 3-4 output)
; 		    External Interrupt 5 for IR signal detection (pin 5)
; 		    External Interrupts 6-7 for on/off and mute output keys (pins 6-7)
; 
; 	 - Port F = Analog Input (pin 1 input)
;                   Encoder 0 outputs A and B (pins 0-1 input)
;                   Encoder 1 outputs A and B (pins 2-3 input)
;                   JTAG (pins 4-7)
;
; 	 - Port G = Internal Status (pin 0-4 input)
; 		    Note: G3 and G4 not available on STK300 (used for realtime clock OSC)
; 
; TIPS: Preferably use port A to E if mixing input and output pins on the same
;       port is required (= instructions CBI/SBI are restricted to these ports)
;******************************************************************************

;******************************************************************************
; Resource definitions
; 
; NOTE: Port use:
; 	 - Port A = Left Audio Channel Relays (8 pins output)
;
; 	 - Port B = Right Audio Channel Relays (8 pins output)
; 
; 	 - Port C = Internal status input from Amplifier Protection (pins 0-5 input)
;              Command output to Amplifier Protection (pins 6-7 output)
; 
; 	 - Port D = Configuration DIP switch input (pins 0-4 pins input)
;              LCD contrast control (pins 5-7 ouput)
; 
; 	 - Port E = Command output for Amplifier Protection (pins 0-2 output)
;              Command output for front LED (pin 3 output)
; 		         External Interrupt 4 for TCP/IP module interrupt request (pin 4)
; 		         External Interrupt 5 for IR signal detection (pin 5)
; 		         External Interrupts 6-7 for on/off and mute output keys (pins 6-7)
; 
; 	 - Port F = Analog input or temperature 1 wire signal (pins 0-1 input)
;              Encoder inputs A and B (pins 2-3 input)
;              JTAG (pins 4-7)
;
; 	 - Port G = RDP control output (pins 0-2 output)
; 		         G3 and G4 not available (used for realtime clock OSC)
;              Extension 0, not used (pin 5) 
; 
; 	 - Port H = TCP/IP module data bus (pins 0-7 input/output)
; 
; 	 - Port J = TCP/IP module control bus (pins 0-5 output)
;              Extension 1 and 2, not used (pins 6-7) 
; 
; 	 - Port K = LCD module data bus (pins 0-7 input/output)
; 
; 	 - Port L = LCD module control bus (pins 0-7 output)
; 
; TIPS: Preferably use port A to E if mixing input and output pins on the same
;       port is required (= instructions CBI/SBI are restricted to these ports)
;******************************************************************************

; Port Direction values
; The port direction values must be adjusted according to port use specified above
; Note: Most of port directions are set at startup and never change (fixed port 
;       mapping/use).
;       Port direction is dynamicaly changed only for ports used as data bus
;       (TCPI/IP module and LCD).
.EQU	DDRAValue = 0b11111111	; 8 bits output
.EQU	DDRBValue = 0b11111111	; 8 bits output
.EQU	DDRCValue = 0b11000000	; bit0-5 input, 6-7 output
.EQU	DDRDValue = 0b11100000	; bit0-4 input, 5-7 output
.EQU	DDREValue = 0b00001111	; bit0-3 output, 4-7 input
.EQU	DDRFValue = 0b00000000	; bit0-1 bidirectional (input by default), 2-7 input
.EQU	DDRGValue = 0b00000111	; bit0-2 output, 3-4 input (NA), 5 input (NC)
.EQU	DDRHValue = 0b00000000	; 8 bits input by default (bidirectional)
.EQU	DDRJValue = 0b00111111	; bit0-5 output, 6-7 input (NC)
.EQU	DDRKValue = 0b11111111	; 8 bits ouput by default (bidirectional)
.EQU	DDRLValue = 0b11111111	; 8 bits output

; Port Data values for pull up activation on input pins
; The port data values on input pins must be adjusted according to port use specified above
; Note: Port data for input pins are set at startup and never change (fixed port mapping/use)
.EQU	PORTEPullupValue = 0b00100000	; pull up on bit5 = external int5 for RC5 device 

; Channels input level relays (includes input mute bit)
.EQU	LeftChannelData = PORTA
.EQU	RightChannelData = PORTB

; Input Polling timer
; This is the timer resource for polling digital input devices (buttons, encoder)
; Timer 0 used by design (8 bit counter)
; Prescaler set to 1024
.EQU	InputPollingTimerCtrlA = TCCR0A
.EQU	InputPollingTimerCtrlB = TCCR0B
.EQU	InputPollingTimerCounter = TCNT0
.EQU	InputPollingTimerComp = OCR0A
.EQU	InputPollingTimerIntMask = TIMSK0
.EQU	InputPollingTimerCompIntEnable = OCIE0A  ; Interrupt enabled on Compare Match A

; User Input timer
; This is the timer resource for polling user inputs.
; User inputs are stable values sampled on input devices (i.e. results of button 
; debouncing and ADC noise cancelation)
; Timer 2 used by design (8 bit counter)
; Prescaler set to 1024
.EQU	UserInputTimerCtrlA = TCCR2A
.EQU	UserInputTimerCtrlB = TCCR2B
.EQU	UserInputTimerCounter = TCNT2
.EQU	UserInputTimerComp = OCR2A
.EQU	UserInputTimerIntMask = TIMSK2
.EQU	UserInputTimerCompIntEnable = OCIE2A ; Interrupt enabled on Compare Match A

; RC5 Frame timer
; This is the timer resource for decoding RC5 frames.
; Timer 1 used by design (16 bit counter).
; No prescaler used and timer is working in compare match mode.
.EQU	RC5FrameTimerCtrlA = TCCR1A
.EQU	RC5FrameTimerCtrlB = TCCR1B
.EQU	RC5FrameTimerCounterH = TCNT1H
.EQU	RC5FrameTimerCounterL = TCNT1L
.EQU	RC5FrameTimerCompH = OCR1AH
.EQU	RC5FrameTimerCompL = OCR1AL
.EQU	RC5FrameTimerIntMask = TIMSK1
.EQU	RC5FrameTimerCompIntEnable = OCIE1A	; Interrupt enabled on Compare Match A

; Analog input level input pin number (i.e. multiplexer input)
; Port F ADC0 to ADC7
.EQU 	AnalogInputADCInput = PINF1

; Temperature sensors pins
; NOTE: Only right sensor is available if 'analog input level' mode is set
;       In this case, definitions for left sensor redirect to right sensor
;       (i.e. no other conditional implementation)
.EQU	TemperatureSensePins = PINF
.EQU	TemperatureSensePortData = PORTF
.EQU	TemperatureSensePortDir = DDRF
.EQU	TemperatureSenseRight = PINF1          ; Right sensor 1-wire interface pin is pin 1
#ifndef ANALOG_INPUTLEVEL
.EQU	TemperatureSenseLeft = PINF0           ; Left sensor 1-wire interface pin is pin 0
#else
.EQU	TemperatureSenseLeft = TemperatureSenseRight
#endif

; Encoder input pins
.EQU	EncoderInputPins = PINF
.EQU	EncoderInputPinA0 = PINF2
.EQU	EncoderInputPinB0 = PINF3
.EQU	EncoderInputMask0 = 0b00001100	; Encoder0 input pins are pins 2 and 3

; Pins on port E for external interrupts 
.EQU	TcpipExtInt4PinNum = PINE4	   ; Interrupt 4
.EQU	RC5ExtInt5PinNum = PINE5	   ; Interrupt 5
.EQU	OnOffExtInt6PinNum = PINE6	   ; Interrupt 6
.EQU	MuteExtInt7PinNum = PINE7   	; Interrupt 7

; Pins and port for RC5 external interrupt
.EQU	RC5ExtIntPinNum = PINE5		; Interrupt 5
.EQU	RC5PortData = PORTE
.EQU	RC5PortPins = PINE

; Pins on port C for internal control (i.e. actions)
#ifdef AMPLIFIERPROT_V31_TRIGGER
.EQU	InternalCtrlPortData = PORTC        ; Command pins connected to trigger (i.e. pulse required for toggle)
.EQU	OnOffInternalCtrlPinNum = PORTC6	   ; bit 6	is On/Off softstart trigger control
.EQU	MuteInternalCtrlPinNum = PORTC7		; bit 7	is Mute/Unmute audio output control
#else
.EQU	InternalCtrlPortPin = PINC          ; Direct pin connection, (i.e. write 1 on PIN port while PORT DIR is output for toggle)
.EQU	OnOffInternalCtrlPinNum = PINC6	   ; bit 6	is On/Off direct pin toggle 
.EQU	MuteInternalCtrlPinNum = PINC7		; bit 7	is Mute/Unmute direct pin toggle
#endif

; Pins on port C for internal status (i.e. senses)
.EQU	InternalStatusPins = PINC		                ; Internal status pins state
.EQU	OnOffInternalStatusPinNum = PINC0	          ; bit 0	is On/Off softstart trigger sense signal
.EQU	MuteInternalStatusPinNum = PINC1	             ; bit 1	is Mute/Unmute audio output status
.EQU	DCProtMuteInternalStatusPinNum = PINC2	       ; bit 2	is DCProt Mute status (0 = muted, 1 = not muted)
.EQU	DCProtWaitInternalStatusPinNum = PINC3	       ; bit 3	is DCProt Wait status (0 = waiting, 1 = not waiting)
.EQU	DCProtErrorInternalStatusPinNum = PINC4	    ; bit 4	is DCProt Error status (0 = error, 1 = no error)
.EQU	SoftStartDelayInternalStatusPinNum = PINC5    ; bit 5	is SoftStart delay status

; Pins on port D for amplifier configuration DIP Swithes (i.e. senses)
; Note: Information from pins 2-4 is significant only if pin 1 is set (i.e. switch config)
.EQU	AmplifierConfigPins = PIND		                ; Amplifier configuration pins state
.EQU	ModeAmplifierConfigPinNum = PIND0	          ; bit 0	is 'Mode' (0 = 'standalone', 1 = 'remote')
.EQU	MemoryAmplifierConfigPinNum = PIND1           ; bit 1	is 'MemConfig' (0 = switch config, 1 = memory config)
.EQU	BalancedAmplifierConfigPinNum = PIND2	       ; bit 2	is 'Balanced' (0 = Unbalanced, 1 = Balanced input)
.EQU	UGSAmplifierConfigPinNum = PIND3	             ; bit 3	is 'UGS' (0 = UGS not used, 1 = UGS used)
.EQU	BypassAmplifierConfigPinNum = PIND4	          ; bit 4	is 'ByPass' (0 = not bypass, 1 = bypass RDP)
.EQU	ConfigSwitchInputMask = 0b00011111	          ; bit0-4 are from configuration switch

; Pins on port E for supply control (i.e. actions)
.EQU	SupplyCtrlPortData = PORTE
.EQU	DelayedVacSupplyCtrlPinNum = PORTE0	   ; bit 0 is Delayed VAC supply control
.EQU	RDPSupplyCtrlPinNum = PORTE1		      ; bit 1 is RDP supply control
.EQU	UGSSupplyCtrlPinNum = PORTE2		      ; bit 2 is UGS supply control
.EQU	FrontLedSupplyCtrlPinNum = PORTE3		; bit 3 is Front Led on/off control

; RDP Control Port bit mapping
.EQU	RDPCtrlPortData = PORTG
.EQU	RDPCtrlBalanced = PORTG0        ; bit 0 is Unbalanced/Balanced input
.EQU	RDPCtrlUGS = PORTG1             ; bit 1 is UGS not used/used
.EQU	RDPCtrlBypass = PORTG2          ; bit 2 is Digital Potentiometer used/bypassed

; WIZ812MJ Ports
.EQU	WIZDriverDataPortData = PORTH
.EQU	WIZDriverDataPortPins = PINH
.EQU	WIZDriverCtrlPortData = PORTJ
.EQU	WIZDriverDataPortDir = DDRH

; WIZ812MJ Control Port bit mapping
.EQU	WIZDriverCtrlA0 = PORTJ0           ; bit 0 is W5100 Address 0 
.EQU	WIZDriverCtrlA1 = PORTJ1           ; bit 1 is W5100 Address 1 
.EQU	WIZDriverCtrlCS = PORTJ2           ; bit 2 is W5100 Chip Select
.EQU	WIZDriverCtrlRD = PORTJ3           ; bit 3 is W5100 Read
.EQU	WIZDriverCtrlWR = PORTJ4           ; bit 4 is W5100 Write
.EQU	WIZDriverCtrlReset = PORTJ5        ; bit 5 is W5100 Reset
.EQU	WIZDriverCtrlReserved0 = PORTJ6    ; bit 6 is not used but reserved (the driver must be revised
                                         ; if this bit need to be used for extension)                
.EQU	WIZDriverCtrlReserved1 = PORTJ7    ; bit 7 is not used but reserved (the driver must be revised
                                         ; if this bit need to be used for extension)


; LCD Ports
.EQU	LCDDriverAD8402PortData = PORTD
.EQU	LCDDriverDataPortData = PORTK
.EQU	LCDDriverCtrlPortData = PORTL

; LCD Contrast Port bit mapping
.EQU	LCDDriverAD8402CS = PORTD5      ; bit 5 is AD8402 CS pin
.EQU	LCDDriverAD8402SDI = PORTD6     ; bit 6 is AD8402 SDI pin
.EQU	LCDDriverAD8402CLK = PORTD7     ; bit 7 is AD8402 CLK pin

; LCD Control Port bit mapping
.EQU	LCDDriverCtrlRS = PORTL0        ; bit 0 is HD44780 Register Select
.EQU	LCDDriverCtrlRW = PORTL1        ; bit 1 is HD44780 Read/Write
.EQU	LCDDriverCtrlEE = PORTL2        ; bit 2 is HD44780 Edge Enable
.EQU	LCDDriverCtrlPower = PORTL7     ; bit 7 is LCD power relay command

; HD44780 command set and command flags
; These are state of D0-D7 pins for HD44780 commands
.EQU	LCDDriverHDCmdClearDisplay = 0x01
.EQU	LCDDriverHDCmdHome = 0x02

.EQU	LCDDriverHDCmdEntryMode_CursorRight = 0x04 | 0x02
.EQU	LCDDriverHDCmdEntryMode_CursorLeft = 0x04 | 0x00
.EQU	LCDDriverHDCmdEntryMode_DisplayShift = 0x04 | 0x01

.EQU	LCDDriverHDCmdDisplayCtrl_DisplayOn = 0x08 | 0x04
.EQU	LCDDriverHDCmdDisplayCtrl_CursorOn = 0x08 | 0x02
.EQU	LCDDriverHDCmdDisplayCtrl_DisplayOff = 0x08 | 0x00
.EQU	LCDDriverHDCmdDisplayCtrl_CursorOff = 0x08 | 0x00 
.EQU	LCDDriverHDCmdDisplayCtrl_CursorBlink = 0x08 | 0x01 

.EQU	LCDDriverHDCmdDisplayShift_Display = 0x10 | 0x08
.EQU	LCDDriverHDCmdDisplayShift_Cursor = 0x10 | 0x00
.EQU	LCDDriverHDCmdDisplayShift_Right = 0x10	| 0x04
.EQU	LCDDriverHDCmdDisplayShift_Left = 0x10 | 0x00

.EQU	LCDDriverHDCmdFuncSet_Length8bit = 0x20 | 0x10
.EQU	LCDDriverHDCmdFuncSet_Lenght4bit = 0x20 | 0x00
.EQU	LCDDriverHDCmdFuncSet_Display2Lines = 0x20 | 0x08 
.EQU	LCDDriverHDCmdFuncSet_Display1Line = 0x20 | 0x00
.EQU	LCDDriverHDCmdFuncSet_Font10Dot = 0x20 | 0x04
.EQU	LCDDriverHDCmdFuncSet_Font8Dot = 0x20 | 0x00

.EQU	LCDDriverHDCmdCGRAMAddrMask = 0x40	; Address must be ORed on the 6 LSB
.EQU	LCDDriverHDCmdDRAMAddrMask = 0x80	; Address must be ORed on the 7 LSB

.EQU	LCDDriverHDStatusBusyBit = 0x80		; Bit D7 is Busy flag when HD44780
				       		                  ; is processing a command
 
; LCD module hardware specification
     
#ifdef LCD_MODULE_LM1602A

; Address in DDRAM for the first character of each line
.EQU	LCDDriverDeviceCharAddrLine0 = 0x00
.EQU	LCDDriverDeviceCharAddrLine1 = 0x40

; Number of characters per line on LCD Device
.EQU	LCDDriverDeviceCharsPerLine = 16

#endif

#ifdef LCD_MODULE_WH2004A

; Address in DDRAM for the first character of each line
.EQU	LCDDriverDeviceCharAddrLine0 = 0x00
.EQU	LCDDriverDeviceCharAddrLine1 = 0x40
.EQU	LCDDriverDeviceCharAddrLine2 = 0x14
.EQU	LCDDriverDeviceCharAddrLine3 = 0x54

; Number of characters per line on LCD Device
.EQU	LCDDriverDeviceCharsPerLine = 20

#endif


; Socket 0 RX memory access
; NOTE: Socket 0 RX size is the default value (2048 bytes)
.EQU  TCPIPSocket0RxBase = 0x6000
.EQU  TCPIPSocket0RxMask = 0x07FF
.EQU  TCPIPSocket0RxSize = 0x0800

; Socket 0 TX memory access
; NOTE: Socket 0 TX size is the default value (2048 bytes)
.EQU  TCPIPSocket0TxBase = 0x4000
.EQU  TCPIPSocket0TxMask = 0x07FF
.EQU  TCPIPSocket0TxSize = 0x0800

; Socket 1 TX memory access
; NOTE: Socket 1 TX size is the default value (2048 bytes)
.EQU  TCPIPSocket1TxBase = 0x4800
.EQU  TCPIPSocket1TxMask = 0x07FF
.EQU  TCPIPSocket1TxSize = 0x0800


;******************************************************************************
; Program constants
;******************************************************************************

; Amplifier Power State
; These constants are used as values for the 'bAmplifierPowerState' variable
.EQU	AMPLIFIERSTATE_POWER_OFF = 0	  	  ; Amplifier stage is powered off
.EQU	AMPLIFIERSTATE_POWERING_UP = 1	  ; Amplifier stage is powering up
                                         ; (i.e. softstart delay)
.EQU	AMPLIFIERSTATE_POWER_ON = 2        ; Amplifier stage is powered on

; Amplifier Audio Output State
; These constants are used as values for the 'bAmplifierOutputState' variable
.EQU	AMPLIFIERSTATE_OUTPUT_MUTED = 0    ; Audio output is muted
.EQU	AMPLIFIERSTATE_OUTPUT_PLAYING = 1  ; Audio output is unmuted

; DC Protection state
; These constants are used as values for the 'bDCProtectionState' is variable
; Values are 'DCPROTECTION_STATE_xxx' (Off/WaitStarted/WaitDone/Error)
; Notes: 
;  - The information is based on PoweringUp AmplifierPowerState and Wait/Error senses
;    of DCProt module 
;  - The ERROR state can be reached only from WAITDONE state (typically WAIT is set
;    when an error is detected)
;  - The WAITSTARTED state can be entered either from OFF and ERROR state
.EQU	DCPROTECTION_STATE_OFF = 0x00           ; The DC Prot module is powered off
.EQU	DCPROTECTION_STATE_WAITSTARTED = 0x01   ; The DC Prot is waiting (after PowerOn of ErrorOff)
.EQU	DCPROTECTION_STATE_WAITDONE = 0x02      ; The DC Prot has finished waiting
.EQU	DCPROTECTION_STATE_ERROR = 0x03         ; The DC Prot has dectected an error

; Main menu options
.EQU	MAIN_MENU_STATE = 0		; State display
					; This is the default screen
.EQU	MAIN_MENU_LEFT_OFFSET = 1	; Adjust Left Channel offset 
.EQU	MAIN_MENU_RIGHT_OFFSET = 2	; Adjust Right Channel offset
.EQU	MAIN_MENU_LAST_OPTION = 2	; Last option index (for rotating menu)

; Remote Control Instructions
; These constants are identifiers for RC5 instructions.
; There are also the indexes in the 'RemoteControlInstructionMap' used to convert
; RC5 devices instruction codes to generic identifiers.
; Note: The 'RemoteControlInstructionMap' is set a start time with values stored in
;       persistent storage (EEPROM). Typically, the RC5 device instruction codes have
;       been configured by the user.
.EQU	REMOTECONTROL_INSTRUCTION_ONOFF = 0    		  ; On/Off instruction
.EQU	REMOTECONTROL_INSTRUCTION_MUTE = 1    		     ; Mute instruction
.EQU	REMOTECONTROL_INSTRUCTION_VOLUMEPLUS = 2    	  ; Volume plus
.EQU	REMOTECONTROL_INSTRUCTION_VOLUMEMINUS = 3      ; Volume minus
.EQU	REMOTECONTROL_INSTRUCTION_BACKLIGHTPLUS = 4    ; LCD backlight plus
.EQU	REMOTECONTROL_INSTRUCTION_BACKLIGHTMINUS = 5   ; LCD backlight minus
.EQU	REMOTECONTROL_INSTRUCTION_CONTRASTPLUS = 6     ; LCD contrast plus
.EQU	REMOTECONTROL_INSTRUCTION_CONTRASTMINUS = 7    ; LCD contrast minus

; User commands
; These constants are indexes in the 'UserCommand_DispatchArray' array used to invoke 
; the processing of User Commands (= via function 'UserCommand_ExecuteCommand')
.EQU	USER_COMMAND_ONOFF = 0		        ; On/Off command
.EQU	USER_COMMAND_MUTE = 1		        ; Mute command
.EQU	USER_COMMAND_CHANGEVOLUME = 2	     ; Change volume command
.EQU	USER_COMMAND_CHANGEBALANCE = 3     ; Change balance command
.EQU	USER_COMMAND_CHANGEBACKLIGHT = 4   ; Change LCD backlight
.EQU	USER_COMMAND_CHANGECONTRAST = 5    ; Change LCD contrast

; LCD layout
.EQU	LCDLineNumber = 4
.EQU	LCDCharPerLineNumber = 20	; Max length is 63 (use of 'adiw' instruction)

; Map for Encoder step direction
; Map is 'LastDebouncedPinState|NewDebouncedPinState' to 'StepDirection'
; Map value indicates step direction: 
;  - 0x00 = invalid change (no step)
;  - 0x01 = step in forward direction
;  - 0xFF = step in backward direction
; NOTE: 
;  - Bit0 is B, bit1 is A
;  - Map values are defined using DW (for alignment purpose).
;    Lobyte is the lower index in map.
;  - This constant array will be copied in RAM during initialization (at 
;    'EncoderDirectionMap' address) for indexed access at runtime.
.EQU	EncoderMapIndex0 = 0x00 	; Map index 0  = 0b0000 is invalid: no change (0x00)
.EQU  EncoderMapIndex1 = 0xFF 	; Map index 1  = 0b0001 is backward (0xFF)
.EQU  EncoderMapIndex2 = 0x01 	; Map index 2  = 0b0010 is forward
.EQU  EncoderMapIndex3 = 0x00 	; Map index 3  = 0b0011 is invalid: no change
.EQU  EncoderMapIndex4 = 0x01 	; Map index 4  = 0b0100 is forward
.EQU  EncoderMapIndex5 = 0x00 	; Map index 5  = 0b0101 is invalid: no change
.EQU  EncoderMapIndex6 = 0x00 	; Map index 6  = 0b0110 is invalid: no change
.EQU  EncoderMapIndex7 = 0xFF 	; Map index 7  = 0b0111 is backward
.EQU  EncoderMapIndex8 = 0xFF 	; Map index 8  = 0b1000 is backward
.EQU  EncoderMapIndex9 = 0x00 	; Map index 9  = 0b1001 is invalid: no change
.EQU  EncoderMapIndex10 = 0x00	; Map index 10 = 0b1010 is invalid: no change
.EQU  EncoderMapIndex11 = 0x01	; Map index 11 = 0b1011 is forward
.EQU  EncoderMapIndex12 = 0x00	; Map index 12 = 0b1100 is invalid: no change
.EQU  EncoderMapIndex13 = 0x01	; Map index 13 = 0b1101 is forward
.EQU  EncoderMapIndex14 = 0xFF	; Map index 14 = 0b1110 is backward
.EQU  EncoderMapIndex15 = 0xFF	; Map index 15 = 0b1111 is invalid: no change

; TCP/IP server states
; Constants used as values for the 'TCPIPServerState' variable
.EQU TCPIP_SERVERSTATE_STOPPED   =    0x00     ; Does not accept incoming connections
.EQU TCPIP_SERVERSTATE_STARTED   =    0x01     ; Ready to accept incoming connections
                                               ; (i.e. not all connections established)
.EQU TCPIP_SERVERSTATE_CONNECTED =    0x02     ; Sockets 0 and 1 are connected
.EQU TCPIP_SERVERSTATE_DISCONNECTED = 0x03     ; Disconnection event detected 
                                               ; (socket 0 or 1 disconnect event or
                                               ; heartbeat notification failure)

; TCP/IP socket states
; Constants used as values for the 'TCPIPSocketState0/1' variables
.EQU TCPIP_SOCKETSTATE_NOTSTARTED   = 0x00
.EQU TCPIP_SOCKETSTATE_CLOSED       = 0x01
.EQU TCPIP_SOCKETSTATE_INIT         = 0x02
.EQU TCPIP_SOCKETSTATE_LISTENING    = 0x03
.EQU TCPIP_SOCKETSTATE_ESTABLISHED  = 0x04
.EQU TCPIP_SOCKETSTATE_RECEIVING    = 0x05
.EQU TCPIP_SOCKETSTATE_CMDRECEIVED  = 0x06
.EQU TCPIP_SOCKETSTATE_SENDINGREPLY = 0x07
.EQU TCPIP_SOCKETSTATE_SENDINGNOTIF = 0x08
.EQU TCPIP_SOCKETSTATE_CLOSING      = 0x09

; TCPIP Notification states
; Constants used as values for the 'TCPIPNotificationState' variable
; This variable is the semaphore for shared access to 'TCPIPNotificationFrame' buffer
.EQU TCPIP_NOTIFICATIONSTATE_BUFFERRELEASED = 0x00
.EQU TCPIP_NOTIFICATIONSTATE_BUFFERACQUIRED = 0x01
.EQU TCPIP_NOTIFICATIONSTATE_SENDINGBUFFER  = 0x02


; Size of a TCPIP 'Frame'
; The TCPIP 'Frame' has a fixed size and maximum value is 255 bytes.
; Note:
;  - 'TCPIPCommandFrame' buffer size must be adjusted if frame size is changed.
;  - 'TCPIPReplyFrame' buffer size must be adjusted if frame size is changed.
;  - The frame format is defined in ACP module.
;  - Using a frame size of 8, 16, 32, 64 or 128 bytes aligns boundaries for
;    RX/TX memory read/write operations (most efficient).
.EQU  TCPIPFrameSize = 64

; ACP protocol definitions
; Frame header
.EQU	ACP_FRAME_HEADER0 = 0x41		; Frame identifier 1st byte ('A')
.EQU	ACP_FRAME_HEADER1 = 0x43		; Frame identifier 2nd byte ('C')
.EQU	ACP_FRAME_HEADER2 = 0x50		; Frame identifier 3rd byte ('P')
.EQU	ACP_FRAME_HEADER3 = 0x3A		; Frame identifier 4th byte (':')

.EQU	ACP_FRAME_VERSION = 0x10		; Frame version 5th byte (v1.0)

; Frame type
.EQU	ACP_FRAME_NONE = 0x00		   ; Empty frame
.EQU	ACP_FRAME_COMMAND = 0x01		; Command frame
.EQU	ACP_FRAME_REPLY = 0x02		   ; Reply frame
.EQU	ACP_FRAME_NOTFICATION = 0x03	; Notification frame

; Offsets for ACP Frame object access
.EQU  ACP_FRAME_OFFSET_TYPE = 5           ; Index for 'Frame type' field
.EQU  ACP_FRAME_OFFSET_DATA = 6           ; Index for 'Frame' data block

; 'UserInput' commands
.EQU	ACP_COMMAND_USER_ONOFF = 0		         ; On/Off command
.EQU	ACP_COMMAND_USER_MUTE = 1		         ; Mute command
.EQU	ACP_COMMAND_USER_CHANGEVOLUME = 2	   ; Change volume command
.EQU	ACP_COMMAND_USER_CHANGEBALANCE = 3	   ; Change balance command
.EQU	ACP_COMMAND_USER_CHANGEBACKLIGHT = 4	; Change LCD backlight
.EQU	ACP_COMMAND_USER_CHANGECONTRAST = 5	   ; Change LCD contrast
.EQU	ACP_COMMAND_USER_RESERVED0 = 6	      ; Reserved 0
.EQU	ACP_COMMAND_USER_RESERVED1 = 7	      ; Reserved 1
.EQU	ACP_COMMAND_USER_RESERVED2 = 8	      ; Reserved 2
.EQU	ACP_COMMAND_USER_RESERVED3 = 9	      ; Reserved 3

; 'Master' commands
; IMPORTANT: 
;  - Master command values MUST directly follow the 'UserInput' command values
;    (command switch is implemented by indirect jump in a vector array)
;  - 'ACP_COMMAND_LAST' value must be set to the last 'Master' command value
.EQU	ACP_COMMAND_MASTER_PING = 10		   ; Heartbeat command
.EQU	ACP_COMMAND_MASTER_CONFIGURE = 11   ; Configuration command

.EQU	ACP_COMMAND_LAST = ACP_COMMAND_MASTER_CONFIGURE	 ; IMPORTANT: Update when adding new command

; Reply 'ReturnCode' values
.EQU	ACP_REPLY_RETURN_NOK = 0		      ; Error occured during command processing
.EQU	ACP_REPLY_RETURN_OK = 1		         ; Command successfully processed

; Reply 'StatusCode' values
.EQU	ACP_REPLY_STATUS_NONE = 0		         ; No additional data in reply
.EQU	ACP_REPLY_STATUS_INVALIDFRAME = 1		; Frame header is invalid
.EQU	ACP_REPLY_STATUS_INVALIDVERSION = 2		; Protocol version not supported
.EQU	ACP_REPLY_STATUS_NOTCOMMAND = 3		   ; Frame is not a command frame
.EQU	ACP_REPLY_STATUS_INVALIDCOMMAND = 4		; Unknown command
.EQU	ACP_REPLY_STATUS_COMMANDQUEUEFULL = 5  ; Command queue is full (asynchroneous 'UserInput' command)

; Notifications
.EQU	ACP_NOTIFICATION_HEARTBEAT = 0 	      ; Heartbeat
.EQU	ACP_NOTIFICATION_VOLUMECHANGED = 1 	   ; Ouput volume changed
.EQU	ACP_NOTIFICATION_MUTECHANGED = 2 	   ; Mute state changed
.EQU	ACP_NOTIFICATION_ONOFFCHANGED = 3 	   ; On/Off state changed
.EQU	ACP_NOTIFICATION_ERRORCHANGED = 4 	   ; Error state changed
.EQU	ACP_NOTIFICATION_IRUSERCOMMAND = 5 	   ; User command qualified on IR device

.EQU	ACP_NOTIFICATION_NUMBER = 6      ; IMPORTANT: Update when adding new notification


; Message layout for screens displayed on LCD 
; Layout for 'STATE' screen
#ifdef USERDISPLAY_LEVEL_DB 
.EQU	LCDStateScreenL3_VarPos = 9              ; Third line contains a variable area
#endif

#ifdef USERDISPLAY_LEVEL_VALUE 
.EQU	LCDStateScreenL3_VarPos = 8              ; Third line contains a variable area
#endif

.EQU	LCDStateScreenL4_VarPos = 9              ; Variable area for 'version' on fourth line
.EQU	LCDStateScreenL4_VarPos1 = 9             ; Variable area for 'left temperature' on fourth line
.EQU	LCDStateScreenL4_VarPos2 = 16            ; Variable area for 'right temperature' on fourth line

.EQU  LCDStateScreenUpdateState = 0b00001010     ; Second and fourth lines to update in case of state change
.EQU  LCDStateScreenUpdateLevel = 0b00000100     ; Third line to update in case of level change

; Temperature Measurement state
; These constants are used as values for the 'TemperatureMeasurementState' variable
.EQU	TEMPMEASUREMENT_STATE_WAITING = 0x00       ; The temperature measurement automaton is waiting for
                                                 ; launching a new measurement (i.e. measurement period)
.EQU	TEMPMEASUREMENT_STATE_MEASURING = 0x01     ; A new measurement is launched on current sensor and the
                                                 ; automaton waits for result
.EQU	TEMPMEASUREMENT_STATE_MEASURED = 0x02      ; The temperature measurement is ready for current sensor
                                                 ; (and not read yet by the automaton)
.EQU	TEMPMEASUREMENT_STATE_TERMINATED = 0x03    ; The temperature measurement automaton is terminated
.EQU	TEMPMEASUREMENT_STATE_ERROR = 0x04         ; Fatal error occured, automaton is terminated

; Number of input polling timer ticks for the temperature measurement automaton clock
; The interrupt handler invokes the temperature measurement automaton each time it counts this number
; of timer ticks
.EQU	TemperaturePollingPeriod = 50              ; Automaton polling period 50 ms

; Number of automaton clock ticks for the 'WAITING' period between two temperature measurements
; NOTE: The conversion duration (typically 500 ms) must be added to this 'WAITING' time to obtain 
;       the real value of period between two measurements 
.EQU	TemperatureWaitPeriod = 30                 ; Wait period 1500 ms (one conversion every 2 seconds)

