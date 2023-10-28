; PIC12F675 assembly code for gpasm
; Functions for setting up and reading ADC pins, setting up PWM pin
; Main program reading first ADC pin, subtracting predefined constant from it, and writing the result to PWM pin

; Define the oscillator frequency
#define _XTAL_FREQ 4000000

; Define the ADC channel numbers
#define AN0 0
#define AN1 1
#define AN2 2
#define AN3 3

; Define the PWM pin number
#define PWM 5

; Define the predefined constant to subtract from ADC value
#define CONST 128

; Include the device header file
#include <p12f675.inc>

; Set the configuration bits
__CONFIG _CP_OFF & _WDT_OFF & _BODEN_OFF & _PWRTE_ON & _INTRC_OSC_NOCLKOUT & _MCLRE_OFF

; Define some registers and variables
CBLOCK 0x20
    ADRESH ; High byte of ADC result
    ADRESL ; Low byte of ADC result
    TEMP   ; Temporary variable
    DUTY   ; Duty cycle for PWM
ENDC

; Initialize the device
ORG 0x00 ; Reset vector
    MOVLW b'01100000' ; Set GP2 as input, GP5 as output, others as analog inputs
    TRIS GPIO
    MOVLW b'00001111' ; Enable all analog inputs, Vref is Vdd
    MOVWF ANSEL
    MOVLW b'10000001' ; Enable ADC, select AN0 channel, Fosc/8 clock
    MOVWF ADCON0
    MOVLW b'00000000' ; Clear TMR2 register
    MOVWF TMR2
    MOVLW b'00000100' ; Set PR2 register to 4, period is 5*Tosc*T2CKPS = 10us
    MOVWF PR2
    MOVLW b'00000100' ; Enable TMR2, prescaler is 1:1, postscaler is 1:1
    MOVWF T2CON
    MOVLW b'00111111' ; Enable PWM on GP5, active high, no steering
    MOVWF CCP1CON

; Main program loop
MAIN:
    CALL ADC_READ ; Read the ADC value from AN0 channel and store in ADRESH:ADRESL
    MOVF ADRESH,W ; Move the high byte of ADC result to W register
    SUBWF CONST,W ; Subtract the predefined constant from W register and store in W register
    MOVWF DUTY ; Move the result to DUTY register
    CALL PWM_WRITE ; Write the DUTY value to PWM pin and update CCP1CON register
    GOTO MAIN ; Repeat the loop

; Function to read the ADC value from the selected channel and store in ADRESH:ADRESL registers    
ADC_READ:
    BSF ADCON0,GO ; Start the conversion by setting GO bit
ADC_WAIT:
    BTFSC ADCON0,GO ; Wait for the conversion to finish by checking GO bit
    GOTO ADC_WAIT 
    MOVF ADRESH,W ; Move the high byte of ADC result to W register 
    MOVWF ADRESH ; Store it in ADRESH register 
    MOVF ADRESL,W ; Move the low byte of ADC result to W register 
    MOVWF ADRESL ; Store it in ADRESL register 
    RETURN

; Function to write the DUTY value to PWM pin and update CCP1CON register    
PWM_WRITE:
    MOVF DUTY,W ; Move the DUTY value to W register 
    ANDLW b'00000011' ; Mask the lower two bits and store in W register 
    MOVWF TEMP ; Store it in TEMP register 
    RRF TEMP,F ; Rotate right TEMP register through carry flag 
    RRF TEMP,F ; Rotate right again 
    BCF CCP1CON,5 ; Clear bit 5 of CCP1CON register 
    BTFSC TEMP,0 ; Check bit 0 of TEMP register 
        BSF CCP1CON,5 ; Set bit 5 of CCP1CON register if bit 0 of TEMP register is set 
    BCF CCP1CON,4 ; Clear bit 4 of CCP1CON register 
    BTFSC TEMP,1 ; Check bit 1 of TEMP register 
        BSF CCP1CON,4 ; Set bit 4 of CCP1CON register if bit 1 of TEMP register is set 
    SWAPF DUTY,W ; Swap nibbles of DUTY register and store in W register 
    MOVWF CCPR1L ; Store it in CCPR1L register 
    RETURN

; End of program
END
