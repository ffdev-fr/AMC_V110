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
; File:	Globals.asm
;
; Author: F.Fargon
;
; Purpose: 
;  - Program definitions for hardware and software configuration
;  - Program definitions for hardware resources
;******************************************************************************

;******************************************************************************
; Global variables defined in RAM memory space
;******************************************************************************

.DSEG

; Program Operating State
; The states are the following:
;  - 0x00 = Initializing. 
;           The program is initializing.
;           Interrupts are not allowed.
;  - 0x01 = Operating. 
;           The program is processing events.
;           Interrupts are allowed.
;  - 0x02 = Shuting down. 
;           The program is terminating events.
;           Interrupts are not allowed.
bOperatingState: .BYTE 1

; Counter for Global Interrupt Enable Flag management
; This counter contains the current recursion level of 'EnterCriticalSection'
; function.
; The Global Interrupt Enable Flag is restored when the recursion level reaches 
; 0 (by call to 'LeaveCriticalSection' function)
bNestedCriticalSectionCount: .BYTE 1

; Amplifier working mode 
; This variable indicates the working mode of the amplifier ('standalone' or 
; 'remote').
; This variable is set on startup from information read on amplifier configuration
; DIP switches
bAmplifierRemoteMode: .BYTE 1

; Amplifier acts as IR detector for ACC in 'remote' mode
; This variable indicates that IR detector of the amplifier is used to send ACP
; notifications in 'remote' mode.
; This variable is set by the ACC program when it connects the amplifier (by default
; the IR detector is disabled in 'remote' mode).
; Note: The ACC program cannot set more than one amplifier on the platform.
bRemoteModeIRDetector: .BYTE 1

; String to display on LCD for amplifier name (first line on LCD)
; This variable is set by ACC when it connects the amplifier
; Before ACC connection (or with standalone configuration) the displayed amplifier
; name is the static string located in CSEG (LCDStateScreenL1)
; Note: The display function use this display name if 'AmplifierDisplayName[0]'
;       is not NULL.
AmplifierDisplayName: .BYTE 20

; Amplifier current configuration
; This variable contains the amplifier configuration computed from DIP switch
; setting and optionally persistent memory.
; This variable is set on startup from information read on amplifier configuration
; DIP switches
bAmplifierCurrentConfig: .BYTE 1

; Current amplifier power state
; This variable indicates the state of the power stage of the amplifier (Off/PoweringUP/
; Values are 'AMPLIFIERSTATE_POWER_xxx' (Off/PoweringUP/On)
; This variable is periodically updated with the value of softstart trigger 
; Information computed using 'On/Off' and 'SoftstartDelay' sense signals.
bAmplifierPowerState: .BYTE 1

; Current amplifier audio output state
; This variable indicates if the audio output relay allows current on the driver
; connectors.
; Values are 'AMPLIFIERSTATE_OUTPUT_xxx' (Muted/Playing)
; Note: The information is based on the Mute/Unmute and Wait senses on DCProt module 
;       (i.e. in order to detect muting due to DCProt action = DC current on loudspeaker)
bAmplifierOutputState: .BYTE 1

; Current amplifier audio input state
; This variable indicates if the audio input relay allows signal on the amplifier
; input (i.e. Mute relays on the potentiometers).
; Note: The audio input is automatically switched ON/OFF when the amplifier power 
;       is switched ON/OFF (based on bAmplifierPowerState state).
bAmplifierInputOn: .BYTE 1

; Current DC Protection state
; This variable indicates if the DC Protection is waiting and/or has detected an error.
; Values are 'DCPROTECTION_STATE_xxx' (Off/WaitStarted/WaitDone/Error)
; Note: The information is based on PoweringUp AmplifierPowerState and Wait/Error senses
;       of DCProt module 
bDCProtectionState: .BYTE 1

; Current input level (7 bit value, maximum is 0x7F)
bCurrentLevel: .BYTE 1

; Mask for enabled external interrupts according to 'Remote' mode
; In 'Remote' mode, IR interrupt is disabled (int5)
; In 'Standalone' mode, TCP/IP interrupt is disabled (int4)
; External interrupts int6 and int7 are always enabled (buttons On/Off and Mute/Unmute)
; Note: External interrupts int6 and int7 may be temporary disabled for button debounce
;       purpose (see InputPollingOnOffButtonDebounce and InputPollingMuteButtonDebounce)
bExternalInterruptMask: .BYTE 1

; Number of succesive AD conversions with level change detected.
; This counter is incremented when an AD conversion gives a value different
; 'bCurrentLevel'. 
; It is set to 0 when the AD conversion gives 'bCurrentLevel' value.
; The new level value is applied when the counter reaches the 'bLevelChangedCount'
; threshold 
bADCLevelChangeCount: .BYTE 1

; Number of successive User Input interrupts with level change detected.
; This counter is incremented when the 'DebouncedEncoderSteps' is not 0 on
; a User Input interrupt.
; It is set to 0 if the 'DebouncedEncoderSteps' variable is 0 on a User Input
; interrupt.
; The new level value is applied when the counter reaches the 'bLevelChangedCount'
; threshold 
bEncoderLevelChangeCount: .BYTE 1

; Number of level change detections after which apply the new level value.
; Note: defined as a variable for eventual use with encoder input (i.e. counts
;       of encoder ticks and delayed change)
; This variable is intended to minimize the number of relay switches on short
; period.
bLevelChangedCount: .BYTE 1

; Current Main Menu option
; This variable is adjusted when the 'Menu' push button is pressed
bCurrentMainMenuOption:	.BYTE 1

; Current keyboard user input
; This variable is incremented when 'Plus' push button is pressed and
; decremented when 'Minus' push button is pressed
bCurrentKeyboardInput: .BYTE 1

; Current Left Channel Offset
; This variable contains the current Left Channel Offset
; At start time the value is read from persitent storage.
; After the value is kept synchronized with value in persistent storage
; NOTE: A DSEG variable is used to avoid slow access to ESEG
bCurrentLeftChannelOffset:	.BYTE 1

; Current Right Channel Offset
; This variable contains the current Right Channel Offset
; At start time the value is read from persitent storage.
; After the value is kept synchronized with value in persistent storage
; NOTE: A DSEG variable is used to avoid slow access to ESEG
bCurrentRightChannelOffset:	.BYTE 1

; LCD current contrast level
; This variable contains the current LCD contrast level
; At start time the value is read from persitent storage.
; After the value is kept synchronized with value in persistent storage
; NOTE: A DSEG variable is used to avoid slow access to ESEG
bCurrentLCDContrast:	.BYTE 1

; LCD current backlight level
; This variable contains the current LCD backlight level
; At start time the value is read from persitent storage.
; After the value is kept synchronized with value in persistent storage
; NOTE: A DSEG variable is used to avoid slow access to ESEG
bCurrentLCDBacklight:	.BYTE 1

; LCD Application Area
; Memory buffer in which application transmit the text to display on the LCD.
; Once text transfered in this buffer the application calls the 
; 'LCDUpdateDisplay' function.
; The 'LCDUpdateDisplay' function read this memory buffer and synchronizes the
; display on the LCD device.
; IMPORTANT: For access to this buffer (read or write) the interrupts must be
;            disabled.

LCDAppBuffer: .BYTE LCDLineNumber * LCDCharPerLineNumber

; LCD Application Area Modified semaphore
; For synchronization and optimization the application indicates the index of
; updated lines in the buffer.
; This semaphore must be updated by the application immediatly before calling
; the 'LCDUpdateDisplay' function.
; The 'LCDUpdateDisplay' function reset the semaphore once the buffer is 
; transfered in its own buffer.
; IMPORTANT: For access to this variable (read or write) the interrupts must be
;            disabled.
LCDAppBufferModifiedLines: .BYTE 1

; LCDUpdateDisplay buffer
; Memory buffer in which the 'LCDUpdateDisplay' function copies the 
; 'LCDAppBuffer' before updating the LCD device.
; To minimize the lock duration on 'LCDAppBuffer' (interrupts disabled), the
; 'LCDUpdateDisplay' function makes a copy in its own buffer (i.e. this one)
LCDUpdateDisplayBuffer:	.BYTE LCDLineNumber * LCDCharPerLineNumber

; LCDUpdateDisplay re-entry flag
; This flag is set when the 'LCDUpdateDisplay' function is entered for detection
; of re-entry.
; If the function is re-entered, the LCD update is processed by the first call:
; there is no recursion, the second call only notifies the first call and exits.
LCDUpdateDisplayCalled:	.BYTE 1

; LCDUpdateDisplay re-entered flag
; This flag is set when the 'LCDUpdateDisplay' function is re-entered.
; The first function call uses this flag to restart the update process with the
; new application text (i.e. synchronizes with the application text and starts
; a new update cycle).
LCDUpdateDisplayReEntered: .BYTE 1

; LCDUpdateDisplay lines to update
; Maintained by the 'LCDUpdateDisplay' function for lines update progress.
; This variable is ORed with 'LCDAppBufferModifiedLines' when the application
; text is synchronized (initial call or re-entering).
; The 'LCDUpdateDisplay' function updates these flags each time a line is 
; updated on the LCD device.
; The 'LCDUpdateDisplay' function exits only when all flags are cleared (i.e.
; all modified lines updated on the LCD device).
LCDUpdateDisplayLinesToUpdate: .BYTE 1

; LCDUpdateDisplay Device buffer
; This buffer contains the text currently displayed on the LCD device.
; These data are used for optimizing the update of the LCD device (typically
; a character is not updated if already displayed on the device).
LCDDeviceBuffer: .BYTE LCDLineNumber * LCDCharPerLineNumber
      
; StringFormatingBuffer
; This buffer is space used for string formating (typically when computing
; field values for LCD display)
; The buffer size is 'LCDCharPerLineNumber'
StringFormatingBuffer: .BYTE LCDCharPerLineNumber

; UserInputLevelLastValue
; This variable contains the Input Level value memorised on last User Input 
; Timer event
UserInputLevelLastValue: .BYTE 1

; UserInputLevelStoreCounter
; This variable is the counter for Input Level persistent storage delay
; This variable is set to 'UserInputLevelStoreDelay' each time the Input
; Level is changed and decremented on each User Input Timer event. When it
; reaches 0, the Input Level is memorized in persistent storage.
; This is a one shot operation (i.e. when counter is 0 the Input Level has been
; stored in persistent storage)
UserInputLevelStoreCounter: .BYTE 1

; UserInputRC5LastInstructionDuration
; This variable contains the number of 'UserInput' timer ticks since last RC5 
; instruction has been received (value contained in 'UserInputRC5LastInstruction').
; This counter is used to avoid unsolicited repeat due to the RC5 protocol:
;  - The RC5 protocol generates about 8 frames per second
;  - Typically, the user 'clic' takes about 500ms (4 RC5 frames)
;  - The 'UserInput' timer is sampling RC5 instructions at 50 samples per second
;    (i.e. all RC5 instructions are detected in 'UserInput')
;  - One instruction is repeated only if the 'UserInputRC5LastInstructionDuration' 
;    counter reaches the 'UserInputRC5ClickDuration' constant.
UserInputRC5LastInstructionDuration: .BYTE 1

; UserInputRC5LastKeyPressDuration
; This variable contains the number of 'UserInput' timer ticks with the last RC5 
; key pressed.
; The information is obtained by sampling 'InputPollingRC5KeyPressed' variable. 
; The typical sampling rate ratio is at least 6 (= 125ms/20ms).
; The counter is set to 0:
;  - When 'InputPollingRC5KeyPressed' is reset (i.e. key released).
;  - When a new RC5 key is pressed (i.e. 'UserInputRC5LastInstruction' changed).
UserInputRC5LastKeyPressDuration: .BYTE 1

; UserInputRC5LastInstruction
; This variable contains the last RC5 instruction sampled by the 'UserInput' 
; interrupt. 
UserInputRC5LastInstruction: .BYTE 1

; UserInputRC5DelayedActionDone
; This variable is set when the RC5 delayed action has been done (delayed actions
; are single shot).
UserInputRC5DelayedActionDone: .BYTE 1

; UserInputRemoteModeIRCommand
; This variable is set when the RC5 action has been qualified and translated to
; 'USER_COMMAND' (only when the amplifier is in 'Remote' mode with IR detector
; activated).
; This variable is used by the ACP Notification send function (i.e. the IR command
; to notify via ACP)
UserInputRemoteModeIRCommand: .BYTE 1

; UserInputRemoteModeIRCommandParam
; This variable is set when the RC5 action has been qualified and translated to
; 'USER_COMMAND' (only when the amplifier is in 'Remote' mode with IR detector
; activated).
; This variable is used by the ACP Notification send function (i.e. the parameter
; associated to the IR command notified via ACP)
UserInputRemoteModeIRCommandParam: .BYTE 1


; *** Debouncing variables ***
; These variables are used for debouncing algorythms

; InputPollingLastEncoderState
; This variable contains the state of Encoder Outputs on last Input 
; Polling Timer event
InputPollingLastEncoderState: .BYTE 1

; InputPollingEncoderStateCounter
; This variable counts the number of Input Polling Timer event for which the
; 'InputPollingLastEncoderState' is unchanged.
; It is set with 'InputPollingEncoderDebouncePeriod' each time a change is
; detected for 'InputPollingLastEncoderState'. 
; It is decremented each time 'InputPollingLastEncoderState' is not changed.
; When the value reaches 0, the new encoder step count is notified via the
; 'DebouncedEncoderStep' and 'DebouncedEncoderDir' variables.
InputPollingEncoderStateCounter: .BYTE 1

; InputPollingLastDebouncedEncoderState
; This variable contains the state of Encoder Outputs present on last debounced
; state (i.e. the last time that 'DebouncedEncoderSteps' variable has been updated)
; This variable is necessary to compute the direction of the new step when a new
; debounced state is reached (i.e. step direction is a comparison of LastDebouncedState
; and new DebouncedState)
InputPollingLastDebouncedEncoderState: .BYTE 1

; InputPollingOnOffButtonDebounce
; These variables contain the counter used for period to wait before enabling back the
; ON/OFF button external interrupt (i.e. after one interrupt is entered)
; When interrupt is entered, counter value is set to 'ExternalButtonInterruptTimerTicks'
; and then decreased on periodical 'InputPolling' interrupt. When zero value is reached,
; the external interrupt is enabled back.
InputPollingOnOffButtonDebounceL: .BYTE 1
InputPollingOnOffButtonDebounceH: .BYTE 1

; InputPollingMuteButtonDebounce
; These variables contain the counter used for period to wait before enabling back the
; Mute button external interrupt (i.e. after one interrupt is entered)
; When interrupt is entered, counter value is set to 'ExternalButtonInterruptTimerTicks'
; and then decreased on periodical 'InputPolling' interrupt. When zero value is reached,
; the external interrupt is enabled back.
InputPollingMuteButtonDebounceL: .BYTE 1
InputPollingMuteButtonDebounceH: .BYTE 1

; InputPollingLastRC5Instruction
; This variable contains the last RC5 instruction stored by the 'RemoteControl_DecodeFrame'
; function (= instruction contained in the last fully decoded frame)
; NOTE: 
;  - The InputPolling interrupt function must not change this variable when it process it
;    because the 'RemoteControl_DecodeFrame' cannot set it again in case of a repeat frame.
;  - The InputPolling interrupt must use the 'InputPollingRC5InstructionCount' variable to
;    check if a new instruction has been set by the 'RemoteControl_DecodeFrame' function.
InputPollingLastRC5Instruction: .BYTE 1

;InputPollingRC5InstructionCount
; This variable contains the number of occurences of the RC5 instruction stored in the
; 'InputPollingLastRC5Instruction' variable.
; The InputPolling interrupt set this variable to 0 when it takes into account the value.
; The 'InputPollingRC5InstructionCount' variable is used for debouncing and auto-repeat
; purposes.
InputPollingRC5InstructionCount: .BYTE 1

; InputPollingLastDebouncedRC5Instruction
; This variable contains the last debounced RC5 instruction (i.e. the last RC5 instruction
; waiting on the 'Input Polling' interrupt).
; This variable is not modified if there is no intruction waiting on the 'Input Polling'
; interrupt (i.e. it reset by the 'User Input' interrupt when processed).
; Note: The 'User Input' interrupt is typically 5 times faster than RC5 instruction
; updates (25ms against 114ms).
InputPollingLastDebouncedRC5Instruction: .BYTE 1

; InputPollingRC5KeyPressed
; This variable contains the state of key for the last decoded RC5 instruction
; NOTE: 
;  - The InputPolling interrupt function updates this variable when the end of inter frame
;    elapses before the occurence of an other RC5 frame.
;  - Typically, the 'UserInput' interrupt uses this variable to generate 'click' or
;    deleyed action behaviours.
InputPollingRC5KeyPressed: .BYTE 1

; InputPollingADCLaunchCounter
; This variable counts the number of Input Polling Timer event for triggerring
; the AD conversion.
; It is decremented on timer event and launches the AD conversion when it
; reaches 0. 
; Each time the AD conversion is launched, the 'InputPollingADCLaunchCounter' 
; is set with 'InputPollingADCLaunchPeriod' for a new period.
InputPollingADCLaunchCounter: .BYTE 1

; ADConversionSampleCounter
; This variable counts the number of AD conversions currently summed in the
; 'ADConversionSampleSum' variable.
; When the value reaches 'ADConversionSampleNumber', the average is computed
; and the variable is set for a new collection.
ADConversionSampleCounter: .BYTE 1

; ADConversionSampleSum
; This variable stores the sum of AD conversion values for the current sampling
; period.
; When the sampling is complete, the average is computed and the variable set
; to 0.
; Note: This is a 16 bit variable.
ADConversionSampleSumLow:  .BYTE 1
ADConversionSampleSumHigh: .BYTE 1

; *** Debounce result variables ***
; These variables contain the input states after debouncing (i.e. stable states)
; These variables are periodicaly updated by the Input Polling Timer interrupt
; handler.
; The 'User Input' functions periodicaly read these variables to detect state
; changes (done by User Input Timer interrupt handler).
; NOTE: These variables are shared. They may be accessed under critical section
;       (i.e. interrupts disabled).
;       Typically, the debouncing interrupt set the variable and the 'User Input'
;       interrupt uses and reset the variable.

; DebouncedEncoderSteps
; This variable contains the Encoder 'Steps' computed when the 'DebouncedEncoderState'
; is updated
; A positive value indicates forward steps and a negative value a backward steps
DebouncedEncoderSteps: .BYTE 1

; AveragedADCValue
; This variable contains the average of the last AD conversions
AveragedADCValue: .BYTE 1

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
;  - This constant array is populated during initialization using CSEG constants for 
;    indexed access at runtime (indirect addressing with Z register only possible
;    for access to DSEG = not possible on CSEG).
EncoderDirectionMap: .BYTE 16

; RC5BitDurationCounter
; This variable counts the number of RC5 Frame Timer events while waiting for a bit
; transition.
; This value is compared to a fraction of the theorical (or computed) bit duration
; for looking to bit transition.
; Note: 
;  - A bit is always expressed as a state change (transition). A 0 bit value is
;    a falling transition and a 1 bit value is a rising transition.
;  - This counter is incremented by FAST ticks of RC5 Frame Timer.
RC5BitDurationCounter: .BYTE 1

; RC5BitMeasuredDuration
; This variable contains the number of RC5 Frame Timer events counted for the second
; start bit of the frame.
; This value is used to check the theorical value and eventually replaces the theorical
; value for waiting bit transitions.
RC5BitMeasuredDuration: .BYTE 1

; RC5FrameDurationCounter
; This variable counts the number of RC5 Frame Timer events from the start of the IR
; frame.
; When the counter passes the theorical frame duration, IR Frame detection external
; interrupt is enabled back (i.e. to detect to next frame).
; Note: 
;  - This counter contains the number of millisec elapsed since frame start detection.
;  - This counter is incremented by FAST ticks of IR Frame Timer (with divider).
;  - This counter is also incremented by SLOW ticks of IR Frame Timer (without divider).
;  - This counter contains 0xFF when the end of frame has been reached.
RC5FrameDurationCounter: .BYTE 1

; RC5InterFrameDurationCounter
; This variable counts the number of RC5 Frame Timer events from the end of the IR
; frame.
; When the counter passes the theorical inter frame duration, the 'InputPollingRC5KeyPressed'
; variable is updated (i.e. the key has been released = otherwise the counter has been stopped
; before reaching this value)
; Note: 
;  - This counter contains the number of millisec elapsed since the frame end detection
;    (or its theorical end).
;  - This counter is only incremented by SLOW ticks of IR Frame Timer (without divider).
;  - This counter contains 0xFF when there is no active counting for inter frame duration
;    (i.e. counting not started or end reached)
RC5InterFrameDurationCounter: .BYTE 1

; RC5FrameDurationDivider
; This variable contains the divider value to apply when processing RC5 Frame Timer
; events.
; It also indicates the RC5 Frame Timer mode (period):
;  - If the value is 1, the Timer is working in SLOW mode (period 1000 µs)
;  - If the value is 20, the Timer is working in FAST mode (period 50 µs)
RC5FrameDurationDivider: .BYTE 1

; RC5FrameDurationDividerCount
; This variable counts the number of RC5 Frame Timer events in FAST mode in order to
; increment the 'RC5FrameDurationCounter' value every millisec.
RC5FrameDurationDividerCount: .BYTE 1

; RC5LastToggleBitState
; This variable contains the state of the toggle bit acquired on last RC5 frame.
; The state is 0x00 if bit value is 0, 0x01 if bit value is 1 and 0xFF if value is
; undefined (the undefine state is present only until the first RC5 frame is decoded)
RC5LastToggleBitState: .BYTE 1

; This variable contains the RC5 address of the terminal.
; The varibale is set at start time with the configured value.
RC5TerminalAddress: .BYTE 1

; Map for RC5 instructions
; Map is 'RC5 device instruction code' to 'REMOTECONTROL_INSTRUCTION_xxx' (the RC5 
; device instruction code is the array index).
; This array is populated during initialization	using values stored in persistent 
; storage (EEPROM). Typically, the RC5 device instruction codes have been configured
; by the user (RC5 code learning).
RemoteControlInstructionMap: .BYTE 64

; TCPIP server current state
; Contains the current state of the TCPIP server.
; This state is a compound value of Socket 0 and Socket 1 states.
TCPIPServerState: .BYTE 1

; TCPIP socket 0 current state (Command port)
; Contains the current state of the W5100 socket 0.
; This variable is used in 'TCPIPSocketEvent' interrupt handler to identify the 
; current state/action.
TCPIPSocketState0: .BYTE 1

; TCPIP socket 1 current state (Notification port)
; Contains the current state of the W5100 socket 1.
; This variable is used in 'TCPIPSocketEvent' interrupt handler to identify the 
; current state/action.
TCPIPSocketState1: .BYTE 1

; TCPIP Command Frame
; Contains the last received 'Command Frame' from the master.
; This memory block is shared between the TCPIP driver and the application.
; The shared access is controlled by the 'TCPIPCommandReceived' semaphore.
; The 'TCPIPCommandReceived' and 'TCPIPCommandFrame' variables must be accessed
; in a critical section.
TCPIPCommandFrame: .BYTE 64

; Number of 'Command Frame' bytes already read in 'TCPIPCommandFrame'
; This variable is used when the Command frame is not received in a single packet
; Note: By design the maximum size for Command frame is 255 bytes.
TCPIPCommandFrameReadBytes: .BYTE 1

; Semaphore used to notify the availability of a new 'Command Frame'.
; This variable is shared between TCPIP driver and the application.
; The 'TCPIPCommandReceived' variable must be accessed  in a critical section.
; Values are: 0 = No command, 1 = command received, 2 = processing command
TCPIPCommandReceived: .BYTE 1

; TCPIP Reply Frame
; Used to send a 'Reply Frame' to the master.
; This memory block is populated by the application and send by the TCPIP driver
; (synchroneous operation).
; This buffer is not protected for concurrent access because the master will
; not send a new command until it has not received the whole reply frame.
TCPIPReplyFrame: .BYTE 64

; InputPollingLastACPCommand
; This variable contains the last command received from master via ACP.
; This variable is used to transmit ACP commands from 'InputPolling' to 'UserInput'
; interrupt handler.
; Only 'UserInput' ACP commands are memorized in this variable.
; By design ACP commands are debounced data (i.e. debouncing done on master side).
; The values used in 'InputPollingLastACPCommand' variable are 'USER_COMMAND_xxx' and
; '0xFF' for no command waiting.
; Note:
;  - Only one ACP command by 'UserInput' polling period (typically 25ms) is allowed 
;    (i.e. no command queue for ACP commands)
;  - Command queue is not required because user input ACP commands should have a
;    similar frequency than local 'UserInput' debounced events (i.e. debouncing done
;    on master side).
;  - If 'InputPolling' cannot submit the ACP command because a previous command is
;    pending, the master is informed (so it can send the command again later). 
InputPollingLastACPCommand: .BYTE 1

; InputPollingLastACPCommandParamX
; These variables contains the parameters associated to the last ACP command
InputPollingLastACPCommandParam0: .BYTE 1
InputPollingLastACPCommandParam1: .BYTE 1
InputPollingLastACPCommandParam2: .BYTE 1

; TCPIP Notification Frame
; Contains the next 'Notification Frame' to send to the master.
; This memory block is shared between the TCPIP driver and the application.
; The shared access is controlled by the 'TCPIPNotificationSent' semaphore.
; The 'TCPIPNotificationState' and 'TCPIPNotificationFrame' variables must be accessed
; in a critical section.
TCPIPNotificationFrame: .BYTE 64

; Number of 'Notification Frame' bytes already sent from 'TCPIPNotificationFrame'
; This variable is used when the Notification frame is not sent in a single packet
; Note: By design the maximum size for Notification frame is 255 bytes.
TCPIPNotificationFrameSentBytes: .BYTE 1

; Semaphore used to notify the state of the 'Notification Frame' buffer.
; This variable is shared between TCPIP driver and the application.
; The 'TCPIPNotificationState' variable must be accessed  in a critical section.
; Values are: 
;  - TCPIP_NOTIFICATIONSTATE_BUFFERRELEASED = Buffer available for a new notification
;  - TCPIP_NOTIFICATIONSTATE_BUFFERACQUIRED = Buffer locked by the app (i.e. preparing notif.) 
;  - TCPIP_NOTIFICATIONSTATE_SENDINGBUFFER  = Buffer owned by TCPIP server within send operation
TCPIPNotificationState: .BYTE 1

; Number of successive send errors (typically timeout).
; This variable is shared between TCPIP driver and the application.
; The 'TCPIPFailedNotifications' variable must be accessed  in a critical section.
; Typically the client uses this variable to put itself in a safe state (i.e.
; master gone).
; NOTE: After a send failure, the TCPIP server is automatically restarted.
;       This variable is not reset on TCPIP server start (i.e. the application 
;       needs the count value independently of TCPIP server restart)
TCPIPFailedNotifications: .BYTE 1

; Array for postponed notifications
; When a notification cannot be sent immediatly, a postpone request is inserted in the 
; corresponding entry in this array.
; The 'ACPCheckSendPostponedNotif' function (periodically called) checks this array 
; and try to send the postponed notifications (one at a time).
; NOTE: 
;  - The array size is the total number of notifications
;  - The 'ACP_NOTIFICATION_xxx' identifier is used as index in the array for 
;    retrieving the corresponding notification.
;  - The 'ACPNextPostponedNotifToCheck' is used by the 'ACPCheckSendPostponedNotif'
;    function to iterate the array (i.e. all notifications have the same priority)
ACPPostponedNotifications: .BYTE ACP_NOTIFICATION_NUMBER

; Index in the 'ACPPostponedNotifications' array for iteration by the
; 'ACPCheckSendPostponedNotif' function
; The 'ACPCheckSendPostponedNotif' function send at most one notification.
; The 'ACPNextPostponedNotifToCheck' is used to identify the start index of the
; iteration on next 'ACPCheckSendPostponedNotif' call.
ACPNextPostponedNotifToCheck: .BYTE 1

; Counter for 'Heartbeat' notification period
; The period is defined by the 'ACPHeatbeatNoficationTimerTicks' constant
; This variable is incremented on every timer tick.
; When the variable value reaches 'ACPHeatbeatNoficationTimerTicks', the 'Heatbeat'
; notification is sent.
ACPHeatbeatNoficationTimerCount: .BYTE 1 

; Input level currently displayed on the 'State' screen (7 bit value, maximum is 0x7F)
; When the 'State' screen is displayed, this value is periodically checked with the
; current input level (bCurrentLevel). The 'State' screen is updated if required.
bStateScreenDisplayedLevel: .BYTE 1

; Counter for temperature measurement automaton polling period
; This variable maintains the number of input polling timer ticks counted by interrupt
; handler between two calls of temperature measurement automaton processing function
; NOTE: 
;  - The main loop invokes the temperature measurement automation when this variable
;    reaches 'TemperaturePollingPeriod'
TemperaturePollingCounter: .BYTE 1

; Counter for period between temperature measurements
; The temperature measurement automaton periodically launches temperature conversion
; Once the temperature conversion is completed and value read for a given sensor, the
; automaton uses this counter to wait before launching the conversion on the other sensor
; NOTE: 
;  - This variable is set to 'TemperatureWaitPeriod' when the 'WAITING' state
;    is entered
TemperatureWaitCounter: .BYTE 1

; Sensor used for current temperature measurement
; The temperature measurement automaton alternatively launches the conversion on right 
; and left sensor
; This variable indicates the sensor currently used by the automaton
; The allowed values are 0x00 for right sensor and 0x01 for left sensor
TemperatureCurrentSensor: .BYTE 1

; State of current temperature measurement
; This variable indicates the state of current temperature measurement
; In operational mode, automaton cycles between 'WAITING' -> 'MEASURING' -> 'MEASURED' states
; Values are 'TEMPMEASUREMENT_STATE_xxx'
TemperatureMeasurementState: .BYTE 1

; Semaphore for re-entry of temperature measurement automaton
; This variable is set on entry of 'TemperatureProcess' function in order to protect
; the automaton against re-entry
; This protection is required because most of automaton's execution time is spent outside
; of critical section for performance purpose (i.e. temperature sensor interface requires
; a quite long synchronization periods)
TemperatureProcessEntered: .BYTE 1

; These variables contain the last measured temperatures
; NOTE:
;  - The measured temperature is always positive (i.e. use only the LSB of DS1820 conversion)
;  - The '0' value means 'undefined' (typically not measured yet or negative temperature)
TemperatureRightValue: .BYTE 1    ; Last temperature measured with right sensor
TemperatureLeftValue: .BYTE 1     ; Last temperature measured with left sensor


;******************************************************************************
; Global variables defined in EEPROM memory space (typically persistent data)
;******************************************************************************

.ESEG

; Amplifier RDP control settings
; Note: bit 0 = Balanced, bit 1 = UGS, bit 2 = ByPass
bPersistentRDPControlConfig:     .DB 0b00000001

; Potentiometer level
bPersistentInputLevel:		      .DB 0x00
bPersistentLeftChannelOffset:	   .DB 0x00
bPersistentRightChannelOffset:	.DB 0x00

; LCD contrast and backlight levels
bPersistentLCDContrast:		      .DB 0x10
bPersistentLCDBacklight:  	      .DB 0x10          ; 8mA

; TCP/IP persistent configuration

; Gateway IP address (bytes in lexical order)
; 192.168.1.1
PersistentGatewayIPAddr0:   .DB 0xC0
PersistentGatewayIPAddr1:   .DB 0xA8
PersistentGatewayIPAddr2:   .DB 0x01
PersistentGatewayIPAddr3:   .DB 0x01
 
; Subnet mask (bytes in lexical order)
; 255.255.255.0
PersistentSubnetMask0:   .DB 0xFF
PersistentSubnetMask1:   .DB 0xFF
PersistentSubnetMask2:   .DB 0xFF
PersistentSubnetMask3:   .DB 0x00
 
; Source Hardware Address (bytes in lexical order)
#ifdef BUILD_TARGET_AMPLIFIER_LAB
; Lab. development platform: 00.08.DC.01.02.03
PersistentSourceHardwareAddr0:   .DB 0x00
PersistentSourceHardwareAddr1:   .DB 0x08
PersistentSourceHardwareAddr2:   .DB 0xDC
PersistentSourceHardwareAddr3:   .DB 0x01
PersistentSourceHardwareAddr4:   .DB 0x02
PersistentSourceHardwareAddr5:   .DB 0x03
#endif

#ifdef BUILD_TARGET_AMPLIFIER_UP_RIGHT
; UP mono amplifier right channel: 00.08.DC.04.05.06
PersistentSourceHardwareAddr0:   .DB 0x00
PersistentSourceHardwareAddr1:   .DB 0x08
PersistentSourceHardwareAddr2:   .DB 0xDC
PersistentSourceHardwareAddr3:   .DB 0x04
PersistentSourceHardwareAddr4:   .DB 0x05
PersistentSourceHardwareAddr5:   .DB 0x06
#endif

#ifdef BUILD_TARGET_AMPLIFIER_UP_LEFT
; UP mono amplifier left channel: 00.08.DC.07.08.09
PersistentSourceHardwareAddr0:   .DB 0x00
PersistentSourceHardwareAddr1:   .DB 0x08
PersistentSourceHardwareAddr2:   .DB 0xDC
PersistentSourceHardwareAddr3:   .DB 0x07
PersistentSourceHardwareAddr4:   .DB 0x08
PersistentSourceHardwareAddr5:   .DB 0x09
#endif

; Source IP Address (bytes in lexical order)
; NOTE: By specification (ACC) the IP addresses for amplifiers within a cluster are starting
;       at a base address and are incremented in the following order: 
;        - range0:right channel or stereo
;        - range0:left channel   (if applicable)
;        - [range1:right channel or stereo
;        - range1:left channel   (if applicable)]
;        - [range2:right channel or stereo
;        - range2:left channel   (if applicable)]
#ifdef BUILD_TARGET_AMPLIFIER_LAB
; Lab development platform uses 'AmplifierProt' modified V3.1 hardware (i.e. commands after softstart trigger)
;#define AMPLIFIERPROT_V31_TRIGGER 1

; Lab. development platform: 192.168.1.100 (cluster base)
PersistentSourceIPAddr0:   .DB 0xC0
PersistentSourceIPAddr1:   .DB 0xA8
PersistentSourceIPAddr2:   .DB 0x01
PersistentSourceIPAddr3:   .DB 0x64
#endif

#ifdef BUILD_TARGET_AMPLIFIER_UP_RIGHT
; UP mono amplifier right channel uses modified 'AmplifierProt' V3.1 hardware (i.e. commands after softstart trigger)
;#define AMPLIFIERPROT_V31_TRIGGER 1

; UP mono amplifier right channel: 192.168.1.110 (cluster base)
PersistentSourceIPAddr0:   .DB 0xC0
PersistentSourceIPAddr1:   .DB 0xA8
PersistentSourceIPAddr2:   .DB 0x01
PersistentSourceIPAddr3:   .DB 0x6E
#endif

#ifdef BUILD_TARGET_AMPLIFIER_UP_LEFT
; UP mono amplifier left channel uses modified 'AmplifierProt' V3.1 hardware (i.e. commands after softstart trigger)
;#define AMPLIFIERPROT_V31_TRIGGER 1

; UP mono amplifier right channel: 192.168.1.111
PersistentSourceIPAddr0:   .DB 0xC0
PersistentSourceIPAddr1:   .DB 0xA8
PersistentSourceIPAddr2:   .DB 0x01
PersistentSourceIPAddr3:   .DB 0x6F
#endif

; Source Port0 (Command port)
; 9001 -> 0x2329
PersistentSourcePortLSB0:   .DB 0x23
PersistentSourcePortMSB0:   .DB 0x29

; Source Port1 (Notification port)
; 9002 -> 0x232A
PersistentSourcePortLSB1:   .DB 0x23
PersistentSourcePortMSB1:   .DB 0x2A

