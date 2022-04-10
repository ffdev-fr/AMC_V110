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
; File:	Menu.asm
;
; Author: F.Fargon
;
; Purpose: 
;  - User menu
;******************************************************************************

#include "LCD.asm"

.CSEG

;******************************************************************************
; Static Display Message Texts
;******************************************************************************
  
; These strings are intended to be copied in 'LCDAppBuffer' SRAM for 
; parametrization and display on LCD device.
; Optionaly one or more 'VarPos' are specified for a message.
; 'VarPos' are positions of variable regions in the message (typically values
; updated at runtime)
; IMPORTANT: Each message length MUST be equal to 'LCDCharPerLineNumber'


; The 'STATE' screen
LCDStateScreenL1:  		   .DB 	" SINGLE CHANNEL AMP "     ; First line is static (title)
LCDStateScreenL2_Sleep:	   .DB 	"****  SLEEPING  ****"     ; Second line indicates current state
LCDStateScreenL2_Powering:	.DB 	"****  POWERING  ****" 
LCDStateScreenL2_Muted:	   .DB 	"****   MUTED   **** " 
LCDStateScreenL2_Playing:  .DB 	"****  PLAYING  **** "     

#ifdef USERDISPLAY_LEVEL_DB 
LCDStateScreenL3: 		   .DB 	"Volume: -xx.xx dB   "     ; Third line is current level
#endif

#ifdef USERDISPLAY_LEVEL_VALUE 
LCDStateScreenL3: 		   .DB 	"Volume: xxx / 127   "     ; Third line is current level
#endif

LCDStateScreenL4_Sleep:       .DB 	"Version: xxxxxxxxxxx"     ; Fourth line displays version string in 'SLEEPING' state
LCDStateScreenL4_Temperature: .DB 	"Temp.: L=xx.x R=xx.x"     ; Fourth line displays temperature when NOT in 'SLEEPING' state
LCDStateScreenL4_TempError:   .DB 	"Temp.:  ** Error ** "     


; Left Channel Offset Edit screen
LCDMsgMainMenuLeftOffsetL1:	.DB 	"LEFT CHANNEL OFFSET "
LCDMsgMainMenuLeftOffsetL2:	.DB 	"Mode: EDIT          "
LCDMsgMainMenuLeftOffsetL3:	.DB 	"Current: xxx.xx dB  "
LCDMsgMainMenuLeftOffsetL4:	.DB 	"New:     xxx.xx dB  "

.EQU	LCDMsgMainMenuLeftOffsetL3_VarPos = 9
.EQU	LCDMsgMainMenuLeftOffsetL4_VarPos = 9

; Right Channel Offset Edit screen
LCDMsgMainMenuRightOffsetL1:	.DB 	"RIGHT CHANNEL OFFSET"
LCDMsgMainMenuRightOffsetL2:	.DB 	"Mode: EDIT          "
LCDMsgMainMenuRightOffsetL3:	.DB 	"Current: xxx.xx dB  "
LCDMsgMainMenuRightOffsetL4:	.DB 	"New:     xxx.xx dB  "

.EQU	LCDMsgMainMenuRightOffsetL3_VarPos = 9
.EQU	LCDMsgMainMenuRightOffsetL4_VarPos = 9

; Volume values
; The values are defined as constants for direct access via index
; (the input value is directly the index from the end of the table)

#ifdef USERDISPLAY_LEVEL_DB 

LCDMsgVolumeValues:	.DB	"95.25" "94.50" "93.75" "93.00"\
                           "92.25" "91.50" "90.75" "90.00"\
                           "89.25" "88.50" "87.75" "87.00"\
                           "86.25" "85.50" "84.75" "84.00"\
                           "83.25" "82.50" "81.75" "81.00"\
                           "80.25" "79.50" "78.75" "78.00"\
                           "77.25" "76.50" "75.75" "75.00"\
                           "74.25" "73.50" "72.75" "72.00"\
                           "71.25" "70.50" "69.75" "69.00"\
                           "68.25" "67.50" "66.75" "66.00"\
                           "65.25" "64.50" "63.75" "63.00"\
                           "62.25" "61.50" "60.75" "60.00"\
                           "59.25" "58.50" "57.75" "57.00"\
                           "56.25" "55.50" "54.75" "54.00"\
                           "53.25" "52.50" "51.75" "51.00"\
                           "50.25" "49.50" "48.75" "48.00"\
                           "47.25" "46.50" "45.75" "45.00"\
                           "44.25" "43.50" "42.75" "42.00"\
                           "41.25" "40.50" "39.75" "39.00"\
                           "38.25" "37.50" "36.75" "36.00"\
                           "35.25" "34.50" "33.75" "33.00"\
                           "32.25" "31.50" "30.75" "30.00"\
                           "29.25" "28.50" "27.75" "27.00"\
                           "26.25" "25.50" "24.75" "24.00"\
                           "23.25" "22.50" "21.75" "21.00"\
                           "20.25" "19.50" "18.75" "18.00"\
                           "17.25" "16.50" "15.75" "15.00"\
                           "14.25" "13.50" "12.75" "12.00"\
                           "11.25" "10.50" "09.75" "09.00"\
                           "08.25" "07.50" "06.75" "06.00"\
                           "05.25" "04.50" "03.75" "03.00"\
                           "02.25" "01.50" "00.75" "00.00"

.EQU	LCDMsgVolumeValues_MsgLength = 5
.EQU	LCDMsgVolumeValues_MsgNumber = 128

#endif

#ifdef USERDISPLAY_LEVEL_VALUE

LCDMsgVolumeValues:	.DB	"000" "001" "002" "003" "004" "005" "006" "007"\
			       	         "008" "009" "010" "011" "012" "013" "014" "015"\
			       	         "016" "017" "018" "019" "020" "021" "022" "023"\
			       	         "024" "025" "026" "027" "028" "029" "030" "031"\
			       	         "032" "033" "034" "035" "036" "037" "038" "039"\
			       	         "040" "041" "042" "043" "044" "045" "046" "047"\
			       	         "048" "049" "050" "051" "052" "053" "054" "055"\
			       	         "056" "057" "058" "059" "060" "061" "062" "063"\
			       	         "064" "065" "066" "067" "068" "069" "070" "071"\
			       	         "072" "073" "074" "075" "076" "077" "078" "079"\
			       	         "080" "081" "082" "083" "084" "085" "086" "087"\
			       	         "088" "089" "090" "091" "092" "093" "094" "095"\
			       	         "096" "097" "098" "099" "100" "101" "102" "103"\
			       	         "104" "105" "106" "107" "108" "109" "110" "111"\
			       	         "112" "113" "114" "115" "116" "117" "118" "119"\
			       	         "120" "121" "122" "123" "124" "125" "126" "127"

.EQU	LCDMsgVolumeValues_MsgLength = 3
.EQU	LCDMsgVolumeValues_MsgNumber = 128

#endif

; Temperature values
; The values are defined as constants for direct access via index
; NOTE:
;  - The '0' index states for negative or undefined values
;  - The maximum temperature is '99.5°C' (index 198).
;    Temperatures with a higher value are clipped to index 199 (value: more than 100°C) 
LCDMsgTemperatureValues:	.DB	"----" "00.5" "01.0" "01.5" "02.0" "02.5" "03.0" "03.5" "04.0" "04.5"\
                                 "05.0" "05.5" "06.0" "06.5" "07.0" "07.5" "08.0" "08.5" "09.0" "09.5"\
                                 "10.0" "10.5" "11.0" "11.5" "12.0" "12.5" "13.0" "13.5" "14.0" "14.5"\
                                 "15.0" "15.5" "16.0" "16.5" "17.0" "17.5" "18.0" "18.5" "19.0" "19.5"\
                                 "20.0" "20.5" "21.0" "21.5" "22.0" "22.5" "23.0" "23.5" "24.0" "24.5"\
                                 "25.0" "25.5" "26.0" "26.5" "27.0" "27.5" "28.0" "28.5" "29.0" "29.5"\
                                 "30.0" "30.5" "31.0" "31.5" "32.0" "32.5" "33.0" "33.5" "34.0" "34.5"\
                                 "35.0" "35.5" "36.0" "36.5" "37.0" "37.5" "38.0" "38.5" "39.0" "39.5"\
                                 "40.0" "40.5" "41.0" "41.5" "42.0" "42.5" "43.0" "43.5" "44.0" "44.5"\
                                 "45.0" "45.5" "46.0" "46.5" "47.0" "47.5" "48.0" "48.5" "49.0" "49.5"\
                                 "50.0" "50.5" "51.0" "51.5" "52.0" "52.5" "53.0" "53.5" "54.0" "54.5"\
                                 "55.0" "55.5" "56.0" "56.5" "57.0" "57.5" "58.0" "58.5" "59.0" "59.5"\
                                 "60.0" "60.5" "61.0" "61.5" "62.0" "62.5" "63.0" "63.5" "64.0" "64.5"\
                                 "65.0" "65.5" "66.0" "66.5" "67.0" "67.5" "68.0" "68.5" "69.0" "69.5"\
                                 "70.0" "70.5" "71.0" "71.5" "72.0" "72.5" "73.0" "73.5" "74.0" "74.5"\
                                 "75.0" "75.5" "76.0" "76.5" "77.0" "77.5" "78.0" "78.5" "79.0" "79.5"\
                                 "80.0" "80.5" "81.0" "81.5" "82.0" "82.5" "83.0" "83.5" "84.0" "84.5"\
                                 "85.0" "85.5" "86.0" "86.5" "87.0" "87.5" "88.0" "88.5" "89.0" "89.5"\
                                 "90.0" "90.5" "91.0" "91.5" "92.0" "92.5" "93.0" "93.5" "94.0" "95.5"\
                                 "96.0" "96.5" "97.0" "97.5" "98.0" "98.5" "99.0" "99.5" "100+"

.EQU	LCDMsgTemperatureValues_MsgLength = 4
.EQU	LCDMsgTemperature_MsgNumber = 199

; Display the 'STATE' screen
; This function displays the 'STATE' screen according to current state and
; input level
; The lines to update on screen is specified in r19 (binary mask for line1-4
; with LSB for line 1)
DisplayStateScreen:
	push 	ZL
	push 	ZH
	push 	r16
	push 	r17
   push  r18

	; Copy the screen static text in the LCD Application area for modified lines
   mov   r16, r19
   andi  r16, 0b00000001
   breq  DisplayStateScreen_CheckLine2

   ; Line 1 must be updated
   ; Default amplifier name can be modified by ACC
   lds   r16, AmplifierDisplayName
   cpi   r16, 0x00                       ; Is custom Amplifier Name set?
   breq  DisplayStateScreen_StaticLine1
	ldi 	ZL, LOW(AmplifierDisplayName)	  ; Line 1 is configured display name (DSEG)
	ldi 	ZH, HIGH(AmplifierDisplayName) 
	ldi 	r18, 0x00
   call  CopyDataMsgInLCDAppArea
   jmp   DisplayStateScreen_CheckLine2

DisplayStateScreen_StaticLine1:
	ldi 	ZL, LOW(LCDStateScreenL1)	  ; Line 1 is static display name text (CSEG)
	ldi 	ZH, HIGH(LCDStateScreenL1)
	ldi 	r18, 0x00
	call 	CopyStaticMsgInLCDAppArea

DisplayStateScreen_CheckLine2:
   mov   r16, r19
   andi  r16, 0b00000010
   breq  DisplayStateScreen_CheckLine3

   ; Line 2 must be updated: text depends on current state
	lds	r16, bAmplifierPowerState
	cpi	r16, AMPLIFIERSTATE_POWER_ON
	breq	DisplayStateScreen_Line2PoweredOn

	; Amplifier power is off or powering up
	cpi	r16, AMPLIFIERSTATE_POWER_OFF
   brne  DisplayStateScreen_Line2PoweringUp

   ; Amplifier power is off, display 'sleep' message
	ldi 	ZL, LOW(LCDStateScreenL2_Sleep)	
	ldi 	ZH, HIGH(LCDStateScreenL2_Sleep)
	jmp	DisplayStateScreen_Line2CopyMsg

DisplayStateScreen_Line2PoweringUp:
	; Amplifier is powering up, display 'powering' message
	ldi 	ZL, LOW(LCDStateScreenL2_Powering)	
	ldi 	ZH, HIGH(LCDStateScreenL2_Powering)
	jmp	DisplayStateScreen_Line2CopyMsg

DisplayStateScreen_Line2PoweredOn:
	; Amplifier power is on, check if output is muted
	lds	r16, bAmplifierOutputState
	cpi	r16, AMPLIFIERSTATE_OUTPUT_MUTED
	brne	DisplayStateScreen_Line2OutputOn

	; Amplifier output is off, display 'mute' message
	ldi 	ZL, LOW(LCDStateScreenL2_Muted)	
	ldi 	ZH, HIGH(LCDStateScreenL2_Muted)
	jmp	DisplayStateScreen_Line2CopyMsg

DisplayStateScreen_Line2OutputOn:
	; Amplifier output is on, display 'play' message
	ldi 	ZL, LOW(LCDStateScreenL2_Playing)	
	ldi 	ZH, HIGH(LCDStateScreenL2_Playing)

DisplayStateScreen_Line2CopyMsg:
	ldi 	r18, 0x01
	call 	CopyStaticMsgInLCDAppArea

DisplayStateScreen_CheckLine3:
   ; Check if line 3 must be updated
   mov   r16, r19
   andi  r16, 0b00000100
   breq  DisplayStateScreen_CheckLine4

	ldi 	ZL, LOW(LCDStateScreenL3)	    ; Line 3 contains a variable area
	ldi 	ZH, HIGH(LCDStateScreenL3)
	ldi 	r18, 0x02
	call 	CopyStaticMsgInLCDAppArea

	; Set variable text area on line 3

	; Obtain text value of 'bCurrentLevel' in dB
	; The function returns pointer to text value (in CSEG) in ZH:ZL and
	; the text length in register r16
	call 	GetCurrentLevelText

	; Copy variable text (field value) in the LCD Application area
	; The function arguments are:
	;   - Register r16 is the length of text to copy
	;   - Register r17 is the first character position in the line
	;   - Register r18 is the line index in the LCD Application area
	;   - Register ZH:ZL is pointer to text (in CSEG)
	ldi 	r17, LCDStateScreenL3_VarPos
	ldi 	r18, 0x02
	call 	SetConstFieldInLCDAppArea

DisplayStateScreen_CheckLine4:
   mov   r16, r19
   andi  r16, 0b00001000
   breq  DisplayStateScreen_UpdateDisplay

   ; Line 4 must be updated: text depends on current state
	lds	r16, bAmplifierPowerState
	cpi	r16, AMPLIFIERSTATE_POWER_OFF
	brne	DisplayStateScreen_Line4PoweredOn

   ; When amplifier is SLEEPING, line 4 displays the firmware version (variable area)
	ldi 	ZL, LOW(LCDStateScreenL4_Sleep)	   
	ldi 	ZH, HIGH(LCDStateScreenL4_Sleep)
	ldi 	r18, 0x03
	call 	CopyStaticMsgInLCDAppArea

	; Set variable text area on line 4

	; Copy variable text (field value) in the LCD Application area
	; The function arguments are:
	;   - Register r16 is the length of text to copy
	;   - Register r17 is the first character position in the line
	;   - Register r18 is the line index in the LCD Application area
	;   - Register ZH:ZL is pointer to text (in CSEG)
	ldi   r16, LCDCharPerLineNumber     ; Length of version string is 'LCDCharPerLineNumber - 9'
	ldi 	r17, 9
   sub   r16, r17
	ldi 	r17, LCDStateScreenL4_VarPos
	ldi 	r18, 0x03

	; The version text value is 'VERSION_String' constant (in CSEG)
	ldi 	ZL, LOW(VERSION_String)	   
	ldi 	ZH, HIGH(VERSION_String)

	; NOTE: ZH:ZL contains a word address (i.e. label address in program
	;       memory), compute the byte address
	lsl   ZH
	lsl   ZL
	brcc  DisplayStateScreen_Line4CopyVersion
	inc   ZH

DisplayStateScreen_Line4CopyVersion:
	call 	SetConstFieldInLCDAppArea
   jmp   DisplayStateScreen_UpdateDisplay

DisplayStateScreen_Line4PoweredOn:
   ; Line 4 displays current temperature when state is not 'SLEEPING' 
   lds   r16, TemperatureMeasurementState         ; Check for error on temperature measurement
   cpi   r16, TEMPMEASUREMENT_STATE_ERROR
   breq  DisplayStateScreen_Line4TempError
	ldi 	ZL, LOW(LCDStateScreenL4_Temperature)	  ; Line for temperature display (variable area)
	ldi 	ZH, HIGH(LCDStateScreenL4_Temperature)
	ldi 	r18, 0x03                                ; Set static area
	call 	CopyStaticMsgInLCDAppArea

	; Set variable text area on line 4 (= 2 variable strings for left and right temperature)

	; Obtain text value of 'bCurrentLevel'
	; The function returns pointer to text value (in CSEG) in ZH:ZL and
	; the text length in register r16
   ldi   r16, 0x00                                ; Retrieve text for left temperature
	call 	GetCurrentTemperatureText

	; Copy variable text (field value) in the LCD Application area
	; The function arguments are:
	;   - Register r16 is the length of text to copy
	;   - Register r17 is the first character position in the line
	;   - Register r18 is the line index in the LCD Application area
	;   - Register ZH:ZL is pointer to text (in CSEG)
	ldi 	r17, LCDStateScreenL4_VarPos1
	ldi 	r18, 0x03
	call 	SetConstFieldInLCDAppArea

   ldi   r16, 0x01                                ; Retrieve text for right temperature
	call 	GetCurrentTemperatureText
	ldi 	r17, LCDStateScreenL4_VarPos2
	ldi 	r18, 0x03
	call 	SetConstFieldInLCDAppArea
   rjmp  DisplayStateScreen_UpdateDisplay         ; Update display

DisplayStateScreen_Line4TempError:
	ldi 	ZL, LOW(LCDStateScreenL4_TempError)	     ; Line for temperature error display (static string)
	ldi 	ZH, HIGH(LCDStateScreenL4_TempError)
	ldi 	r18, 0x03
	call 	CopyStaticMsgInLCDAppArea

DisplayStateScreen_UpdateDisplay:
	; Update the display on the LCD device
	sts 	LCDAppBufferModifiedLines, r19     ; Indicate modified lines for update function
	call 	LCDUpdateDisplay

DisplayStateScreen_Exit:
   pop   r18
	pop 	r17
	pop 	r16
	pop 	ZH
	pop 	ZL
	ret


; Display Main Menu 'Left Channel Offset' screen
; This function displays the 'Edit Left Channel Offset' screen
DisplayLeftChannelOffsetScreen:
	push 	ZL
	push 	ZH
	push 	r16

	; Copy the screen static text in the LCD Application area
	ldi 	ZL, LOW(LCDMsgMainMenuLeftOffsetL1)	; Line 1
	ldi 	ZH, HIGH(LCDMsgMainMenuLeftOffsetL1)
	ldi 	r18, 0x00
	call 	CopyStaticMsgInLCDAppArea

	ldi 	ZL, LOW(LCDMsgMainMenuLeftOffsetL2)	; Line 2
	ldi 	ZH, HIGH(LCDMsgMainMenuLeftOffsetL2)
	ldi 	r18, 0x01
	call 	CopyStaticMsgInLCDAppArea

	ldi 	ZL, LOW(LCDMsgMainMenuLeftOffsetL3)	; Line 3
	ldi 	ZH, HIGH(LCDMsgMainMenuLeftOffsetL3)
	ldi 	r18, 0x02
	call 	CopyStaticMsgInLCDAppArea

	; Set variable text region in Line 3
	; Obtain text value of current 'Left Channel Offset' in dB (i.e. value memorized
	; in 'bCurrentLeftChannelOffset')
	; The function accepts the 'Offset Value' in register r16 and returns 
	; pointer to text value (in DSEG) in ZH:ZL with the text length in register r16
	lds 	r16, bCurrentLeftChannelOffset
	call 	GetLevelOffsetText

	; Copy variable text (field value) in the LCD Application area
	; The function arguments are:
	;   - Register r16 is the length of text to copy
	;   - Register r17 is the first character position in the line
	;   - Register r18 is the line index in the LCD Application area
	;   - Register ZH:ZL is pointer to text (in CSEG)
	ldi 	r17, LCDMsgMainMenuLeftOffsetL3_VarPos
	ldi 	r18, 0x02
	call 	SetFieldInLCDAppArea

	ldi 	ZL, LOW(LCDMsgMainMenuLeftOffsetL4)	; Line 4
	ldi 	ZH, HIGH(LCDMsgMainMenuLeftOffsetL4)
	ldi 	r18, 0x03
	call 	CopyStaticMsgInLCDAppArea

	; Set variable text region in Line 4
	; Obtain text value of 'Temporary Level Offset' in dB (i.e. value memorized
	; in 'bCurrentKeyboardInput')
	; The function accepts the 'Offset Value' in register r16 and returns 
	; pointer to text value (in DSEG) in ZH:ZL with the text length in register r16
	lds 	r16, bCurrentKeyboardInput
	call 	GetLevelOffsetText

	; Copy variable text (field value) in the LCD Application area
	; The function arguments are:
	;   - Register r16 is the length of text to copy
	;   - Register r17 is the first character position in the line
	;   - Register r18 is the line index in the LCD Application area
	;   - Register ZH:ZL is pointer to text (in CSEG)
	ldi 	r17, LCDMsgMainMenuLeftOffsetL4_VarPos
	ldi 	r18, 0x03
	call 	SetFieldInLCDAppArea

	; Update the display on the LCD device
	ldi 	r16, 0b00001111	; Line1-4 modified
	sts 	LCDAppBufferModifiedLines, r16 
	call 	LCDUpdateDisplay

	pop 	r16
	pop 	ZH
	pop 	ZL
	ret

; Display Main Menu 'Right Channel Offset' screen
; This function displays the 'Edit Right Channel Offset' screen
DisplayRightChannelOffsetScreen:
	push 	ZL
	push 	ZH
	push 	r16

	; Copy the screen static text in the LCD Application area
	ldi 	ZL, LOW(LCDMsgMainMenuRightOffsetL1)	; Line 1
	ldi 	ZH, HIGH(LCDMsgMainMenuRightOffsetL1)
	ldi 	r18, 0x00
	call 	CopyStaticMsgInLCDAppArea

	ldi 	ZL, LOW(LCDMsgMainMenuRightOffsetL2)	; Line 2
	ldi 	ZH, HIGH(LCDMsgMainMenuRightOffsetL2)
	ldi 	r18, 0x01
	call 	CopyStaticMsgInLCDAppArea

	ldi 	ZL, LOW(LCDMsgMainMenuRightOffsetL3)	; Line 3
	ldi 	ZH, HIGH(LCDMsgMainMenuRightOffsetL3)
	ldi 	r18, 0x02
	call 	CopyStaticMsgInLCDAppArea

	; Set variable text region in Line 3
	; Obtain text value of current 'High Pass Offset' in dB (i.e. value memorized
	; in 'bCurrentRightChannelOffset')
	; The function accepts the 'Offset Value' in register r16 and returns 
	; pointer to text value (in DSEG) in ZH:ZL with the text length in register r16
	lds 	r16, bCurrentRightChannelOffset
	call 	GetLevelOffsetText

	; Copy variable text (field value) in the LCD Application area
	; The function arguments are:
	;   - Register r16 is the length of text to copy
	;   - Register r17 is the first character position in the line
	;   - Register r18 is the line index in the LCD Application area
	;   - Register ZH:ZL is pointer to text (in CSEG)
	ldi 	r17, LCDMsgMainMenuRightOffsetL3_VarPos
	ldi 	r18, 0x02
	call 	SetFieldInLCDAppArea

	ldi 	ZL, LOW(LCDMsgMainMenuRightOffsetL4)	; Line 4
	ldi 	ZH, HIGH(LCDMsgMainMenuRightOffsetL4)
	ldi 	r18, 0x03
	call 	CopyStaticMsgInLCDAppArea

	; Set variable text region in Line 3
	; Obtain text value of 'Temporary Level Offset' in dB (i.e. value memorized
	; in 'bCurrentKeyboardInput')
	; The function accepts the 'Offset Value' in register r16 and returns 
	; pointer to text value (in DSEG) in ZH:ZL with the text length in register r16
	lds 	r16, bCurrentKeyboardInput
	call 	GetLevelOffsetText

	; Copy variable text (field value) in the LCD Application area
	; The function arguments are:
	;   - Register r16 is the length of text to copy
	;   - Register r17 is the first character position in the line
	;   - Register r18 is the line index in the LCD Application area
	;   - Register ZH:ZL is pointer to text (in CSEG)
	ldi 	r17, LCDMsgMainMenuRightOffsetL4_VarPos
	ldi 	r18, 0x03
	call 	SetFieldInLCDAppArea

	; Update the display on the LCD device
	ldi 	r16, 0b00001111	; Line1-4 modified
	sts 	LCDAppBufferModifiedLines, r16 
	call 	LCDUpdateDisplay

	pop 	r16
	pop 	ZH
	pop 	ZL
	ret

; Construct the text string (in dB) of the 'bCurrentLevel'
; The function returns pointer to text value (in CSEG) in ZH:ZL and the text
; length in register r16
; IMPORTANT: The returned ZH:ZL address is a BYTE address
GetCurrentLevelText:
	push 	r17
	push 	r0
	push 	r1

	; The 'bCurrentLevel' is the 7 bit index in the  'LCDMsgVolumeValues' 
   ; static messages table (so the table contains 128 messages)

	; Compute offset in 'LCDMsgVolumeValues' table
	lds 	r17, bCurrentLevel
	ldi 	r16, LCDMsgVolumeValues_MsgLength
	mul 	r16, r17

	; Compute 'LCDMsgVolumeValues' address
	; 'LCDMsgVolumeValues' is a word address (i.e. label address in program 
	; memory), compute the byte address
	ldi 	ZL, LOW(LCDMsgVolumeValues)
	ldi 	ZH, HIGH(LCDMsgVolumeValues)
	lsl 	ZH
	lsl 	ZL
	brcc 	GetCurrentLevelText_AddOffset
	inc 	ZH

GetCurrentLevelText_AddOffset:
	; Add offset to 'LCDMsgVolumeValues' address
	add 	ZL, r0
	adc   ZH, r1

	pop 	r1
	pop 	r0
	pop 	r17
	ret

; Construct the text string (in dB) of a specified Level Offset (signed value)
; The 'Level Offset' is specified in r16 register.
; The function returns pointer to text value (in DSEG) in ZH:ZL and the text
; length in register r16
GetLevelOffsetText:
	push 	r17
	push 	r18
	push 	r0
	push 	r1
	push 	YL
	push 	YH

	; The absolute value of 'Level Offset' is the 7 bit index from the 
	; beginning in the 'LCDMsgVolumeValues' static messages table (the table 
	; contains 128 messages)

	; Compute offset in 'LCDMsgVolumeValues' table
	mov 	r18, r16
	cpi 	r18, 0
	brge 	GetLevelOffsetText_AddrOffset
	neg 	r18

GetLevelOffsetText_AddrOffset:
	ldi 	r17, LCDMsgVolumeValues_MsgLength
	mul 	r18, r17

	; Compute 'LCDMsgVolumeValues' address
	; 'LCDMsgVolumeValues' is a word address (i.e. label address in program 
	; memory), compute the byte address
	ldi 	ZL, LOW(LCDMsgVolumeValues)
	ldi 	ZH, HIGH(LCDMsgVolumeValues)
	lsl 	ZH
	lsl 	ZL
	brcc 	GetLevelOffsetText_AddOffset
	inc 	ZH

GetLevelOffsetText_AddOffset:
	; Add offset to 'LCDMsgVolumeValues' address
	add 	ZL, r0
	adc 	ZH, r1

	; Formated string returned in 'StringFormatingBuffer' because the sign 
	; character must be added in front of the absolute value text
	ldi 	YL, LOW(StringFormatingBuffer)
	ldi 	YH, HIGH(StringFormatingBuffer)

	; Sign character
	ldi 	r17, '+'
	cpi 	r16, 0
	brge 	GetLevelOffsetText_StoreSign
	ldi 	r17, '-'

GetLevelOffsetText_StoreSign:
	st 	Y+, r17

	; Offset value
	ldi 	r17, LCDMsgVolumeValues_MsgLength

GetLevelOffsetText_CopyLoop:
	lpm 	r16, Z+	; Copy char from source to destination
	st 	Y+, r16
	dec 	r17
	brne 	GetLevelOffsetText_CopyLoop	

	; Return address and size of formated text
	ldi 	ZL, LOW(StringFormatingBuffer)
	ldi 	ZH, HIGH(StringFormatingBuffer)
	ldi 	r16, LCDMsgVolumeValues_MsgLength
	inc 	r16

	pop 	YH
	pop 	YL
	pop 	r1
	pop 	r0
	pop 	r18
	pop 	r17
	ret

; Construct the text string of the temperature measured by a specified sensor
; The sensor to use in specified in the r16 register
; The function returns pointer to text value (in CSEG) in ZH:ZL and the text
; length in register r16
; IMPORTANT: The returned ZH:ZL address is a BYTE address
GetCurrentTemperatureText:
	push 	r17
	push 	r0
	push 	r1

   ; Retrieve temperature value according to specified sensor
   cpi   r16, 0x00
   brne  GetCurrentTemperatureText_Right
   lds   r17, TemperatureLeftValue
   rjmp  GetCurrentTemperatureText_CheckValue

GetCurrentTemperatureText_Right:
   lds   r17, TemperatureRightValue

GetCurrentTemperatureText_CheckValue:
   ; Temperature greater than 99.5°C are displayed as '100+' (i.e. index 198)
   cpi   r17, 199
   brlo  GetCurrentTemperatureText_ComputeOffset
   ldi   r17, 198

GetCurrentTemperatureText_ComputeOffset:

	; The retrieved temperature value is the index in 'LCDMsgTemperatureValues' 
   ; static messages table (the table contains 199 messages)

	; Compute offset in 'LCDMsgTemperatureValues' table
	ldi 	r16, LCDMsgTemperatureValues_MsgLength
	mul 	r16, r17

	; Compute 'LCDMsgTemperatureValues' address
	; 'LCDMsgTemperatureValues' is a word address (i.e. label address in program 
	; memory), compute the byte address
	ldi 	ZL, LOW(LCDMsgTemperatureValues)
	ldi 	ZH, HIGH(LCDMsgTemperatureValues)
	lsl 	ZH
	lsl 	ZL
	brcc 	GetCurrentTemperatureText_AddOffset
	inc 	ZH

GetCurrentTemperatureText_AddOffset:
	; Add offset to 'LCDMsgTemperatureValues' address
	add 	ZL, r0
	adc   ZH, r1

	pop 	r1
	pop 	r0
	pop 	r17
	ret

