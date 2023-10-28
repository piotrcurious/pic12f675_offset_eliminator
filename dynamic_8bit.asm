; PIC12F675 assembly code for gpasm
; Functions for setting up and reading ADC pins, setting up PWM pin
; Main program subtracting the value of first ADC pin with value of second ADC pin and writing the result to PWM pin

    list p=12f675
    include "p12f675.inc"
    __config _CP_OFF & _WDT_OFF & _PWRTE_ON & _INTRC_OSC_NOCLKOUT & _MCLRE_OFF

; Define constants
    #define ADCON0_INIT 0b10000001 ; AN0, A/D on, clock Fosc/8
    #define ANSEL_INIT 0b00001111 ; AN0-AN3 analog, others digital
    #define TRISIO_INIT 0b00001111 ; GP0-GP3 inputs, others outputs
    #define PR2_INIT 0x7F ; PWM period value
    #define T2CON_INIT 0b00000100 ; Timer2 on, prescaler 1:1, postscaler 1:1

; Define variables
    cblock 0x20
        adc_value1 ; ADC value from AN0
        adc_value2 ; ADC value from AN1
        pwm_value ; PWM value for GP2
    endc

; Initialize registers and variables
    org 0x00
    movlw TRISIO_INIT ; Set GPIO direction
    movwf TRISIO
    movlw ANSEL_INIT ; Set analog pins
    movwf ANSEL
    movlw ADCON0_INIT ; Set ADC configuration
    movwf ADCON0
    movlw PR2_INIT ; Set PWM period value
    movwf PR2
    movlw T2CON_INIT ; Set Timer2 configuration
    movwf T2CON

; Main program loop
main_loop:
    call read_adc0 ; Read ADC value from AN0 and store in adc_value1
    call read_adc1 ; Read ADC value from AN1 and store in adc_value2
    call subtract_adc_values ; Subtract adc_value1 from adc_value2 and store in pwm_value
    call write_pwm ; Write pwm_value to CCPR1L register and set CCP1CON bits for PWM duty cycle
    goto main_loop ; Repeat the loop

; Function to read ADC value from AN0 and store in adc_value1 variable
read_adc0:
    bcf ADCON0, CHS0 ; Select channel AN0
    bcf ADCON0, CHS1 
    bsf ADCON0, GO ; Start conversion
wait_adc0:
    btfsc ADCON0, GO ; Wait for conversion to finish
    goto wait_adc0 
    movf ADRESH, W ; Move high byte of result to W register
    movwf adc_value1 ; Store W register to adc_value1 variable
    return

; Function to read ADC value from AN1 and store in adc_value2 variable
read_adc1:
    bsf ADCON0, CHS0 ; Select channel AN1
    bcf ADCON0, CHS1 
    bsf ADCON0, GO ; Start conversion
wait_adc1:
    btfsc ADCON0, GO ; Wait for conversion to finish
    goto wait_adc1 
    movf ADRESH, W ; Move high byte of result to W register
    movwf adc_value2 ; Store W register to adc_value2 variable
    return

; Function to subtract adc_value1 from adc_value2 and store in pwm_value variable
subtract_adc_values:
    movf adc_value2, W ; Move adc_value2 to W register
    subwf adc_value1, W ; Subtract adc_value1 from W register (W = adc_value2 - adc_value1)
    movwf pwm_value ; Store W register to pwm_value variable
    return

; Function to write pwm_value to CCPR1L register and set CCP1CON bits for PWM duty cycle 
write_pwm:
    movf pwm_value, W ; Move pwm_value to W register 
    movwf CCPR1L ; Write W register to CCPR1L register (low byte of PWM duty cycle)
    bcf CCP1CON, DC1B0 ; Clear DC1B bits (high nibble of PWM duty cycle)
    bcf CCP1CON, DC1B1 
    bsf CCP1CON, CCP1M3 ; Set CCP module as PWM mode 
return

      
