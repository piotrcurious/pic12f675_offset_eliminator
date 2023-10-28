; PIC12F675 assembly for gpasm
; Setting up and reading ADC pins, setting up PWM pin
; Main program reading first ADC pin, storing result to memory
; Reading second ADC pin, storing the result to memory
; Subtracting the value of first ADC pin with value of second ADC pin
; Writing the result to PWM pin

    list p=12f675
    include "p12f675.inc"
    __config _INTRC_OSC_NOCLKOUT & _WDT_OFF & _PWRTE_ON & _MCLRE_OFF & _CP_OFF & _BODEN_OFF

    #define ADCON0_INIT 0b10000001 ; ADON, CHS<2:0>=000 (AN0)
    #define ANSEL_INIT 0b00001111 ; ANS<3:0>=1111 (AN0-AN3), ADCS<2:0>=111 (Fosc/8)
    #define TRISIO_INIT 0b00111111 ; GP<5:0> as inputs
    #define GPIO_INIT 0b00000000 ; GP<5:0> as low
    #define PR2_INIT 0b11111111 ; PR2 value for PWM period
    #define CCPR1L_INIT 0b00000000 ; CCPR1L value for PWM duty cycle
    #define CCP1CON_INIT 0b00001100 ; CCP1M<3:0>=1100 (PWM mode), DC1B<1:0>=00 (LSB of duty cycle)
    #define T2CON_INIT 0b00000101 ; TMR2ON, T2CKPS<1:0>=01 (Prescaler 4)

    cblock 0x20
        temp ; temporary variable for calculations
        adc1 ; variable to store ADC result from AN0
        adc2 ; variable to store ADC result from AN1
    endc

    org 0x00 ; reset vector
    goto main

    org 0x04 ; interrupt vector
    retfie

main:
    bsf STATUS, RP0 ; select bank 1
    movlw ANSEL_INIT ; initialize ANSEL register
    movwf ANSEL
    movlw TRISIO_INIT ; initialize TRISIO register
    movwf TRISIO
    movlw GPIO_INIT ; initialize GPIO register
    movwf GPIO
    movlw PR2_INIT ; initialize PR2 register for PWM period
    movwf PR2
    movlw CCPR1L_INIT ; initialize CCPR1L register for PWM duty cycle
    movwf CCPR1L
    movlw CCP1CON_INIT ; initialize CCP1CON register for PWM mode and LSB of duty cycle
    movwf CCP1CON
    movlw T2CON_INIT ; initialize T2CON register for timer 2 control and prescaler
    movwf T2CON
    bcf STATUS, RP0 ; select bank 0

loop:
    call read_adc_0 ; read ADC value from AN0 and store in adc1 variable
    call read_adc_1 ; read ADC value from AN1 and store in adc2 variable
    call subtract_adc_values ; subtract adc1 from adc2 and store in temp variable
    call write_pwm_value ; write temp value to PWM duty cycle registers

goto loop

read_adc_0:
; This function reads the ADC value from AN0 and stores it in adc1 variable

; Select channel AN0 (CHS<2:0>=000)
bsf STATUS, RP0 ; select bank 1
bcf ANSEL, ANS3 
bcf ANSEL, ANS2 
bcf ANSEL, ANS1 
bcf STATUS, RP0 ; select bank 0

; Start conversion (GO/DONE=1)
bsf ADCON0, GO

; Wait for conversion to finish (GO/DONE=0)
wait_0:
btfsc ADCON0, GO 
goto wait_0

; Read result from ADRESH and ADRESL registers and store in adc1 variable
movf ADRESH, W 
movwf adc1 
swapf ADRESL, W 
andlw 0x03 
iorwf adc1, F 

return

read_adc_1:
; This function reads the ADC value from AN1 and stores it in adc2 variable

; Select channel AN1 (CHS<2:0>=001)
bsf STATUS, RP0 ; select bank 1
bcf ANSEL, ANS3 
bcf ANSEL, ANS2 
bsf ANSEL, ANS1 
bcf STATUS, RP0 ; select bank 0

; Start conversion (GO/DONE=1)
bsf ADCON0, GO

; Wait for conversion to finish (GO/DONE=0)
wait_1:
btfsc ADCON0, GO 
goto wait_1

; Read result from ADRESH and ADRESL registers and store in adc2 variable
movf ADRESH, W 
movwf adc2 
swapf ADRESL, W 
andlw 0x03 
iorwf adc2, F 

return

subtract_adc_values:
; This function subtracts adc1 from adc2 and stores the result in temp variable
; It also checks for overflow and underflow and clamps the result to 0 or 255 accordingly

movf adc2, W ; load adc2 value to W register
subwf adc1, W ; subtract adc1 value from W register
btfss STATUS, C ; check for borrow (underflow)
goto underflow ; if borrow, go to underflow handler
btfsc STATUS, Z ; check for zero result
goto zero ; if zero, go to zero handler
btfss STATUS, DC ; check for digit carry (overflow)
goto overflow ; if no digit carry, go to overflow handler
movwf temp ; store result in temp variable
return

underflow:
clrf temp ; set temp to 0
return

zero:
clrf temp ; set temp to 0
return

overflow:
movlw 0xFF ; load 255 to W register
movwf temp ; set temp to 255
return

write_pwm_value:
; This function writes the temp value to the PWM duty cycle registers (CCPR1L and DC1B<1:0>)

movf temp, W ; load temp value to W register
andlw 0xFC ; mask out the lower 2 bits
rrf WREG, F ; right rotate W register by 2 bits
movwf CCPR1L ; store result in CCPR1L register
swapf temp, W ; swap nibbles of temp value in W register
andlw 0x03 ; mask out the upper 6 bits
movwf CCP1CON ; store result in DC1B<1:0> bits of CCP1CON register
return

end
