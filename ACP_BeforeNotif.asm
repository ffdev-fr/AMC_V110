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

   ; 1- Check for a new command received
   cli
   lds   r16, TCPIPCommandReceived
   sei
   cpi   r16, 0x01  
   breq  ACPCheckProcessCommand_CommandWaiting
   jmp   ACPCheckProcessCommand_Exit
   
ACPCheckProcessCommand_CommandWaiting:
   ; New command received, update 'TCPIPCommandReceived' shared variable
   ; (state = processing) 
   ldi   r16, 0x02
   cli
   sts   TCPIPCommandReceived, r16
   sei

   ; 2- Validate the 'TCPIPCommandFrame' (i.e. signature, version, command)
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

   ; 3- Process the command (code in r16) 
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
	jmp 	ACPCheckProcessCommand_ExecutePing
   ; End of command dispatch array

ACPCheckProcessCommand_ExecuteOnOff:
   ; Submit a 'OnOff' command to the 'UserInput' asynchroneous processing
   ; In current version, only one entry in 'UserInput' command queue shared variable
   cli
   lds   r16, InputPollingLastACPCommand   ; 'UserInput' command queue shared variable 
   sei
   cpi   r16, 0xFF                ; Check if command can be inserted in command queue
   breq  ACPCheckProcessCommand_ExecuteOnOffError
   cli
   ldi   r16, USER_COMMAND_ONOFF          ; Set 'InputPollingLastACPCommand' with 'USER_COMMAND_'
                                          ; No parameters for this command
   sts   InputPollingLastACPCommand, r16 
   sei
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
   cli
   lds   r16, InputPollingLastACPCommand   ; 'UserInput' command queue shared variable 
   sei
   cpi   r16, 0xFF                ; Check if command can be inserted in command queue
   breq  ACPCheckProcessCommand_ExecuteMuteError
   cli
   ldi   r16, USER_COMMAND_MUTE           ; Set 'InputPollingLastACPCommand' with 'USER_COMMAND_'
                                          ; No parameters for this command
   sts   InputPollingLastACPCommand, r16 
   sei
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
   cli
   lds   r16, InputPollingLastACPCommand   ; 'UserInput' command queue shared variable 

; Debug - display InputPollingLastACPCommand
;sts  PORTL, r16
; End debug


   sei
   cpi   r16, 0xFF                ; Check if command can be inserted in command queue
   brne  ACPCheckProcessCommand_ExecuteChangeVolumeError
   cli
   ldi   r16, USER_COMMAND_CHANGEVOLUME   ; Set 'InputPollingLastACPCommand' with 'USER_COMMAND_'
   sts   InputPollingLastACPCommand, r16 
   sts   InputPollingLastACPCommandParam0, r17   ; Param0 contains the volume change to apply
   sei
   ldi   r16, ACP_REPLY_RETURN_OK         ; Reply OK
   ldi   r17, ACP_REPLY_STATUS_NONE

; Debug - leds 0 if ExecuteChangeVolume scheduled
ldi  r18, 0b00000001
sts  PORTL, r18
; End debug

   jmp   ACPCheckProcessCommand_SendReply

ACPCheckProcessCommand_ExecuteChangeVolumeError:
   ldi   r16, ACP_REPLY_RETURN_NOK                 ; No room to submit command
   ldi   r17, ACP_REPLY_STATUS_COMMANDQUEUEFULL
   jmp   ACPCheckProcessCommand_SendReply

ACPCheckProcessCommand_ExecuteChangeBalance:
   ; Submit a 'OnOff' command to the 'UserInput' asynchroneous processing
   ; In current version, only one entry in 'UserInput' command queue shared variable
   cli
   lds   r16, InputPollingLastACPCommand   ; 'UserInput' command queue shared variable 
   sei
   cpi   r16, 0xFF                ; Check if command can be inserted in command queue
   breq  ACPCheckProcessCommand_ExecuteChangeBalanceError
   cli
   ldi   r16, USER_COMMAND_CHANGEBALANCE         ; Set 'InputPollingLastACPCommand' with 'USER_COMMAND_'
   sts   InputPollingLastACPCommand, r16 
   sts   InputPollingLastACPCommandParam0, r17   ; Param0 contains the balance change to apply
   sei
   ldi   r16, ACP_REPLY_RETURN_OK         ; Reply OK
   ldi   r17, ACP_REPLY_STATUS_NONE
   jmp   ACPCheckProcessCommand_SendReply

ACPCheckProcessCommand_ExecuteChangeBalanceError:
   ldi   r16, ACP_REPLY_RETURN_NOK                 ; No room to submit command
   ldi   r17, ACP_REPLY_STATUS_COMMANDQUEUEFULL
   jmp   ACPCheckProcessCommand_SendReply

ACPCheckProcessCommand_ExecutePing:
   ; Heart beat command ('Master' command)
   ; The master is only waiting for a reply to confirm that slave is still alive
   ldi   r16, ACP_REPLY_RETURN_OK
   ldi   r17, ACP_REPLY_STATUS_NONE
   jmp   ACPCheckProcessCommand_SendReply

   ; 4- Send reply

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
;  - 
;
; Notes:
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

   ret

