
        
        
        
                include "p16f1454.inc"
                
                errorlevel -302
                
;===============================================================================
;-------------------------------------------------------------------------------
                
 __CONFIG _CONFIG1, _FOSC_INTOSC & _WDTE_OFF & _PWRTE_OFF & _MCLRE_ON & _CP_OFF & _BOREN_OFF & _CLKOUTEN_OFF & _IESO_OFF & _FCMEN_OFF

 __CONFIG _CONFIG2, _WRT_OFF & _CPUDIV_CLKDIV6 & _USBLSCLK_48MHz & _PLLMULT_3x & _PLLEN_ENABLED & _STVREN_ON & _BORV_LO & _LPBOR_OFF & _LVP_OFF

;===============================================================================
; Hardware Configuration
;-------------------------------------------------------------------------------

OSC             equ     .16000000
PLL             equ     .3
             
FOSC            equ     OSC * PLL
            
;-------------------------------------------------------------------------------

; Inputs
            
SQW_TRIS        equ     TRISA
SQW_PORT        equ     PORTA
SQW_PIN         equ     .5

SWA_TRIS        equ     TRISC
SWA_PORT        equ     PORTC
SWA_PIN         equ     .5
            
SWB_TRIS        equ     TRISC
SWB_PORT        equ     PORTC
SWB_PIN         equ     .4

; Outputs
         
SCL_TRIS        equ     TRISC
SCL_PIN         equ     .0

SDA_TRIS        equ     TRISC
SDA_PIN         equ     .0

LED_TRIS        equ     TRISC
LED_LAT         equ     LATC
LED_BIT         equ     .3

;===============================================================================
; Data Areas
;-------------------------------------------------------------------------------

                udata_shr
         
           
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
                
S1              res     .8 * .3
S2              res     .8 * .3
              
.segments       udata
        
S3              res     .8 * .3            
S4              res     .8 * .3

;===============================================================================
;-------------------------------------------------------------------------------
        
.Interrupt      code    h'0004'
      
                retfie
                
;===============================================================================
;-------------------------------------------------------------------------------

.Reset          code    h'0000'
          
                goto    PowerOnReset
                
;-------------------------------------------------------------------------------
                
                code
              
PowerOnReset:
        
                movlw   b'11111110'     ; Switch tp 48Mhz
                banksel OSCCON
                movwf   OSCCON
                
                clrwdt
                ifndef  __MPLAB_DEBUGGER_SIMULATOR
WaitTillStable:
                btfss   OSCSTAT,HFIOFS  ; Stabalised yet>
                bra     WaitTillStable
                endif
        
                banksel ANSELA          ; Make all pins digital
                clrf    ANSELA
                banksel LATA
                clrf    LATA
                clrf    LATC
                banksel TRISA           ; Set the I/O directions
                movlw   .0
                movwf   TRISA
                movlw   .0
                movwf   TRISC
                
                
                movlw   low S4
                movwf   FSR0L
                movlw   high S4
                movwf   FSR0H
                
                movlw   .0
                movwi   SEG_A+LED_R[FSR0]
                movlw   .240
                movwi   SEG_A+LED_G[FSR0]
                movlw   .255
                movwi   SEG_A+LED_B[FSR0]
                
Loop:
                call    UpdateLeds
                bra     Loop
                
;===============================================================================
; I2C
;-------------------------------------------------------------------------------

        
;===============================================================================
; NeoPixels
;-------------------------------------------------------------------------------

; Sends state of all the segments to the display modules. Interrupts must be
; disable during the transfer as the pulse timings are critical.
                
UpdateLeds:
                bcf     INTCON,GIE      ; Disable interrupts
                movlw   low S4          ; Update low seconds
                movwf   FSR0L
                movlw   high S4
                movwf   FSR0H
                call    NormalLed
                movlw   low S3          ; Then high seconds
                movwf   FSR0L
                movlw   high S3
                movwf   FSR0H
                call    RotateLed
                movlw   low S2          ; Then low minutes
                movwf   FSR0L
                movlw   high S2
                movwf   FSR0H
                call    NormalLed       ; Then high minutes
                movlw   low S1
                movwf   FSR0L
                movlw   high S1
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