;******************************************************************************
; Amplifier Main Controller V1.x
;
; File:	Version.asm
;
; Author: F.Fargon
;
; Purpose: This file contains the version string.
;          This string is displayed on the LCD when amplifier is in 'SLEEPING'
;          state.
;
; Comment: The version string MUST be updated during the build process of a new
;          release.
;******************************************************************************


;******************************************************************************
; Version history
;******************************************************************************


;******************************************************************************
; Version V1.1.0 RC1
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
; Release date:
;  - 01/10/2012
;
; Deployment:
;  - Lab. development platform
;  - UP1 and UP2 mono amplifiers
;
; Restrictions:
;  - Not for use on dual channel amplifier (not tested with dual channel 
;    amplifier protection board)
;******************************************************************************

;******************************************************************************
; Version V1.1.0 RC2
;
; Feature summary:
;  - See V1.1.0 RC1
;
; Fixed issues:
;  - None
;
; New feature:
;  - Added support for direct control of ON/OFF and MUTE/UNMUTE without pulse 
;    generation on Amplifier Protection trigger pins.
;    This feature is used on modified Amplifier Protection V3.1 boards and later
;    versions.
;    This feature is added for fixing unwanted triggering on Amplifier Protection
;    V3.1 board due to relay transient (because of too high pulldown resistors on
;    input pin of CMOS logic chips)
;    This feature can be disabled by #define 'AMPLIFIERPROT_V31_TRIGGER'
;
; Release date:
;  - 14/12/2012
;
; Deployment:
;  - Lab. development platform
;  - UP1 and UP2 mono amplifiers
;
; Restrictions:
;  - Not for use on dual channel amplifier (not tested with dual channel 
;    amplifier protection board)
;******************************************************************************

;******************************************************************************
; Version V1.1.0 RC3
;
; Feature summary:
;  - See V1.1.0 RC1, V1.1.0 RC2
;
; Fixed issues:
;  - None
;
; New feature:
;  - Added temperature measurement and display (left and right sensors)
;
; Release date:
;  - 11/01/2013
;
; Deployment:
;  - Lab. development platform
;  - UP1 and UP2 mono amplifiers
;
; Restrictions:
;  - Not for use on dual channel amplifier (not tested with dual channel 
;    amplifier protection board)
;******************************************************************************

;******************************************************************************
; Version V1.1.0 RC4
;
; Feature summary:
;  - See V1.1.0 RC1, V1.1.0 RC2, V1.1.0 RC3
;
; Fixed issues:
;  - Firmware rebuilt without '#define BUTTON_LESS' (front panel ON/OFF button
;    not detected with RC3)
;
; New feature:
;  - None
;
; Release date:
;  - 03/12/2013
;
; Deployment:
;  - Lab. development platform
;  - UP1 and UP2 mono amplifiers
;
; Restrictions:
;  - Not for use on dual channel amplifier (not tested with dual channel 
;    amplifier protection board)
;******************************************************************************

;******************************************************************************
; Version V1.1.0 RC5
;
; Feature summary:
;  - See V1.1.0 RC1, V1.1.0 RC2, V1.1.0 RC3, V1.1.0 RC4
;
; Fixed issues:
;  - Bounces on front panel ON/OFF button with RC4: interrupt associated to
;    ON/OFF button is disabled for a short period after initial interrupt is
;    entered 
;
; New feature:
;  - None
;
; Release date:
;  - 04/02/2014
;
; Deployment:
;  - Lab. development platform
;  - UP1 and UP2 mono amplifiers
;
; Restrictions:
;  - Not for use on dual channel amplifier (not tested with dual channel 
;    amplifier protection board)
;******************************************************************************

;******************************************************************************
; Version V1.1.0 RC6
;
; Feature summary:
;  - See V1.1.0 RC1, V1.1.0 RC2, V1.1.0 RC3, V1.1.0 RC4, V1.1.0 RC5
;
; Fixed issues:
;  - Bounces on front panel ON/OFF button not fully fixed with RC5: explicit
;    counter used to reject interrupts associated to ON/OFF and MUTE buttons
;    during a short period after initial interrupt is entered 
;
; New feature:
;  - None
;
; Release date:
;  - 14/04/2014
;
; Deployment:
;  - Lab. development platform
;  - UP1 and UP2 mono amplifiers
;
; Restrictions:
;  - Not for use on dual channel amplifier (not tested with dual channel 
;    amplifier protection board)
;******************************************************************************


.CSEG

;******************************************************************************
; Static Version String
;******************************************************************************
  
; The version string format is 'Major.Minor.SP [RCx][GA] with:
; 'Major'     = The major version number
; 'Minor'     = The minor version number
; 'SP'        = The service pack version number
; '[RCx][GA]' = The Release Candidate number or General Availablity tag
;               (mutually exclusive)

; IMPORTANT: The version string length MUST be equal to 'LCDCharPerLineNumber - 9'

VERSION_String:  .DB   "1.1.0 RC6  "
