;===============================================================================
;  ____   ____ ____         ____ _            _    
; |  _ \ / ___| __ )       / ___| | ___   ___| | __
; | |_) | |  _|  _ \ _____| |   | |/ _ \ / __| |/ /
; |  _ <| |_| | |_) |_____| |___| | (_) | (__|   < 
; |_| \_\\____|____/       \____|_|\___/ \___|_|\_\
;                                                  
;-------------------------------------------------------------------------------
; Copyright (C)2019 Andrew John Jacobs.
; All rights reserved.
;
; This work is made available under the terms of the Creative Commons
; Attribution-NonCommercial-ShareAlike 4.0 International license. Open the
; following URL to see the details.
;
; http://creativecommons.org/licenses/by-nc-sa/4.0/
;===============================================================================
;
; Notes:
;
;-------------------------------------------------------------------------------
        
                errorlevel -302
                
#define M(X)	(.1<<(X))
		
;===============================================================================
; Device Configuration
;-------------------------------------------------------------------------------
                
                include "p16f1455.inc"
                
 __CONFIG _CONFIG1, _FOSC_INTOSC & _WDTE_OFF & _PWRTE_OFF & _MCLRE_ON & _CP_OFF & _BOREN_OFF & _CLKOUTEN_OFF & _IESO_OFF & _FCMEN_OFF

 __CONFIG _CONFIG2, _WRT_OFF & _CPUDIV_NOCLKDIV & _USBLSCLK_48MHz & _PLLMULT_3x & _PLLEN_ENABLED & _STVREN_ON & _BORV_LO & _LPBOR_OFF & _LVP_OFF

;===============================================================================
; Hardware Configuration
;-------------------------------------------------------------------------------

OSC             equ     .16000000
PLL             equ     .3
             
FOSC            equ     OSC * PLL
            
;-------------------------------------------------------------------------------

; Inputs
            
SQW_TRIS        equ     TRISC		; SQW output from DS1307
SQW_PORT        equ     PORTC
SQW_PIN         equ     .2

SWA_TRIS        equ     TRISA		; Switch A (SELECT)
SWA_PORT        equ     PORTA
SWA_WPU		equ	WPUA
SWA_PIN         equ     .5
            
SWB_TRIS        equ     TRISA		; Switch B (CHANGE)
SWB_PORT        equ     PORTA
SWB_WPU		equ	WPUA
SWB_PIN         equ     .4

; Outputs

SCL_TRIS        equ     TRISC		; Software generated I2C SCL
SCL_LAT		equ	LATC
SCL_PIN         equ     .4

SDA_TRIS        equ     TRISC		; Software generated I2C SDA
SDA_PORT        equ     PORTC
SDA_LAT		equ	LATC
SDA_PIN         equ     .5

LED_TRIS        equ     TRISC		; Neo pixel data out
LED_LAT         equ     LATC
LED_BIT         equ     .3
         
;-------------------------------------------------------------------------------
         
TMR2_HZ         equ     .100		; Target frequency
TMR2_PRE        equ     .64             ; Prescaler 1, 4, 16 or 64
TMR2_POST       equ     .16             ; Postscaler 1 to 16
       
TMR2_PR         equ     FOSC / (.4 * TMR2_HZ * TMR2_PRE * TMR2_POST ) - .1
         
                if      TMR2_PR & h'ffffff00'
                error   "Timer2 PR does not fit in 8-bits
                endif

; DS1307 I2C address
		
DS1307		equ	h'd0'
I2C_RD		equ	h'01'
I2C_WR		equ	h'00'
		
;===============================================================================
; Macros
;-------------------------------------------------------------------------------
		
; Transmit the byte in WREG into as a series short (0.4uS) and long (0.85uS)
; pulses representing zero and one respectively.
                
SEND_BIT        macro   BIT
                bsf     LED_LAT,LED_BIT
                nop
                nop
                nop
                btfss   WREG,BIT
                bcf     LED_LAT,LED_BIT
                nop
                nop
                nop
                nop
                bcf     LED_LAT,LED_BIT
                endm
                
SEND_GAP        macro
                nop
		nop
		nop
		nop
                nop
                nop
                endm
        
;-------------------------------------------------------------------------------		
		
; The SET_RGB macro loads the RED, GREEN and BLUE registers with a set of scaled
; values.

SET_RGB		macro	XR,XG,XB,XP
		movlw	((XR * XP) / .100)
		movwf	RED
		movlw	((XG * XP) / .100)
		movwf	GREEN
		movlw	((XB * XP) / .100)
		movwf	BLUE
		endm
	
;===============================================================================
; Data Areas
;-------------------------------------------------------------------------------

                udata_shr       h'070'
		
TICKS           res     .1		; Count down tick counter
SQW		res	.1		; State of SQW at last interrupt
UPDATED		res	.1		; Non-zero if SQW has changed
		
HR		res	.1		; Hour
MN		res	.1		; Minute
SC		res	.1		; Second
		
RED		res	.1		; RGB colour
GREEN		res	.1
BLUE		res	.1
		
SAVED_RED	res	.1		; Saved colour
SAVED_GREEN	res	.1
SAVED_BLUE	res	.1
         
THEME		res	.1		; Colour theme
BUTTONS		res	.1		; Button states

SCRATCH		res	.1

;-------------------------------------------------------------------------------
            
SEG_A           equ     .0
SEG_B           equ     .3
SEG_C           equ     .6
SEG_D           equ     .9
SEG_E           equ     .12
SEG_F           equ     .15
SEG_G           equ     .18
SEG_P           equ     .21
           
LED_R           equ     .0
LED_G           equ     .1
LED_B           equ     .2
                 
.segments0      udata
                
S1              res     .8 * .3		; Hour Hi
S2              res     .8 * .3		; Hour Lo
              
.segments       udata
        
S3              res     .8 * .3		; Minute Hi     
S4              res     .8 * .3		; Minute Lo

;===============================================================================
; Interrupt Handler
;-------------------------------------------------------------------------------
        
.Interrupt      code    h'0004'
      
                banksel PIR1
                btfss   PIR1,TMR2IF     ; Did Timer2 cause the interrupt?
                goto    Timer2Handled
                bcf     PIR1,TMR2IF     ; Yes, clear the flag
		
                movf    TICKS,F         ; Any ticks left?
                btfss   STATUS,Z
                decf    TICKS,F         ; Yes, reduce the count
				
		banksel	SQW_PORT	; Read SQW state
		movf	SQW_PORT,W
		xorwf	SQW,W		; Save latest state
		xorwf	SQW,F

		andlw	M(SQW_PIN)	; SQW Changed?
		btfsc	STATUS,Z
		bra	Timer2Handled	; No.
		bsf	UPDATED,.0	; Yes.
		
		btfss	SQW,SQW_PIN	; SQW now HI?
		bra	Timer2Handled	; No.
		
		call	BumpSeconds	; Bump the time
		btfsc	STATUS,Z
		call	BumpMinutes
		btfsc	STATUS,Z
		call	BumpHours	
Timer2Handled:
        
                retfie
		
;-------------------------------------------------------------------------------

; Add one to the seconds value. Return with Z set to indicate if the value
; has wrapped around.

BumpSeconds:
		movf	SC,W		; Bump seconds
		addlw	.7
		btfss	STATUS,DC	; .. decimal adjust
		addlw	-.6
		movwf	SC
		xorlw	h'60'		; Reached limit?
		btfss	STATUS,Z
		return			; No
		clrf	SC		; Yes
		return
		
; Add one to the minutes value. Return with Z set to indicate if the value
; has wrapped around.

BumpMinutes:
		movf	MN,W		; Bump minutes
		addlw	.7
		btfss	STATUS,DC	; .. decimal adjust
		addlw	-.6
		movwf	MN
		xorlw	h'60'		; Reached limit?
		btfss	STATUS,Z
		return			; No
		clrf	MN		; Yes
		return
	
; Add one to the hours value. Return with Z set to indicate if the value has
; wrapped around.

BumpHours:
		movf	HR,W		; Bump hours
		addlw	.7
		btfss	STATUS,DC	; .. decimal adjust
		addlw	-.6
		movwf	HR
		xorlw	h'24'		; Reached limit?
		btfss	STATUS,Z
		return			; No
		clrf	HR		; Yes
		return			

;===============================================================================
; Power On Reset
;-------------------------------------------------------------------------------

.Reset          code    h'0000'
          
                goto    PowerOnReset
                
;-------------------------------------------------------------------------------
                
                code
              
PowerOnReset:
		banksel OPTION_REG	; Enable WPU register
		bcf	OPTION_REG,.7
        
                movlw   b'11111100'     ; Switch to 48Mhz
                banksel OSCCON
                movwf   OSCCON
                
                clrwdt
                ifndef  __MPLAB_DEBUGGER_SIMULATOR
WaitTillStable:
                btfss   OSCSTAT,HFIOFS  ; Stabilised yet?
                bra     WaitTillStable
                endif
                
;-------------------------------------------------------------------------------
        
                banksel ANSELA          ; Make all pins digital
                clrf    ANSELA
		clrf	ANSELC
                banksel LATA
                clrf    LATA
                clrf    LATC
		banksel	WPUA
		movwf	WPUA
                movlw   M(SWA_PIN)|M(SWB_PIN)
                banksel TRISA           ; Set the I/O directions
                movwf   TRISA
                movlw	M(SQW_PIN) 
                movwf   TRISC
                
;-------------------------------------------------------------------------------
                
                movlw   TMR2_PR		; Set the period
                banksel PR2
                movwf   PR2
                clrf    TMR2
                
                movlw   b'01111111'	; Configure the timer
                banksel T2CON
                movwf   T2CON
                
                banksel PIR2
                bcf     PIR2,TMR2IF	; Prepare interrupts
                banksel PIE1
                bsf     PIE1,TMR2IE
                
;-------------------------------------------------------------------------------
		
		call	RtcInit		; Read initial time
		
		clrf	THEME
	
                bsf     INTCON,PEIE	; Start interrupt handling
                bsf     INTCON,GIE
      
                call	SelectHrHi	; Clear segments
		call	SetBlank
		call	SelectHrLo
		call	SetBlank
		call	SelectMnHi
		call	SetBlank
		call	SelectMnLo
		call	SetBlank
		
                call    UpdateLeds	; And update the pixels
		
;===============================================================================
; User Inteface
;-------------------------------------------------------------------------------
		
WaitForPress:
		clrwdt
		movf	UPDATED,W	; Has SQW changed?
		btfss	STATUS,Z
		call	FlashSeconds	; Yes, update the time
		
		movlw	.10		; Set press timeout
		movwf	TICKS
		
		banksel	SWA_PORT	; Check switches
		btfss	SWA_PORT,SWA_PIN
		bra	TimeRelease	
		btfss	SWB_PORT,SWB_PIN
		bra	ThemeRelease

		bra	WaitForPress

;-------------------------------------------------------------------------------

TimeRelease:
		clrwdt			
		movf	UPDATED,W	; Has SQW changed?
		btfss	STATUS,Z
		call	FlashSeconds	; Yes, update the time
		
		banksel	SWA_PORT	; Has the switch been released?
		btfss	SWA_PORT,SWA_PIN
		bra	TimeRelease	; No
		movf	TICKS,W		; Yes, for debounce period?
		btfss	STATUS,Z
		bra	WaitForPress	; No.
		
AlterHours:
		clrwdt
		movf	UPDATED,W	; Has SQW changed?
		btfss	STATUS,Z
		call	FlashHours
		
		movlw	.10		; Set press timeout
		movwf	TICKS
		
		banksel	SWA_PORT	; Check switches
		btfss	SWA_PORT,SWA_PIN
		bra	HoursRelease	
		btfsc	SWB_PORT,SWB_PIN
		bra	AlterHours
		
RepeatHours:
		call	BumpHours	; Change the time
		
		movlw	.100		; Set repeat timeout
		movwf	TICKS
		
HeldHours:
		clrwdt
		movf	UPDATED,W	; Has SQW changed?
		btfss	STATUS,Z
		call	FlashHours
		
		banksel	SWB_PORT	; Switch held?
		btfsc	SWB_PORT,SWB_PIN
		bra	AlterHours
	
		movf	TICKS,W		; Timeout out?
		btfss	STATUS,Z
		bra	HeldHours	; No
		bra	RepeatHours	; Yes
		
;-------------------------------------------------------------------------------
		
HoursRelease:
		clrwdt	
		movf	UPDATED,W	; Has SQW changed?
		btfss	STATUS,Z
		call	FlashHours
		
		banksel	SWA_PORT	; Has the switch been released?
		btfss	SWA_PORT,SWA_PIN
		bra	HoursRelease	; No
		movf	TICKS,W		; Yes, for debounce period?
		btfss	STATUS,Z
		bra	AlterHours	; No.
	
AlterMinutes:
		clrwdt
		movf	UPDATED,W	; Has SQW changed?
		btfss	STATUS,Z
		call	FlashMinutes	
    		
		movlw	.10		; Set press timeout
		movwf	TICKS
		
		banksel	SWA_PORT	; Check switches
		btfss	SWA_PORT,SWA_PIN
		bra	MinutesRelease	
		btfsc	SWB_PORT,SWB_PIN
		bra	AlterMinutes
		
RepeatMinutes:
		call	BumpMinutes

		movlw	.100		; Set repeat timeout
		movwf	TICKS
		
HeldMinutes:
		clrwdt
		movf	UPDATED,W	; Has SQW changed?
		btfss	STATUS,Z
		call	FlashMinutes
		
		banksel	SWB_PORT	; Switch held?
		btfsc	SWB_PORT,SWB_PIN
		bra	AlterMinutes
	
		movf	TICKS,W		; Timeout out?
		btfss	STATUS,Z
		bra	HeldMinutes	; No
		bra	RepeatMinutes	; Yes

;-------------------------------------------------------------------------------
		
MinutesRelease:
		clrwdt			; Has the switch been released?
		banksel	SWA_PORT
		btfss	SWA_PORT,SWA_PIN
		bra	MinutesRelease	; No
		movf	TICKS,W		; Yes, for debounce period?
		btfss	STATUS,Z
		bra	AlterMinutes	; No.
		
		call	RtcWrite	; Save back to RTC
		bra	WaitForPress	; .. and go back to display
		
;-------------------------------------------------------------------------------
		
ThemeRelease:

		bra	WaitForPress
	
		
;===============================================================================
; Time Display
;-------------------------------------------------------------------------------

; Display the current time flashing the seconds in sync with the SQW input.

FlashSeconds:
		call	SelectHrHi	; Work out new pixel states
		swapf	HR,W
		call	ShowDigit
		call	SetBlack
		call	SetSegment
		
		call	SelectHrLo
		movf	HR,W
		call	ShowDigit
		call	SetBlack
		btfss	SQW,SQW_PIN
		call	SetWhite
		call	SetSegment

		call	SelectMnHi
		swapf	MN,W
		call	ShowDigit
		call	SetBlack
		btfss	SQW,SQW_PIN
		call	SetWhite
		call	SetSegment

		call	SelectMnLo
		movf	MN,W
		call	ShowDigit
		call	SetBlack
		call	SetSegment
		
		clrf	UPDATED
		goto	UpdateLeds

; Display the time flashing the hours in sync with the SQW input.

FlashHours:
                call	SelectHrHi	; Clear hours segments
		call	SetBlank
		call	SelectHrLo
		call	SetBlank
		
		btfss	SQW,SQW_PIN
		bra	HoursFlashed
		
		call	SelectHrHi	; Work out new pixel states
		swapf	HR,W
		call	ShowDigit
		call	SetBlack
		call	SetSegment
		
		call	SelectHrLo
		movf	HR,W
		call	ShowDigit
		call	SetBlack
		call	SetSegment
HoursFlashed:
	
		call	SelectMnHi
		swapf	MN,W
		call	ShowDigit
		call	SetBlack
		call	SetSegment

		call	SelectMnLo
		movf	MN,W
		call	ShowDigit
		call	SetBlack
		call	SetSegment

		clrf	UPDATED
		goto	UpdateLeds

; Display the time flashing the minutes in sync with the SQW input.
		
FlashMinutes:
		call	SelectHrHi	; Work out new pixel states
		swapf	HR,W
		call	ShowDigit
		call	SetBlack
		call	SetSegment
		
		call	SelectHrLo
		movf	HR,W
		call	ShowDigit
		call	SetBlack
		call	SetSegment

                call	SelectMnHi	; Clear minutes segments
		call	SetBlank
		call	SelectMnLo
		call	SetBlank

		btfss	SQW,SQW_PIN
		bra	MinutesFlashed
		
		call	SelectMnHi
		swapf	MN,W
		call	ShowDigit
		call	SetBlack
		call	SetSegment

		call	SelectMnLo
		movf	MN,W
		call	ShowDigit
		call	SetBlack
		call	SetSegment	; PM??
MinutesFlashed:
	
		clrf	UPDATED
		goto	UpdateLeds

;===============================================================================
; Segment 
;-------------------------------------------------------------------------------
		
SelectHrHi:
                movlw   low S1
                movwf   FSR0L
                movlw   high S1
                movwf   FSR0H
		return
		
SelectHrLo:
                movlw   low S2
                movwf   FSR0L
                movlw   high S2
                movwf   FSR0H
		return
		
SelectMnHi:
                movlw   low S3
                movwf   FSR0L
                movlw   high S3
                movwf   FSR0H
		return

SelectMnLo:
                movlw   low S4
                movwf   FSR0L
                movlw   high S4
                movwf   FSR0H
		return

;-------------------------------------------------------------------------------

; Set all of the colour data for the selected display to black.
		
SetBlank:
		call	SetBlack
		call	SetSegment
		call	SetSegment
		call	SetSegment
		call	SetSegment
		call	SetSegment
		call	SetSegment
		call	SetSegment
		goto	SetSegment

;-------------------------------------------------------------------------------
		
ShowDigit:
		movwf	SCRATCH
		movf	THEME,W
		andlw	.3
		brw
		goto	FixedSegment
		goto	FixedNumber
		goto	Rotating
		goto	DawnToDusk
    
;===============================================================================
; Theme 0 - Fixed Segment Colours
;-------------------------------------------------------------------------------
    
FixedSegment:
		movf	SCRATCH,W
		andlw	h'0f'
		brw
		
		goto	Fixed0
		goto	Fixed1
		goto	Fixed2
		goto	Fixed3
		goto	Fixed4
		goto	Fixed5
		goto	Fixed6
		goto	Fixed7
		goto	Fixed8
		goto	Fixed9
		return
		return
		return
		return
		return
		return
		
Fixed0:
		call	SetRed
		call	SetSegment
		call	SetOrange
		call	SetSegment
		call	SetYellow
		call	SetSegment
		call	SetGreen
		call	SetSegment
		call	SetBlue
		call	SetSegment
		call	SetIndigo
		call	SetSegment
		call	SetBlack
		goto	SetSegment

Fixed1:
		call	SetBlack
		call	SetSegment
		call	SetOrange
		call	SetSegment
		call	SetYellow
		call	SetSegment
		call	SetBlack
		call	SetSegment
		call	SetBlack
		call	SetSegment
		call	SetBlack
		call	SetSegment
		call	SetBlack
		goto	SetSegment

Fixed2:
		call	SetRed
		call	SetSegment
		call	SetOrange
		call	SetSegment
		call	SetBlack
		call	SetSegment
		call	SetGreen
		call	SetSegment
		call	SetBlue
		call	SetSegment
		call	SetBlack
		call	SetSegment
		call	SetViolet
		goto	SetSegment

Fixed3:
		call	SetRed
		call	SetSegment
		call	SetOrange
		call	SetSegment
		call	SetYellow
		call	SetSegment
		call	SetGreen
		call	SetSegment
		call	SetBlack
		call	SetSegment
		call	SetBlack
		call	SetSegment
		call	SetViolet
		goto	SetSegment

Fixed4:
		call	SetBlack
		call	SetSegment
		call	SetOrange
		call	SetSegment
		call	SetYellow
		call	SetSegment
		call	SetBlack
		call	SetSegment
		call	SetBlack
		call	SetSegment
		call	SetIndigo
		call	SetSegment
		call	SetViolet
		goto	SetSegment
		
Fixed5:
		call	SetRed
		call	SetSegment
		call	SetBlack
		call	SetSegment
		call	SetYellow
		call	SetSegment
		call	SetGreen
		call	SetSegment
		call	SetBlack
		call	SetSegment
		call	SetIndigo
		call	SetSegment
		call	SetViolet
		goto	SetSegment
		
Fixed6:
		call	SetRed
		call	SetSegment
		call	SetBlack
		call	SetSegment
		call	SetYellow
		call	SetSegment
		call	SetGreen
		call	SetSegment
		call	SetBlue
		call	SetSegment
		call	SetIndigo
		call	SetSegment
		call	SetViolet
		goto	SetSegment
		
Fixed7:
		call	SetRed
		call	SetSegment
		call	SetOrange
		call	SetSegment
		call	SetYellow
		call	SetSegment
		call	SetBlack
		call	SetSegment
		call	SetBlack
		call	SetSegment
		call	SetBlack
		call	SetSegment
		call	SetBlack
		goto	SetSegment
		
Fixed8:
		call	SetRed
		call	SetSegment
		call	SetOrange
		call	SetSegment
		call	SetYellow
		call	SetSegment
		call	SetGreen
		call	SetSegment
		call	SetBlue
		call	SetSegment
		call	SetIndigo
		call	SetSegment
		call	SetViolet
		goto	SetSegment
		
Fixed9:
		call	SetRed
		call	SetSegment
		call	SetOrange
		call	SetSegment
		call	SetYellow
		call	SetSegment
		call	SetBlack
		call	SetSegment
		call	SetBlack
		call	SetSegment
		call	SetIndigo
		call	SetSegment
		call	SetViolet
		goto	SetSegment
		
;===============================================================================
; Fixed Number Colours
;-------------------------------------------------------------------------------
		
FixedNumber:
		movf	SCRATCH,W
		andlw	h'0f'
		brw
		
		goto	Number0
		goto	Number1
		goto	Number2
		goto	Number3
		goto	Number4
		goto	Number5
		goto	Number6
		goto	Number7
		goto	Number8
		goto	Number9
		return
		return
		return
		return
		return
		return
		
Number0:
		call	SetRed
Digit0:
		call	PushColour
		call	SetSegment
		call	SetSegment
		call	SetSegment
		call	SetSegment
		call	SetSegment
		call	SetSegment
		call	SetBlack
		goto	SetSegment

Number1:
		call	SetOrange
Digit1:
		call	PushColour
		call	SetBlack
		call	SetSegment
		call	PullColour
		call	SetSegment
		call	SetSegment
		call	SetBlack
		call	SetSegment
		call	SetSegment
		call	SetSegment
		goto	SetSegment

Number2:
		call	SetYellow
Digit2:
		call	PushColour
		call	SetSegment
		call	SetSegment
		call	SetBlack
		call	SetSegment
		call	PullColour
		call	SetSegment
		call	SetSegment
		call	SetBlack
		call	SetSegment
		call	PullColour
		goto	SetSegment

Number3:
		call	SetGreen
Digit3:
		call	PushColour
		call	SetSegment
		call	SetSegment
		call	SetSegment
		call	SetSegment
		call	SetBlack
		call	SetSegment
		call	SetSegment
		call	PullColour
		goto	SetSegment

Number4:
		call	SetBlue
Digit4:
		call	PushColour
		call	SetBlack
		call	SetSegment
		call	PullColour
		call	SetSegment
		call	SetSegment
		call	SetBlack
		call	SetSegment
		call	SetSegment
		call	PullColour
		call	SetSegment
		goto	SetSegment
		
Number5:
		call	SetIndigo
Digit5:
		call	PushColour
		call	SetSegment
		call	SetBlack
		call	SetSegment
		call	PullColour
		call	SetSegment
		call	SetSegment
		call	SetBlack
		call	SetSegment
		call	PullColour
		call	SetSegment
		goto	SetSegment
		
Number6:
		call	SetViolet
Digit6:
		call	PushColour
		call	SetSegment
		call	SetBlack
		call	SetSegment
		call	PullColour
		call	SetSegment
		call	SetSegment
		call	SetSegment
		call	SetSegment
		goto	SetSegment
		
Number7:
		call	SetFuchsia
Digit7:
		call	PushColour
		call	SetSegment
		call	SetSegment
		call	SetSegment
		call	SetBlack
		call	SetSegment
		call	SetSegment
		call	SetSegment
		goto	SetSegment
		
Number8:
		call	SetTurquoise
Digit8:
		call	PushColour
		call	SetSegment
		call	SetSegment
		call	SetSegment
		call	SetSegment
		call	SetSegment
		call	SetSegment
		goto	SetSegment
		
Number9:
		call	SetCyan
Digit9:
		call	PushColour
		call	SetSegment
		call	SetSegment
		call	SetSegment
		call	SetBlack
		call	SetSegment
		call	SetSegment
		call	PullColour
		call	SetSegment
		goto	SetSegment

;===============================================================================
;-------------------------------------------------------------------------------
		
Rotating:
		movf	MN,W
		call	SetColour
DoDigit:
		movf	SCRATCH,W
		andlw	h'0f'
		brw
		
		goto	Digit0
		goto	Digit1
		goto	Digit2
		goto	Digit3
		goto	Digit4
		goto	Digit5
		goto	Digit6
		goto	Digit7
		goto	Digit8
		goto	Digit9
		return
		return
		return
		return
		return
		return
    
;===============================================================================
;-------------------------------------------------------------------------------

DawnToDusk:
		movf	HR,W
		andlw	h'3f'
		brw
		
		goto	Hour00
		goto	Hour01
		goto	Hour02
		goto	Hour03
		goto	Hour04
		goto	Hour05
		goto	Hour06
		goto	Hour07
		goto	Hour08
		goto	Hour09
		return
		return
		return
		return
		return
		return
		
		goto	Hour10
		goto	Hour11
		goto	Hour12
		goto	Hour13
		goto	Hour14
		goto	Hour15
		goto	Hour16
		goto	Hour17
		goto	Hour18
		goto	Hour19
		return
		return
		return
		return
		return
		return
		
		goto	Hour20
		goto	Hour21
		goto	Hour22
		goto	Hour23
		return
		return
		return
		return
		return
		return
		return
		return
		return
		return
		return
		return
		
		return
 		return
		return
		return
		return
 		return
		return
		return
		return
 		return
		return
		return
		return
 		return
		return
		return

Hour00:
		SET_RGB h'24',h'25',h'a4',.20
		goto	DoDigit
    
Hour01:
		SET_RGB h'00',h'01',h'9d',.20
		goto	DoDigit
    
Hour02:
		SET_RGB h'00',h'01',h'ab',.20
		goto	DoDigit
    
Hour03:
		SET_RGB h'00',h'07',h'bf',.20
		goto	DoDigit
    
Hour04:
		SET_RGB h'38',h'61',h'b6',.20
		goto	DoDigit
    
Hour05:
		SET_RGB h'50',h'95',h'cc',.20
		goto	DoDigit
    
Hour06:
		SET_RGB h'5f',h'b4',h'c2',.20
		goto	DoDigit
    
Hour07:
		SET_RGB h'8c',h'dd',h'c8',.20
		goto	DoDigit
    
Hour08:
		SET_RGB h'99',h'e5',h'ae',.20
		goto	DoDigit
    
Hour09:
		SET_RGB h'f8',h'fe',h'86',.20
		goto	DoDigit
    
Hour10:
		SET_RGB h'ec',h'ff',h'dd',.20
		goto	DoDigit
    
Hour11:
		SET_RGB h'9c',h'ff',h'e2',.20
		goto	DoDigit
    
Hour12:
		SET_RGB h'80',h'ff',h'ff',.20
		goto	DoDigit
    
Hour13:
		SET_RGB h'80',h'ff',h'ff',.20
		goto	DoDigit
    
Hour14:
		SET_RGB h'5b',h'ec',h'ed',.20
		goto	DoDigit
    
Hour15:
		SET_RGB h'3e',h'dd',h'de',.20
		goto	DoDigit
    
Hour16:
		SET_RGB h'0d',h'c4',h'c6',.20
		goto	DoDigit
    
Hour17:
		SET_RGB h'20',h'c7',h'c8',.20
		goto	DoDigit
    
Hour18:
		SET_RGB h'74',h'dc',h'dc',.20
		goto	DoDigit
    
Hour19:
		SET_RGB h'ff',h'b5',h'61',.20
		goto	DoDigit
    
Hour20:
		SET_RGB h'fa',h'7a',h'56',.20
		goto	DoDigit
    
Hour21:
		SET_RGB h'e3',h'4a',h'54',.20
		goto	DoDigit
    
Hour22:
		SET_RGB h'a0',h'6f',h'c7',.20
		goto	DoDigit
    
Hour23:
		SET_RGB h'5b',h'5b',h'da',.20
		goto	DoDigit
     
;===============================================================================
; RGB Color Selection
;-------------------------------------------------------------------------------

SetColour:
		andlw	h'0f'
		brw
		goto	SetRed
		goto	SetOrange
		goto	SetYellow
		goto	SetGreen
		goto	SetBlue
		goto	SetIndigo
		goto	SetViolet
		goto	SetFuchsia
		goto	SetTurquoise
		goto	SetCyan
		return
		return
		return
		return
		return
		return		
		
SetBlack:
		SET_RGB	h'00',h'00',h'00',.20
		goto	SetBrightness
		
SetWhite:
		SET_RGB	h'ff',h'ff',h'ff',.20
		goto	SetBrightness
		
SetRed:
		SET_RGB	h'ff',h'00',h'00',.20
		goto	SetBrightness
		
SetOrange:
		SET_RGB	h'ff',h'8c',h'00',.20
		goto	SetBrightness
    
SetYellow:
		SET_RGB	h'ff',h'ff',h'00',.20
		goto	SetBrightness
		
SetGreen:
		SET_RGB	h'00',h'ff',h'00',.20
		goto	SetBrightness
		
SetBlue:
		SET_RGB	h'00',h'00',h'ff',.20
		goto	SetBrightness
		
SetIndigo:
		SET_RGB	h'4b',h'00',h'82',.20
		goto	SetBrightness
		
SetViolet:
		SET_RGB	h'ee',h'82',h'ee',.20
		goto	SetBrightness

SetFuchsia:
		SET_RGB h'ca',h'2c',h'92',.20
		goto	SetBrightness
		
SetTurquoise:
		SET_RGB h'40',h'e0',h'd0',.20
		goto	SetBrightness
		
SetCyan:
		SET_RGB h'00',h'ff',h'ff',.20
		goto	SetBrightness
				
; If the display is dimmed then reduce RGB colour values by a fixed factor
		
SetBrightness:
		movf	HR,W
		xorlw	h'23'
		btfsc	STATUS,Z
		bra	Dim
		xorlw	h'00' ^ h'23'
		btfsc	STATUS,Z
		bra	Dim
		xorlw	h'01' ^ h'00'
		btfsc	STATUS,Z
		bra	Dim
		xorlw	h'02' ^ h'01'
		btfsc	STATUS,Z
		bra	Dim
		xorlw	h'03' ^ h'02'
		btfsc	STATUS,Z
		bra	Dim
		xorlw	h'04' ^ h'03'
		btfsc	STATUS,Z
		bra	Dim
		xorlw	h'05' ^ h'04'
		btfsc	STATUS,Z
		bra	Dim
		xorlw	h'06' ^ h'05'
		btfsc	STATUS,Z
		bra	Dim
		return
		
Dim:
		lsrf	RED,F
		lsrf	RED,F
		lsrf	GREEN,F
		lsrf	GREEN,F
		lsrf	BLUE,F
		lsrf	BLUE,F
		return
		
; Save the current RGB colour values.
		
PushColour:
		movf	RED,W
		movwf	SAVED_RED
		movf	GREEN,W
		movwf	SAVED_GREEN
		movf	BLUE,W
		movwf	SAVED_BLUE
		return

; Restore the saved RGB colour values.

PullColour:
		movf	SAVED_RED,W
		movwf	RED
		movf	SAVED_GREEN,W
		movwf	GREEN
		movf	SAVED_BLUE,W
		movwf	BLUE
		return
		
;-------------------------------------------------------------------------------

; Copies the current RED, GREEN and BLUE values to the segment array at FSR0
; then moves to the next segment.
		
SetSegment:
		movf	RED,W
		movwi	LED_R[FSR0]
		movf	GREEN,W
		movwi	LED_G[FSR0]
		movf	BLUE,W
		movwi	LED_B[FSR0]
		addfsr	FSR0,.3
		return
		
;===============================================================================
; DS1307 RTC
;-------------------------------------------------------------------------------
		
; Initialise the current time from the RTC chip. If the time does not look
; right then reset it to 00:00 and start the clock. Ensure that a 1Hz SQW
; signal is being generated.
		
RtcInit:
		call	I2CStop		; Ensure the bus is free
		call	I2CStop
		call	RtcRead		; Read the current time
		
		btfsc	SC,.7		; Is timer running?
		bra	InvalidTime	; No.
		btfss	HR,.6		; 24 Hour clock?
		bra	ValidTime	; Yes

InvalidTime:
		clrf	HR		; Reset the time
		clrf	MN
		clrf	SC
		call	RtcWrite	; And write back
	
ValidTime:
		call	I2CStart	; Configure SQW for 1Hz output
		movlw	DS1307|I2C_WR
		call	I2CSend
		movlw	h'07'
		call	I2CSend
		movlw	h'10'
		call	I2CSend
		goto	I2CStop	

; Read the current time from the RTC and store in memory.
		
RtcRead:
		call	I2CStart
		movlw	DS1307|I2C_WR
		call	I2CSend
		movlw	h'00'
		call	I2CSend
		call	I2CStop
	
		call	I2CStart
		movlw	DS1307|I2C_RD
		call	I2CSend
		call	I2CRecv
		movwf	SC
		call	I2CAck
		call	I2CRecv
		movwf	MN
		call	I2CAck
		call	I2CRecv
		movwf	HR
		call	I2CNak
		goto	I2CStop

; Write the time from memory back to the RTC chip

RtcWrite:
		call	I2CStart
		movlw	DS1307|I2C_WR
		call	I2CSend
		movlw	h'00'
		call	I2CSend
		
		movf	SC,W
		andlw	h'7f'
		call	I2CSend
		movf	MN,W
		andlw	h'7f'
		call	I2CSend
		movf	HR,W
		andlw	h'3f'
		call	I2CSend		
		goto	I2CStop
		
;===============================================================================
; I2C
;-------------------------------------------------------------------------------

; Signal an I2C Start condition by changing SDA rom HI to LO while SCL is HI.
		
I2CStart:
		call	SetSclLo
		call	SetSdaHi
		call	SetSclHi
		call	SetSdaLo
		goto	SetSclLo
	
; Signal an I2C Stop condition by changing SDA rom LO to HI while SCL is HI.

I2CStop:
		call	SetSclLo
		call	SetSdaLo
		call	SetSclHi
		goto	SetSdaHi

; Send an I2C ACK pulse to the slave,

I2CAck:
		call	SetSdaLo
		call	SetSclHi
		call	SetSclLo
		goto	SetSdaHi
		
I2CNak:
		call	SetSdaHi
		call	SetSclHi
		goto	SetSclLo
			
; Send 	
I2CSend:
		movwf	SCRATCH		; Save the byte to be sent
		call	I2CTxBit	; Send MSB ..
		call	I2CTxBit
		call	I2CTxBit
		call	I2CTxBit
		call	I2CTxBit
		call	I2CTxBit
		call	I2CTxBit
		call	I2CTxBit	; .. to LSB
		bra	I2CNak		; Ignore the slaves ACK/NAK
		
I2CTxBit:
		rlf	SCRATCH,F
		btfsc	STATUS,C
		bra	I2CTxHi
		call	SetSdaLo
		bra	I2CTxClk
I2CTxHi:	call	SetSdaHi
I2CTxClk:	call	SetSclHi
		goto	SetSclLo
		
I2CRecv:
		call	I2CRxBit
		call	I2CRxBit
		call	I2CRxBit
		call	I2CRxBit
		call	I2CRxBit
		call	I2CRxBit
		call	I2CRxBit
		call	I2CRxBit
		movf	SCRATCH,W
		return
		
I2CRxBit:
		call	SetSclHi
		banksel	SDA_PORT
		lslf	SCRATCH,F	
		btfsc	SDA_PORT,SDA_PIN
		incf	SCRATCH,F
		goto	SetSclLo

; Return after delaying for around 50uS
		
I2CDelay:
		call	I2CPause
		call	I2CPause
		call	I2CPause
		call	I2CPause

; Return after delaying for around 10uS
		
I2CPause:
		clrwdt
		nop
		nop
		nop
		nop
		nop
		nop
		return

; Set the SCL line high by making it an input and let the external resistor
; pull the signal hi.
		
SetSclHi:
		banksel	SCL_TRIS
		bsf	SCL_TRIS,SCL_PIN
		goto	I2CDelay
	
; Set the SCL line low by making it an output with a zero bit in the latch.
		
SetSclLo:
		banksel	SCL_LAT
		bcf	SCL_LAT,SCL_PIN
		banksel	SCL_TRIS
		bcf	SCL_TRIS,SCL_PIN
		goto	I2CDelay
		
; Set the SDA line high by making it an input and let the external resistor
; pull the signal hi.
		
SetSdaHi:
		banksel	SDA_TRIS
		bsf	SDA_TRIS,SDA_PIN
		goto	I2CDelay
		
; Set the SCL line low by making it an output with a zero bit in the latch.
		
SetSdaLo:
		banksel	SDA_LAT
		bcf	SDA_LAT,SDA_PIN
		banksel	SDA_TRIS
		bcf	SDA_TRIS,SDA_PIN
		goto	I2CDelay
		
;===============================================================================
; NeoPixels
;-------------------------------------------------------------------------------

; Sends state of all the segments to the display modules. Interrupts must be
; disabled during the transfer as the pulse timings are critical.
                
UpdateLeds:
                bcf     INTCON,GIE      ; Disable interrupts
                movlw   low S1          ; Update low seconds
                movwf   FSR0L
                movlw   high S1
                movwf   FSR0H
                call    NormalLed
                movlw   low S2          ; Then high seconds
                movwf   FSR0L
                movlw   high S2
                movwf   FSR0H
                call    NormalLed
		movlw   low S3          ; Then low minutes
                movwf   FSR0L
                movlw   high S3
                movwf   FSR0H
                call    RotateLed       ; Then high minutes
                movlw   low S4
                movwf   FSR0L
                movlw   high S4
                movwf   FSR0H
                call    NormalLed
                bsf     INTCON,GIE      ; Re-enable interrupts
                return                  ; Done.

; Send all the RGB values for a normally oriented display to the LED module.
                
NormalLed:
                moviw   SEG_A+LED_G[FSR0]
                call    SendByte
                moviw   SEG_A+LED_R[FSR0]
                call    SendByte
                moviw   SEG_A+LED_B[FSR0]
                call    SendByte
                moviw   SEG_B+LED_G[FSR0]
                call    SendByte
                moviw   SEG_B+LED_R[FSR0]
                call    SendByte
                moviw   SEG_B+LED_B[FSR0]
                call    SendByte
                moviw   SEG_C+LED_G[FSR0]
                call    SendByte
                moviw   SEG_C+LED_R[FSR0]
                call    SendByte
                moviw   SEG_C+LED_B[FSR0]
                call    SendByte
                moviw   SEG_D+LED_G[FSR0]
                call    SendByte
                moviw   SEG_D+LED_R[FSR0]
                call    SendByte
                moviw   SEG_D+LED_B[FSR0]
                call    SendByte
                moviw   SEG_E+LED_G[FSR0]
                call    SendByte
                moviw   SEG_E+LED_R[FSR0]
                call    SendByte
                moviw   SEG_E+LED_B[FSR0]
                call    SendByte
                moviw   SEG_F+LED_G[FSR0]
                call    SendByte
                moviw   SEG_F+LED_R[FSR0]
                call    SendByte
                moviw   SEG_F+LED_B[FSR0]
                call    SendByte
                moviw   SEG_G+LED_G[FSR0]
                call    SendByte
                moviw   SEG_G+LED_R[FSR0]
                call    SendByte
                moviw   SEG_G+LED_B[FSR0]
                call    SendByte
                moviw   SEG_P+LED_G[FSR0]
                call    SendByte
                moviw   SEG_P+LED_R[FSR0]
                call    SendByte
                moviw   SEG_P+LED_B[FSR0]
                goto    SendByte
                
; Send all the RGB values for a rotated oriented display to the LED module.
        
RotateLed:
                moviw   SEG_D+LED_G[FSR0]
                call    SendByte
                moviw   SEG_D+LED_R[FSR0]
                call    SendByte
                moviw   SEG_D+LED_B[FSR0]
                call    SendByte
                moviw   SEG_E+LED_G[FSR0]
                call    SendByte
                moviw   SEG_E+LED_R[FSR0]
                call    SendByte
                moviw   SEG_E+LED_B[FSR0]
                call    SendByte
                moviw   SEG_F+LED_G[FSR0]
                call    SendByte
                moviw   SEG_F+LED_R[FSR0]
                call    SendByte
                moviw   SEG_F+LED_B[FSR0]
                call    SendByte
                moviw   SEG_A+LED_G[FSR0]
                call    SendByte
                moviw   SEG_A+LED_R[FSR0]
                call    SendByte
                moviw   SEG_A+LED_B[FSR0]
                call    SendByte
                moviw   SEG_B+LED_G[FSR0]
                call    SendByte
                moviw   SEG_B+LED_R[FSR0]
                call    SendByte
                moviw   SEG_B+LED_B[FSR0]
                call    SendByte
                moviw   SEG_C+LED_G[FSR0]
                call    SendByte
                moviw   SEG_C+LED_R[FSR0]
                call    SendByte
                moviw   SEG_C+LED_B[FSR0]
                call    SendByte
                moviw   SEG_G+LED_G[FSR0]
                call    SendByte
                moviw   SEG_G+LED_R[FSR0]
                call    SendByte
                moviw   SEG_G+LED_B[FSR0]
                call    SendByte
                moviw   SEG_P+LED_G[FSR0]
                call    SendByte
                moviw   SEG_P+LED_R[FSR0]
                call    SendByte
                moviw   SEG_P+LED_B[FSR0]
                goto    SendByte
        
SendByte:
                banksel LED_LAT         ; Select correct SFR bank

                SEND_BIT .7
                SEND_GAP
                SEND_BIT .6
                SEND_GAP
                SEND_BIT .5
                SEND_GAP
                SEND_BIT .4
                SEND_GAP
                SEND_BIT .3
                SEND_GAP
                SEND_BIT .2
                SEND_GAP
                SEND_BIT .1
                SEND_GAP
                SEND_BIT .0

                return
                             
                end