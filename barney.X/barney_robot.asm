; ============================================================================
; AER201 LED Testing Machine
; Programmer: Matthew MacKay
; ============================================================================

#include <p18f4620.inc>
		list P=18F4620, F=INHX32, C=160, N=80, ST=OFF, MM=OFF, R=DEC

; ============================================================================
;Configuration Bits
; ============================================================================
		CONFIG OSC=HS, FCMEN=OFF, IESO=OFF
		CONFIG PWRT = OFF, BOREN = SBORDIS, BORV = 3
		CONFIG WDT = OFF, WDTPS = 32768
		CONFIG MCLRE = ON, LPT1OSC = OFF, PBADEN = OFF, CCP2MX = PORTC
		CONFIG STVREN = ON, LVP = OFF, XINST = OFF
		CONFIG DEBUG = OFF
		CONFIG CP0 = OFF, CP1 = OFF, CP2 = OFF, CP3 = OFF
		CONFIG CPB = OFF, CPD = OFF
		CONFIG WRT0 = OFF, WRT1 = OFF, WRT2 = OFF, WRT3 = OFF
		CONFIG WRTB = OFF, WRTC = OFF, WRTD = OFF
		CONFIG EBTR0 = OFF, EBTR1 = OFF, EBTR2 = OFF, EBTR3 = OFF
		CONFIG EBTRB = OFF

; ============================================================================
; Constant Definitions
; ===========================================================================
#define     first_line  B'10000000'
#define     second_line B'11000000'
#define     LCD_RS      PORTD, 2
#define     LCD_E       PORTD, 3

#define     key_1       d'0'
#define     key_2       d'1'
#define     key_3       d'2'
#define     key_A       d'3'
#define     key_4       d'4'
#define     key_5       d'5'
#define     key_6       d'6'
#define     key_B       d'7'
#define     key_7       d'8'
#define     key_8       d'9'
#define     key_9       d'10'
#define     key_C       d'11'
#define     key_star    d'12'
#define     key_0       d'13'
#define     key_#       d'14'
#define     key_D       d'15'
; ============================================================================
; General Purpose Registers (using Access Bank)
; ============================================================================
temp_var1       EQU     0x20
delay1          EQU     0x21
delay2          EQU     0x22

keypad_data     EQU     0x23
keypad_result   EQU     0x24
keypad_test     EQU     0x25



; ============================================================================
; Macros
; ============================================================================
; ----------------------------------------------------------------------------
; General macros
; ----------------------------------------------------------------------------
; movlf:    Move a literal value to the file register specified
movlf       macro   literal, register
            movlw   literal
            movwf   register
            endm

; beq:      branches to label if register value == literal
beq         macro   literal, register, label
;            movf    register, W
;            iorlw   literal
;            bz      label
;            endm
            movlw   literal
            subwf   register
            bz     label
            endm
; ----------------------------------------------------------------------------
; Keypad macros
; ----------------------------------------------------------------------------
; testkey:  Checks if key has been pressed, branches to label if so
testkey     macro   literal, label
            movlf   literal, keypad_test
            call    CheckButton
            beq     d'1', keypad_test, label
            endm

; ----------------------------------------------------------------------------



; ----------------------------------------------------------------------------
; LCD macros
; ----------------------------------------------------------------------------
; lcddisplay:   Displays the inputted table on the LCD display on given line
lcddisplay  macro   Table, Line
            ; If Line = 10000000, use Line 1; if Line = 11000000, use Line 2
            movlw   Line
            call    WriteLCDInst
            ; move full address of table into Table Pointer
            movlw   upper Table
            movwf   TBLPTRU
            movlw   high Table
            movwf   TBLPTRH
            movlw   low Table
            movwf   TBLPTRL
            ; write character data to LCD
            call    WriteLCDChar
            endm
; ----------------------------------------------------------------------------


; ============================================================================
; Start of code
; ============================================================================
        org         0x00        ; Reset vector
        goto        Main

        org         0x08        ; Low priority interrupt vector
        retfie

        org         0x12        ; High priority interrupt vector
        retfie
; ============================================================================
; Tables
; ============================================================================

WelcomeMsg              db      "Welcome User!", 0
WelcomeMsg2             db      "Press any button to continue.", 0
MenuMsg1                db      "Main Menu"
MenuMsg2                db      "1:Begin, 2:Logs"
OpMsg                   db      "Operation Begins"
LogMsg                  db      "Logs here"


; ============================================================================
; Main program
; ============================================================================

Main
Configure
        ; set all ports to output
        clrf        TRISA
        movlw       b'11110010'
        movwf       TRISB
        clrf        TRISC
        clrf        TRISD
        ; clear all ports
        clrf        PORTA
        clrf        PORTB
        clrf        PORTC
        clrf        PORTD
        clrf        PORTE


        call        ConfigureLCD


WelcomeScreen
        call        ClearLCD
        ;display first and secondlines of welcome message
        lcddisplay  WelcomeMsg, first_line
        lcddisplay  WelcomeMsg2, second_line

WelcomeLoop
        call        CheckAnyButton
        btfss       keypad_result, 0       ; if key has not been pressed
        bra         WelcomeLoop         ; continue looping
        goto        Menu                ; key has been pressed, go to Menu

Menu
        call        ClearLCD
        lcddisplay  MenuMsg1, first_line
        lcddisplay  MenuMsg2, second_line

MenuLoop
        testkey     key_1, BeginOperation
        testkey     key_2, Logs
        bra         MenuLoop

BeginOperation
        call        ClearLCD
        lcddisplay  OpMsg, first_line
        goto        Stop

Logs
        call        ClearLCD
        lcddisplay  LogMsg, first_line
        goto        Stop
Stop
        bra         Stop

; ============================================================================
; Subroutines
; ============================================================================
; ----------------------------------------------------------------------------
; LCD Subroutines
; ----------------------------------------------------------------------------
; ConfigureLCD: Configures the LCD for use
; INPUT: None
; OUTPUT: None
; ----------------------------------------------------------------------------
ConfigureLCD
        ;wait for LCD to warm up
        call        Delay5ms
        call        Delay5ms
        call        Delay5ms
        ; set for 8 bit
        movlw       B'00110011'
        call        WriteLCDInst
        ; set for 8 bit again then 4 bit
        movlw       B'00110010'
        call        WriteLCDInst
        ; 4 bits, 2 lines, 5x7 dot
        movlw       B'00101000'
        call        WriteLCDInst
        ; display on/off
        movlw       B'00001100'
        call        WriteLCDInst
        ; Entry mode
        movlw       B'00000110'
        call        WriteLCDInst
        ; clear ram
        call        ClearLCD
        return
; ----------------------------------------------------------------------------
; WriteLCDInst: Writes an instruction to the LCD to set its configuration
; INPUT: W
; OUTPUT: None
; ----------------------------------------------------------------------------
WriteLCDInst
        bcf         LCD_RS          ; clear Register Status for instruction mode
        movwf       temp_var1       ; store W into a temporary register
        call        MovMSB
        call        ClockLCD
        swapf       temp_var1, w    ; swap nibbles
        call        MovMSB
        call        ClockLCD
        call        Delay5ms
        return
; ----------------------------------------------------------------------------
; WriteLCDChar: Displays the characters in the table pointer on LCD
; INPUT: TBLPTR
; OUTPUT: None
; ----------------------------------------------------------------------------
WriteLCDChar
        tblrd*                      ; copy byte pointed to by TBLPTR into TABLAT
        movf        TABLAT, W       ; move contents of TABLAT into W
CharReadLoop
        call        WriteLCDData    ; write the contents of W into the LCD
        tblrd+*                     ; read next byte into TABLAT
        movf        TABLAT, W       ; move contents of TABLAT into W
        bnz         CharReadLoop    ; all bytes have been read once 0 is reached
        return
; ----------------------------------------------------------------------------
; WriteLCDData: Writes data given in W register to LCD
; INPUT: W
; OUTPUT: None
; ----------------------------------------------------------------------------
WriteLCDData
        bsf         LCD_RS          ; set Register Status bit for data mode
        movwf       temp_var1       ; store character into temorary variable
        call        MovMSB
        call        ClockLCD
        swapf       temp_var1, w    ; swap nibbles
        call        MovMSB
        call        ClockLCD
        call        Delay5ms       ; wait for LCD to process
        return

; ----------------------------------------------------------------------------
; ClockLCD: Pulses enable bit to transmit information to LCD
; INPUT: None
; OUTPUT: None
; ----------------------------------------------------------------------------
ClockLCD
        bsf         LCD_E
        nop
        call        Delay5ms
        call        Delay5ms
        bcf         LCD_E
        call        Delay44us
        return
; ----------------------------------------------------------------------------
; MovMSB: Move the MSB of W to PORTD without disturbing LSB
; INPUT: W
; OUTPUT: None
; ----------------------------------------------------------------------------
MovMSB
        andlw       0xF0
        iorwf       PORTD, f
        iorlw       0x0F
        andwf       PORTD, f
        return
; ----------------------------------------------------------------------------
; ClearLCD: Clear both lines of LCD
; INPUT: None
; OUTPUT: None
; ----------------------------------------------------------------------------
ClearLCD
        movlw       B'11000000'
        call        WriteLCDInst
        movlw       B'00000001'
        call        WriteLCDInst
        movlw       B'10000000'
        call        WriteLCDInst
        movlw       B'00000001'
        call        WriteLCDInst
        return

; ----------------------------------------------------------------------------
; Keypad Subroutines
; ----------------------------------------------------------------------------
; CheckAnyButton: Checks if any keypad button has been pressed
; INPUT: None
; OUTPUT: keypad_result (1 if button has been pressed, 0 otherwise)
; ----------------------------------------------------------------------------
CheckAnyButton
        movff       PORTB, keypad_data
        btfsc       keypad_data, 1
        goto        AnyPressed ; a key has been pressed

        movlf       B'0', keypad_result
        goto        EndCheckAnyButton

AnyPressed
        movlf       B'1', keypad_result

EndCheckAnyButton
        return

; ----------------------------------------------------------------------------
; CheckButton: Checks for keypad button, returns button info
; INPUT: None
; OUTPUT: keypad_result (sets bit 7 if no press)
; ----------------------------------------------------------------------------
CheckButton
        movff       PORTB, keypad_data
        btfss       keypad_data, 1      ;test if any data is input
        goto        NoButtonPressed

        swapf       keypad_data, W
        andlw       B'00001111'
        subwf       keypad_test, w
        bnz         NoButtonPressed

; hold, wait for user to unpress
CheckForKeypress_Loop
        movff       PORTB, keypad_data
        btfsc       keypad_data, 1
        bra         CheckForKeypress_Loop

        movlf        d'1', keypad_result
        bra          EndCheckButton

NoButtonPressed
        movlf       d'0', keypad_result
        movff       keypad_result, PORTC
        goto        EndCheckButton
EndCheckButton
        return


; ----------------------------------------------------------------------------
; Delay Subroutines
; ----------------------------------------------------------------------------
; Delay44us: Delays program for 44us (110 cycles)
; ----------------------------------------------------------------------------
Delay44us
        movlf       0x23, delay1
Delay44usLoop
        decfsz      delay1, f
        bra         Delay44usLoop
        return
; ----------------------------------------------------------------------------
; Delay5ms: Delays program for 5ms
; ----------------------------------------------------------------------------
Delay5ms
        movlf       0xC2, delay1
        movlf       0x0A, delay2
Delay5msLoop
        decfsz      delay1, f
        bra         d2
        decfsz      delay2, f
d2      bra         Delay5msLoop
        return


    end







