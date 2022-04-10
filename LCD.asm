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
;  - LCD low level functions
;  - LCD string display functions
;******************************************************************************


;******************************************************************************
; LCD String Display Functions
;****************************************************************************** 
	
; Function for updating the LCD Device display with the text stored in the 
; LCD Application Area buffer
; This function is synchroneous but it can be interrupted and re-entered.
; The function exists only when display synchronization is done (i.e. if
; re-entered the synchronization is guaranteed with the most recent text
; contained in the LCD Application Area buffer.
; NOTE: This function can be re-entered but it is not recursive (so it will
;       never produce stack overflow).
LCDUpdateDisplay:
	; Check if re-entering the function
	; Re-entry semaphore accessed in non-interruptible section (i.e. mutex)
	ENTER_CRITICAL_SECTION
	push r16
	lds r16, LCDUpdateDisplayCalled
	cpi r16, 0
	breq LCDUpdateDisplay_UpdateAllowed
	
   ; Re-entering function
   ldi r16, 0x01	; Set re-entered flag
   sts LCDUpdateDisplayReEntered, r16

	; Exit re-entered call
	pop   r16
	LEAVE_CRITICAL_SECTION
	ret
	
LCDUpdateDisplay_UpdateAllowed:
	; First call (not re-entering), proceed with the update
	ldi r16, 0x01	; Set re-entry semaphore
	sts LCDUpdateDisplayCalled, r16
	LEAVE_CRITICAL_SECTION	    	; End of critical section for re-entry semaphore access

	push r17	; Saved working registers
	push r18
	push r19
	push r20
	push r21
	push r22
	push YL
	push YH
	push ZL
	push ZH
	
LCDUpdateDisplay_CopyAppBuffer:
	; Copy the Application modified lines from the Application buffer to the
	; function buffer
	ENTER_CRITICAL_SECTION 	; Buffer copy in a critical section

	; Set pointers to buffers
	ldi ZL, LOW(LCDAppBuffer)	; Register Z is source buffer
	ldi ZH, HIGH(LCDAppBuffer)
	ldi YL, LOW(LCDUpdateDisplayBuffer)	; Register Y is destination buffer
	ldi YH, HIGH(LCDUpdateDisplayBuffer)

	; Registers:
	;  - r16 is for temporary
	;  - r17 is LCDAppBufferModifiedLines
	;  - r18 is line counter
	;  - r19 is line mask
	;  - r20 is character counter

	lds r17, LCDAppBufferModifiedLines 
	ldi r18, 0		; Reset line counter
	ldi r19, 0b00000001	; Corresponding line mask

LCDUpdateDisplay_CheckCopyLine:
	; Is line modified?
	push r17 		
	and r17, r19
	pop r17
	brne LCDUpdateDisplay_CopyLine	; Line modified, copy line
	
	; Line not modified, adjust pointers to buffers
	adiw ZL, LCDCharPerLineNumber
	adiw YL, LCDCharPerLineNumber
	rjmp LCDUpdateDisplay_SelectNextCopyLine

LCDUpdateDisplay_CopyLine:
	; Copy line
	ldi r20, LCDCharPerLineNumber
	 
LCDUpdateDisplay_CopyChar:
	ld r16, Z+
	st Y+, r16
	dec r20		; Next char
	brne LCDUpdateDisplay_CopyChar

LCDUpdateDisplay_SelectNextCopyLine:
	; Select next line
	inc r18
	lsl r19
	cpi r18, LCDLineNumber
	breq LCDUpdateDisplay_LinesCopied	; All lines copied
	rjmp LCDUpdateDisplay_CheckCopyLine

LCDUpdateDisplay_LinesCopied:
	; Synchronize the 'LinesToUpdate' flags	with the 'ModifiedLine' flags
	lds r16, LCDAppBufferModifiedLines 
	lds r17, LCDUpdateDisplayLinesToUpdate
	or r17, r16
	sts LCDUpdateDisplayLinesToUpdate, r17
	
	; Clear 'ModifiedLine' flags (i.e. the function is processing the new 
	; application text)
	ldi r16, 0
	sts LCDAppBufferModifiedLines, r16
	
	; Clear 'ReEntered' flag (i.e. if copy has been launched by reentry detection,
   ; the application text is now synchronized) 
	sts LCDUpdateDisplayReEntered, r16

	LEAVE_CRITICAL_SECTION	; Application text copied, give access back to application

	; LCD Device update loop:
	;  - For each line check if line is modified
	;  - If line is modified, for each character check if modified
	;  - If character modified, update it on the LCD device
	;  - Before incrementing to next line, check if function has been
	;    re-entered. If yes, restart loop on the first line.
	;
	; Registers:
	;  - r16 is for temporary
	;  - r17 is LCDUpdateDisplayLinesToUpdate
	;  - r18 is line counter
	;  - r19 is line mask
	;  - r20 is character counter
	;  - r21 is current X position on LCD device (0xFF indicates not set)
	;  - r22 is current Y position on LCD device (0xFF indicates not set)
	;  - r23 is for second temporary
	;  - Register Z is new text buffer	
	;  - Register Y is LCD device buffer

LCDUpdateDisplay_UpdateModifiedLines:	
	ldi r18, 0		; Reset line counter
	ldi r19, 0b00000001	; Corresponding line mask
	ldi ZL, LOW(LCDUpdateDisplayBuffer)	; Modified text pointer
	ldi ZH, HIGH(LCDUpdateDisplayBuffer)
	ldi YL, LOW(LCDDeviceBuffer)		; Current LCD device text pointer		
	ldi YH, HIGH(LCDDeviceBuffer)

LCDUpdateDisplay_CheckLine:
	; Check for function re-entry
	lds r16, LCDUpdateDisplayReEntered
	cpi r16, 0
	brne LCDUpdateDisplay_CopyAppBuffer	; Function has been re-entered:
										; synchronize again application 
										; text and restart LCD device 
										; update cycle

	; Is line modified?
	push r17 		
	and r17, r19
	pop r17
	brne LCDUpdateDisplay_LineModified

	; Line not modified, prepare access to next line : adjust buffer pointers
	; (in case of modified line these pointers have been incremented during 
	; line copy)
	adiw ZL, LCDCharPerLineNumber
	adiw YL, LCDCharPerLineNumber
	
	; Select and update next line it if necessary
	rjmp LCDUpdateDisplay_SelectNextLine
	
LCDUpdateDisplay_LineModified:
	; Send modified line to LCD device
	; Line characters are compared from new text line and current LCD
	; device text line. 
	; Only modified characters are updated
	ldi r21, 0xFF 	; Cursor position on LCD device undefined
	ldi r22, 0xFF
	ldi r20, 0x00	; First char on line
	
LCDUpdateDisplay_CheckChar:
	ld r16, Z+	; Load new text char and increment pointer to next
	ld r23, Y	; Load current text char on LCD (without pointer increment)
	cp r16, r23	; Compare characters
   brne LCDUpdateDisplay_UpdateChar
	
	; Character not modified, check next one
	adiw YL, 0x01	; Increment current char position on LCD device
	inc r20
	cpi r20, LCDCharPerLineNumber	; Check for end of line
	brne LCDUpdateDisplay_CheckChar
	rjmp LCDUpdateDisplay_LineUpdated
	
LCDUpdateDisplay_UpdateChar:
	; Char modified, update it on LCD device
	; Check if a cursor position must be selected
	; A cursor position command is required if:
	;  - Current cursor position is not defined
	;  - X current position on LCD device different from char position on line
	cpi r21, 0xFF
	breq LCDUpdateDisplay_SetLCDCursorPos
	cpi r22, 0xFF
	breq LCDUpdateDisplay_SetLCDCursorPos
	cp r21, r20
	breq LCDUpdateDisplay_DisplayLCDChar

LCDUpdateDisplay_SetLCDCursorPos:
	mov r21, r20
	mov r22, r18
	call LCDDriverSetCursorPos	; XPos specified in r21, YPos specified in r22

LCDUpdateDisplay_DisplayLCDChar:
	; Display new char on LCD device at current cursor position
	call LCDDriverDisplayChar	; char to display is specified in r16 register
	
	; Character updated on LCD device, update char in 'LCDDeviceBuffer'
	; (i.e. image of current LCD device display)
	st Y+, r16	; Pointer is incremented to next buffer address

	; XPos on LCD has been incremented by the Display command, adjust r21
	inc r21

	; Next character
	inc r20
	cpi r20, LCDCharPerLineNumber	; Check for end of line
	brne LCDUpdateDisplay_CheckChar

LCDUpdateDisplay_LineUpdated:
	; Line updated on the LCD device, adjust update progression flags
	ldi r16, 0xFF
	eor r19, r16
	and r17, r19
	eor r19, r16
	sts LCDUpdateDisplayLinesToUpdate, r17

LCDUpdateDisplay_SelectNextLine:
	; Select next line to update
	inc r18
	cpi r18, LCDLineNumber
	breq LCDUpdateDisplay_CheckForExit	; All lines updated, final check and exit
	
	; Ajust line mask and update next line it if necessary
	; NOTE: buffer pointers have been incremented by line copy
	lsl r19
	rjmp LCDUpdateDisplay_CheckLine

LCDUpdateDisplay_CheckForExit:
	; Final check before exit: all lines must be synchronized and function
	; not re-entered
	; This is done in critical section to avoid miss of re-entry call
	ENTER_CRITICAL_SECTION
       
	lds r16, LCDUpdateDisplayReEntered	; Is function re-entered?
	cpi r16, 0
	breq LCDUpdateDisplay_CheckForExit2
	LEAVE_CRITICAL_SECTION
	rjmp LCDUpdateDisplay_CopyAppBuffer
	
LCDUpdateDisplay_CheckForExit2:
	cpi r17, 0	; All lines updated?
	breq LCDUpdateDisplay_exit
	LEAVE_CRITICAL_SECTION
	rjmp LCDUpdateDisplay_UpdateModifiedLines

LCDUpdateDisplay_exit:
	; Pop the stack in critical section to avoid stack overflow if late
	; re-entry (i.e. late re-entry will keep LCD synchronization but may
	; cause stack overflow if exit is not protected)
	ldi r16, 0x00
	sts LCDUpdateDisplayCalled, r16
	pop ZH
	pop ZL
	pop YH
	pop YL
	pop r22
	pop r21
	pop r20
	pop r19
	pop r18
	pop r17
	pop r16
	LEAVE_CRITICAL_SECTION
	ret

; This function copy a static text message (i.e. located in CSEG) in the
; LCD Application Area (located in DSEG)
; Typically after calling this function the caller adjusts variable regions of
; the message and calls 'LCDUpdateDisplay' function for message display.
; IMPORTANT: Static Text Messages MUST have a 'LCDCharPerLineNumber' length
;            (use ASCII code 32 for blank characters)
; The function arguments are the following:
;  - r18 register is the line on which message is displayed on the LCD device
;  - Z register is the address of the static text message to copy
; IMPORTANT: On return these registers are modified.
CopyStaticMsgInLCDAppArea:
	push r16
	push YL
	push YH
	
	; Compute destination address in LCD Application Area
	ldi YL, LOW(LCDAppBuffer)	       
	ldi YH, HIGH(LCDAppBuffer)
	cpi r18, 0

CopyStaticMsgInLCDAppArea_AdjustLinePtr:	
	breq CopyStaticMsgInLCDAppArea_StartCopy
	adiw YL, LCDCharPerLineNumber
	dec r18
	rjmp CopyStaticMsgInLCDAppArea_AdjustLinePtr

CopyStaticMsgInLCDAppArea_StartCopy:
	ldi r18, LCDCharPerLineNumber

	; NOTE: ZH:ZL contains a word address (i.e. label address in program
	;       memory), compute the byte address
	lsl ZH
	lsl ZL
	brcc CopyStaticMsgInLCDAppArea_CopyLoop
	inc ZH
	
CopyStaticMsgInLCDAppArea_CopyLoop:
	lpm r16, Z+	; Copy char from source to destination
	st Y+, r16
	dec r18
	brne CopyStaticMsgInLCDAppArea_CopyLoop	
      
	; Line copied  
	pop YH
	pop YL
	pop r16
	ret

; This function copy a data text message (i.e. located in DSEG) in the
; LCD Application Area (located in DSEG)
; Typically after calling this function the caller adjusts variable regions of
; the message and calls 'LCDUpdateDisplay' function for message display.
; IMPORTANT: Data Text Messages MUST have a 'LCDCharPerLineNumber' length
;            (use ASCII code 32 for blank characters)
; The function arguments are the following:
;  - r18 register is the line on which message is displayed on the LCD device
;  - Z register is the address of the data text message to copy
; IMPORTANT: On return these registers are modified.
CopyDataMsgInLCDAppArea:
	push r16
	push YL
	push YH
	
	; Compute destination address in LCD Application Area
	ldi YL, LOW(LCDAppBuffer)	       
	ldi YH, HIGH(LCDAppBuffer)
	cpi r18, 0

CopyDataMsgInLCDAppArea_AdjustLinePtr:	
	breq CopyDataMsgInLCDAppArea_StartCopy
	adiw YL, LCDCharPerLineNumber
	dec r18
	rjmp CopyDataMsgInLCDAppArea_AdjustLinePtr

CopyDataMsgInLCDAppArea_StartCopy:
	ldi r18, LCDCharPerLineNumber

CopyDataMsgInLCDAppArea_CopyLoop:
	ld r16, Z+	; Copy char from source to destination
	st Y+, r16
	dec r18
	brne CopyDataMsgInLCDAppArea_CopyLoop	
      
	; Line copied  
	pop YH
	pop YL
	pop r16
	ret

; This function clears the LCDDeviceBuffer 
; The 'LCDDeviceBuffer' contains the text currently displayed on the LCD.
; Typically this function is must be called when the display is resetted 
; (i.e. after calling 'LCDDriverInitializeHD' function).
LCDClearDeviceBuffer:
	push r16
	push r17
	push r18
	push YL
	push YH
	
	ldi YL, LOW(LCDDeviceBuffer)		; Current LCD device text pointer		
	ldi YH, HIGH(LCDDeviceBuffer)

   ldi r16, 0x00
   ldi r17, LCDLineNumber

LCDClearDeviceBuffer_LineLoop:
   ldi r18, LCDCharPerLineNumber

LCDClearDeviceBuffer_CharLoop:
	st Y+, r16	; Pointer is incremented to next buffer address
   dec r18
   brne LCDClearDeviceBuffer_CharLoop
   dec r17
   brne LCDClearDeviceBuffer_LineLoop
                             
   pop YH
   pop YL
   pop r18
   pop r17
   pop r16
   ret

; Display LCD screen according to current Main Menu Option 
RefreshLCDScreen:
	push r16
	lds r16, bCurrentMainMenuOption
	cpi r16, MAIN_MENU_STATE
	brne RefreshLCDScreen_CheckNext 
;  call DisplayStateScreen
	rjmp RefreshLCDScreen_Exit

RefreshLCDScreen_CheckNext:
	cpi r16, MAIN_MENU_LEFT_OFFSET
	brne RefreshLCDScreen_CheckNext2 
	call DisplayLeftChannelOffsetScreen
	rjmp RefreshLCDScreen_Exit

RefreshLCDScreen_CheckNext2:
	cpi r16, MAIN_MENU_RIGHT_OFFSET
	brne RefreshLCDScreen_Exit 
	call DisplayRightChannelOffsetScreen

RefreshLCDScreen_Exit:
	pop r16
	ret


; Copy a variable text region (field value) FROM CSEG to the LCD Application
; area
; The function arguments are:
;   - Register r16 is the length of text to copy
;   - Register r17 is the first character position in the line
;   - Register r18 is the line index in the LCD Application area
;   - Register ZH:ZL is pointer to text (in CSEG)
; IMPORTANT: 
;   - This function works with field text located in program memory 
;     (CSEG = Constant Field = typically value from constant table)
;   - ZH:ZL must contain a BYTE address
;   - On return argument registers are modified.
SetConstFieldInLCDAppArea:
	push YL
	push YH
	
	; Compute destination address in LCD Application Area
	ldi YL, LOW(LCDAppBuffer)	       
	ldi YH, HIGH(LCDAppBuffer)
	cpi r18, 0

SetConstFieldInLCDAppArea_AdjustLinePtr:	
	breq SetConstFieldInLCDAppArea_AddXPos
	adiw YL, LCDCharPerLineNumber
	dec r18
	rjmp SetConstFieldInLCDAppArea_AdjustLinePtr

SetConstFieldInLCDAppArea_AddXPos:
	add YL, r17
	brcc SetConstFieldInLCDAppArea_CopyLoop
	inc YH
	
SetConstFieldInLCDAppArea_CopyLoop:
	lpm r18, Z+	; Copy char from source to destination
	st Y+, r18
	dec r16
	brne SetConstFieldInLCDAppArea_CopyLoop	
      
	; Line copied  
	pop YH
	pop YL
	ret

; Copy a variable text region (field value) FROM DSEG to the LCD Application
; area
; The function arguments are:
;   - Register r16 is the length of text to copy
;   - Register r17 is the first character position in the line
;   - Register r18 is the line index in the LCD Application area
;   - Register ZH:ZL is pointer to text (in DSEG)
; IMPORTANT: 
;   - This function works with field text located in data memory 
;     (DSEG = Formated Field = typically value from 'StringFormatingBuffer
;     variable)
;   - On return argument registers are modified.
SetFieldInLCDAppArea:
	push YL
	push YH
	
	; Compute destination address in LCD Application Area
	ldi YL, LOW(LCDAppBuffer)	       
	ldi YH, HIGH(LCDAppBuffer)
	cpi r18, 0

SetFieldInLCDAppArea_AdjustLinePtr:	
	breq SetFieldInLCDAppArea_AddXPos
	adiw YL, LCDCharPerLineNumber
	dec r18
	rjmp SetFieldInLCDAppArea_AdjustLinePtr

SetFieldInLCDAppArea_AddXPos:
	add YL, r17
	brcc SetFieldInLCDAppArea_CopyLoop
	inc YH
	
SetFieldInLCDAppArea_CopyLoop:
	ld r18, Z+	; Copy char from source to destination
	st Y+, r18
	dec r16
	brne SetFieldInLCDAppArea_CopyLoop	
      
	; Line copied  
	pop YH
	pop YL
	ret


;******************************************************************************
; LCD Driver Functions
;****************************************************************************** 

; Initialize the HD44780
; This function must be called one time before using the LCDDriver.
; It initialize the HD44780 for its default behaviour (i.e. correct mode for use
; with the 'LCDxx' high level functions)
;
; NOTE: Make sure that LCD device is powered on before calling this function.
;       The function must be called each time the LCD device is powered off and
;       then powered on again.
LCDDriverInitializeHD:	  
	push r16
	
	; Initialize ports connected to HD44780
	; Clear the 3 control bits on control port
   lds r16, LCDDriverCtrlPortData
   cbr r16, 1 << LCDDriverCtrlEE | 1 << LCDDriverCtrlRW | 1 << LCDDriverCtrlRS
   sts LCDDriverCtrlPortData, r16

	; Clear the 8 data bits on data port
	ldi r16, 0x00
	sts LCDDriverDataPortData, r16

	; Set the working mode
	ldi r16, LCDDriverHDCmdFuncSet_Length8bit |  LCDDriverHDCmdFuncSet_Display2Lines | LCDDriverHDCmdFuncSet_Font10Dot
	call LCDDriverLaunchCommand
;	call LCDDriverWaitStdDelay 	; Additional delay (uncomment if needed)	

	; Set display mode (display ON and no cursor)
	ldi r16, LCDDriverHDCmdDisplayCtrl_DisplayOn | LCDDriverHDCmdDisplayCtrl_CursorOff
	call LCDDriverLaunchCommand
;	call LCDDriverWaitStdDelay 	; Additional delay (uncomment if needed)	

	; Automatic cursor increment (i.e. scroll right)
	ldi r16, LCDDriverHDCmdEntryMode_CursorRight
	call LCDDriverLaunchCommand
;	call LCDDriverWaitStdDelay 	; Additional delay (uncomment if needed)	

	; Reset the display (clear screen and go to home location)
	ldi r16, LCDDriverHDCmdClearDisplay
	call LCDDriverLaunchCommand

   ; This command needs extra wait time (1.5 ms according to datasheet)
   ldi r16, 40
   
LCDDriverInitializeHD_WaitLoop:  
	call LCDDriverWaitStdDelay 	; 75 usec wait
   dec r16
   brne LCDDriverInitializeHD_WaitLoop

	pop r16
	ret
	
; Set current cursor location at specified coordinates
; This function moves the cursor at specified line/column coordinates
; The XPos is specified in r21 register and YPos specified in r22 register
; The function MUST NOT modify these registers
; NOTE: 
;  - This function calls 'LCDDriverLaunchCommand' and cannot be re-entered.
;  - By design, this function is called only from 'LCDUpdateDisplay' function
;    (or function called by 'LCDUpdateDisplay'). The 'LCDUpdateDisplay' is
;    protected against re-entry.

LCDDriverSetCursorPos:
	push r16
	push r17

	; Compute DDRAM address for the specified coordinate
   cpi  r22, 0x00
   brne LCDDriverSetCursorPos_CheckLine1
   ldi  r17, LCDDriverDeviceCharAddrLine0
   rjmp LCDDriverSetCursorPos_AddXPos

LCDDriverSetCursorPos_CheckLine1:
   cpi  r22, 0x01
   brne LCDDriverSetCursorPos_CheckLine2
   ldi  r17, LCDDriverDeviceCharAddrLine1
   rjmp LCDDriverSetCursorPos_AddXPos

LCDDriverSetCursorPos_CheckLine2:
   cpi  r22, 0x02
   brne LCDDriverSetCursorPos_CheckLine3
   ldi  r17, LCDDriverDeviceCharAddrLine2
   rjmp LCDDriverSetCursorPos_AddXPos

LCDDriverSetCursorPos_CheckLine3:
   cpi  r22, 0x03
   brne LCDDriverSetCursorPos_Exit          ; More than 4 lines is not supported
   ldi  r17, LCDDriverDeviceCharAddrLine3

LCDDriverSetCursorPos_AddXPos:
	add r17, r21	; DDRAM address in r17 (i.e. absolute char position)
	
	; Prepare command byte (write DDRAM command + 7 bit address)
	ldi r16, 0b01111111  ; Make sure address length is 7 bits 
	and r16, r17
	ori r16, LCDDriverHDCmdDRAMAddrMask

	; Execute command
	call LCDDriverLaunchCommand
 
LCDDriverSetCursorPos_Exit:  
	pop r17
	pop r16
	ret

; Write an LCD ASCII character byte at cursor location
; This function displays a specified ASCII character at current cursor location
; The character to display is specified in r16 register
; The function MUST NOT modify this register
; NOTE: The function generates the required state cycle on EN, RW and RS HD44780
;       pins.
; NOTE: 
;  - This function or other functions affecting the 'LCDDriverCtrlPortData'
;    cannot be called during the execution of this function (i.e. generation
;    of LCD controller I/O timing). For performance, interrupts are not
;    disabled during this I/O timing).
;  - By design, this function is called only from 'LCDUpdateDisplay' function
;    (or function called by 'LCDUpdateDisplay'). The 'LCDUpdateDisplay' is
;    protected against re-entry.
LCDDriverDisplayChar:
   push r17

	; Prepare data output with the specified ASCII character
	sts LCDDriverDataPortData, r16

	; Start DDRAM write triggering is RS=1, R/W=0, EE=1
	; IMPORTANT: EE, RS and R/W are assumed to be 0 (i.e. default state)
   lds r17, LCDDriverCtrlPortData
   sbr r17, 1 << LCDDriverCtrlRS
   sts LCDDriverCtrlPortData, r17
   sbr r17, 1 << LCDDriverCtrlRS | 1 << LCDDriverCtrlEE
   sts LCDDriverCtrlPortData, r17
	
	; Minimum pulse width is 230 ns
;  nop
;  nop
;  nop

   call LCDDriverWaitStdDelay

	; End of DDRAM write triggering is RS=0, R/W=0, EE=0
#message "LCDDriver: Check with	HD44780 datasheet,leave RS to 1?"
   lds r17, LCDDriverCtrlPortData
   cbr r17, 1 << LCDDriverCtrlRS | 1 << LCDDriverCtrlEE
   sts LCDDriverCtrlPortData, r17
	
	; Wait for command completion
	call LCDDriverWaitStdDelay

   pop r17
	ret

; Write an LCD command byte
; This function generates the state cycle on EN, RW and RS HD44780 pins for
; launching a specified command
; The command to launch is specified in r16 register 
; The function waits for typical command completion delays
; NOTE: 
;  - This function or other functions affecting the 'LCDDriverCtrlPortData'
;    cannot be called during the execution of this function (i.e. generation
;    of LCD controller I/O timing). For performance, interrupts are not
;    disabled during this I/O timing).
;  - By design, this function is mainly called from 'LCDUpdateDisplay' function
;    (or function called by 'LCDUpdateDisplay'). The 'LCDUpdateDisplay' is
;    protected against re-entry.
;  - The driver initialization function ('LCDDriverInitializeHD') is also calling
;    'LCDDriverLaunchCommand'.
LCDDriverLaunchCommand:
   push r17

	; Prepare data output with the specified Command Byte
	sts LCDDriverDataPortData, r16

	; Start command triggering is RS=0, R/W=0, EE=1
	; IMPORTANT: EE, RS and R/W are assumed to be 0 (i.e. default state)
   lds r17, LCDDriverCtrlPortData
   sbr r17, 1 << LCDDriverCtrlEE
   sts LCDDriverCtrlPortData, r17
	
	; Minimum pulse width is 230 ns
;  nop
;  nop
;  nop

 call LCDDriverWaitStdDelay

	; End of command triggering is RS=0, R/W=0, EE=0
   lds r17, LCDDriverCtrlPortData
   cbr r17, 1 << LCDDriverCtrlEE
   sts LCDDriverCtrlPortData, r17
	
	; Wait for command completion
	call LCDDriverWaitStdDelay
	
   pop r17
	ret
	
; Wait the standard delay for HD44780 command processing
; According to datasheet the standard delay (typical max delay) is:
;  - 37usec for standard commands
;  - 43usec for commands with access to device internal RAM
; This function waits 75usec (total 300 cycles with 4Mhz clock)
;
; NOTE: 
;  - Theorically, the program must check the device's Busy Flag in order
;    to know if the previous command has completed.
;  - The implementation choice is to wait for the theorical processing
;    time at the end of each command.     
LCDDriverWaitStdDelay:
	push r16		; 2 cycles
       
#ifdef CLOCK_FREQUENCY_1MHZ
	ldi r16, 8		; 1 cycle
#endif

#ifdef CLOCK_FREQUENCY_1_25MHZ
	ldi r16, 10		; 1 cycle
#endif

#ifdef CLOCK_FREQUENCY_4MHZ
	ldi r16, 29		; 1 cycle
#endif

#ifdef CLOCK_FREQUENCY_5MHZ
	ldi r16, 37		; 1 cycle
#endif

#ifdef CLOCK_FREQUENCY_8MHZ
	ldi r16, 58		; 1 cycle
#endif

#ifdef CLOCK_FREQUENCY_10MHZ
	ldi r16, 75		; 1 cycle
#endif

; 10 cycle loop
LCDDriverWaitStdDelay_Loop:
	nop 			;1 cycle
	nop
	nop
	nop
	nop
	nop
	nop
	dec r16			; 1 cycle
	brne LCDDriverWaitStdDelay_Loop	; (10 * loop count) + 1 cycles
	
	pop r16			; 2 cycles
	ret 			; 4 cycles
	

;******************************************************************************
; LCD Power Management Functions
;****************************************************************************** 

; Power on the LCD
; This function switches on the LCD power relay 
; Note: The LCDDriverInitializeHD function must be called each time the LCD is
;       powered on
LCDDriverPowerOn:
   push r17
   lds  r17, LCDDriverCtrlPortData
   sbr  r17, 1 << LCDDriverCtrlPower
   sts  LCDDriverCtrlPortData, r17

   ; Wait for HD44780 boot (according to datasheet: at least 40 ms after Vcc reaches 2.7V)
   push r16
   ldi r16, 6     ; Main loop (110 ms)

LCDDriverPowerOn_WaitLoop:  
   ldi r17, 250   ; 18 ms inner loop

LCDDriverPowerOn_InnerWaitLoop:  
	call LCDDriverWaitStdDelay 	; 75 usec wait
   dec r17
   brne LCDDriverPowerOn_InnerWaitLoop
   dec r16
   brne LCDDriverPowerOn_WaitLoop

   pop  r16
   pop  r17
   ret

; Power off the LCD
; This function switches off the LCD power relay 
LCDDriverPowerOff:
   push r17
   lds  r17, LCDDriverCtrlPortData
   cbr  r17, 1 << LCDDriverCtrlPower
   sts  LCDDriverCtrlPortData, r17
   pop  r17
   ret

; Adjust LCD background ligth
; This function set a specified value for the digital variable resistance controlling
; the backlight led of the LCD (AD8402 channel 0)
; The requested backlight level is specified in R16
LCDDriverAdjustBacklight:
   push r17
   ldi  r17, 0x00
   call LCDDriverSetAD8402
   pop  r17
   ret

; Adjust LCD contrast
; This function set a specified value for the digital variable resistance controlling
; the contrast of the LCD (AD8402 channel 1)
; The requested contrast level is specified in R16
LCDDriverAdjustContrast:
   push r17
   ldi  r17, 0x01
   call LCDDriverSetAD8402
   pop  r17
   ret

; Set resistance value of a specified channel in the AD8402
; This function set a specified resistance value of a specified channel in the AD8402
; used for LCD backlight and contrast.
; The requested resistance value is specified in R16.
; The destination channel is specified in R17 (0x00 = channel 0 = backlight,
; 0x01 = channel 1 = contrast)


LCDDriverSetAD8402:
   push r18
   push r19
   push r20

   ; Select AD8402 chip (i.e. set CS pin to 0)
   ldi  r18, 0x00
   cbi  LCDDriverAD8402PortData, LCDDriverAD8402CS

   ; Transfer the 10 bit command word in the serial register
   ; Note: 
   ;  - The 10 bit word pattern is A1,A0,D7..D0 with A1,A0 as the channel address
   ;    and D7..D0 as the resistance value
   ;  - The transfer starts with Address bits and continue with Data bits 
   ;    (with MSB first for both address and data) 
   
   ; Loop for address bits (A1..A0)
   mov  r19, r17
   lsl  r19
   lsl  r19
   lsl  r19
   lsl  r19
   lsl  r19
   lsl  r19
   ldi  r20, 0x02

LCDDriverSetAD8402_AddressLoop:
   lsl  r19                                         ; Bit to store in carry
   brcc LCDDriverSetAD8402_AddressLoopSetSDI
   sbi  LCDDriverAD8402PortData, LCDDriverAD8402SDI ; Value to serialize on SDI pin
                                                    ; (0 by default)

LCDDriverSetAD8402_AddressLoopSetSDI:
   sbi  LCDDriverAD8402PortData, LCDDriverAD8402CLK ; Generate positive pulse on CLK to 
                                                    ; store SDI bit in serial register
   nop
   cbi  LCDDriverAD8402PortData, LCDDriverAD8402CLK 
   nop
   cbi  LCDDriverAD8402PortData, LCDDriverAD8402SDI ; Reset SDI to default value
   dec  r20
   brne LCDDriverSetAD8402_AddressLoop

   ; D7..D0 loop
   mov  r19, r16
   ldi  r20, 0x08

LCDDriverSetAD8402_DataLoop:
   lsl  r19                                         ; Bit to store in carry
   brcc LCDDriverSetAD8402_DataLoopSetSDI
   sbi  LCDDriverAD8402PortData, LCDDriverAD8402SDI ; Value to serialize on SDI pin
                                                    ; (0 by default)

LCDDriverSetAD8402_DataLoopSetSDI:
   sbi  LCDDriverAD8402PortData, LCDDriverAD8402CLK ; Generate positive pulse on CLK to 
                                                    ; store SDI bit in serial register
   nop
   cbi  LCDDriverAD8402PortData, LCDDriverAD8402CLK 
   nop
   cbi  LCDDriverAD8402PortData, LCDDriverAD8402SDI ; Reset SDI to default value
   dec  r20
   brne LCDDriverSetAD8402_DataLoop

   ; Set RDAC value from 10 bit word in serial register 
   sbi  LCDDriverAD8402PortData, LCDDriverAD8402CS  ; Positive edge on CS pin
                                                    ; Note: leave CS pin high 
                                                    ; (i.e. AD8402 chip not selected)
   pop  r20
   pop  r19
   pop  r18
   ret

