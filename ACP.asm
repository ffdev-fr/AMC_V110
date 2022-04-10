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
; File:	ACP.asm
;
; Author: F.Fargon
;
; Purpose: 
;  - Amplifier Control Protocol (ACP) functions
;  - Function for processing received 'TCPIPCommandFrame' frames
;  - Function for sending notifications
;  - Protocol implementation (frames parsing and command dispatch)
; 
; NOTES:
;  - The function for processing the received 'TCPIPCommandFrame' frames must
;    be periodically invoked (typically called by the 'InputPolling' interrupt 
;    handler).
;  - For commands identified as 'UserInput' commands, the standard debouncing
;    mechanism is used (i.e. the command is stored for a later processing in
;    the 'UserInput' interrupt handler).
;  - The ACP functions access TCPIP server shared variables in a critical 
;    section ('TCPIPCommandReceived', 'TCPIPCommandFrame', TCPIPNotificationFrame,
;    TCPIPNotificationState and 'TCPIPFailedNotifications' variables).
;******************************************************************************

;******************************************************************************
; ACP PROTOCOL SPECIFICATION (V1.0)
; 
; 1- Description
; ---------------
; The 'ACP' protocol is a synchroneous master/slave protocol for commands:
;  - The master send 'Command' to the slave.
;  - The slave processes the command and send a 'Reply' to the master.
;  - The master is not allowed to send a new command until it has not received
;    the reply for the pending command.
;  
; The 'ACP' protocol supports asynchroneous slave notifications:
;  - At anytime the slave can send a 'Notification' to the master.
;  - The master does not reply to a notification.
;  - If the notification cannot be sent to the master (typically link broken),
;    a 'failed notification' counter is incremented.
; 
; 2- Frames
; ---------
; Command, reply and notification sent between master and slave are contained
; in a fixed size data block called 'Frame'.
; The frame format is the following:
;  - 'Protocol identifier' (4 bytes)
;    Fixed value used as protocol frame signature. The value is 'ACP:'
;  - 'Protocol version' (1 byte)
;    Contains the protocol version number. Minor version number is in the 4 low
;    significant bits and major version number in the 4 most significant bits 
;    (0x10 for V1.0).
;  - 'Type of frame' (1 byte)
;    Indicates the nature of the frame (Command, Reply or Notication).
;  - 'Frame data' (variable size)
;    Contains frame data according to the associated frame type.
; 
; 3- Commands
; -----------
; There are two categories for commands:
;  - The 'UserInput' commands are commands from user also available from other
;    user interfaces (button, encoder, IR).
;  - The 'Master' commands are programatic commands send for system operations.
; 
; The following 'UserInput' commands are available:
;  - 'OnOff'
;    This command asks to toggle the amplifier power state.
;    The possible replies to this command are:
;      .. 'OK'  = The command has been submitted as a 'UserInput' and will be 
;                 processed on next 'UserInput' timer interrupt.
;      .. 'NOK' = An error occurs for the command.
;    Note: A notification will be sent when the amplifier actual 'power' state
;          changes in response to this command.
;  - 'Mute'
;    This command asks to mute/unmute (toggle) the amplifier on speaker outputs.
;    The possible replies to this command are:
;      .. 'OK'  = The command has been submitted as a 'UserInput' and will be 
;                 processed on next 'UserInput' timer interrupt.
;      .. 'NOK' = An error occurs for the command.
;    Note: A notification will be sent when the amplifier actual 'mute' state
;          changes in response to this command.
;  - 'ChangeVolume'
;    This command asks for changing output volume of a specified value (increment
;    or decrement).
;    The possible replies to this command are:
;      .. 'OK'  = The command has been submitted as a 'UserInput' and will be 
;                 processed on next 'UserInput' timer interrupt.
;      .. 'NOK' = An error occurs for the command.
; 
;  - 'ChangeBacklight'
; 
;  - 'ChangeContrast'
; 
; The following 'Master' commands are available:
;  - 'Configure'
;    The master transmit the configuration parameters to the AMC.
;    Parameters are:
;      .. 'IRDetector'  = Indicates if the IRDetector must be enabled.
;                         If IR activated, the AMC transmit to ACC via ACP protocol
;                         the user commands received from IR Remote Control.
;      .. 'ChannelName' = Name to display on the LCD
;    The possible replies to this command are:
;      .. 'OK'  = The command has been processed.
;      .. 'NOK' = An error occurs for the command.
; 
; 4- Replies
; ----------
; The reply contains the following data:
;  - 'ResultCode' = Indicates the result of the operation.
;                   Values are OK and NOK.
;  - 'StatusCode' = Optional data typically used to indicate the reason for
;                   failure.
;  - 'Data'       = Requested information in case of 'informative' commands.
; 
; 5- Notifications
; ----------------
; There are two categories of notification:
;  - The 'heartbeat' notification is periodically sent to inform the master 
;    that slave is reacheable. The 'heartbeat' notification contains the 
;    current slave state. 
;    This notification is also used to check that master is still alive. If the
;    notification cannot be sent, the ACP heartbeat failed flag is set and the
;    ACP client can put itself in a safe state.
;  - The 'event' notifications are sent to inform the master that a specific
;    event has occured (ouput level changed, DC protection...). Typically these
;    events are related to the result of a delayed command (for example the
;    'change volume' command does not change the volume immediatly due to the
;    debouncing algorithm).
;****************************************************************************** 


;******************************************************************************
; ACP API functions 
;****************************************************************************** 
  
; Function for processing of ACP commands received from TCP/IP server.
;
; This function checks if a new command is received and process it as follows:
;  - Check if 'TCPIPCommandReceived' shared variable is set (in a critical section).
;  - If set, a new command is available.
;  - Check if 'TCPIPCommandFrame' is valid.
;  - Decode 'TCPIPCommandFrame' command.
;  - Process 'TCPIPCommandFrame' command.
;  - Send reply.
;
; Notes:
;  - This function is called periodically by the 'InputPolling' interrupt.
;  - A new command cannot be received since the reply has not been sent (i.e.
;    only initial check on 'TCPIPCommandReceived' shared variable done in 
;    critical section = if 'TCPIPCommandReceived' is set, the TCP/IP server will
;    not access shared variables until the reply is sent). 
ACPCheckProcessCommand:

   push  r16
   push  r17
   push  r18
   push  XL
   push  XH

   ; 1- Process command only if the TCPIP server is started and the client connected
   ENTER_CRITICAL_SECTION                    ; State checks are made in critical section
   lds   r16, TCPIPServerState
   cpi   r16, TCPIP_SERVERSTATE_CONNECTED
   breq  ACPCheckProcessCommand_CheckNewCommand
   LEAVE_CRITICAL_SECTION
   jmp   ACPCheckProcessCommand_Exit

ACPCheckProcessCommand_CheckNewCommand:
   ; 2- Check for a new command received
   lds   r16, TCPIPCommandReceived
   LEAVE_CRITICAL_SECTION
   cpi   r16, 0x01  
   breq  ACPCheckProcessCommand_CommandWaiting
   jmp   ACPCheckProcessCommand_Exit
   
ACPCheckProcessCommand_CommandWaiting:
   ; New command received, update 'TCPIPCommandReceived' shared variable
   ; (state = processing) 
   ldi   r16, 0x02
   ENTER_CRITICAL_SECTION
   sts   TCPIPCommandReceived, r16
   LEAVE_CRITICAL_SECTION

   ; 3- Validate the 'TCPIPCommandFrame' (i.e. signature, version, command)
	ldi   XL, LOW(TCPIPCommandFrame)
	ldi   XH, HIGH(TCPIPCommandFrame)
   ld    r16, X+

; Debug - Display first Byte received
;sts  PORTL, r16
; End debug


   cpi   r16, ACP_FRAME_HEADER0                 ; Check frame identifier
   brne  ACPCheckProcessCommand_InvalidFrame
   ld    r16, X+

; Debug - Display second Byte received
;sts  PORTL, r16
; End debug

   cpi   r16, ACP_FRAME_HEADER1         
   brne  ACPCheckProcessCommand_InvalidFrame
   ld    r16, X+

; Debug - Display 3rd Byte received
;sts  PORTL, r16
; End debug

   cpi   r16, ACP_FRAME_HEADER2         
   brne  ACPCheckProcessCommand_InvalidFrame
   ld    r16, X+

; Debug - Display 4th Byte received
;sts  PORTL, r16
; End debug

   cpi   r16, ACP_FRAME_HEADER3         
   brne  ACPCheckProcessCommand_InvalidFrame
   ld    r16, X+

; Debug - Display 5th Byte received
;sts  PORTL, r16
; End debug

   cpi   r16, ACP_FRAME_VERSION                         ; Check protocol version (V1.0)         
   brne  ACPCheckProcessCommand_InvalidVersion
   ld    r16, X+

; Debug - Display 6th Byte received
;sts  PORTL, r16
; End debug

   cpi   r16, ACP_FRAME_COMMAND                 ; Should be a 'Command' frame
   brne  ACPCheckProcessCommand_NotCommandFrame
   ld    r16, X+       ; Command frame validated
                       ; r16 contains the command code 'ACP_COMMAND_xxx'


; Debug - leds 0 if frame is valid
;ldi  r18, 0b00000001
;sts  PORTL, r18
; End debug

   ; Check if command code is in the valid range
   cpi   r16, ACP_COMMAND_LAST + 1
   brlo  ACPCheckProcessCommand_DoProcess

   ; Unknown command (not in valid range)
   ldi   r16, ACP_REPLY_RETURN_NOK
   ldi   r17, ACP_REPLY_STATUS_INVALIDCOMMAND
   jmp   ACPCheckProcessCommand_SendReply

ACPCheckProcessCommand_InvalidFrame:
   ; Frame header is invalid, send a NOK reply with 'InvalidFrame' status
   ; Note: A reply is sent to invalid frame to reset the ACP synchroneous
   ;       automaton (i.e. to be able to receive next command)
   ldi   r16, ACP_REPLY_RETURN_NOK
   ldi   r17, ACP_REPLY_STATUS_INVALIDFRAME
   jmp   ACPCheckProcessCommand_SendReply

ACPCheckProcessCommand_InvalidVersion:
   ; ACP protocol version not supported, send a NOK reply with 'InvalidVersion' status
   ldi   r16, ACP_REPLY_RETURN_NOK
   ldi   r17, ACP_REPLY_STATUS_INVALIDVERSION
   jmp   ACPCheckProcessCommand_SendReply

ACPCheckProcessCommand_NotCommandFrame:
   ; Master can send only 'Command' frame, send a NOK reply with 'NotCommand' status
   ldi   r16, ACP_REPLY_RETURN_NOK
   ldi   r17, ACP_REPLY_STATUS_NOTCOMMAND
   jmp   ACPCheckProcessCommand_SendReply

   ; 4- Process the command (code in r16) 
ACPCheckProcessCommand_DoProcess:

; Debug - leds 0 if do process
;ldi  r18, 0b00000001
;sts  PORTL, r18
; End debug

   ; Load command parameters in r17 and r18
   ld    r17, X+     
   ld    r18, X+     
   
   ; Switch to specified command by indirect jump
	ldi	ZH, HIGH(ACPCheckProcessCommand_DispatchArray)
	ldi	ZL, LOW(ACPCheckProcessCommand_DispatchArray)
	lsl	r16		; Command index
	adc	ZL, r16
	brcc 	ACPCheckProcessCommand_DoProcessJump	
	inc	ZH

ACPCheckProcessCommand_DoProcessJump:
	ijmp

ACPCheckProcessCommand_DispatchArray:
   ; Dispatch array for indirect jump to command processing routine
   ; IMPORTANT: Must be updated when a new command is added in ACP protocol
	jmp 	ACPCheckProcessCommand_ExecuteOnOff
	jmp 	ACPCheckProcessCommand_ExecuteMute
	jmp 	ACPCheckProcessCommand_ExecuteChangeVolume
	jmp 	ACPCheckProcessCommand_ExecuteChangeBalance
	jmp 	ACPCheckProcessCommand_ExecuteChangeBacklight
	jmp 	ACPCheckProcessCommand_ExecuteChangeContrast
	jmp 	ACPCheckProcessCommand_ExecuteNotImplemented     ; Reserved command 0
	jmp 	ACPCheckProcessCommand_ExecuteNotImplemented     ; Reserved command 1
	jmp 	ACPCheckProcessCommand_ExecuteNotImplemented     ; Reserved command 2
	jmp 	ACPCheckProcessCommand_ExecuteNotImplemented     ; Reserved command 3
	jmp 	ACPCheckProcessCommand_ExecutePing
	jmp 	ACPCheckProcessCommand_ExecuteConfigure
   ; End of command dispatch array

ACPCheckProcessCommand_ExecuteOnOff:
   ; Submit a 'OnOff' command to the 'UserInput' asynchroneous processing
   ; In current version, only one entry in 'UserInput' command queue shared variable
   ENTER_CRITICAL_SECTION
   lds   r16, InputPollingLastACPCommand   ; 'UserInput' command queue shared variable 
   LEAVE_CRITICAL_SECTION
   cpi   r16, 0xFF                ; Check if command can be inserted in command queue
   brne  ACPCheckProcessCommand_ExecuteOnOffError
   ENTER_CRITICAL_SECTION
   ldi   r16, USER_COMMAND_ONOFF          ; Set 'InputPollingLastACPCommand' with 'USER_COMMAND_'
                                          ; No parameters for this command
   sts   InputPollingLastACPCommand, r16 
   LEAVE_CRITICAL_SECTION
   ldi   r16, ACP_REPLY_RETURN_OK         ; Reply OK
   ldi   r17, ACP_REPLY_STATUS_NONE
   jmp   ACPCheckProcessCommand_SendReply

ACPCheckProcessCommand_ExecuteOnOffError:
   ldi   r16, ACP_REPLY_RETURN_NOK                 ; No room to submit command
   ldi   r17, ACP_REPLY_STATUS_COMMANDQUEUEFULL
   jmp   ACPCheckProcessCommand_SendReply

ACPCheckProcessCommand_ExecuteMute:
   ; Submit a 'OnOff' command to the 'UserInput' asynchroneous processing
   ; In current version, only one entry in 'UserInput' command queue shared variable
   ENTER_CRITICAL_SECTION
   lds   r16, InputPollingLastACPCommand   ; 'UserInput' command queue shared variable 
   LEAVE_CRITICAL_SECTION
   cpi   r16, 0xFF                ; Check if command can be inserted in command queue
   brne  ACPCheckProcessCommand_ExecuteMuteError
   ENTER_CRITICAL_SECTION
   ldi   r16, USER_COMMAND_MUTE           ; Set 'InputPollingLastACPCommand' with 'USER_COMMAND_'
                                          ; No parameters for this command
   sts   InputPollingLastACPCommand, r16 
   LEAVE_CRITICAL_SECTION
   ldi   r16, ACP_REPLY_RETURN_OK         ; Reply OK
   ldi   r17, ACP_REPLY_STATUS_NONE
   jmp   ACPCheckProcessCommand_SendReply

ACPCheckProcessCommand_ExecuteMuteError:
   ldi   r16, ACP_REPLY_RETURN_NOK                 ; No room to submit command
   ldi   r17, ACP_REPLY_STATUS_COMMANDQUEUEFULL
   jmp   ACPCheckProcessCommand_SendReply

ACPCheckProcessCommand_ExecuteChangeVolume:

; Debug - leds 0 if ExecuteChangeVolume
;ldi  r18, 0b00000001
;sts  PORTL, r18
; End debug

   ; Submit a 'OnOff' command to the 'UserInput' asynchroneous processing
   ; In current version, only one entry in 'UserInput' command queue shared variable
   ENTER_CRITICAL_SECTION
   lds   r16, InputPollingLastACPCommand   ; 'UserInput' command queue shared variable 

; Debug - display InputPollingLastACPCommand
;sts  PORTL, r16
; End debug


   LEAVE_CRITICAL_SECTION
   cpi   r16, 0xFF                ; Check if command can be inserted in command queue
   brne  ACPCheckProcessCommand_ExecuteChangeVolumeError
   ENTER_CRITICAL_SECTION
   ldi   r16, USER_COMMAND_CHANGEVOLUME   ; Set 'InputPollingLastACPCommand' with 'USER_COMMAND_'
   sts   InputPollingLastACPCommand, r16 
   sts   InputPollingLastACPCommandParam0, r17   ; Param0 contains the volume change to apply
   LEAVE_CRITICAL_SECTION
   ldi   r16, ACP_REPLY_RETURN_OK         ; Reply OK
   ldi   r17, ACP_REPLY_STATUS_NONE

; Debug - leds 0 if ExecuteChangeVolume scheduled
;ldi  r18, 0b00000001
;sts  PORTL, r18
; End debug

   jmp   ACPCheckProcessCommand_SendReply

ACPCheckProcessCommand_ExecuteChangeVolumeError:
   ldi   r16, ACP_REPLY_RETURN_NOK                 ; No room to submit command
   ldi   r17, ACP_REPLY_STATUS_COMMANDQUEUEFULL
   jmp   ACPCheckProcessCommand_SendReply

ACPCheckProcessCommand_ExecuteChangeBalance:
   ; Submit a 'OnOff' command to the 'UserInput' asynchroneous processing
   ; In current version, only one entry in 'UserInput' command queue shared variable
   ENTER_CRITICAL_SECTION
   lds   r16, InputPollingLastACPCommand   ; 'UserInput' command queue shared variable 
   LEAVE_CRITICAL_SECTION
   cpi   r16, 0xFF                ; Check if command can be inserted in command queue
   brne  ACPCheckProcessCommand_ExecuteChangeBalanceError
   ENTER_CRITICAL_SECTION
   ldi   r16, USER_COMMAND_CHANGEBALANCE         ; Set 'InputPollingLastACPCommand' with 'USER_COMMAND_'
   sts   InputPollingLastACPCommand, r16 
   sts   InputPollingLastACPCommandParam0, r17   ; Param0 contains the balance change to apply
   LEAVE_CRITICAL_SECTION
   ldi   r16, ACP_REPLY_RETURN_OK         ; Reply OK
   ldi   r17, ACP_REPLY_STATUS_NONE
   jmp   ACPCheckProcessCommand_SendReply

ACPCheckProcessCommand_ExecuteChangeBalanceError:
   ldi   r16, ACP_REPLY_RETURN_NOK                 ; No room to submit command
   ldi   r17, ACP_REPLY_STATUS_COMMANDQUEUEFULL
   jmp   ACPCheckProcessCommand_SendReply

ACPCheckProcessCommand_ExecuteChangeBacklight:

   ; Submit a 'ChangeBacklight' command to the 'UserInput' asynchroneous processing
   ; In current version, only one entry in 'UserInput' command queue shared variable
   ENTER_CRITICAL_SECTION
   lds   r16, InputPollingLastACPCommand   ; 'UserInput' command queue shared variable 
   LEAVE_CRITICAL_SECTION

   cpi   r16, 0xFF                ; Check if command can be inserted in command queue
   brne  ACPCheckProcessCommand_ExecuteChangeBacklightError

   ENTER_CRITICAL_SECTION
   ldi   r16, USER_COMMAND_CHANGEBACKLIGHT   ; Set 'InputPollingLastACPCommand' with 'USER_COMMAND_'
   sts   InputPollingLastACPCommand, r16 
   sts   InputPollingLastACPCommandParam0, r17   ; Param0 contains the volume change to apply
   LEAVE_CRITICAL_SECTION

   ldi   r16, ACP_REPLY_RETURN_OK         ; Reply OK
   ldi   r17, ACP_REPLY_STATUS_NONE
   jmp   ACPCheckProcessCommand_SendReply

ACPCheckProcessCommand_ExecuteChangeBacklightError:
   ldi   r16, ACP_REPLY_RETURN_NOK                 ; No room to submit command
   ldi   r17, ACP_REPLY_STATUS_COMMANDQUEUEFULL
   jmp   ACPCheckProcessCommand_SendReply

ACPCheckProcessCommand_ExecuteChangeContrast:

   ; Submit a 'ChangeContrast' command to the 'UserInput' asynchroneous processing
   ; In current version, only one entry in 'UserInput' command queue shared variable
   ENTER_CRITICAL_SECTION
   lds   r16, InputPollingLastACPCommand   ; 'UserInput' command queue shared variable 
   LEAVE_CRITICAL_SECTION

   cpi   r16, 0xFF                ; Check if command can be inserted in command queue
   brne  ACPCheckProcessCommand_ExecuteChangeContrastError

   ENTER_CRITICAL_SECTION
   ldi   r16, USER_COMMAND_CHANGECONTRAST        ; Set 'InputPollingLastACPCommand' with 'USER_COMMAND_'
   sts   InputPollingLastACPCommand, r16 
   sts   InputPollingLastACPCommandParam0, r17   ; Param0 contains the volume change to apply
   LEAVE_CRITICAL_SECTION

   ldi   r16, ACP_REPLY_RETURN_OK         ; Reply OK
   ldi   r17, ACP_REPLY_STATUS_NONE
   jmp   ACPCheckProcessCommand_SendReply

ACPCheckProcessCommand_ExecuteChangeContrastError:
   ldi   r16, ACP_REPLY_RETURN_NOK                 ; No room to submit command
   ldi   r17, ACP_REPLY_STATUS_COMMANDQUEUEFULL
   jmp   ACPCheckProcessCommand_SendReply

ACPCheckProcessCommand_ExecuteNotImplemented:
   ; Reserved room for user commands (no implementation)
   ldi   r16, ACP_REPLY_RETURN_NOK                 ; Not implemented command
   ldi   r17, ACP_REPLY_STATUS_INVALIDCOMMAND
   jmp   ACPCheckProcessCommand_SendReply


ACPCheckProcessCommand_ExecutePing:
   ; Heartbeat command ('Master' command)
   ; The master is only waiting for a reply to confirm that slave is still alive
   ldi   r16, ACP_REPLY_RETURN_OK
   ldi   r17, ACP_REPLY_STATUS_NONE
   jmp   ACPCheckProcessCommand_SendReply

ACPCheckProcessCommand_ExecuteConfigure:
   ; Configure command ('Master' command)
   ; The master transmits the configuration parameters

   ; Activate the IR detection if asked (and not already activated)
   ; Note: It is not possible to deactivate IR detection when activated
   cpi   r17, 0x01  
   brne  ACPCheckProcessCommand_ConfigureName
   lds   r16, bRemoteModeIRDetector
   cpi   r16, 0x01  
   breq  ACPCheckProcessCommand_ConfigureName

   ; IR must be activated
   ldi   r16, 0x01
   sts   bRemoteModeIRDetector, r16
   lds   r16, bExternalInterruptMask        ; Enable Int 5 (IR)
   ori   r16, 0b00100000
   sts   bExternalInterruptMask, r16
	out 	EIMSK, r16

ACPCheckProcessCommand_ConfigureName:
   ; Copy display name of the channel from ACPFrame
   ; Name length is 20 characters, name is located at offset 8 in the ACPFrame
	ldi   XL, LOW(TCPIPCommandFrame)
	ldi   XH, HIGH(TCPIPCommandFrame)
   ldi   r16, 0x08
   add   XL, r16                               
   ldi   r16, 0x00
   adc   XH, r16
	ldi   YL, LOW(AmplifierDisplayName)
	ldi   YH, HIGH(AmplifierDisplayName)

   ldi   r17, 20
ACPCheckProcessCommand_CopyNameLoop:
   ld    r16, X+
	st    Y+, r16
   dec   r17          ; Next char
   brne  ACPCheckProcessCommand_CopyNameLoop

   ; Update display (line 1 only)
   ldi   r17, 0b00000001
   call  DisplayStateScreen

   ; Command done
   ldi   r16, ACP_REPLY_RETURN_OK
   ldi   r17, ACP_REPLY_STATUS_NONE
   jmp   ACPCheckProcessCommand_SendReply


   ; 5- Send reply

ACPCheckProcessCommand_SendReply:
   ; Note:
   ;  - r16 contains the return code (ACP_REPLY_RETURN_xx)
   ;  - r17 contains the status code (ACP_REPLY_STATUS_xx)

   ; Prepare data in reply buffer
   ; Note: Reply buffer is not protected for concurrent access because the master will
   ;       not send a new command until it has not received the whole reply frame.
   ldi   XL, LOW(TCPIPReplyFrame)        ; Reply frame buffer address
  	ldi   XH, HIGH(TCPIPReplyFrame)
   ldi   r18, ACP_FRAME_OFFSET_DATA    ; Beginning of data (i.e. header never modified, skip it)
   add   XL, r18
   ldi   r18, 0x00
   adc   XH, r18
   st    X+, r16                       ; Set reply data (return and status codes)
   st    X, r17
   call  TCPIPSendReply

; Debug clean cmd frame buffer if processed (to see offset error in WIZ read)
	ldi   XL, LOW(TCPIPCommandFrame)
	ldi   XH, HIGH(TCPIPCommandFrame)
   ldi   r17, 0x40
   ldi   r16, 0x00
ACPCheckProcessCommand_DbgCleanFrameBuffer:
   st    X+, r16
   dec   r17
   brne  ACPCheckProcessCommand_DbgCleanFrameBuffer
; End debug


ACPCheckProcessCommand_Exit:
   pop   XH
   pop   XL
   pop   r18
   pop   r17
   pop   r16
   ret


; Function to send an ACP notification with the TCP/IP server.
;
; This function behaves as follows:
;  - The function checks the TCPIP server state to know if the notification must and
;    can be sent (if no link with master the notifcation must no be sent, if a current
;    notification send operation is pending the notification cannot be sent) 
;  - The 'TCPIPNotificationFrame' shared buffer is locked.
;  - The notification is prepared in the 'TCPIPNotificationFrame' shared buffer.
;    The notification preparation is made according to the ACP protocol specification.
;    The function directly access the application data required for notification
;    preparation (shared access if required).
;  - The 'TCPIPSendNotification' function in invoked to sent the notification frame.
;  - If the notification cannot be sent due to a pending notification send operation,
;    the notification request in inserted in the 'ACPPostponedNotifications' array 
;    in order to be sent later.
;    The 'ACPCheckSendPostponedNotif' function must be periodically called to 
;    allow the processing of postponed notifications.
;    
; The function arguments are the followings:
;  - Register r16 = Notification code ('ACP_NOTIFICATION_xxx')
; 
; The function returns the result in r16 register:
;  - 0x01 = The notification send has been transmitted to the TCP/IP server
;  - 0x00 = The notification cannot be sent (typically TCP/IP server busy or disconnected)
;           Note: The notification has been postponed only in case of a busy error (i.e.
;                 notification lost if server is disconnected)
; 
; Notes:
;  - The direct access to application data by this function for notification preparation
;    is necessary for the postpone algorithm (i.e. scheduled action array rather than
;    a command queue).
;  - The TCP/IP channel used for notification is using a TCP/IP server automaton.
;    In other words, even for notifications the master is a TCP/IP client and the
;    slave a TCP/IP server.
;  - From the ACP point of view, the notification send is synchroneous.
;    When this function returns, the 'TCPIPNotificationFrame' is ready for an other
;    notification (i.e. the data have been transfered to the socket buffer, the 
;    function does not wait for the result of socket send operation).
;    If the socket send fails later, the 'TCPIPFailedNotifications' shared variable
;    will be incremented.
ACPSendNotification:

   push  XL
   push  XH
   push  ZL
   push  ZH

   ; 1- Check if the notification must be sent
   ;    The notification must be sent only if the TCPIP server is started and the
   ;    client is connected
   ENTER_CRITICAL_SECTION                  ; State checks are made in critical section
   lds   r23, TCPIPServerState
   cpi   r23, TCPIP_SERVERSTATE_CONNECTED
   breq  ACPSendNotification_AcquireBuffer
   LEAVE_CRITICAL_SECTION
   ldi   r16, 0x00                  ; Notification not sent
   jmp   ACPSendNotification_Exit

ACPSendNotification_AcquireBuffer:
   ; 2- Acquire the notification buffer
   ;    The notification buffer may be currently used by an other 'SendNotification'
   ;    operation
   lds   r23, TCPIPNotificationState
   cpi   r23, TCPIP_NOTIFICATIONSTATE_BUFFERRELEASED
   breq  ACPSendNotification_BufferAvailable

   ; There is a pending 'SendNotification' operation
   ; Postpone the notification
   ldi   XL, LOW(ACPPostponedNotifications)    ; Postponed notifications array address
  	ldi   XH, HIGH(ACPPostponedNotifications)
   add   XL, r16                               ; Entry for the notification to postpone
   ldi   r23, 0x00
   adc   XH, r23
   ldi   r23, 0x01
   st    X, r23              ; Postpone request for the notification registered in the array
   LEAVE_CRITICAL_SECTION
   ldi   r16, 0x00                  ; Notification not sent (postponed)
   jmp   ACPSendNotification_Exit
   
ACPSendNotification_BufferAvailable:
   ; Lock the buffer
   ldi   r23, TCPIP_NOTIFICATIONSTATE_BUFFERACQUIRED
   sts   TCPIPNotificationState, r23
   LEAVE_CRITICAL_SECTION                          ; Exit critical section

   ; 3- Build the notification in the buffer according to the notification code
   ;    Switch to notification preparation routine by indirect jump
	ldi	ZH, HIGH(ACPSendNotification_DispatchArray)
	ldi	ZL, LOW(ACPSendNotification_DispatchArray)
   push  r16                                         ; Save notification code
	lsl	r16		                                   ; Notification index
	adc	ZL, r16
   pop   r16
	brcc 	ACPSendNotification_DoProcessJump	
	inc	ZH

ACPSendNotification_DoProcessJump:
   ldi   XL, LOW(TCPIPNotificationFrame)    ; Notification frame buffer address
  	ldi   XH, HIGH(TCPIPNotificationFrame)
   ldi   r23, ACP_FRAME_OFFSET_DATA         ; Beginning of data (i.e. header never modified, skip it)
   add   XL, r23
   ldi   r23, 0x00
   adc   XH, r23
   st    X+, r16                       ; The first data byte is the Notification code
	ijmp                                ; Indirect jump

ACPSendNotification_DispatchArray:
   ; Dispatch array for indirect jump to notification processing routine
   ; IMPORTANT: Must be updated when a new notification is added in ACP protocol
	jmp 	ACPSendNotification_PrepareHeartbeat
	jmp 	ACPSendNotification_PrepareVolumeChanged
	jmp 	ACPSendNotification_PrepareMuteChanged
	jmp 	ACPSendNotification_PrepareOnOffChanged
	jmp 	ACPSendNotification_PrepareErrorChanged
   jmp   ACPSendNotification_PrepareIRUserCommand
   ; End of notification dispatch array

ACPSendNotification_PrepareHeartbeat:
   ; ACP_NOTIFICATION_HEARTBEAT notification
   ; Parameters are:
   ;  - AmplifierPower = Power state of amplifier stage (0 = Off, 1 = PoweringUp, 2 = On)
   ;  - OutputState    = Output mute state (0 = Muted, 1 = Unmuted)
   ;  - CurrentLevel   = Current output level (0 = -96dB, 127 = 0dB, step = 0.75dB)
   lds   r16, bAmplifierPowerState
   st    X+, r16
   lds   r16, bAmplifierOutputState
   st    X+, r16
   lds   r16, bCurrentLevel
   st    X+, r16
   jmp   ACPSendNotification_SendBuffer

ACPSendNotification_PrepareVolumeChanged:
   ; ACP_NOTIFICATION_VOLUMECHANGED notification
   ; Parameters are:
   ;  - CurrentLevel = Current output level (0 = -96dB, 127 = 0dB, step = 0.75dB)
   lds   r16, bCurrentLevel
   st    X+, r16
   jmp   ACPSendNotification_SendBuffer

ACPSendNotification_PrepareMuteChanged:
   ; ACP_NOTIFICATION_MUTECHANGED notification
   ; Parameters are:
   ;  - OutputState = Output mute state (0 = Muted, 1 = Unmuted)
   lds   r16, bAmplifierOutputState
   st    X+, r16
   jmp   ACPSendNotification_SendBuffer

ACPSendNotification_PrepareOnOffChanged:
   ; ACP_NOTIFICATION_ONOFFCHANGED notification
   ; Parameters are:
   ;  - AmplifierPower = Power state of amplifier stage (0 = Off, 1 = PoweringUp, 2 = On)
   lds   r16, bAmplifierPowerState
   st    X+, r16
   jmp   ACPSendNotification_SendBuffer

ACPSendNotification_PrepareErrorChanged:

   jmp   ACPSendNotification_SendBuffer

ACPSendNotification_PrepareIRUserCommand:
   ; ACP_NOTIFICATION_IRUSERCOMMAND
   ; Parameters are:
   ;  - UserCommand  = The user command qualified by 'UserInput' interrupt ('USER_COMMAND_xxx')
   ;  - CommandParam = Optional parameter (depends on the comand)
   lds   r16, UserInputRemoteModeIRCommand
   st    X+, r16
   lds   r16, UserInputRemoteModeIRCommandParam
   st    X+, r16
   jmp   ACPSendNotification_SendBuffer


ACPSendNotification_SendBuffer:
   ; 4- Send the notification frame buffer
   call  TCPIPSendNotification

   ; The notification buffer must be released in case of fatal error in TCPIP server.
   ; Typically this case is because server has been disconnected during the send operation.
   ; In this case the notification is lost (not postponed):
   ;  - The AMC will enter the safe state soon (due to the lost of the master connection)
   ;  - When the master will connect again, the AMC starts a new life cycle 
   cpi   r16, 0x01
   breq  ACPSendNotification_Exit

   ENTER_CRITICAL_SECTION                ; TCPIP send failure, release notification buffer
   ldi   r23, TCPIP_NOTIFICATIONSTATE_BUFFERRELEASED
   sts   TCPIPNotificationState, r23
   LEAVE_CRITICAL_SECTION                                     

ACPSendNotification_Exit:

   pop   ZH
   pop   Zl
   pop   XH
   pop   Xl
   ret

; Function to send the postponed ACP notification with the TCP/IP server.
;
; This function behaves as follows:
;  - The function iterates the 'ACPPostponedNotifications' array and detects the first
;    notification to postpone (if any).
;  - The iteration starts 'ACPNextPostponedNotifToCheck' at array index.
;  - If a postponed notification must be send, the function calls 'ACPSendNotification'.
;
; The function returns the result in r16:
;  - 0x00 = No notification to postpone registered in the array
;  - 0x01 = The function have tried to send a postponed notification
; 
; Notes:
;  - This function is called periodically by the 'InputPollingTimer' interrupt (typical
;    period is 7.5ms).
;  - The function try to send only one notification.
ACPCheckSendPostponedNotif:

   push  r17
   push  r18
   push  XL
   push  XH

   ; Postponed notifications can be sent only if the TCPIP server is started and the 
   ; client connected
   ENTER_CRITICAL_SECTION                ; State checks are made in critical section
   lds   r16, TCPIPServerState
   LEAVE_CRITICAL_SECTION
   cpi   r16, TCPIP_SERVERSTATE_CONNECTED
   breq  ACPCheckSendPostponedNotif_InitArrayAccess
   ldi   r17, 0x00                         ; Return value, no send has been tried
   jmp   ACPCheckSendPostponedNotif_Exit

ACPCheckSendPostponedNotif_InitArrayAccess:
   ; Access to the first entry to check in 'ACPPostponedNotifications' array
   ldi   XL, LOW(ACPPostponedNotifications)    ; Postponed notifications array address
  	ldi   XH, HIGH(ACPPostponedNotifications)
   lds   r18, ACPNextPostponedNotifToCheck     ; Entry for the first notification to check
   add   XL, r18                               
   ldi   r17, 0x00
   adc   XH, r17

   ; Iterate the array
   ;  - r17 is entry counter
   ;  - r18 is the notification index (i.e. 'ACP_NOTIFICATION_xxx' code)

ACPCheckSendPostponedNotif_CheckEntry:
   ld    r16, X
   cpi   r16, 0x01
   brne  ACPCheckSendPostponedNotif_SelectNextEntry

   ; There is a postpone request for the notification
   mov   r16, r18
   call  ACPSendNotification       ; Send the notification
   ldi   r17, 0x01                 ; Return value, a send has been tried
   cpi   r16, 0x01
   brne  ACPCheckSendPostponedNotif_Exit  ; Notification not sent
                                          ; No update on postpone variables in order to retry
                                          ; on next call

   ; Postponed notification sent, update variables for next call
   ldi   r16, 0x00
   st    X, r16         ; Clear entry in 'ACPPostponedNotifications' array
   inc   r18
   cpi   r18, ACP_NOTIFICATION_NUMBER
   brne  ACPCheckSendPostponedNotif_UpdateNextCheck
   ldi   r18, 0x00                           ; Next to check is the first entry in array

ACPCheckSendPostponedNotif_UpdateNextCheck:
   sts   ACPNextPostponedNotifToCheck, r18   ; Update 'ACPNextPostponedNotifToCheck'
   jmp   ACPCheckSendPostponedNotif_Exit

ACPCheckSendPostponedNotif_SelectNextEntry:
   inc   r17                                 ; Check if whole array iterated
   cpi   r17, ACP_NOTIFICATION_NUMBER
   brne  ACPCheckSendPostponedNotif_NextEntry
   ldi   r17, 0x00                 ; Return value, no postponed notification in the array
   jmp   ACPCheckSendPostponedNotif_Exit     

ACPCheckSendPostponedNotif_NextEntry:
   ; Adjust index for next entry
   inc   r18
   cpi   r18, ACP_NOTIFICATION_NUMBER
   breq  ACPCheckSendPostponedNotif_FirstEntry
   inc   XL
   ldi   r16, 0x00
   adc   XH, r16
   jmp   ACPCheckSendPostponedNotif_CheckEntry   ; Iterate next

ACPCheckSendPostponedNotif_FirstEntry:
   ; The next entry to check is the first entry of the array
   ldi   XL, LOW(ACPPostponedNotifications)    ; Postponed notifications array address
  	ldi   XH, HIGH(ACPPostponedNotifications)
   ldi   r18, 0x00
   jmp   ACPCheckSendPostponedNotif_CheckEntry   ; Iterate next

ACPCheckSendPostponedNotif_Exit:
   mov   r16, r17                   ; r16 contains return value
   pop   XH
   pop   XL
   pop   r18
   pop   r17
   ret

