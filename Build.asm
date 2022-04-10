;******************************************************************************
; Amplifier Main Controller V1.1.0
;
; File:	Build.asm
;
; Author: F.Fargon
; 
; Purpose:
;  - This file is used to indicate the target amplifier for the generated 
;    executable code.
;
; Comments:
;  - The current software does not allow external configuration of amplifier
;    TCP/IP parameters. In a future version, it will be possible to adjust
;    these parameters after firmware update using ACP protocol or IR remote
;    control.
;  - This include file is provided as helper for generation of the specific
;    firmware instances for the different targeted amplifiers.
;******************************************************************************

;******************************************************************************
; Target amplifiers
;******************************************************************************

; Select one of the following definition in order to build the firmware for the
; corresponding amplifier
#define	BUILD_TARGET_AMPLIFIER_LAB          ; Lab. development platform
;#define	BUILD_TARGET_AMPLIFIER_UP_RIGHT     ; UP mono amplifier right channel (UP2)   
;#define	BUILD_TARGET_AMPLIFIER_UP_LEFT      ; UP mono amplifier left channel (UP1)   

