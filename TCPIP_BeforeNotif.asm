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
; File:	TCPIP.asm
;
; Author: F.Fargon
;
; Purpose: 
;  - WIZnet W5100 low level functions
;  - TCP/IP socket functions
;  - TCP/IP server (two ports: one for Command/Reply, one for Notification)
;  - ACP interface with application (shared variables 'TCPIPCommandFrame',
;    'TCPIPNotificationFrame'...).
; 
; NOTES:
;  - The WIZnet W5100 is implemented on a WIZ812MJ module
;  - The WIZ812MJ module is interfaced via 2 ports (WIZDriverDataPortData and
;    WIZDriverCtrlPortData).
;  - The W5100 is addressed using the Indirect Bus Interface Mode (A0-A1 
;    address bus).
;  - For better performance, the W5100 driver assumes that bit6-7 of the
;    control port are not used (the driver must be revised if these bits are
;    needed later for extension). 
;  - All TCPIP server API functions and the W5100 Interrupt handler function 
;    are executed in a critical section (i.e. with external interrupts disabled).
;    The application will access TCPIP server shared variables with its own
;    interrupt handlers. The application must also access shared variable in a
;    critical section (see ACP for details).
;    For good performance, all these functions should terminate in less than
;    1 millisec.
;******************************************************************************



;******************************************************************************
;
; Auto increment read issue on WIZ5100
; 
; With the development platform the auto increment read cannot be used because
; the values of read bytes are corrupted (mainly at the end of the command frame).
; The explanation seems to be related to electrical glitch on RD pin (the WIZ5100
; increments address twice on a single PIC transition).
; To debug this the following has been tried:
;  - Pullup or pulldown resistor on RD pin: more errors
;  - Resistor divider to adapt 5V/3.3V high level on RD pin: does not work even
;    in normal read. Probably all pins (CS, A0, A1, WR, RD) must use 3.3V level.
; Maybe this will be fixed by a clean wiring on the final PCB.
;
; The current implementation uses normal 'ByteRead' to read the RX buffer.
; This is set by the 'TCPIP_WIZ5100_NO_AUTOINCREMENT' flag.
; 
; The same issue appears on Write operation.
; The current implementation does not use auto increment write as well.
;******************************************************************************
#define TCPIP_WIZ5100_NO_AUTOINCREMENT  1


;******************************************************************************
; WIZnet 5100 Driver Functions (high level)
;****************************************************************************** 
	
; Function for initialization of the WIZnet W5100 device.
;
; This function initializes the device and TCP/IP parameters as follows:
;  - Hardware reset of w5100 device
;    (Mode Register set for Indirect Access and Interrupt Mask Register with
;    all interrupts disabled)
;  - Initial setting for 'Retry Time value' and 'Retry Count'
;  - TCP/IP network configuration (Gateway, Hardware Address, Subnet Mask, 
;    Source IP Address)
;  - Socket memory configuration (base address and mask address)
;  - TCPIP server variables are resetted
TCPIPInitW5100:

   push  r16
   push  r17
   push  r18

   ; 1- Hardware reset
   call  W5100Reset
   
   ; 2- TCP/IP timeout
   ; Retry Time Value (registers 0x0017-0x0018)
   ldi   r16, 0x17
   ldi   r17, 0x00
   ldi   r18, HIGH(TCPIPRetryTimeValue)
   call  W5100WriteByte
   inc   r16
   ldi   r18, LOW(TCPIPRetryTimeValue)
   call  W5100WriteByte

   ; Retry Count (register 0x0019)
   ldi   r16, 0x19
   ldi   r17, 0x00
   ldi   r18, TCPIPRetryCount
   call  W5100WriteByte

   ; 3- TCP/IP network configuration
   ; Initialization of Gateway Address, Subnet Mask, MAC Address and IP Address.

   ; Gateway Address (registers 0x0001-0x0004)
	ldi 	r17, LOW(PersistentGatewayIPAddr0)		; Pointer to ESEG address
	ldi 	r18, HIGH(PersistentGatewayIPAddr0)
	call 	ReadPersistentByte
   mov   r18, r16
   ldi   r16, 0x01                           ; Write in 0x0001 register
   ldi   r17, 0x00
   call  W5100WriteFirstByte

	ldi 	r17, LOW(PersistentGatewayIPAddr1)
	ldi 	r18, HIGH(PersistentGatewayIPAddr1)
	call 	ReadPersistentByte
   mov   r18, r16
   ldi   r17, 0x00                           ; Write in 0x0002 register (the next)
   call  W5100WriteNextByte

	ldi 	r17, LOW(PersistentGatewayIPAddr2)
	ldi 	r18, HIGH(PersistentGatewayIPAddr2)
	call 	ReadPersistentByte
   mov   r18, r16
   ldi   r17, 0x00                           ; Write in 0x0003 register (the next and last)
   call  W5100WriteNextByte

	ldi 	r17, LOW(PersistentGatewayIPAddr3)
	ldi 	r18, HIGH(PersistentGatewayIPAddr3)
	call 	ReadPersistentByte
   mov   r18, r16
   ldi   r17, 0x01                           ; Write in 0x0004 register (the next)
   call  W5100WriteNextByte

   ; Subnet Mask (registers 0x0005-0x0008)
	ldi 	r17, LOW(PersistentSubnetMask0)		; Pointer to ESEG address
	ldi 	r18, HIGH(PersistentSubnetMask0)
	call 	ReadPersistentByte
   mov   r18, r16
   ldi   r16, 0x05                           ; Write in 0x0005 register
   ldi   r17, 0x00
   call  W5100WriteFirstByte

	ldi 	r17, LOW(PersistentSubnetMask1)
	ldi 	r18, HIGH(PersistentSubnetMask1)
	call 	ReadPersistentByte
   mov   r18, r16
   ldi   r17, 0x00                           ; Write in 0x0006 register (the next)
   call  W5100WriteNextByte

	ldi 	r17, LOW(PersistentSubnetMask2)
	ldi 	r18, HIGH(PersistentSubnetMask2)
	call 	ReadPersistentByte
   mov   r18, r16
   ldi   r17, 0x00                           ; Write in 0x0007 register (the next)
   call  W5100WriteNextByte

	ldi 	r17, LOW(PersistentSubnetMask3)
	ldi 	r18, HIGH(PersistentSubnetMask3)
	call 	ReadPersistentByte
   mov   r18, r16
   ldi   r17, 0x01                           ; Write in 0x0008 register (the next and last)
   call  W5100WriteNextByte

   ; MAC Address (Source Hardware Address registers 0x0009-0x000E)
	ldi 	r17, LOW(PersistentSourceHardwareAddr0)		; Pointer to ESEG address
	ldi 	r18, HIGH(PersistentSourceHardwareAddr0)
	call 	ReadPersistentByte
   mov   r18, r16
   ldi   r16, 0x09                           ; Write in 0x0009 register
   ldi   r17, 0x00
   call  W5100WriteFirstByte

	ldi 	r17, LOW(PersistentSourceHardwareAddr1)
	ldi 	r18, HIGH(PersistentSourceHardwareAddr1)
	call 	ReadPersistentByte
   mov   r18, r16
   ldi   r17, 0x00                           ; Write in 0x000A register (the next)
   call  W5100WriteNextByte

	ldi 	r17, LOW(PersistentSourceHardwareAddr2)
	ldi 	r18, HIGH(PersistentSourceHardwareAddr2)
	call 	ReadPersistentByte
   mov   r18, r16
   ldi   r17, 0x00                           ; Write in 0x000B register (the next)
   call  W5100WriteNextByte

	ldi 	r17, LOW(PersistentSourceHardwareAddr3)
	ldi 	r18, HIGH(PersistentSourceHardwareAddr3)
	call 	ReadPersistentByte
   mov   r18, r16
   ldi   r17, 0x00                           ; Write in 0x000C register (the next)
   call  W5100WriteNextByte

	ldi 	r17, LOW(PersistentSourceHardwareAddr4)
	ldi 	r18, HIGH(PersistentSourceHardwareAddr4)
	call 	ReadPersistentByte
   mov   r18, r16
   ldi   r17, 0x00                           ; Write in 0x000D register (the next)
   call  W5100WriteNextByte

	ldi 	r17, LOW(PersistentSourceHardwareAddr5)
	ldi 	r18, HIGH(PersistentSourceHardwareAddr5)
	call 	ReadPersistentByte
   mov   r18, r16
   ldi   r17, 0x01                           ; Write in 0x000E register (the next and last)
   call  W5100WriteNextByte

   ; Source IP Address (registers 0x000F-0x0012)
	ldi 	r17, LOW(PersistentSourceIPAddr0)		; Pointer to ESEG address
	ldi 	r18, HIGH(PersistentSourceIPAddr0)
	call 	ReadPersistentByte
   mov   r18, r16
   ldi   r16, 0x0F                           ; Write in 0x000F register
   ldi   r17, 0x00
   call  W5100WriteFirstByte

	ldi 	r17, LOW(PersistentSourceIPAddr1)
	ldi 	r18, HIGH(PersistentSourceIPAddr1)
	call 	ReadPersistentByte
   mov   r18, r16
   ldi   r17, 0x00                           ; Write in 0x0010 register (the next)
   call  W5100WriteNextByte

	ldi 	r17, LOW(PersistentSourceIPAddr2)
	ldi 	r18, HIGH(PersistentSourceIPAddr2)
	call 	ReadPersistentByte
   mov   r18, r16
   ldi   r17, 0x00                           ; Write in 0x0011 register (the next)
   call  W5100WriteNextByte

	ldi 	r17, LOW(PersistentSourceIPAddr3)
	ldi 	r18, HIGH(PersistentSourceIPAddr3)
	call 	ReadPersistentByte
   mov   r18, r16
   ldi   r17, 0x01                           ; Write in 0x0012 register (the next and last)
   call  W5100WriteNextByte

   ; 4- Socket memory configuration
   ; In this version the default socket memory is used:
   ;  - Each socket has 2K memory for RX and TX
   
   ; 5- Reset TCPIP server variables
   ldi   r16, TCPIP_SOCKETSTATE_NOTSTARTED
   sts   TCPIPSocketState, r16

   pop   r18
   pop   r17
   pop   r16
   ret

; Function for starting the TCPIP server.
;
; This function starts the TCPIP server as follows:
;  - If the server is not already started:
;     .. The server variables are resetted
;     .. Socket 0 is initialized for TCPIP protocol
;     .. The 'PersistentSourcePort' port is affected to Socket 0
;     .. Interrupts are enabled for Socket 0 events
;     .. The Socket 0 is open and the listen state is entered
;     .. Socket 0 is now waiting for client connection or termination of TCPIP server
;
; NOTES:
;  - The interrupt handler for socket events is implemented in this file
;    ('TCPIPSocketEvent' function)
;  - Received data and data to send are exchanged between TCPIP driver and the 
;    application using a shared memory block and a semaphore.
TCPIPStartServer:

   cli                 ; 'TCPIPStartServer' API in critical section
   call  TCPIPProcessStartServer
   sei
   ret

; Processing function for starting the TCPIP server.
;
; This function is callesd by the 'TCPIPStartServer' API and the W5100 Interrupt Handler.
; See 'TCPIPStartServer' for comments
TCPIPProcessStartServer:

   push  r16
   push  r17
   push  r18
   push  XL
   push  XH

   ; 1- Check if server is not already started
   ; NOTE: The server must be explicitly stopped first if a restart is required
   lds   r16, TCPIPSocketState
   cpi   r16, TCPIP_SOCKETSTATE_NOTSTARTED
   breq  TCPIPProcessStartServerStartRequired
   jmp   TCPIPProcessStartServerExit                    ; Server already started

TCPIPProcessStartServerStartRequired:

   ; 2- Reset server variables
   ldi   r16, 0x00                                ; Command Frame empty
   sts   TCPIPCommandFrameReadBytes, r16
   sts   TCPIPCommandReceived, r16

   ldi   XL, LOW(TCPIPReplyFrame)        ; Initialize Reply Frame (the 'TCPIPSendReply' function
                                         ; will not change the ACP header and Frame type) 
  	ldi   XH, HIGH(TCPIPReplyFrame)
   ldi   r16, ACP_FRAME_HEADER0
   st    X+, r16                       
   ldi   r16, ACP_FRAME_HEADER1
   st    X+, r16                       
   ldi   r16, ACP_FRAME_HEADER2
   st    X+, r16                       
   ldi   r16, ACP_FRAME_HEADER3
   st    X+, r16               
   ldi   r16, ACP_FRAME_VERSION
   st    X+, r16                       
   ldi   r16, ACP_FRAME_REPLY
   st    X+, r16                       
           
   ; 3- Set socket 0 port
   ; Socket 0 Source Port Register is located at addresses 0x0404-0x0405
	ldi 	r17, LOW(PersistentSourcePortLSB)		; Pointer to ESEG address
	ldi 	r18, HIGH(PersistentSourcePortLSB)
	call 	ReadPersistentByte
   mov   r18, r16
   ldi   r16, 0x04          ; Write in 0x0404 register
   ldi   r17, 0x04
   call  W5100WriteByte
	ldi 	r17, LOW(PersistentSourcePortMSB)		; Pointer to ESEG address
	ldi 	r18, HIGH(PersistentSourcePortMSB)
	call 	ReadPersistentByte
   mov   r18, r16
   ldi   r16, 0x05          ; Write in 0x0405 register
   ldi   r17, 0x04
   call  W5100WriteByte

   ; 4- Set socket 0 for TCPIP protocol
   ; Socket 0 Mode register address is 0x400
   ldi   r16, 0x00          ; Write in 0x0400 register
   ldi   r17, 0x04
   ldi   r18, 0b00000001    ; TCPIP protocol is bit0 set to 1
   call  W5100WriteByte
   ldi   r16, TCPIP_SOCKETSTATE_CLOSED
   sts   TCPIPSocketState, r16

   ; 5- Enable interrupts for socket 0
   ; Interrupt Mask Register address is 0x0016
   ldi   r16, 0x16          ; Write in 0x0016 register
   ldi   r17, 0x00
   ldi   r18, 0b00000001    ; Socket 0 interrupt enabled
   call  W5100WriteByte

   ; 6- Open socket 0
   ; The OPEN command is launched using the Socket 0 Command Register (address 0x0401)
   ; NOTE: The OPEN command should work at all times (i.e. status register not checked
   ;       after command launched)
   ldi   r16, 0x01          ; Write in 0x0401 register
   ldi   r17, 0x04
   ldi   r18, 0x01          ; OPEN command is 0x01
   call  W5100WriteByte
   ldi   r16, TCPIP_SOCKETSTATE_INIT
   sts   TCPIPSocketState, r16

   ; 7- Start Listen on socket 0
   ; The LISTEN command is launched using the Socket 0 Command Register (address 0x0401)
   ; NOTE: The LISTEN command should work at all times (i.e. status register not checked
   ;       after command launched)
   ldi   r16, 0x01          ; Write in 0x0401 register
   ldi   r17, 0x04
   ldi   r18, 0x02          ; LISTEN command is 0x02
   call  W5100WriteByte
   ldi   r16, TCPIP_SOCKETSTATE_LISTENING
   sts   TCPIPSocketState, r16

   ; 8- From now any event on socket 0 will trigger W5100 interrupt
   ; The MCU interrupt vector for W5100 interrupt is set for calling the
   ; 'TCPIPSocketEvent' function
   ; NOTE: In the 'TCPIP_SOCKETSTATE_LISTENING' listening state, the only valid interrupt is
   ;       an incoming connection event from a peer.

TCPIPProcessStartServerExit:
   pop   XH
   pop   XL
   pop   r18
   pop   r17
   pop   r16
   ret

; Function for stopping the TCPIP server.
;
; This function stops the TCPIP server as follows:
;  - If the server is started
;     .. Interrupts are disabled for Socket 0
;     .. If a connection is established, the DISCONNECT command is sent to disconnect
;        the peer from socket 0 (socket 0 state changed to CLOSED)
;     .. Otherwise, a CLOSE command id sent to Socket 0 (socket 0 should be open)
;     .. The Socket 0 state variable is updated (= 'TCPIP_SOCKETSTATE_NOTSTARTED')
;
; NOTE:
;  - The 'TCPIPStartServer' function can be called again to restart the server.
TCPIPStopServer:

   cli                 ; 'TCPIPStopServer' API in critical section
   push  r16
   push  r17
   push  r18

   ; 1- Check if the server is started
   lds   r16, TCPIPSocketState
   cpi   r16, TCPIP_SOCKETSTATE_NOTSTARTED
   breq  TCPIPStopServer_StopRequired
   jmp   TCPIPStopServer_Exit                    ; Server not started

TCPIPStopServer_StopRequired:

   ; 2- Disable interrupts for socket 0
   ; Interrupt Mask Register address is 0x0016
   ldi   r16, 0x16          ; Write in 0x0016 register
   ldi   r17, 0x00
   ldi   r18, 0b00000000    ; Socket 0 interrupt disabled
   call  W5100WriteByte

   ; 3- Check if Socket 0 is open (should be open)
   cpi   r16, TCPIP_SOCKETSTATE_CLOSED
   breq  TCPIPStopServer_SocketClosed
   cpi   r16, TCPIP_SOCKETSTATE_CLOSING
   breq  TCPIPStopServer_SocketClosed

   ; 4- If a connection is established, disconnect the peer
   cpi   r16, TCPIP_SOCKETSTATE_ESTABLISHED
   brlo  TCPIPStopServer_CloseSocket

   ; Send DISCONNECT command to Socket 0
   ; The DISCONNECT command is launched using the Socket 0 Command Register (address 0x0401)
   ; NOTE: The DISCONNECT command should work at all times (i.e. status register not checked
   ;       after command launched)
   ldi   r16, 0x01          ; Write in 0x0401 register
   ldi   r17, 0x04
   ldi   r18, 0x08          ; DISCONNECT command is 0x08
   call  W5100WriteByte
   jmp   TCPIPStopServer_SocketClosed

TCPIPStopServer_CloseSocket:

   ; 5- If not connection established, close the socket (i.e. stop to listen)
   ; Send CLOSE command to Socket 0
   ; The CLOSE command is launched using the Socket 0 Command Register (address 0x0401)
   ; NOTE: The CLOSE command should work at all times (i.e. status register not checked
   ;       after command launched)
   ldi   r16, 0x01          ; Write in 0x0401 register
   ldi   r17, 0x04
   ldi   r18, 0x10          ; CLOSE command is 0x10
   call  W5100WriteByte

TCPIPStopServer_SocketClosed:

   ; 6- The socket 0 is stopped
   ; Update the 'TCPIPSocketState' state variable for server stopped
   ldi   r16, TCPIP_SOCKETSTATE_NOTSTARTED
   sts   TCPIPSocketState, r16

TCPIPStopServer_Exit:
   pop   r18
   pop   r17
   pop   r16
   sei
   ret

; Function for sending a Reply Frame to the client.
;
; This function works as follows:
;  - The caller function must set the Reply information in the 'TCPIPReplyFrame'
;    buffer before calling.
;  - The function checks the TCPIP automaton state and Socket 0 TX buffer free size.
;  - The function copies the contents of the 'TCPIPReplyFrame' buffer in the W5100 
;    Socket 0 TX buffer.
;  - The function launches a send operation on Socket 0.
;  - The fuction updates the TCPIP automaton state and returns.
;
; The function returns the result of the operation in R16 register:
;  - 0x01 = Reply send launched
;  - 0x00 = Cannot send Reply (wrong state, TX buffer full...)
;           Typically, the caller must retry later.
; 
; NOTE: 
;  The 'SendReply' operation is synchronized by design (i.e. no critical section for 
;  access to 'TCPIPReplyFrame' buffer):
;   - The client will not send a new command until it has received the whole reply frame.
;   - The server will not have to send a reply until it has not received a new command.
;
; NOTE: 
;  All the Reply frame bytes are sent in a single call (i.e. the function fails if there
;  is not enough space in TX buffer to send the whole frame).
TCPIPSendReply:

   push  r17
   push  r18
   push  r19
   push  r20
   push  r21
   push  r22
   push  r23
   push  r24
   push  XL
   push  XH


   ; 1- Check TCPIP automaton state
   ; This function is not directly called directly from the TCPIP automaton (i.e. W5100 interrupt handler).
   ; TCPIP automaton state is checked for design consistency (if implementation is clean, there is not reason
   ; to call this function in the wrong state).
   cli      ; Access automaton state in critical section
   lds   r16, TCPIPSocketState
   sei
   cpi   r16, TCPIP_SOCKETSTATE_CMDRECEIVED   ; Send reply allowed only in response to a received command 
   breq  TCPIPSendReply_CheckTXFreeSize
   ldi   r16, 0x00                            ; Wrong state, not allowed to send reply
   jmp   TCPIPSendReply_Exit

TCPIPSendReply_CheckTXFreeSize:
   ; 2- Copy the 'Reply Frame' bytes in the TX buffer
   ; Obtain the free size available in TX buffer
   ; Information available in Socket 0 TX Free Size Register (register address 0x0420-0x0421)
   ; The address '0x0420' must be read first (MSB of free size)
   ldi   r16, 0x20             ; Read in 0x0420 register
   ldi   r17, 0x04
   call  W5100ReadByte         ; r18 contains MSB of S0_TX_FSR on return
   mov   r20, r18
   inc   r16
   call  W5100ReadByte         ; r18 contains LSB of S0_TX_FSR on return
   mov   r19, r18              ; Free size stored in r20:r19

   ; Check if enough space in TX buffer for send of the 'Reply Frame'
   ; NOTE: By design the TX buffer cannot be satured
   cpi   r20, 0x00             ; Maximum 'Frame' size is 255 bytes
   brne  TCPIPSendReply_ComputeOffset
   ldi   r16, TCPIPFrameSize
   cp    r16, r19              ; Carry set if r19 > r16
   brcc  TCPIPSendReply_ComputeOffset

   ldi   r16, 0x00             ; Not enough space in TX memory to send reply
   jmp   TCPIPSendReply_Exit

TCPIPSendReply_ComputeOffset:

   ; Obtain the Write Pointer
   ; Information available in Socket 0 TX Write Pointer Register (register address 0x0424-0x0425)
   ; The address '0x0424' must be read first (MSB of read pointer)
   ; NOTE: 
   ;  - The current Write Pointer value is stored on stack
   ;  - This value will be used at the end of copy process to update the Write Pointer in the W5100
   ldi   r16, 0x24             ; Read in 0x0424 register
   ldi   r17, 0x04
   call  W5100ReadByte         ; r18 contains MSB of S0_TX_WR on return
   mov   r22, r18
   push  r18                   ; Save current value of 0x0424 register
   inc   r16
   call  W5100ReadByte         ; r18 contains LSB of S0_TX_WR on return
   mov   r21, r18
   push  r18                   ; Save current value of 0x0425 register

   ; Compute address offset for writing data
   andi  r21, LOW(TCPIPSocket0TxMask)     ; Address offset in r22:r21
   andi  r22, HIGH(TCPIPSocket0TxMask)   

   ; Source buffer ('TCPIPReplyFrame') is addressed with XH:XL pointer
	ldi   XL, LOW(TCPIPReplyFrame)
	ldi   XH, HIGH(TCPIPReplyFrame)

   ; Check for TX socket overflow (i.e. rotating buffer)
   ; Overflow if: Offset + Send Size > Mask + 1
   mov   r16, r21
   mov   r17, r22
   ldi   r18, TCPIPFrameSize
   add   r16, r18
   ldi   r18, 0x00
   adc   r17, r18
   cpi   r17, HIGH(TCPIPSocket0TxSize)
   brlo  TCPIPSendReply_JumpNoOverflow
   brne  TCPIPSendReply_Overflow
   cpi   r16, LOW(TCPIPSocket0TxSize)
   brlo  TCPIPSendReply_JumpNoOverflow
   breq  TCPIPSendReply_JumpNoOverflow
   rjmp  TCPIPSendReply_Overflow

TCPIPSendReply_JumpNoOverflow:
   jmp   TCPIPSendReply_NoOverflow
      
TCPIPSendReply_Overflow:

#ifdef TCPIP_WIZ5100_NO_AUTOINCREMENT

   ; Overflow case ont implemented with TCPIP_WIZ5100_NO_AUTOINCREMENT flag
   ; This should never occur if frame size is 64 bytes
   jmp   TCPIPSendReply_NoOverflow

#else

   ; Bytes to send are contained at the end of TX buffer and overflow to the beginning of buffer
   ; NOTE: No overflow occurs if the frame size is 8, 16, 32, 64 or 128 bytes (on reset the
   ;       WIZ5100 always starts at 0 address offset for TX buffer).
   ; 
   ; Bytes are written using the sequential access mode (i.e. if more than one byte to send)
   ; Compute Socket TX buffer start address (S0_TX_Tase + Send data address Offset)
   ldi   r16, LOW(TCPIPSocket0TxBase)
   ldi   r17, HIGH(TCPIPSocket0TxBase)
   add   r16, r21
   adc   r17, r22

   ; Loop counter (i.e. number of bytes to write) is r24:r23
   ; Compute the number of bytes to write at the upper address
   ; Upper size is S0_TX_Size - Offset
   ldi   r23, LOW(TCPIPSocket0TxSize)
   ldi   r24, HIGH(TCPIPSocket0TxSize)
   sub   r23, r19
   sbc   r24, r20
   push  r23               ; Save the number of bytes to write at the upper address
   push  r24

   ; Write the first byte
   ; Check for only one byte to write in the upper memory block
   cpi   r24, 0x00
   brne  TCPIPSendReply_OverflowStartUpperLoop
   cpi   r23, 0x01
   brne  TCPIPSendReply_OverflowStartUpperLoop

   ; Only one byte to write in the upper memory block
   ld    r18, X                 ; Load r18 with the byte to write
   call  W5100WriteByte         
   jmp   TCPIPSendReply_OverflowInitLowerLoop

TCPIPSendReply_OverflowStartUpperLoop:
   ; More than one byte to write in the upper memory block
   ld    r18, X+                    ; Load r18 with the byte to write
   call  W5100WriteFirstByte    

   ldi   r16, 0x00                  ; Decrement loop counter
   dec   r23
   brne  TCPIPSendReply_OverflowUpperLoop
   cpi   r24, 0x00
   breq  TCPIPSendReply_OverflowInitLowerLoop
   dec   r24

TCPIPSendReply_OverflowUpperLoop:
   cpi   r23, 0x01                  ; Is last byte to write
   brne  TCPIPSendReply_OverflowUpperLoopWrite
   cpi   r24, 0x00
   brne  TCPIPSendReply_OverflowUpperLoopWrite
   ldi   r17, 0x01                  ; Last byte to write

TCPIPSendReply_OverflowUpperLoopWrite:
   ld    r16, X+                    ; Load r16 with the byte to write
   call  W5100WriteNextByte

   ldi   r17, 0x00                  ; Decrement loop counter
   dec   r23
   brne  TCPIPSendReply_OverflowUpperLoop
   cpi   r24, 0x00
   breq  TCPIPSendReply_OverflowInitLowerLoop
   dec   r24
   jmp   TCPIPSendReply_OverflowUpperLoop

TCPIPSendReply_OverflowInitLowerLoop:
   ; Compute the number of bytes to write at the lower address
   ; The number of left bytes to write is: 
   ; number of bytes to send - number of bytes written at upper memory address 
   pop   r16                     ; Retrieve the number of bytes written at the upper address
   pop   r17
   ldi   r23, TCPIPFrameSize     ; Number of bytes to write is frame size
   ldi   r24, 0x00
   sub   r23, r16
   sbc   r24, r17

   ; Bytes are written from the Socket 0 TX base address
   ldi   r16, LOW(TCPIPSocket0TxBase)
   ldi   r17, HIGH(TCPIPSocket0TxBase)

   ; Write the first byte
   ; Check for only one byte to write in the lower memory block
   cpi   r24, 0x00
   brne  TCPIPSendReply_OverflowStartLowerLoop
   cpi   r23, 0x01
   brne  TCPIPSendReply_OverflowStartLowerLoop

   ; Only one byte to read in the lower memory block
   ld    r18, X+                    ; Load r18 with the byte to write
   call  W5100WriteByte
   jmp   TCPIPSendReply_BytesWritten

TCPIPSendReply_OverflowStartLowerLoop:
   ; More than one byte to write in the lower memory block
   ld    r18, X+                    ; Load r18 with the byte to write
   call  W5100WriteFirstByte 

   ldi   r17, 0x00                  ; Decrement loop counter
   dec   r23
   brne  TCPIPSendReply_OverflowLowerLoop
   cpi   r24, 0x00
   breq  TCPIPSendReply_BytesWritten
   dec   r24

TCPIPSendReply_OverflowLowerLoop:
   cpi   r23, 0x01                  ; Is last byte to write
   brne  TCPIPSendReply_OverflowLowerLoopWrite
   cpi   r24, 0x00
   brne  TCPIPSendReply_OverflowLowerLoopWrite
   ldi   r17, 0x01                  ; Last byte to write

TCPIPSendReply_OverflowLowerLoopWrite:
   ld    r16, X+                    ; Load r16 with the byte to write
   call  W5100WriteNextByte

   ldi   r17, 0x00                  ; Decrement loop counter
   dec   r23
   brne  TCPIPSendReply_OverflowLowerLoop
   cpi   r24, 0x00
   breq  TCPIPSendReply_BytesWritten
   dec   r24
   jmp   TCPIPSendReply_OverflowLowerLoop

#endif


TCPIPSendReply_NoOverflow:
   ; Bytes to send copied to a contiguous data block

#ifdef TCPIP_WIZ5100_NO_AUTOINCREMENT

   ; Loop with WriteByte instead of autoincrement mode mode

   ; Compute Socket TX buffer start address (S0_TX_Base + Send data address Offset)
   ldi   r16, LOW(TCPIPSocket0TxBase)
   ldi   r17, HIGH(TCPIPSocket0TxBase)
   add   r16, r21
   adc   r17, r22

   ; Loop counter (i.e. number of bytes to write) is r24:r23
   ldi   r23, TCPIPFrameSize     ; Number of bytes to write is Frame size
                                 ; Note: By design Frame size cannot be less than 12
   ldi   r24, 0x00

TCPIPSendReply_WriteNextByte:
   ld    r18, X+                    ; Load r18 with the byte to write
   call  W5100WriteByte

   ; Prepare for next byte write (i.e. increment address to write in TX memory)
   inc   r16         
   ldi   r18, 0x00
   adc   r17, r18

   ; Decrement loop counter
   dec   r23
   brne  TCPIPSendReply_WriteNextByte
   cpi   r24, 0x00
   breq  TCPIPSendReply_BytesWritten
   dec   r24
   jmp   TCPIPSendReply_WriteNextByte

#else

   ; Bytes are written using the sequential access mode (i.e. if more than one byte to read)
   ; Compute Socket TX buffer start address (S0_TX_Base + Send data address Offset)
   ldi   r16, LOW(TCPIPSocket0TxBase)
   ldi   r17, HIGH(TCPIPSocket0TxBase)
   add   r16, r21
   adc   r17, r22

   ; Loop counter (i.e. number of bytes to write) is r24:r23
   ldi   r23, TCPIPFrameSize     ; Number of bytes to write is Frame size
                                 ; Note: By design Frame size cannot be less than 12
   ldi   r24, 0x00

   ; Write the first byte
   ld    r18, X+                    ; Load r18 with the byte to write
   call  W5100WriteFirstByte 

   ldi   r17, 0x00                  ; Decrement loop counter
   dec   r23
   brne  TCPIPSendReply_NoOverflowLoop
   cpi   r24, 0x00
   breq  TCPIPSendReply_BytesWritten
   dec   r24

TCPIPSendReply_NoOverflowLoop:
   cpi   r23, 0x01                  ; Is last byte to read
   brne  TCPIPSendReply_NoOverflowLoopWrite
   cpi   r24, 0x00
   brne  TCPIPSendReply_NoOverflowLoopWrite
   ldi   r17, 0x01                  ; Last byte to read

TCPIPSendReply_NoOverflowLoopWrite:
   ld    r16, X+                    ; Load r16 with the byte to write
   call  W5100WriteNextByte

   ldi   r17, 0x00                  ; Decrement loop counter
   dec   r23
   brne  TCPIPSendReply_NoOverflowLoop
   cpi   r24, 0x00
   breq  TCPIPSendReply_BytesWritten
   dec   r24
   jmp   TCPIPSendReply_NoOverflowLoop

#endif


TCPIPSendReply_BytesWritten:
   ; 3 - Bytes to send are ready in the TX buffer
   ; Launch the SEND command in the W5100
   
   ; Increase the Write Pointer value with the number of bytes to send
   ; Information available in Socket 0 TX Write Pointer Register (register address 0x0424-0x0425)
   ; The address '0x0424' must be read first (MSB of read pointer)
   ; NOTE: 
   ;  - The current Write Pointer value have been stored on stack
   pop   r19                   ; Current register 0x0425 value of S0_TX_WR in r19 (LSB)
   pop   r18                   ; Current register 0x0424 value of S0_TX_WR in r19 (MSB)
   ldi   r16, TCPIPFrameSize   ; Frame Size bytes written in TX buffer
   add   r19, r16
   ldi   r16, 0x00
   adc   r18, r16

   ldi   r16, 0x24             ; Write in 0x0424 register
   ldi   r17, 0x04
   call  W5100WriteByte        
   mov   r18, r19              ; Write in 0x0425 register
   inc   r16
   call  W5100WriteByte        
    
   ; The SEND command is launched using the Socket 0 Command Register (address 0x0401)
   ; Note: The W5100 SEND command is launched in a critical section because the
   ;       state and shared variables must be updated before receiving the next
   ;       TCPIP event.
   cli
   ldi   r16, TCPIP_SOCKETSTATE_SENDINGREPLY     ; Update socket state
   sts   TCPIPSocketState, r16

   ldi   r16, 0x01          ; Write in 0x0401 register
   ldi   r17, 0x04
   ldi   r18, 0x20          ; SEND command is 0x20
   call  W5100WriteByte
   sei

TCPIPSendReply_Exit:

   pop   XH
   pop   XL
   pop   r24
   pop   r23
   pop   r22
   pop   r21
   pop   r20
   pop   r19
   pop   r18
   pop   r17
   ret

; Interrupt handler for W5100 interrupt
;
; This function is called when the W5100 generates an interrupt.
; As the W5100 is only used as TCPIP server, the interrupts occur only on socket
; events.
; This function does the following:
;  - The socket event is identified (by design, in this implementation only socket 0
;    is used)
;  - The event is checked against the socket state
;  - The event is processed
TCPIPSocketEvent:

   cli                ; W5100 Interrupt Handler in critical section
   push  r16
   push  r17
   push  r18

   ; 1- Identify the socket event
   ; Only socket event should be received (by design Interrupt Register Mask enables
   ; only socket 0 interrupts)
   ; Read Interrupt Register to check the source of the interrupt
   ; Interrupt Register address is 0x0015
   ldi   r16, 0x15             ; Read in 0x0015 register
   ldi   r17, 0x00
   call  W5100ReadByte
	cpi   r18, 0b00000001                  ; Is socket 0 interrupt
	breq  TCPIPSocketEvent_Socket0Event
   jmp   TCPIPSocketEvent_ClearUnexpectedInterrupt

TCPIPSocketEvent_Socket0Event:
   ; Socket 0 event is identified
   ; Read Socket 0 Interrupt Register to identify the event
   ; Socket 0 Interrupt Register address is 0x0402
   ldi   r16, 0x02             ; Read in 0x0402 register
   ldi   r17, 0x04
   call  W5100ReadByte         ; r18 contains S0_IR on return

   ; 2- Check the Socket 0 event according to socket state
   lds   r16, TCPIPSocketState                    
   cpi   r18, 0b00000001       ; Is Incoming Connection event?
   breq  TCPIPSocketEvent_CheckConnectEvent
   cpi   r18, 0b00000010       ; Is Disconnect event?
   breq  TCPIPSocketEvent_CheckDisconnectEvent
   cpi   r18, 0b00000100       ; Is Receive event?
   breq  TCPIPSocketEvent_CheckReceiveEvent
   cpi   r18, 0b00001000       ; Is Timeout event?
   breq  TCPIPSocketEvent_CheckTimeoutEvent
   cpi   r18, 0b00010000       ; Is Send OK event?
   breq  TCPIPSocketEvent_CheckSentEvent
   jmp   TCPIPSocketEvent_ClearSocket0Int     ; This point should never be reached
                                    
TCPIPSocketEvent_CheckConnectEvent:
   ; Connect event is valid only in 'TCPIP_SOCKETSTATE_LISTENING' state                                 
   cpi   r16, TCPIP_SOCKETSTATE_LISTENING
   breq  TCPIPSocketEvent_ProcessConnectEvent        
   jmp   TCPIPSocketEvent_ClearSocket0Int
             
TCPIPSocketEvent_CheckDisconnectEvent:
   ; Disconnect event is valid in 'TCPIP_SOCKETSTATE_ESTABLISHED',
   ; 'TCPIP_SOCKETSTATE_RECEIVING', 'TCPIP_SOCKETSTATE_CMDRECEIVED' and
   ; 'TCPIP_SOCKETSTATE_SENDINGREPLY' states                                 
   cpi   r16, TCPIP_SOCKETSTATE_ESTABLISHED
   breq  TCPIPSocketEvent_ProcessDisconnectEvent        
   cpi   r16, TCPIP_SOCKETSTATE_RECEIVING
   breq  TCPIPSocketEvent_ProcessDisconnectEvent        
   cpi   r16, TCPIP_SOCKETSTATE_CMDRECEIVED
   breq  TCPIPSocketEvent_ProcessDisconnectEvent        
   cpi   r16, TCPIP_SOCKETSTATE_SENDINGREPLY
   breq  TCPIPSocketEvent_ProcessDisconnectEvent        
   jmp   TCPIPSocketEvent_ClearSocket0Int
             
TCPIPSocketEvent_CheckReceiveEvent:
   ; Receive event is valid in 'TCPIP_SOCKETSTATE_ESTABLISHED' and
   ; 'TCPIP_SOCKETSTATE_RECEIVING' states
   cpi   r16, TCPIP_SOCKETSTATE_ESTABLISHED
   breq  TCPIPSocketEvent_ProcessReceiveEvent        
   cpi   r16, TCPIP_SOCKETSTATE_RECEIVING
   breq  TCPIPSocketEvent_ProcessReceiveEvent        
   jmp   TCPIPSocketEvent_ClearSocket0Int
             
TCPIPSocketEvent_CheckTimeoutEvent:
   ; Timeout event is valid in 'TCPIP_SOCKETSTATE_RECEIVING' and
   ; 'TCPIP_SOCKETSTATE_SENDINGREPLY' states
   cpi   r16, TCPIP_SOCKETSTATE_RECEIVING
   breq  TCPIPSocketEvent_ProcessTimeoutEvent        
   cpi   r16, TCPIP_SOCKETSTATE_SENDINGREPLY
   breq  TCPIPSocketEvent_ProcessTimeoutEvent        
   jmp   TCPIPSocketEvent_ClearSocket0Int

TCPIPSocketEvent_CheckSentEvent:
   ; Send OK event is valid in 'TCPIP_SOCKETSTATE_SENDINGREPLY' state
   cpi   r16, TCPIP_SOCKETSTATE_SENDINGREPLY
   breq  TCPIPSocketEvent_ProcessSentEvent        
   jmp   TCPIPSocketEvent_ClearSocket0Int

   ; 3- Process Socket 0 event

TCPIPSocketEvent_ProcessConnectEvent:
   ; 3.1- Process Incoming Connection event
   push  r18                           ; Save S0_IR flags (required to acknoledge the interrupt)
   call  TCPIPProcessConnectEvent
   pop   r18
   jmp   TCPIPSocketEvent_ClearSocket0Int

TCPIPSocketEvent_ProcessDisconnectEvent:
   ; 3.2- Process Disconnect event
   push  r18                           ; Save S0_IR flags (required to acknoledge the interrupt)
   call  TCPIPProcessDisonnectEvent
   pop   r18
   jmp   TCPIPSocketEvent_ClearSocket0Int

TCPIPSocketEvent_ProcessReceiveEvent:
   ; 3.3- Process Receive event
   push  r18                           ; Save S0_IR flags (required to acknoledge the interrupt)
   call  TCPIPProcessReceiveEvent
   pop   r18
   jmp   TCPIPSocketEvent_ClearSocket0Int

TCPIPSocketEvent_ProcessTimeoutEvent:
   ; 3.3- Process Timeout event
   push  r18                           ; Save S0_IR flags (required to acknoledge the interrupt)
   call  TCPIPProcessTimeoutEvent
   pop   r18
   jmp   TCPIPSocketEvent_ClearSocket0Int

TCPIPSocketEvent_ProcessSentEvent:
   ; 3.3- Process Send OK event
   push  r18                           ; Save S0_IR flags (required to acknoledge the interrupt)
   call  TCPIPProcessSentEvent
   pop   r18
   jmp   TCPIPSocketEvent_ClearSocket0Int

TCPIPSocketEvent_ClearUnexpectedInterrupt:
   ; Unexpected interrupt has been received, clear the Interrupt Register
   ; NOTE: This should never occur
   ; Only bit5-7 may be set in IR (the other ones are socket and only socket 0 in IMR).
   ; These interrupts are cleared by writing the corresponding bit in IR
   ldi   r16, 0x15             ; Read in 0x0015 register
   ldi   r17, 0x00
   call  W5100WriteByte        ; Note: r18 only contains the bits to write for clearing
   jmp   TCPIPSocketEvent_Exit

TCPIPSocketEvent_ClearSocket0Int:
   ; The socket 0 interrupt has been processed, clear the interrupt register
   ; The S0_IR is cleared by writting one in register (for the interrupt(s) to acknowledge)
   ldi   r16, 0x02             ; Write in 0x0402 register
   ldi   r17, 0x04             ; r18 already contains the original S0_IR value
   call  W5100WriteByte

TCPIPSocketEvent_Exit:

   pop   r18
   pop   r17
   pop   r16
   sei
   reti

; Function called by 'TCPIPSocketEvent' interrupt handler for processing a connect event
;
; This function is called when a connect event is received on the Socket 0.
; This function does the following:
;  - The socket state variable 'TCPIPSocketState' is updated to 'ESTABLISHED'
;    The socket is now waiting for incoming data (a 'Command' frame) or disconnection.
;    The socket is also ready to send data (i.e. a 'Notification' frame).
; 
; NOTE: 
;  - This function is called only if current socket state is valid for the operation
;  - Registers r16, r17, r18 are already saved by the caller function and this function
;    is allowed to modify them.
TCPIPProcessConnectEvent:

   ; Update socket 0 state variable
   ldi   r16, TCPIP_SOCKETSTATE_ESTABLISHED
   sts   TCPIPSocketState, r16

   ret

; Function called by 'TCPIPSocketEvent' interrupt handler for processing a disconnect event
;
; This function is called when a disconnect event is received on the Socket 0.
; Typically this event occurs when a peer disconnects. There is no disconnect event when 
; the 'TCPIPStopServer' function is called (i.e. interrupts are disabled).
; The rules are: 
;  - If disconnected by the peer TCPIP server stays started (i.e. continue to listen).
;  - If disconnected by 'TCPIPStopServer' the TCPIP server is really stopped
; 
; This function does the following:
;  - The Socket 0 is open again
;  - The TCPIP server start to listen for a new connection
; 
; NOTE: 
;  - This function is called only if current socket state is valid for the operation
;  - Registers r16, r17, r18 are already saved by the caller function and this function
;    is allowed to modify them.
TCPIPProcessDisonnectEvent:

   ; 1- Open socket 0
   ; The OPEN command is launched using the Socket 0 Command Register (address 0x0401)
   ; NOTE: The OPEN command should work at all times (i.e. status register not checked
   ;       after command launched)
   ldi   r16, 0x01          ; Write in 0x0401 register
   ldi   r17, 0x04
   ldi   r18, 0x01          ; OPEN command is 0x01
   call  W5100WriteByte
   ldi   r16, TCPIP_SOCKETSTATE_INIT
   sts   TCPIPSocketState, r16

   ; 2- Start Listen on socket 0
   ; The LISTEN command is launched using the Socket 0 Command Register (address 0x0401)
   ; NOTE: The LISTEN command should work at all times (i.e. status register not checked
   ;       after command launched)
   ldi   r16, 0x01          ; Write in 0x0401 register
   ldi   r17, 0x04
   ldi   r18, 0x02          ; LISTEN command is 0x02
   call  W5100WriteByte
   ldi   r16, TCPIP_SOCKETSTATE_LISTENING
   sts   TCPIPSocketState, r16

   ret

; Function called by 'TCPIPSocketEvent' interrupt handler for processing a receive event
;
; This function is called when a data are received on the Socket 0 (i.e. data available
; in the socket 0 RX buffer).
; This function does the following:
;  - The received bytes are copied to the application shared RX data block ('TCPIPCommandFrame')
;  - If the whole 'Command Frame' is received:
;      .. The socket state variable 'TCPIPSocketState' is updated to 'TCPIP_SOCKETSTATE_CMDRECEIVED'
;      .. The application is notified for a received 'Command frame' (semaphore 'TCPIPCommandReceived')
;      .. The server is waiting for sending the application 'Reply frame' (i.e. a call to the
;         'TCPIPSendReply' function)
;  - If the 'Command Frame' is not fully received:
;      .. The socket state variable 'TCPIPSocketState' is updated to 'TCPIP_SOCKETSTATE_RECEIVING'
;      .. The server is waiting for next 'ReceiveEvent' (i.e. next bytes of 'Command Frame')
; 
; NOTE:
;  - The received data cannot contain more than one 'Command Frame' because the client will wait
;    for the server's 'Reply Frame' before sending another 'Command Frame' (see 'ACP' for details)
; 
; NOTE: 
;  - This function is called only if current socket state is valid for the operation
;  - Registers r16, r17, r18 are already saved by the caller function and this function
;    is allowed to modify them.
TCPIPProcessReceiveEvent:

   push  r19
   push  r20
   push  r21
   push  r22
   push  r23
   push  r24
   push  XL
   push  XH

   ; 1- Read the received bytes
   ; Obtain size of received data
   ; Information available in Socket 0 RX Received Size Register (register address 0x0426-0x0427)
   ; The address '0x0426' must be read first (MSB of received size)
   ldi   r16, 0x26             ; Read in 0x0426 register
   ldi   r17, 0x04
   call  W5100ReadByte         ; r18 contains MSB of S0_RX_RSR on return
   mov   r20, r18
   inc   r16
   call  W5100ReadByte         ; r18 contains LSB of S0_RX_RSR on return
   mov   r19, r18              ; Received size stored in r20:r19

   ; Obtain the Read Pointer
   ; Information available in Socket 0 RX Read Pointer Register (register address 0x0428-0x0429)
   ; The address '0x0428' must be read first (MSB of read pointer)
   ; Note: The current Read Pointer is stored on stack because it will be used at the end of copy 
   ;       process to update the register in the W5100
   inc   r16                   ; r17:r16 previously set to 0x0427
   call  W5100ReadByte         ; r18 contains MSB of S0_RX_RD on return
   mov   r22, r18
   push  r18                   ; Save current value of 0x0427 register
   inc   r16
   call  W5100ReadByte         ; r18 contains LSB of S0_RX_RD on return
   mov   r21, r18
   push  r18                   ; Save current value of 0x0428 register

   ; Compute received data address offset
   andi  r21, LOW(TCPIPSocket0RxMask)     ; Address offset in r22:r21
   andi  r22, HIGH(TCPIPSocket0RxMask)   

   ; Destination buffer ('TCPIPCommandFrame') is addressed with XH:XL pointer
	ldi   XL, LOW(TCPIPCommandFrame)
	ldi   XH, HIGH(TCPIPCommandFrame)
   lds   r16, TCPIPCommandFrameReadBytes
   add   XL, r16
   ldi   r16, 0x00
   adc   XH, r16

   ; Check for RX socket overflow (i.e. rotating buffer)
   ; Overflow if: Offset + Size > Mask + 1
   mov   r16, r21
   mov   r17, r22
   add   r16, r19
   adc   r17, r20
   cpi   r17, HIGH(TCPIPSocket0RxSize)
   brlo  TCPIPProcessReceiveEvent_JumpNoOverflow
   brne  TCPIPProcessReceiveEvent_Overflow
   cpi   r16, LOW(TCPIPSocket0RxSize)
   brlo  TCPIPProcessReceiveEvent_JumpNoOverflow
   breq  TCPIPProcessReceiveEvent_JumpNoOverflow
   rjmp  TCPIPProcessReceiveEvent_Overflow

TCPIPProcessReceiveEvent_JumpNoOverflow:
   jmp   TCPIPProcessReceiveEvent_NoOverflow
      
TCPIPProcessReceiveEvent_Overflow:

#ifdef TCPIP_WIZ5100_NO_AUTOINCREMENT

   ; Overflow case ont implemented with TCPIP_WIZ5100_NO_AUTOINCREMENT flag
   ; This should never occur if frame size is 64 bytes
   jmp   TCPIPProcessReceiveEvent_NoOverflow

#else

   ; Received bytes contained at the end of RX buffer and overflow to the beginning of buffer

   ; Bytes are read using the sequential access mode (i.e. if more than one byte to read)
   ; Compute Socket RX buffer start address (S0_RX_Base + Received data address Offset)
   ldi   r16, LOW(TCPIPSocket0RxBase)
   ldi   r17, HIGH(TCPIPSocket0RxBase)
   add   r16, r21
   adc   r17, r22

   ; Loop counter (i.e. number of bytes to read) is r24:r23
   ; Compute the number of bytes to read from the upper address
   ; Upper size is S0_RX_Size - Offset
   ldi   r23, LOW(TCPIPSocket0RxSize)
   ldi   r24, HIGH(TCPIPSocket0RxSize)
   sub   r23, r19
   sbc   r24, r20
   push  r23               ; Save the number of bytes to read at the upper address
   push  r24

   ; Read the first byte
   ; Check for only one byte to read in the upper memory block
   cpi   r24, 0x00
   brne  TCPIPProcessReceiveEvent_OverflowStartUpperLoop
   cpi   r23, 0x01
   brne  TCPIPProcessReceiveEvent_OverflowStartUpperLoop

   ; Only one byte to read in the upper memory block
   call  W5100ReadByte         ; r18 contains the byte
   st    X, r18
   jmp   TCPIPProcessReceiveEvent_OverflowInitLowerLoop

TCPIPProcessReceiveEvent_OverflowStartUpperLoop:
   ; More than one byte to read in the upper memory block
   call  W5100ReadFirstByte         ; r18 contains the byte
   st    X+, r18

   ldi   r16, 0x00                  ; Decrement loop counter
   dec   r23
   brne  TCPIPProcessReceiveEvent_OverflowUpperLoop
   cpi   r24, 0x00
   breq  TCPIPProcessReceiveEvent_OverflowInitLowerLoop
   dec   r24

TCPIPProcessReceiveEvent_OverflowUpperLoop:
   cpi   r23, 0x01                  ; Is last byte to read
   brne  TCPIPProcessReceiveEvent_OverflowUpperLoopRead
   cpi   r24, 0x00
   brne  TCPIPProcessReceiveEvent_OverflowUpperLoopRead
   ldi   r16, 0x01                  ; Last byte to read

TCPIPProcessReceiveEvent_OverflowUpperLoopRead:
   call  W5100ReadNextByte          ; r18 contains the byte
   st    X+, r18

   ldi   r16, 0x00                  ; Decrement loop counter
   dec   r23
   brne  TCPIPProcessReceiveEvent_OverflowUpperLoop
   cpi   r24, 0x00
   breq  TCPIPProcessReceiveEvent_OverflowInitLowerLoop
   dec   r24
   jmp   TCPIPProcessReceiveEvent_OverflowUpperLoop

TCPIPProcessReceiveEvent_OverflowInitLowerLoop:
   ; Compute the number of bytes to read from the lower address
   ; The number of left bytes to read is:
   ; number of received bytes - number of bytes read at upper memory address
   pop   r16               ; Retrieve the number of bytes to read at the upper address
   pop   r17
   mov   r23, r19
   mov   r24, r20
   sub   r23, r16
   sbc   r24, r17

   ; Bytes are read from the Socket 0 RX base address
   ldi   r16, LOW(TCPIPSocket0RxBase)
   ldi   r17, HIGH(TCPIPSocket0RxBase)

   ; Read the first byte
   ; Check for only one byte to read in the lower memory block
   cpi   r24, 0x00
   brne  TCPIPProcessReceiveEvent_OverflowStartLowerLoop
   cpi   r23, 0x01
   brne  TCPIPProcessReceiveEvent_OverflowStartLowerLoop

   ; Only one byte to read in the lower memory block
   call  W5100ReadByte         ; r18 contains the byte
   st    X, r18
   jmp   TCPIPProcessReceiveEvent_BytesRead

TCPIPProcessReceiveEvent_OverflowStartLowerLoop:
   ; More than one byte to read in the lower memory block
   call  W5100ReadFirstByte         ; r18 contains the byte
   st    X+, r18

   ldi   r16, 0x00                  ; Decrement loop counter
   dec   r23
   brne  TCPIPProcessReceiveEvent_OverflowLowerLoop
   cpi   r24, 0x00
   breq  TCPIPProcessReceiveEvent_BytesRead
   dec   r24

TCPIPProcessReceiveEvent_OverflowLowerLoop:
   cpi   r23, 0x01                  ; Is last byte to read
   brne  TCPIPProcessReceiveEvent_OverflowLowerLoopRead
   cpi   r24, 0x00
   brne  TCPIPProcessReceiveEvent_OverflowLowerLoopRead
   ldi   r16, 0x01                  ; Last byte to read

TCPIPProcessReceiveEvent_OverflowLowerLoopRead:
   call  W5100ReadNextByte          ; r18 contains the byte
   st    X+, r18

   ldi   r16, 0x00                  ; Decrement loop counter
   dec   r23
   brne  TCPIPProcessReceiveEvent_OverflowLowerLoop
   cpi   r24, 0x00
   breq  TCPIPProcessReceiveEvent_BytesRead
   dec   r24
   jmp   TCPIPProcessReceiveEvent_OverflowLowerLoop

#endif


TCPIPProcessReceiveEvent_NoOverflow:
   ; Received bytes contained in a contiguous data block
   ; NOTE: No overflow occurs if the frame size is 8, 16, 32, 64 or 128 bytes (on reset the
   ;       WIZ5100 always starts at 0 address offset for TX buffer).

#ifdef TCPIP_WIZ5100_NO_AUTOINCREMENT

   ; Loop with ReadByte instead of autoincrement mode mode

   ; Compute Socket RX buffer start address (S0_RX_Base + Received data address Offset)
   ldi   r16, LOW(TCPIPSocket0RxBase)
   ldi   r17, HIGH(TCPIPSocket0RxBase)
   add   r16, r21
   adc   r17, r22

   ; Loop counter (i.e. number of bytes to read) is r24:r23
   mov   r23, r19
   mov   r24, r20

TCPIPProcessReceiveEvent_ReadNextByte:
   call  W5100ReadByte
   st    X+, r18

   ; Prepare for next byte read (i.e. increment address to read in RX memory)
   inc   r16         
   ldi   r18, 0x00
   adc   r17, r18

   ; Decrement loop counter
   dec   r23
   brne  TCPIPProcessReceiveEvent_ReadNextByte
   cpi   r24, 0x00
   breq  TCPIPProcessReceiveEvent_BytesRead
   dec   r24
   jmp   TCPIPProcessReceiveEvent_ReadNextByte

#else

   ; Bytes are read using the sequential access mode (i.e. if more than one byte to read)
   ; Compute Socket RX buffer start address (S0_RX_Base + Received data address Offset)
   ldi   r16, LOW(TCPIPSocket0RxBase)
   ldi   r17, HIGH(TCPIPSocket0RxBase)
   add   r16, r21
   adc   r17, r22

   ; Loop counter (i.e. number of bytes to read) is r24:r23
   mov   r23, r19
   mov   r24, r20

   ; Read the first byte
   ; Check for only one byte to read
   cpi   r24, 0x00
   brne  TCPIPProcessReceiveEvent_NoOverflowStartLoop
   cpi   r23, 0x01
   brne  TCPIPProcessReceiveEvent_NoOverflowStartLoop

   ; Only one byte to read
   call  W5100ReadByte         ; r18 contains the byte
   st    X, r18
   jmp   TCPIPProcessReceiveEvent_BytesRead

TCPIPProcessReceiveEvent_NoOverflowStartLoop:
   ; More than one byte to read
   call  W5100ReadFirstByte         ; r18 contains the byte
   st    X+, r18

   ldi   r16, 0x00                  ; Decrement loop counter
   dec   r23
   brne  TCPIPProcessReceiveEvent_NoOverflowLoop
   cpi   r24, 0x00
   breq  TCPIPProcessReceiveEvent_BytesRead
   dec   r24

TCPIPProcessReceiveEvent_NoOverflowLoop:
   cpi   r23, 0x01                  ; Is last byte to read
   brne  TCPIPProcessReceiveEvent_NoOverflowLoopRead
   cpi   r24, 0x00
   brne  TCPIPProcessReceiveEvent_NoOverflowLoopRead
   ldi   r16, 0x01                  ; Last byte to read

TCPIPProcessReceiveEvent_NoOverflowLoopRead:
   call  W5100ReadNextByte          ; r18 contains the byte
   st    X+, r18

   ldi   r16, 0x00                  ; Decrement loop counter
   dec   r23
   brne  TCPIPProcessReceiveEvent_NoOverflowLoop
   cpi   r24, 0x00
   breq  TCPIPProcessReceiveEvent_BytesRead
   dec   r24
   jmp   TCPIPProcessReceiveEvent_NoOverflowLoop

#endif

TCPIPProcessReceiveEvent_BytesRead:

   ; All received bytes are read from RX buffer
   ; Increase the RX Read Pointer value with the number of bytes to read
   ; Socket 0 RX Read Pointer Register address is 0x0428-0x0429
   ; The address '0x0428' must be written first (MSB of read pointer)
   ; NOTE: 
   ;  - The current Read Pointer value have been stored on stack
   pop   r22                   ; Current register 0x0429 value of S0_RX_RD in r22 (LSB)
   pop   r21                   ; Current register 0x0428 value of S0_RX_RD in r21 (MSB)
   add   r22, r19              ; r19 contains the number of bytes read
   ldi   r16, 0x00
   adc   r21, r16


; Debug -> check for fragmented frame
   cpi   r19, 0x40  ; 64 bytes
   breq  TCPIPProcessReceiveEvent_dbgNotFragmented
   nop   ; fragmented (for breakpoint)
   jmp   TCPIPProcessReceiveEvent_dbgNext
TCPIPProcessReceiveEvent_dbgNotFragmented:
   nop   ; fragmented (for breakpoint)
TCPIPProcessReceiveEvent_dbgNext:
; End debug


   ldi   r16, 0x28             ; Write in 0x0428 register
   ldi   r17, 0x04
   mov   r18, r21
   call  W5100WriteByte        
   mov   r18, r22              ; Write in 0x0429 register
   inc   r16
   call  W5100WriteByte        

   ; Inform the W5100 that RX bytes are copied by issuing a RECV command.
   ; RECV command is launched using the Socket 0 Command Register (address 0x0401)
   ; NOTE: The RECV command should work at all times (i.e. status register not checked
   ;       after command launched)
   ldi   r16, 0x01          ; Write in 0x0401 register
   ldi   r17, 0x04
   ldi   r18, 0x40          ; RECV command is 0x40
   call  W5100WriteByte

   ; Bytes are read
   ; Update 'TCPIPCommandFrameReadBytes' and check if the whole frame is received
   ; The 'TCPIPCommandFrameReadBytes' variable value is not 0 only if the
   ; 'TCPIPCommandFrame' buffer is not containing a whole command frame
   lds   r16, TCPIPCommandFrameReadBytes
   add   r16, r19
   cpi   r16, TCPIPFrameSize
   brne  TCPIPProcessReceiveEvent_PartialFrameReceived

   ; Whole 'Command Frame' received
   ldi   r16, 00                                ; 'TCPIPCommandFrameReadBytes' set to 0
   sts   TCPIPCommandFrameReadBytes, r16
   ldi   r16, TCPIP_SOCKETSTATE_CMDRECEIVED     ; Update Socket 0 state
   sts   TCPIPSocketState, r16
   ldi   r16, 0x01                              ; Notify the application for new 'Command Frame'
   sts   TCPIPCommandReceived, r16
   jmp   TCPIPProcessReceiveEvent_Exit

TCPIPProcessReceiveEvent_PartialFrameReceived:
   ; Not all data for the 'Command Frame' received
   ; Update the Socket 0 state for waiting the end of the frame
   sts   TCPIPCommandFrameReadBytes, r19
   ldi   r16, TCPIP_SOCKETSTATE_RECEIVING     ; Update Socket 0 state
   sts   TCPIPSocketState, r16

TCPIPProcessReceiveEvent_Exit:
   pop   XH
   pop   XL
   pop   r24
   pop   r23
   pop   r22
   pop   r21
   pop   r20
   pop   r19

   ret

; Function called by 'TCPIPSocketEvent' interrupt handler for processing a timeout event
;
; This function is called when a send or disconnect command has timed out on the Socket 0.
; Typically this occurs when connection to the remote peer is lost (most of the times 
; because remote peer has terminated without disconnecting the socket).
; This function does the following:
;   - The socket 0 is closed (forced close)
;   - The TCPIP server is restarted. By design, this event occurs only on a started server.
;     This is an abnormal situation and the server has to be restarted (i.e. ready to accept
;     a new connection).
; 
; NOTE: 
;  - This function is called only if current socket state is valid for the operation
;  - Registers r16, r17, r18 are already saved by the caller function and this function
;    is allowed to modify them.
TCPIPProcessTimeoutEvent:

   push  r16
   push  r17
   push  r18

   ; 1- Close the socket
   ; Send CLOSE command to Socket 0
   ; The CLOSE command is launched using the Socket 0 Command Register (address 0x0401)
   ; NOTE: The CLOSE command should work at all times (i.e. status register not checked
   ;       after command launched)
   ldi   r16, 0x01          ; Write in 0x0401 register
   ldi   r17, 0x04
   ldi   r18, 0x10          ; CLOSE command is 0x10
   call  W5100WriteByte

   ; 2- The socket 0 is stopped
   ; Update the 'TCPIPSocketState' state variable for server stopped
   ldi   r16, TCPIP_SOCKETSTATE_NOTSTARTED
   sts   TCPIPSocketState, r16

   ; 3- Restart the server
   call  TCPIPProcessStartServer

   pop   r18
   pop   r17
   pop   r16
   ret

; Function called by 'TCPIPSocketEvent' interrupt handler for processing a send OK event
;
; This function is called when all data have been sent on the Socket 0 (i.e. all data in
; the TX buffer of Socket 0 are sent).
; The send operation has been launched by call to 'TCPIPSendReply' function.
; This function does the following:
;   - The 'TCPIPSocketState' variable is updated
;   - The 'TCPIPCommandReceived' shared variable is updated (i.e. the 'Command/Reply'
;     sequence is terminated and the automaton is ready to receive a new command from 
;     the client).
;
; NOTE: 
;  - This function is called only if current socket state is valid for the operation
;  - The function is called in a critical section
;  - Registers r16, r17, r18 are already saved by the caller function and this function
;    is allowed to modify them.
TCPIPProcessSentEvent:

   ; Note: 'TCPIPCommandReceived' shared variable accessed in critical section
   ;       (i.e. polled by 'InputPolling' interrupt) 
   ; The reply has been sent so command processing is terminated
   ; Clear 'TCPIPCommandReceived' to allow a new command notify to the application.
   ldi   r16, 0x00
   sts   TCPIPCommandReceived, r16

   ; Socket state changed from 'TCPIP_SOCKETSTATE_SENDINGREPLY' to 'TCPIP_SOCKETSTATE_ESTABLISHED
   ldi   r16, TCPIP_SOCKETSTATE_ESTABLISHED
   sts   TCPIPSocketState, r16

   ret

;******************************************************************************
; WIZnet 5100 Driver Functions (low level)
;****************************************************************************** 

; Function for resetting the W5100 device
; 
; The reset operation do the following:
;  - Hardware reset (i.e. electrical reset applied on W5100 pin)
;  - Activation of the Indirect Bus Mode (to access the W5100 registers using the 
;    indirect mode = only A0-1 pins of the address bus are connected to the MCU).
;  - Set control bus pins for steady state of the W5100 in high impedence 
;    (i.e. chip not selected)
;
; NOTE: 
;  - The Interrupt Mask Register is not modified (all interrupts are disabled).
;    Interrupts will be enabled according to open sockets.
;  - The 'WIZDriverCtrlPortData' direction must be already in output direction
;    (direction set on program initialization)
W5100Reset:

   push  r16
   cli         ; Interrupts not allowed during the reset

   ; 1- Hardware reset
   ; Make sure that CS, RD, WR and Reset pins are at level 1
   ; NOTE: 
   ;  - They should be because it was part of program initialization and them
   ;    the idle state level (i.e. chip not selected)
   ;  - This is to be sure to perform a clean Reset cycle
   ldi   r16, (1 << WIZDriverCtrlCS) | (1 << WIZDriverCtrlRD) | (1 << WIZDriverCtrlWR) | (1 << WIZDriverCtrlReset)
   sts   WIZDriverCtrlPortData, r16

   ; Apply the reset timing:
   ;  -  Set Reset pin low for 2 탎ec
   ;  - Wait 10 msec for W5100 internal reset processing
   ldi   r16, (1 << WIZDriverCtrlCS) | (1 << WIZDriverCtrlRD) | (1 << WIZDriverCtrlWR)
   sts   WIZDriverCtrlPortData, r16

   nop                  ; 4 wait cycles (suitable for up to 16MHz MCU)
   nop
   nop
   nop

   ldi   r16, (1 << WIZDriverCtrlCS) | (1 << WIZDriverCtrlRD) | (1 << WIZDriverCtrlWR) | (1 << WIZDriverCtrlReset)
   sts   WIZDriverCtrlPortData, r16

   ; Reset triggered, wait for W5100 internal reset processing
   ldi   r16, 20        ; 2 msec wait done 5 times
   call  W5100Wait
   call  W5100Wait
   call  W5100Wait
   call  W5100Wait
   call  W5100Wait

   ; 2- Set Indirect Bus Mode (i.e. initialize the MR register)
   ldi   r16, 0b11111111                 ; Data port in output mode
   sts   WIZDriverDataPortDir, r16
   ldi   r16, 0b00000001                 ; Value to write in MR register:
                                         ;  - bit 0 = Indirect I/F bus mode
   sts   WIZDriverDataPortData, r16      ; Mode available on data bus

   ; Set register MR register address on A0-A1
   ; Address must be present for at least 7ns before triggering the register write
   ; (no additional cycle required with ATMega frequency)
   ldi   r16, (1 << WIZDriverCtrlCS) | (1 << WIZDriverCtrlRD) | (1 << WIZDriverCtrlWR) | (1 << WIZDriverCtrlReset)
   sts   WIZDriverCtrlPortData, r16

   ; Trigger the write to register (i.e. set Mode in MR)
   ;  - No minimum delay betwwen CS and WR 
   ;  - Minimum cycle time 70ns
   ldi   r16, (1 << WIZDriverCtrlRD) | (1 << WIZDriverCtrlReset)
   sts   WIZDriverCtrlPortData, r16
   nop                                       ; 1 cycle to allow data write
   ldi   r16, (1 << WIZDriverCtrlCS) | (1 << WIZDriverCtrlRD) | (1 << WIZDriverCtrlWR) | (1 << WIZDriverCtrlReset)
   sts   WIZDriverCtrlPortData, r16

   ldi   r16, 0b00000000                 ; Data port in input mode (high impedence steady state)
   sts   WIZDriverDataPortDir, r16


; Debug: Read MR value to validate write and read timings
;
;#message "TO DO: REMOVE DBG -> W5100Reset write/read timings in direct address mode (read value displayed on port L)"
;
;  ldi   r16, 0b00000000                 ; Data port in input mode
;  sts   WIZDriverDataPortDir, r18
;
;  sts   WIZDriverDataPortDir, r16       ; clear data port (just be be sure, because we will read data port input value)
;
;
;
;  ; Set register MR register address on A0-A1
;  ; Address must be present for at least 7ns before triggering the register write
;  ; (no additional cycle required with ATMega frequency)
;  ldi   r16, (1 << WIZDriverCtrlCS) | (1 << WIZDriverCtrlRD) | (1 << WIZDriverCtrlWR) | (1 << WIZDriverCtrlReset)
;  sts   WIZDriverCtrlPortData, r16
;
;  ; Trigger the read from register (i.e. set Mode in MR)
;  ;  - No minimum delay betwwen CS and RD
;  ;  - Minimum cycle time 70ns
;  ldi   r16, (1 << WIZDriverCtrlWR) | (1 << WIZDriverCtrlReset)
;  sts   WIZDriverCtrlPortData, r16
;  nop                                       ; 1 cycle to allow data read
;
;  ; Read the data available on W5100 data bus (i.e. load Atmel's 'WIZDriverDataPortData' port)
;  push  r18
;  lds   r18, WIZDriverDataPortPins    ; WIZDriverDataPortData -> NOK for read, use PINS!!!
;
;  ; Terminate the read cycle
;  ldi   r16, (1 << WIZDriverCtrlCS) | (1 << WIZDriverCtrlRD) | (1 << WIZDriverCtrlWR) | (1 << WIZDriverCtrlReset)
;  sts   WIZDriverCtrlPortData, r16
;
;  ; display read value on port
;  sts   PORTL, r18
;
;  pop   r18    ; Restore caller's value
; end debug


; Debug: Write/read GAR0 (addr: 0x0001) value using indirect address mode to validate addressing and timings
;
;#message "TO DO: REMOVE DBG -> W5100Reset write/read timings in indirect address mode (read value displayed on port L)"
;
;  push  r17
;  push  r18
;
;  ; Write
;  ldi   r16, 0x01      ; Register r16 is the LSB of the address to write
;  ldi   r17, 0x00      ; Register r17 is the MSB of the address to write
;  ldi   r18, 0xAF  ; Value to write
;  call  W5100WriteByte
;
;  ; Read
;  ldi   r16, 0x01      ; Register r16 is the LSB of the address to read
;  ldi   r17, 0x00      ; Register r17 is the MSB of the address to read
;  ldi   r18, 0x00      ; Clear return value (just to be sure)
;  call  W5100ReadByte
;
;  ; Display read byte on port L
;  sts   PORTL, r18
;
;  pop   r18
;  pop   r17
; End debug


; Debug: Write/read GAR0-3 (addr: 0x0001) value using sequencial indirect address mode to validate addressing and timings
;
;#message "TO DO: REMOVE DBG -> W5100Reset write/read timings in sequential indirect address mode (read value displayed on port L)"
;
;  push  r17
;  push  r18
;
;  ; Normal write
;;  ldi   r16, 0x01      ; Register r16 is the LSB of the address to write
;;  ldi   r17, 0x00      ; Register r17 is the MSB of the address to write
;;  ldi   r18, 0xA0  ; Value to write
;;  call  W5100WriteByte
;;
;;  ldi   r16, 0x02      ; Register r16 is the LSB of the address to write
;;  ldi   r17, 0x00      ; Register r17 is the MSB of the address to write
;;  ldi   r18, 0xA1  ; Value to write
;;  call  W5100WriteByte
;
;
;  ; Sequential Write
;  ldi   r16, 0x01              ; Register r16 is the LSB of the address to write
;  ldi   r17, 0x00              ; Register r17 is the MSB of the address to write
;  ldi   r18, 0xA0              ; Value to write
;  call  W5100WriteFirstByte    ; write 1st byte
;
;
;
;;  ; Read MR value to validate write and read timings
;;  ldi   r16, 0b00000000                 ; Data port in input mode
;;  sts   WIZDriverDataPortDir, r18
;;  sts   WIZDriverDataPortDir, r16       ; clear data port (just be be sure, because we will read data port input value)
;;
;;  ; Set register MR register address on A0-A1
;;  ; Address must be present for at least 7ns before triggering the register write
;;  ; (no additional cycle required with ATMega frequency)
;;  ldi   r16, (1 << WIZDriverCtrlCS) | (1 << WIZDriverCtrlRD) | (1 << WIZDriverCtrlWR) | (1 << WIZDriverCtrlReset)
;;  sts   WIZDriverCtrlPortData, r16
;;
;;  ; Trigger the read from register (i.e. set Mode in MR)
;;  ;  - No minimum delay betwwen CS and RD
;;  ;  - Minimum cycle time 70ns
;;  ldi   r16, (1 << WIZDriverCtrlWR) | (1 << WIZDriverCtrlReset)
;;  sts   WIZDriverCtrlPortData, r16
;;  nop                                       ; 1 cycle to allow data read
;;
;;  ; Read the data available on W5100 data bus (i.e. load Atmel's 'WIZDriverDataPortData' port)
;;  push  r18
;;  lds   r18, WIZDriverDataPortPins    ; WIZDriverDataPortData -> NOK for read, use PINS!!!
;;
;;  ; Terminate the read cycle
;;  ldi   r16, (1 << WIZDriverCtrlCS) | (1 << WIZDriverCtrlRD) | (1 << WIZDriverCtrlWR) | (1 << WIZDriverCtrlReset)
;;  sts   WIZDriverCtrlPortData, r16
;;
;;  ; display read value on port
;;  sts   PORTL, r18
;
;
;
;
;  ldi   r16, 0xA1              ; Register r16 contains the next byte to write
;  ldi   r17, 0x00              ; Register r17 indicates if this write is for the last byte of the block
;  call  W5100WriteNextByte     ; Write next byte
;  ldi   r16, 0xA2
;  ldi   r17, 0x00
;  call  W5100WriteNextByte     ; Write next byte
;  ldi   r16, 0xA3
;  ldi   r17, 0x01
;  call  W5100WriteNextByte     ; Write last byte
;
;;  ; Normal Read
;;  ldi   r16, 0x01      ; Register r16 is the LSB of the address to read
;;  ldi   r17, 0x00      ; Register r17 is the MSB of the address to read
;;  ldi   r18, 0x00      ; Clear return value (just to be sure)
;;  call  W5100ReadByte
;;
;;;sts   PORTL, r18
;;
;;  ldi   r16, 0x02      ; Byte 1
;;  ldi   r17, 0x00
;;  ldi   r18, 0x00      ; Clear return value (just to be sure)
;;  call  W5100ReadByte
;;
;;;sts   PORTL, r18
;;
;;  ldi   r16, 0x03      ; Byte 2
;;  ldi   r17, 0x00
;;  ldi   r18, 0x00      ; Clear return value (just to be sure)
;;  call  W5100ReadByte
;;
;;;  sts   PORTL, r18
;;
;;  ldi   r16, 0x04      ; Byte 3
;;  ldi   r17, 0x00
;;  ldi   r18, 0x00      ; Clear return value (just to be sure)
;;  call  W5100ReadByte
;;
;;;  sts   PORTL, r18
;
;  ; Sequential Read
;  ldi   r16, 0x01      ; Register r16 is the LSB of the address to read
;  ldi   r17, 0x00      ; Register r17 is the MSB of the address to read
;  ldi   r18, 0x00      ; Clear return value (just to be sure)
;  call  W5100ReadFirstByte
;
;  ; Display read byte on port L  (byte 0)
;; sts   PORTL, r18
;
;  ldi   r16, 0x00           ; Register r16 indicates if this read is for the last byte of the block
;  ldi   r18, 0x00           ; Clear return value (just to be sure)
;  call  W5100ReadNextByte
;
;  ; Display read byte on port L (byte 1)
;; sts   PORTL, r18
;
;  ldi   r16, 0x00           ; Register r16 indicates if this read is for the last byte of the block
;  ldi   r18, 0x00           ; Clear return value (just to be sure)
;  call  W5100ReadNextByte
;
;  ; Display read byte on port L (byte 2)
;;  sts   PORTL, r18
;
;  ldi   r16, 0x01           ; Register r16 indicates if this read is for the last byte of the block
;  ldi   r18, 0x00           ; Clear return value (just to be sure)
;  call  W5100ReadNextByte
;
;  ; Display read byte on port L (byte 3)
; sts   PORTL, r18
;
;
;  pop   r18
;  pop   r17
;; End debug

   ; Done
   sei
   pop   r16
   ret


; Function for reading a byte at a specified W5100 memory address
; The function arguments are:
;   - Register r16 is the LSB of the address to read
;   - Register r17 is the MSB of the address to read
; 
; The function returns the following values:
;   - Register r18 contains the read byte
;
; By default (i.e. not in a block sequential access) the W5100 is configured 
; for random memory access (i.e. AI bit of Mode Register (MR) cleared).
W5100ReadByte:

   ; 1 - Write the MSB of the address to access in the IDM_AR0 register (register 
   ;     address 0x01)
   ; Prepare data (MSB) on the data port
   ldi   r18, 0b11111111                 ; Data port in output mode
   sts   WIZDriverDataPortDir, r18
   sts   WIZDriverDataPortData, r17      ; Address MSB

   ; Set register IDM_AR0 address on A0-A1
   ; Address must be present for at least 7ns before triggering the register write
   ; (no additional cycle required with ATMega frequency)
   ldi   r18, 0x01 | (1 << WIZDriverCtrlCS) | (1 << WIZDriverCtrlRD) | (1 << WIZDriverCtrlWR) | (1 << WIZDriverCtrlReset)
   sts   WIZDriverCtrlPortData, r18

   ; Trigger the write to register
   ;  - No minimum delay betwwen CS and WR 
   ;  - Minimum cycle time 70ns
   ldi   r18, 0x01 | (1 << WIZDriverCtrlRD) | (1 << WIZDriverCtrlReset)
   sts   WIZDriverCtrlPortData, r18
   nop                                       ; 1 cycle to allow data write
   ldi   r18, 0x01 | (1 << WIZDriverCtrlCS) | (1 << WIZDriverCtrlRD) | (1 << WIZDriverCtrlWR) | (1 << WIZDriverCtrlReset)
   
   ; 2 - Write the LSB of the address to access in the IDM_AR1 register (register
   ;     address 0x02)
   sts   WIZDriverDataPortData, r16      ; Address LSB

   ; Set register IDM_AR1 address on A0-A1
   ; Address must be present for at least 7ns before triggering the register write
   ; (no additional cycle required with ATMega frequency)
   ldi   r18, 0x02 | (1 << WIZDriverCtrlCS) | (1 << WIZDriverCtrlRD) | (1 << WIZDriverCtrlWR) | (1 << WIZDriverCtrlReset)
   sts   WIZDriverCtrlPortData, r18

   ; Trigger the write to register
   ;  - No minimum delay betwwen CS and WR 
   ;  - Minimum cycle time 70ns
   ldi   r18, 0x02 | (1 << WIZDriverCtrlRD) | (1 << WIZDriverCtrlReset)
   sts   WIZDriverCtrlPortData, r18
   nop                                       ; 1 cycle to allow data write
   ldi   r18, 0x02 | (1 << WIZDriverCtrlCS) | (1 << WIZDriverCtrlRD) | (1 << WIZDriverCtrlWR) | (1 << WIZDriverCtrlReset)

   ; 3 - Read the value in IDM_DR register (register address 0x03)
   ldi   r18, 0b00000000                 ; Data port in input mode
   sts   WIZDriverDataPortDir, r18

   ; Set register IDM_DR address on A0-A1
   ; Address must be present for at least 7ns before triggering the register write
   ; (no additional cycle required with ATMega frequency)
   ldi   r18, 0x03 | (1 << WIZDriverCtrlCS) | (1 << WIZDriverCtrlRD) | (1 << WIZDriverCtrlWR) | (1 << WIZDriverCtrlReset)
   sts   WIZDriverCtrlPortData, r18

   ; Trigger the read from register
   ;  - No minimum delay betwwen CS and WR 
   ;  - Minimum data output delay 80ns
   ldi   r18, 0x03 | (1 << WIZDriverCtrlWR) | (1 << WIZDriverCtrlReset)
   sts   WIZDriverCtrlPortData, r18
   nop                                       ; 1 cycle to allow data output on W5100 data bus

   ; Read the data available on W5100 data bus (i.e. load Atmel's 'WIZDriverDataPortData' port)
   lds   r18, WIZDriverDataPortPins
   push  r18                           ; Save read value

   ; Terminate the read cycle
   ldi   r18, 0x03 | (1 << WIZDriverCtrlCS) | (1 << WIZDriverCtrlRD) | (1 << WIZDriverCtrlWR) | (1 << WIZDriverCtrlReset)
   sts   WIZDriverCtrlPortData, r18

   pop   r18      ; Restore read value for return
   ret


; Function for reading the first byte of a specified W5100 memory block
; The function arguments are:
;   - Register r16 is the LSB of the address to read
;   - Register r17 is the MSB of the address to read
; 
; The function returns the following values:
;   - Register r18 contains the read byte
;
; This function activates sequential memory access mode of the W5100  
; (i.e. AI bit of Mode Register (MR) set).
; The sequential memory access mode will be terminated by calling the 
; 'W5100ReadNextByte' function and specifying 'last byte'.
W5100ReadFirstByte:

   ; 1- Activate the sequential memory access mode in MR register (register 
   ;    address 0x00)
   ; The next sequential address will be set in address registers after the next 'read'
   ; to data register.
   ; The subsequent call to the 'W5100ReadNextByte' function will automaticaly access 
   ; the next sequential address.
   ldi   r18, 0b11111111                 ; Data port in output mode
   sts   WIZDriverDataPortDir, r18
   ldi   r18, 0b00000011                 ; Value to write in MR register:
                                         ;  - bit 0 = Indirect I/F bus mode
                                         ;  - bit 1 = Address Auto Increment
   sts   WIZDriverDataPortData, r18      ; Mode available on data bus

   ; Set register MR register address on A0-A1
   ; Address must be present for at least 7ns before triggering the register write
   ; (no additional cycle required with ATMega frequency)
   ldi   r18, (1 << WIZDriverCtrlCS) | (1 << WIZDriverCtrlRD) | (1 << WIZDriverCtrlWR) | (1 << WIZDriverCtrlReset)
   sts   WIZDriverCtrlPortData, r18

   ; Trigger the write to register (i.e. set Mode in MR)
   ;  - No minimum delay betwwen CS and WR 
   ;  - Minimum cycle time 70ns
   ldi   r18, (1 << WIZDriverCtrlRD) | (1 << WIZDriverCtrlReset)
   sts   WIZDriverCtrlPortData, r18
   nop                                       ; 1 cycle to allow data write
   ldi   r18, (1 << WIZDriverCtrlCS) | (1 << WIZDriverCtrlRD) | (1 << WIZDriverCtrlWR) | (1 << WIZDriverCtrlReset)
   sts   WIZDriverCtrlPortData, r18

   ldi   r18, 0b00000000                 ; Data port in input mode (high impedence steady state)
   sts   WIZDriverDataPortDir, r18

   ; 2- Perform a standard 'ReadByte'
   call  W5100ReadByte

   ret

; Function for reading the next byte of a specified W5100 memory block
; The function arguments are:
;   - Register r16 indicates if this read is for the last byte of the block
;     (0 = not the last read, 1 = last read call).
; 
; The function returns the following values:
;   - Register r18 contains the read byte
;
; NOTES:
;  - There is no check to confirm that 'W5100ReadFirstByte' has been called before (the client
;    function has to be clean, typically no concurrency allowed on 'W5100xxx' low level functions).
;  - If the call is for the last byte of the block, this function deactivates the
;    sequential memory access mode of the W5100 (i.e. AI bit of Mode Register (MR) cleared).
W5100ReadNextByte:

   ; 1- Read the next sequencial byte
   ldi   r18, 0b00000000                ; Data port in input mode
   sts   WIZDriverDataPortDir, r18

   ; Set register IDM_DR address on A0-A1
   ; Address must be present for at least 7ns before triggering the register write
   ; (no additional cycle required with ATMega frequency)
   ldi   r18, 0x03 | (1 << WIZDriverCtrlCS) | (1 << WIZDriverCtrlRD) | (1 << WIZDriverCtrlWR) | (1 << WIZDriverCtrlReset)
   sts   WIZDriverCtrlPortData, r18

   ; Trigger the read from register
   ;  - No minimum delay betwwen CS and WR 
   ;  - Minimum data output delay 80ns
   ldi   r18, 0x03 | (1 << WIZDriverCtrlWR) | (1 << WIZDriverCtrlReset)
   sts   WIZDriverCtrlPortData, r18
   nop                                       ; 1 cycle to allow data output on W5100 data bus

   ; Read the data available on W5100 data bus (i.e. load Atmel's 'WIZDriverDataPortData' port)
   lds   r18, WIZDriverDataPortPins
   push  r18                ; Save read byte

   ; Terminate the read cycle
   ldi   r18, 0x03 | (1 << WIZDriverCtrlCS) | (1 << WIZDriverCtrlRD) | (1 << WIZDriverCtrlWR) | (1 << WIZDriverCtrlReset)
   sts   WIZDriverCtrlPortData, r18

   ; 2- Terminate sequencial memory access mode if required 
	cpi   r16, 0x00
	breq  W5100ReadNextByte_Exit

   ; Last block byte read, update mode in the MR register (register address 0x00)
   ldi   r18, 0b11111111                 ; Data port in output mode
   sts   WIZDriverDataPortDir, r18
   ldi   r18, 0b00000001                 ; Value to write in MR register:
                                         ;  - bit 0 = Indirect I/F bus mode
                                         ;  - bit 1 = Address Auto Increment
   sts   WIZDriverDataPortData, r18      ; Mode available on data bus

   ; Set register MR register address on A0-A1
   ; Address must be present for at least 7ns before triggering the register write
   ; (no additional cycle required with ATMega frequency)
   ldi   r18, (1 << WIZDriverCtrlCS) | (1 << WIZDriverCtrlRD) | (1 << WIZDriverCtrlWR) | (1 << WIZDriverCtrlReset)
   sts   WIZDriverCtrlPortData, r18

   ; Trigger the write to register (i.e. set Mode in MR)
   ;  - No minimum delay betwwen CS and WR 
   ;  - Minimum cycle time 70ns
   ldi   r18, (1 << WIZDriverCtrlRD) | (1 << WIZDriverCtrlReset)
   sts   WIZDriverCtrlPortData, r18
   nop                                       ; 1 cycle to allow data write
   ldi   r18, (1 << WIZDriverCtrlCS) | (1 << WIZDriverCtrlRD) | (1 << WIZDriverCtrlWR) | (1 << WIZDriverCtrlReset)
   sts   WIZDriverCtrlPortData, r18

   ldi   r18, 0b00000000                 ; Data port in input mode (high impedence steady state)
   sts   WIZDriverDataPortDir, r18

W5100ReadNextByte_Exit:
   pop   r18      ; Restore read byte for return
   ret


; Function for writing a byte to a specified W5100 memory address
; The function arguments are:
;   - Register r16 is the LSB of the address to write
;   - Register r17 is the MSB of the address to write
;   - Register r18 contains the byte to write
; 
; The function returns nothing
;
; By default (i.e. not in a block sequential access) the W5100 is configured 
; for random memory access (i.e. AI bit of Mode Register (MR) cleared).
W5100WriteByte:

   push  r19

   ; 1 - Write the MSB of the address to access in the IDM_AR0 register (register 
   ;     address 0x01)
   ; Prepare data (MSB) on the data port
   ldi   r19, 0b11111111                 ; Data port in output mode
   sts   WIZDriverDataPortDir, r19
   sts   WIZDriverDataPortData, r17      ; Address MSB

   ; Set register IDM_AR0 address on A0-A1
   ; Address must be present for at least 7ns before triggering the register write
   ; (no additional cycle required with ATMega frequency)
   ldi   r19, 0x01 | (1 << WIZDriverCtrlCS) | (1 << WIZDriverCtrlRD) | (1 << WIZDriverCtrlWR) | (1 << WIZDriverCtrlReset)
   sts   WIZDriverCtrlPortData, r19

   ; Trigger the write to register
   ;  - No minimum delay betwwen CS and WR 
   ;  - Minimum cycle time 70ns
   ldi   r19, 0x01 | (1 << WIZDriverCtrlRD) | (1 << WIZDriverCtrlReset)
   sts   WIZDriverCtrlPortData, r19
   nop                                       ; 1 cycle to allow data write
   ldi   r19, 0x01 | (1 << WIZDriverCtrlCS) | (1 << WIZDriverCtrlRD) | (1 << WIZDriverCtrlWR) | (1 << WIZDriverCtrlReset)
   
   ; 2 - Write the LSB of the address to access in the IDM_AR1 register (register
   ;     address 0x02)
   sts   WIZDriverDataPortData, r16      ; Address LSB

   ; Set register IDM_AR1 address on A0-A1
   ; Address must be present for at least 7ns before triggering the register write
   ; (no additional cycle required with ATMega frequency)
   ldi   r19, 0x02 | (1 << WIZDriverCtrlCS) | (1 << WIZDriverCtrlRD) | (1 << WIZDriverCtrlWR) | (1 << WIZDriverCtrlReset)
   sts   WIZDriverCtrlPortData, r19

   ; Trigger the write to register
   ;  - No minimum delay betwwen CS and WR 
   ;  - Minimum cycle time 70ns
   ldi   r19, 0x02 | (1 << WIZDriverCtrlRD) | (1 << WIZDriverCtrlReset)
   sts   WIZDriverCtrlPortData, r19
   nop                                       ; 1 cycle to allow data write
   ldi   r19, 0x02 | (1 << WIZDriverCtrlCS) | (1 << WIZDriverCtrlRD) | (1 << WIZDriverCtrlWR) | (1 << WIZDriverCtrlReset)

   ; 3 - Write the value in IDM_DR register (register address 0x03)
   ; Prepare the data on the W5100 data bus (i.e. set Atmel's 'WIZDriverDataPortData' port with data)
   ; REM: Data port already in output mode
   sts   WIZDriverDataPortData, r18

   ; Set register IDM_DR address on A0-A1
   ; Address must be present for at least 7ns before triggering the register write
   ; (no additional cycle required with ATMega frequency)
   ldi   r19, 0x03 | (1 << WIZDriverCtrlCS) | (1 << WIZDriverCtrlRD) | (1 << WIZDriverCtrlWR) | (1 << WIZDriverCtrlReset)
   sts   WIZDriverCtrlPortData, r19

   ; Trigger the write to register
   ;  - No minimum delay betwwen CS and WR 
   ;  - Minimum cycle time 70ns
   ldi   r19, 0x03 | (1 << WIZDriverCtrlRD) | (1 << WIZDriverCtrlReset)
   sts   WIZDriverCtrlPortData, r19
   nop                                       ; 1 cycle to allow data output on W5100 data bus
   ldi   r19, 0x03 | (1 << WIZDriverCtrlCS) | (1 << WIZDriverCtrlRD) | (1 << WIZDriverCtrlWR) | (1 << WIZDriverCtrlReset)
   sts   WIZDriverCtrlPortData, r19

   ; Restore input direction on data port (i.e. high impedence on steady state)
   ldi   r19, 0b00000000               ; Data port in input mode
   sts   WIZDriverDataPortDir, r19

   pop   r19
   ret

; Function for writing the first byte to a specified W5100 memory block
; The function arguments are:
;   - Register r16 is the LSB of the address to write
;   - Register r17 is the MSB of the address to write
;   - Register r18 contains the byte to write
; 
; The function returns nothing
; 
; This function activates sequential memory access mode of the W5100  
; (i.e. AI bit of Mode Register (MR) set).
; The sequential memory access mode will be terminated by calling the 
; 'W5100ReadNextByte' function and specifying 'last byte'.
W5100WriteFirstByte:


   ; 1- Activate the sequential memory access mode in MR register (register 
   ;    address 0x00)
   ; The next sequential address will be set in address registers after the next 'write'
   ; in data register.
   ; A subsequent call to the 'W5100WriteNextByte' function will automaticaly access 
   ; the next sequential address and increment address after.
   push  r18                             ; Preserve the r18 argument
   ldi   r18, 0b11111111                 ; Data port in output mode
   sts   WIZDriverDataPortDir, r18
   ldi   r18, 0b00000011                 ; Value to write in MR register:
                                         ;  - bit 0 = Indirect I/F bus mode
                                         ;  - bit 1 = Address Auto Increment
   sts   WIZDriverDataPortData, r18      ; Mode available on data bus

   ; Set register MR register address on A0-A1
   ; Address must be present for at least 7ns before triggering the register write
   ; (no additional cycle required with ATMega frequency)
   ldi   r18, (1 << WIZDriverCtrlCS) | (1 << WIZDriverCtrlRD) | (1 << WIZDriverCtrlWR) | (1 << WIZDriverCtrlReset)
   sts   WIZDriverCtrlPortData, r18

   ; Trigger the write to register (i.e. set Mode in MR)
   ;  - No minimum delay betwwen CS and WR 
   ;  - Minimum cycle time 70ns
   ldi   r18, (1 << WIZDriverCtrlRD) | (1 << WIZDriverCtrlReset)
   sts   WIZDriverCtrlPortData, r18
   nop                                       ; 1 cycle to allow data write
   ldi   r18, (1 << WIZDriverCtrlCS) | (1 << WIZDriverCtrlRD) | (1 << WIZDriverCtrlWR) | (1 << WIZDriverCtrlReset)
   sts   WIZDriverCtrlPortData, r18

   ldi   r18, 0b00000000                 ; Data port in input mode (high impedence steady state)
   sts   WIZDriverDataPortDir, r18

   pop   r18   ; Restore the r18 argument

   ; 2- Perform a standard 'WriteByte'
   call  W5100WriteByte

   ret

; Function for writing the next byte to a specified W5100 memory block
; The function arguments are:
;   - Register r16 contains the byte to write
;   - Register r17 indicates if this write is for the last byte of the block
;     (0 = not the last write, 1 = last write call).
; 
; The function returns nothing
; 
; NOTES:
;  - There is no check to confirm that 'W5100WriteFirstByte' has been called before (the client
;    function has to be clean, typically no concurrency allowed on 'W5100xxx' low level functions).
;  - If the call is for the last byte of the block, this function deactivates the
;    sequential memory access mode of the W5100 (i.e. AI bit of Mode Register (MR) cleared).
W5100WriteNextByte:

   push r18

   ; 1- Write the next sequencial byte
   ldi   r18, 0b11111111                ; Data port in output mode
   sts   WIZDriverDataPortDir, r18

   ; Prepare the data on the W5100 data bus (i.e. set Atmel's 'WIZDriverDataPortData' port with data)
   ; REM: Data port already in output mode
   sts   WIZDriverDataPortData, r16

   ; Set register IDM_DR address on A0-A1 (register address 0x03)
   ; Address must be present for at least 7ns before triggering the register write
   ; (no additional cycle required with ATMega frequency)
   ldi   r18, 0x03 | (1 << WIZDriverCtrlCS) | (1 << WIZDriverCtrlRD) | (1 << WIZDriverCtrlWR) | (1 << WIZDriverCtrlReset)
   sts   WIZDriverCtrlPortData, r18

   ; Trigger the write to register
   ;  - No minimum delay betwwen CS and WR 
   ;  - Minimum cycle time 70ns
   ldi   r18, 0x03 | (1 << WIZDriverCtrlRD) | (1 << WIZDriverCtrlReset)
   sts   WIZDriverCtrlPortData, r18
   nop                                       ; 1 cycle to allow data output on W5100 data bus
   ldi   r18, 0x03 | (1 << WIZDriverCtrlCS) | (1 << WIZDriverCtrlRD) | (1 << WIZDriverCtrlWR) | (1 << WIZDriverCtrlReset)
   sts   WIZDriverCtrlPortData, r18

   ; 2- Terminate sequencial memory access mode if required 
	cpi   r17, 0x00
	breq  W5100WriteNextByte_Exit

   ; Last block byte read, update mode in the MR register (register address 0x00)
   ; REM: The Data port is already in output mode
   ldi   r18, 0b00000001                 ; Value to write in MR register:
                                         ;  - bit 0 = Indirect I/F bus mode
                                         ;  - bit 1 = Address Auto Increment
   sts   WIZDriverDataPortData, r18      ; Mode available on data bus

   ; Set register MR register address on A0-A1
   ; Address must be present for at least 7ns before triggering the register write
   ; (no additional cycle required with ATMega frequency)
   ldi   r18, (1 << WIZDriverCtrlCS) | (1 << WIZDriverCtrlRD) | (1 << WIZDriverCtrlWR) | (1 << WIZDriverCtrlReset)
   sts   WIZDriverCtrlPortData, r18

   ; Trigger the write to register (i.e. set Mode in MR)
   ;  - No minimum delay betwwen CS and WR 
   ;  - Minimum cycle time 70ns
   ldi   r18, (1 << WIZDriverCtrlRD) | (1 << WIZDriverCtrlReset)
   sts   WIZDriverCtrlPortData, r18
   nop                                       ; 1 cycle to allow data write
   ldi   r18, (1 << WIZDriverCtrlCS) | (1 << WIZDriverCtrlRD) | (1 << WIZDriverCtrlWR) | (1 << WIZDriverCtrlReset)
   sts   WIZDriverCtrlPortData, r18

   ; Restore input direction on data port (i.e. high impedence on steady state)
   ldi   r18, 0b00000000              
   sts   WIZDriverDataPortDir, r18

W5100WriteNextByte_Exit:
   pop   r18 
   ret


; Function for non time critical wait period
; 
; The function arguments are:
;   - Register r16 contains the minimum wait duration (the unit is 100탎ec).
; 
; This function waits at least for a specified duration.
; The duration may be more than the specified value if interrupts occur.
; The duration range is from 100탎 to 25.6ms (by 100탎 step)
W5100Wait:
	push 	r16		; 2 cycles
   push  r17      ; 2 cycles

; Main loop (number of 10탎 steps)
W5100Wait_MainLoop:

#ifdef CLOCK_FREQUENCY_4MHZ
	ldi 	r17, 40		; 1 cycle
#endif

#ifdef CLOCK_FREQUENCY_8MHZ
	ldi 	r17, 80		; 1 cycle
#endif

#ifdef CLOCK_FREQUENCY_10MHZ
	ldi 	r17, 100		; 1 cycle
#endif

; 10 cycle loop
W5100Wait_Loop:
	nop 			;1 cycle
	nop
	nop
	nop
	nop
	nop
	nop
	dec 	r17		; 1 cycle
	brne 	W5100Wait_Loop	; ((10 * loop count) + 1) cycles
	dec 	r16		; 1 cycle
	brne 	W5100Wait_MainLoop 
	
	pop 	r17     	; 2 cycles
	pop 	r16     	; 2 cycles
	ret 			   ; 4 cycles



