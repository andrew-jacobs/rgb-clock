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
                
 __CONFIG _CONFIG1, _FOSC_INTOSC & _WDTE_OFF & _PWRTE_OFF & _MCLRE_ON & _CP_OFF & _BOREN_OFF & _CLKOUTEN_ON & _IESO_OFF & _FCMEN_OFF

 __CONFIG _CONFIG2, _WRT_OFF & _CPUDIV_NOCLKDIV & _USBLSCLK_48MHz & _PLLMULT_3x & _PLLEN_ENABLED & _STVREN_ON & _BORV_LO & _LPBOR_OFF & _LVP_OFF

;===============================================================================
; Hardware Configuration
;-------------------------------------------------------------------------------

OSC             equ     .16000000
PLL             equ     .3
             
FOSC            equ     OSC * PLL
            
;-------------------------------------------------------------------------------

; Inputs
            
SQW_TRIS        equ     TRISA		; SQW output from DS1307
SQW_PORT        equ     PORTA
SQW_PIN         equ     .5

SWA_TRIS        equ     TRISC		; Switch A (SELECT)
SWA_PORT        equ     PORTC
SWA_PIN         equ     .5
            
SWB_TRIS        equ     TRISC		; Switch B (CHANGE)
SWB_PORT        equ     PORTC
SWB_PIN         equ     .4

; Outputs

SCL_TRIS        equ     TRISA		; Software generated I2C SCL
SCL_LAT		equ	LATA
SCL_PIN         equ     .0

SDA_TRIS        equ     TRISA		; Software generated I2C SDA
SDA_PORT        equ     PORTA
SDA_LAT		equ	LATA
SDA_PIN         equ     .1

LED_TRIS        equ     TRISC		; Neo pixel data out
LED_LAT         equ     LATC
LED_BIT         equ     .3
         
;-------------------------------------------------------------------------------
         
TMR2_HZ         equ     .64		; Target frequency
TMR2_PRE        equ     .64             ; Prescaler 1, 4, 16 or 64
TMR2_POST       equ     .16             ; Postscaler 1 to 16
       
TMR2_PR         equ     FOSC / (.4 * TMR2_HZ * TMR2_PRE * TMR2_POST ) - .1
         
                if      TMR2_PR & h'ffffff00'
                error   "Timer2 PR does not fit in 8-bits
                endif

;===============================================================================
; Data Areas
;-------------------------------------------------------------------------------

                udata_shr       h'070'
		
HR		res	.1		; Hour
MN		res	.1		; Minute
SC		res	.1		; Second
SS		res	.1		; Sub seconds
		
RED		res	.1
GREEN		res	.1
BLUE		res	.1
         
TICKS           res     .1
	  
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
		
	    movlw	M(.2)
	    banksel	LATC
	    xorwf	LATC,F
                
                movf    TICKS,F         ; Any ticks left?
                btfss   STATUS,Z
                decf    TICKS,F         ; Yes, reduce the count
		
		incf	SS,W		; Bump sub-seconds
		movwf	SS
		xorlw	.64
		btfss	STATUS,Z
		bra	Timer2Handled
		clrf	SS
		
		movf	SC,W		; Bump seconds
		addlw	.7
		btfss	STATUS,DC
		addlw	-.6
		movwf	SC
		xorlw	h'60'
		btfss	STATUS,Z
		bra	Timer2Handled
		clrf	SC
		
		movf	MN,W		; Bump minutes
		addlw	.7
		btfss	STATUS,DC
		addlw	-.6
		movwf	MN
		xorlw	h'60'
		btfss	STATUS,Z
		bra	Timer2Handled
		clrf	MN
		
		movf	HR,W		; Bump hours
		addlw	.7
		btfss	STATUS,DC
		addlw	-.6
		movwf	HR
		xorlw	h'24'
		btfss	STATUS,Z
		bra	Timer2Handled
		clrf	HR	
Timer2Handled:
        
                retfie
                
;===============================================================================
; Power On Reset
;-------------------------------------------------------------------------------

.Reset          code    h'0000'
          
                goto    PowerOnReset
                
;-------------------------------------------------------------------------------
                
                code
              
PowerOnReset:
        
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
                banksel LATA
                clrf    LATA
                clrf    LATC
                banksel TRISA           ; Set the I/O directions
                movlw   .0
                movwf   TRISA
                movlw	M(SWA_PIN)|M(SWB_PIN)  
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
		
		clrf	HR		; Reset the time
		clrf	MN
		clrf	SC
                clrf	SS
		
		call	I2CStop
		call	I2CStop
		
                bsf     INTCON,PEIE	; Start interrupt handling
                bsf     INTCON,GIE
      
;===============================================================================
; Time Display
;-------------------------------------------------------------------------------
		
                call	SelectHrHi	; Clear segments
		call	SetBlank
		call	SelectHrLo
		call	SetBlank
		call	SelectMnHi
		call	SetBlank
		call	SelectMnLo
		call	SetBlank
		   
Loop:
                movlw   .8		; 
                movwf   TICKS
                call    UpdateLeds
		
		call	SelectHrHi
		swapf	HR,W
		call	ShowDigit
		call	SetBlack
		call	SetSegment
		
		call	SelectHrLo
		movf	HR,W
		call	ShowDigit
		call	SetBlack
		btfss	SS,.5
		call	SetWhite
		call	SetSegment

		call	SelectMnHi
		swapf	MN,W
		call	ShowDigit
		call	SetBlack
		btfss	SS,.5
		call	SetWhite
		call	SetSegment

		call	SelectMnLo
		movf	MN,W
		call	ShowDigit
		call	SetBlack
		call	SetSegment

Wait:
                movf    TICKS,F
                btfss   STATUS,Z
                bra     Wait
                
                bra     Loop
		
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
		andlw	h'0f'
		brw
		
		bra	Show0
		bra	Show1
		bra	Show2
		bra	Show3
		bra	Show4
		bra	Show5
		bra	Show6
		bra	Show7
		bra	Show8
		bra	Show9
		return
		return
		return
		return
		return
		
Show0:
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

Show1:
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

Show2:
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

Show3:
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

Show4:
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
		
Show5:
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
		
Show6:
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
		
Show7:
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
		
Show8:
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
		
Show9:
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
; Time Display
;-------------------------------------------------------------------------------
		

		

;===============================================================================
; RGB Color Selection
;-------------------------------------------------------------------------------

SET_RGB		macro	XR,XG,XB,XP
		movlw	((XR * XP) / .100)
		movwf	RED
		movlw	((XG * XP) / .100)
		movwf	GREEN
		movlw	((XB * XP) / .100)
		movwf	BLUE
		endm
		
SetBlack:
		SET_RGB	h'00',h'00',h'00',.20
		bra	SetBrightness
		
SetWhite:
		SET_RGB	h'ff',h'ff',h'ff',.20
		bra	SetBrightness
		
SetRed:
		SET_RGB	h'ff',h'00',h'00',.20
		bra	SetBrightness
		
SetOrange:
		SET_RGB	h'ff',h'8c',h'00',.20
		bra	SetBrightness
    
SetYellow:
		SET_RGB	h'ff',h'ff',h'00',.20
		bra	SetBrightness
		
SetGreen:
		SET_RGB	h'00',h'ff',h'00',.20
		bra	SetBrightness
		
SetBlue:
		SET_RGB	h'00',h'00',h'ff',.20
		bra	SetBrightness
		
SetIndigo:
		SET_RGB	h'4b',h'00',h'82',.20
		bra	SetBrightness
		
SetViolet:
		SET_RGB	h'ee',h'82',h'ee',.20
		bra	SetBrightness
		
; If the display is dimmed then reduce RGB colour values by a fixed.
		
SetBrightness:
		return

;-------------------------------------------------------------------------------
			
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
; I2C
;-------------------------------------------------------------------------------
	

		
I2CStart:
		call	SetSclLo
		call	SetSdaHi
		call	SetSclHi
		call	SetSdaLo
		goto	SetSclLo
		
I2CStop:
		call	SetSclLo
		call	SetSdaLo
		call	SetSclHi
		goto	SetSdaHi

I2CAck:
		call	SetSdaLo
		call	SetSclHi
		call	SetSclLo
		goto	SetSdaHi
		
I2CNak:
		call	SetSdaHi
		call	SetSclHi
		goto	SetSclLo
		
		
I2CSend:
		movwf	SCRATCH
		call	I2CTxBit
		call	I2CTxBit
		call	I2CTxBit
		call	I2CTxBit
		call	I2CTxBit
		call	I2CTxBit
		call	I2CTxBit
		call	I2CTxBit
		goto	SetSdaHi
		
I2CTxBit:
		rlf	SCRATCH,F
		btfsc	STATUS,C
		bra	I2CTxHi
		call	SetSdaLo
		bra	I2CTxClk
I2CTxHi:	call	SetSclHi
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
                endm
        
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