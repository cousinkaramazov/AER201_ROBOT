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
; ============================================================================
; ----------------------------------------------------------------------------
; LCD related definitions
; ----------------------------------------------------------------------------
#define     first_line  B'10000000'
#define     second_line B'11000000'
#define     LCD_RS      PORTD, 2
#define     LCD_E       PORTD, 3
; ----------------------------------------------------------------------------
; keypad inputs and corresponding decimal values
; ----------------------------------------------------------------------------
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
temp_var1       EQU     0x20        ; general variable to be used temporarily
delay1          EQU     0x21        ; variable used in delay counter
delay2          EQU     0x22        ; variable used in delay counter


keypad_data     EQU     0x23        ; holds input from keypad (PORTB)
keypad_result   EQU     0x24        ; is entered value is equal to keypad_test?
keypad_test     EQU     0x25        ; holds key value that is to be tested

delay3          EQU     0x26        ; variable used in delay counter
table_length    EQU     0x27        ; length of table currently displayed

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
            beq     d'1', keypad_result, label
            endm

; ----------------------------------------------------------------------------



; ----------------------------------------------------------------------------
; LCD macros
; ----------------------------------------------------------------------------
; lcddisplay:   Displays the inputted table on the LCD display on given line
lcddisplay  macro   Table, Line
            ; If Line = 10000000, use Line 1; if Line = 11000000, use Line 2
            movlw   Line
            writelcdinst
            getlen  Table
            ; move full address of table into Table Pointer
            movlw   upper Table
            movwf   TBLPTRU
            movlw   high Table
            movwf   TBLPTRH
            movlw   low Table
            movwf   TBLPTRL
            ; write character data to LCD
            call    WriteLCDChar
            ; if length is > 16, shift to left length - 16 times
            ; pause between shifts
            ; once its reached the end, send it back to the beginning
            ;pause
            ; begin scrolling again
            endm
; ----------------------------------------------------------------------------
; writelcdinst: Writes an instruction in W to the LCD display
writelcdinst    macro
            bcf     LCD_RS
            call    WriteLCD
            endm
; ----------------------------------------------------------------------------
; writelcddata: Writes data in W to the LCD display
writelcddata    macro
            bsf     LCD_RS
            call    WriteLCD
            endm
; ----------------------------------------------------------------------------
; getlen: Stores length of given table in table_length variable
getlen          macro   Table
            ; move full address of table into Table Pointer
            movlw   upper Table
            movwf   TBLPTRU
            movlw   high Table
            movwf   TBLPTRH
            movlw   low Table
            movwf   TBLPTRL
            tblrd*                      ; copy byte pointed to by TBLPTR into TABLAT
            movf    TABLAT, W           ; move contents of TABLAT into W
            movlf   d'0', table_length  ; initialize table_length to zero
getlengthloop
            incf    table_length        ; increment table length by one
            tblrd+*                     ; read next byte into TABLAT
            movf    TABLAT, W           ; move contents of TABLAT into W
            bnz     getlengthloop       ; all bytes have been read once 0 is reached
            endm
; ----------------------------------------------------------------------------
lcdshift        macro   Line
            movlw   Line
            writelcdinst
            movlw   b'00011000'
            writelcdinst
            endm


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
LogMsg                  db      "Logs here until here therefore unsi"


; ============================================================================
; Main program
; ============================================================================

Main
; ----------------------------------------------------------------------------
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


        call        ConfigureLCD                ; configure LCD for use
; ----------------------------------------------------------------------------

WelcomeScreen
        call        ClearLCD                    ; clear LCD screen

        ;display welcome message
        lcddisplay  WelcomeMsg, first_line
        lcddisplay  WelcomeMsg2, second_line

WelcomeLoop
        call        CheckAnyButton              ; check if any button is pressed
        beq         d'1', keypad_result, Menu   ; if key has not been pressed
        bra         WelcomeLoop                 ; continue looping
; ----------------------------------------------------------------------------
Menu
        call        ClearLCD                    ; clear LCD of previous message

        ;display menu message- options are operation or logs
        lcddisplay  MenuMsg1, first_line
        lcddisplay  MenuMsg2, second_line

MenuLoop                                        ; loop until 1 or 2 is pressed
        testkey     key_1, BeginOperation       ; if 1 is pressed, begin operating
        testkey     key_2, Logs                 ; if 2 is pressed, access logs
        bra         MenuLoop
; ----------------------------------------------------------------------------
BeginOperation
        call        ClearLCD                    ; clear LCD of previous message
        lcddisplay  OpMsg, first_line
        goto        Stop
; ----------------------------------------------------------------------------
Logs
        call        ClearLCD
        lcddisplay  LogMsg, first_line
        call        Delay1s
        lcdshift    first_line
        call        Delay1s
        lcdshift    first_line
        goto        Stop
; ----------------------------------------------------------------------------
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
        writelcdinst
        ; set for 8 bit again then 4 bit
        movlw       B'00110010'
        writelcdinst
        ; 4 bits, 2 lines, 5x7 dot
        movlw       B'00101000'
        writelcdinst
        ; display on/off
        movlw       B'00001100'
        writelcdinst
        ; Entry mode
        movlw       B'00000110'
        writelcdinst
        ; clear ram
        call        ClearLCD
        return
; ----------------------------------------------------------------------------
; WriteLCD: Writes data/instructions to the LCD
; INPUT: W
; OUTPUT: None
; ----------------------------------------------------------------------------
WriteLCD
        movwf       temp_var1       ; store W into a temporary register
        call        MovMSB          ; moves 4 MSBs of W to PORTD
        call        ClockLCD        ; sends PORTD to LCD
        swapf       temp_var1, w    ; swap nibbles
        call        MovMSB          ; moves 4 LSBs of W to PORTD
        call        ClockLCD        ; sends pORTD to LCD
        call        Delay5ms        ; 5 ms delay
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
        writelcddata                ; write the contents of W into the LCD
        tblrd+*                     ; read next byte into TABLAT
        movf        TABLAT, W       ; move contents of TABLAT into W
        bnz         CharReadLoop    ; all bytes have been read once 0 is reached
        return
; ----------------------------------------------------------------------------
; ClockLCD: Pulses enable bit to transmit information to LCD
; INPUT: None
; OUTPUT: None
; ----------------------------------------------------------------------------
ClockLCD
        bsf         LCD_E           ; set enable bit to transmit information
        call        Delay5ms        ; wait until information has been read
        call        Delay5ms
        bcf         LCD_E           ; clear enable bit - transfer is over
        call        Delay44us
        return
; ----------------------------------------------------------------------------
; MovMSB: Move the MSBs of W to PORTD without disturbing LSBs
; INPUT: W
; OUTPUT: None
; ----------------------------------------------------------------------------
MovMSB
        andlw       0xF0            ; masks all but 4 MSBs
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
        movlw       B'10000000'     ; set for line 1
        writelcdinst
        movlw       B'00000001'     ; clear line 1
        writelcdinst
        return
        movlw       B'11000000'     ; set for line 2
        writelcdinst
        movlw       B'00000001'     ; clear line 2
        writelcdinst

; ----------------------------------------------------------------------------
; Keypad Subroutines
; ----------------------------------------------------------------------------
; CheckAnyButton: Checks if any keypad button has been pressed
; INPUT: None
; OUTPUT: keypad_result (1 if button has been pressed, 0 otherwise)
; ----------------------------------------------------------------------------
CheckAnyButton
        movff       PORTB, keypad_data  ; put keypad output into keypad_data
        btfsc       keypad_data, 1      ; if a key has been pressed...
        goto        AnyPressed          ; ...go to AnyPressed

        movlf       B'0', keypad_result ; if not, set keypad_result to 0
        goto        EndCheckAnyButton

AnyPressed
        movlf       B'1', keypad_result ; key has been pressed, keypad_result is 1

EndCheckAnyButton
        return

; ----------------------------------------------------------------------------
; CheckButton: Checks for keypad button, returns button info
; INPUT: None
; OUTPUT: keypad_result (sets bit 7 if no press)
; ----------------------------------------------------------------------------
CheckButton
        movff       PORTB, keypad_data      ; move keypad output to keypad_data
        btfss       keypad_data, 1          ; test if any data is input...
        goto        NoButtonPressed         ; ...if not, no button has been pressed

        swapf       keypad_data, W          ; swap bits <7:4> of keypad with <3:1>
        andlw       B'00001111'             ; mask all other nonrelevant bits
        subwf       keypad_test, w          ; subtract tested value from actual
        bnz         NoButtonPressed         ; if not zero, our target button has
                                            ; not been pressed-same thing as no button pressed

        movlf        d'1', keypad_result    ; if zero, target button has been pressed
        bra          EndCheckButton
NoButtonPressed
        movlf       d'0', keypad_result     ; result is 0, target not pressed
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
; ----------------------------------------------------------------------------
; Delay1s: Delays program for 1s
; ----------------------------------------------------------------------------
Delay1s
        movlf       d'100', delay3
Delay1sLoop
        dcfsnz      delay3, f
        goto        EndDelay1s
        call        Delay5ms
        bra         Delay1sLoop
EndDelay1s
        return


    end







