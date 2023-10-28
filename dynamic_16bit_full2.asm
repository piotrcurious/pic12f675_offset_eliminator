; contains bugs:
;-subtract routine is invalid
;
; PIC12F675 assembly code for gpasm
; Functions for setting up and reading ADC pins
; Functions for setting up PWM pin
; Main program subtracting the value of first ADC pin with value of second ADC pin
; Then multiplying the result by value of third ADC pin
; And writing the final result to PWM pin
; All operations are done with 16-bit precision and maximum possible range (10-bit) of PWM is used

    #include <p12f675.inc> ; Include device header file

    __CONFIG _CP_OFF & _WDT_OFF & _INTRC_OSC_NOCLKOUT & _MCLRE_OFF ; Set configuration bits

    ; Define constants
    #define FOSC 4000000 ; Oscillator frequency in Hz
    #define TMR2PRE 4 ; Timer 2 prescaler value
    #define PR2VAL 249 ; Timer 2 period register value
    #define PWMFREQ (FOSC/(TMR2PRE*(PR2VAL+1))) ; PWM frequency in Hz
    #define PWMMAX 1023 ; Maximum PWM duty cycle value (10-bit)

    ; Define registers
    cblock 0x20 ; Start of general purpose registers
        tempL ; Temporary low byte register
        tempH ; Temporary high byte register
        adcL1 ; ADC low byte register for channel 1 (AN0)
        adcH1 ; ADC high byte register for channel 1 (AN0)
        adcL2 ; ADC low byte register for channel 2 (AN1)
        adcH2 ; ADC high byte register for channel 2 (AN1)
        adcL3 ; ADC low byte register for channel 3 (AN2)
        adcH3 ; ADC high byte register for channel 3 (AN2)
        diffL ; Difference low byte register (adc1 - adc2)
        diffH ; Difference high byte register (adc1 - adc2)
        prodL ; Product low byte register (diff * adc3)
        prodH ; Product high byte register (diff * adc3)
        pwmL ; PWM low byte register (prod / PWMMAX)
        pwmH ; PWM high byte register (prod / PWMMAX)
    endc

    org 0x00 ; Start of program memory

; Initialize device
init
    movlw b'01110000' ; Set internal oscillator to 4 MHz, enable GP4 as digital input
    movwf OSCCAL
    movlw b'00000111' ; Set GP0, GP1 and GP2 as analog inputs, GP3 as MCLR, GP4 and GP5 as digital outputs
    movwf TRISIO
    movlw b'00000111' ; Enable weak pull-ups on GP0, GP1 and GP2
    movwf WPU
    movlw b'00001000' ; Enable comparator output on GP5, disable comparator inputs on GP0 and GP1
    movwf CMCON0

; Call functions to set up ADC and PWM modules
    call setupADC ; Set up ADC module
    call setupPWM ; Set up PWM module

; Main loop
mainloop

; Call functions to read ADC values from channels 1, 2 and 3
    call readADC1 ; Read ADC value from channel 1 (AN0) and store in adcL1 and adcH1
    call readADC2 ; Read ADC value from channel 2 (AN1) and store in adcL2 and adcH2
    call readADC3 ; Read ADC value from channel 3 (AN2) and store in adcL3 and adcH3

; Subtract the value of first ADC pin with value of second ADC pin and store in diffL and diffH
;    movf adcL1, w ; Move low byte of adc1 to W register
;    subwf adcL2, w ; Subtract low byte of adc2 from W register
;    movwf diffL ; Move result to diffL register
;    movf adcH1, w ; Move high byte of adc1 to W register
;    subwfb adcH2, w ; Subtract high byte of adc2 from W register with borrow
;    movwf diffH ; Move result to diffH register

; Subtract the value of first ADC pin with value of second ADC pin and store in diffL and diffH
; Use unsigned 16-bit by 16-bit subtraction algorithm from Microchip Application Note AN617
sub16u16u

; Initialize borrow flag to zero
    bcf STATUS, C ; Clear carry flag (inverted borrow flag)

; Subtract low byte of adc2 from low byte of adc1
    movf adcL2, w ; Move low byte of adc2 to W register
    subwf adcL1, w ; Subtract W register from low byte of adc1
    movwf diffL ; Move result to diffL register

; Subtract high byte of adc2 from high byte of adc1 with borrow
    movf adcH2, w ; Move high byte of adc2 to W register
    subwfb adcH1, w ; Subtract W register from high byte of adc1 with borrow
    movwf diffH ; Move result to diffH register

; If borrow flag is set, complement the result and set MSB of diffH
    btfsc STATUS, C ; Test carry flag (inverted borrow flag)
    goto sub16u16u_nop ; If clear (no borrow), go to nop routine
    goto sub16u16u_comp ; If set (borrow), go to complement routine

sub16u16u_comp

; Complement low byte of result
    movf diffL, w ; Move low byte of diff register to W register
    xorlw 0xFF ; Exclusive OR W register with literal value 255
    movwf diffL ; Move result to low byte of diff register

; Complement high byte of result
    movf diffH, w ; Move high byte of diff register to W register
    xorlw 0xFF ; Exclusive OR W register with literal value 255
    movwf diffH ; Move result to high byte of diff register

; Set MSB of high byte of result
    bsf diffH, 7 ; Set bit 7 of high byte of diff register

sub16u16u_nop

; End of subtraction routine


; Multiply the result by value of third ADC pin and store in prodL and prodH
; Use unsigned 16-bit by 16-bit multiplication algorithm from Microchip Application Note AN617
mul16u16u

; Initialize product registers to zero
    clrf prodL ; Clear low byte of product register
    clrf prodH ; Clear high byte of product register

; Initialize loop counter to 16
    movlw .16 ; Load literal value 16 to W register
    movwf tempL ; Move W register to tempL register

mul16u16u_loop

; Shift left diffL and diffH (multiplicand)
    bcf STATUS, C ; Clear carry flag
    rlf diffL, f ; Rotate left low byte of diff register through carry
    rlf diffH, f ; Rotate left high byte of diff register through carry

; If carry flag is set, add adcL3 and adcH3 (multiplier) to prodL and prodH (product)
    btfsc STATUS, C ; Test carry flag
    goto mul16u16u_add ; If set, go to add routine
    goto mul16u16u_nop ; If clear, go to nop routine

mul16u16u_add

; Add low byte of multiplier to low byte of product
    movf adcL3, w ; Move low byte of adc3 to W register
    addwf prodL, f ; Add W register to low byte of prod register

; Add high byte of multiplier to high byte of product with carry
    movf adcH3, w ; Move high byte of adc3 to W register
    btfsc STATUS, C ; Test carry flag
    incfsz WREG, w ; If set, increment W register and skip next instruction
    goto mul16u16u_skip ; If zero, go to skip routine
    addwf prodH, f ; Add W register to high byte of prod register

mul16u16u_skip

; Add carry to high byte of product if any
    btfsc STATUS, C ; Test carry flag
    incf prodH, f ; If set, increment high byte of prod register

mul16u16u_nop

; Shift right prodL and prodH (product)
    bcf STATUS, C ; Clear carry flag
    rrf prodH, f ; Rotate right high byte of prod register through carry
    rrf prodL, f ; Rotate right low byte of prod register through carry

; Decrement loop counter and repeat until zero
    decfsz tempL, f ; Decrement tempL register and skip next instruction if zero
    goto mul16u16u_loop ; If not zero, go to loop routine

; End of multiplication routine

; Divide the result by PWMMAX and store in pwmL and pwmH
; Use unsigned 16-bit by 10-bit division algorithm from Microchip Application Note AN617
div16u10u

; Initialize quotient registers to zero
    clrf pwmL ; Clear low byte of quotient register
    clrf pwmH ; Clear high byte of quotient register

; Initialize loop counter to 10
    movlw .10 ; Load literal value 10 to W register
    movwf tempL ; Move W register to tempL register

div16u10u_loop

; Shift left prodL and prodH (dividend)
    bcf STATUS, C ; Clear carry flag
    rlf prodL, f ; Rotate left low byte of dividend register through carry
    rlf prodH, f ; Rotate left high byte of dividend register through carry

; Shift left pwmL and pwmH (quotient)
    rlf pwmL, f ; Rotate left low byte of quotient register through carry
    rlf pwmH, f ; Rotate left high byte of quotient register through carry

; Subtract PWMMAX from prodL and prodH (dividend)
    movlw low(PWMMAX) ; Move low byte of PWMMAX to W register
    subwf prodL, w ; Subtract W register from low byte of dividend register
    movwf tempH ; Move result to tempH register
    movlw high(PWMMAX) ; Move high byte of PWMMAX to W register
    subwfb prodH, w ; Subtract W register from high byte of dividend register with borrow

; If borrow flag is clear, store tempH and WREG in prodL and prodH (dividend) and set LSB of quotient
    btfss STATUS, C ; Test carry flag (inverted borrow flag)
    goto div16u10u_nop ; If set (borrow), go to nop routine
    goto div16u10u_store ; If clear (no borrow), go to store routine

div16u10u_store

; Store tempH and WREG in dividend registers
    movf tempH, w ; Move tempH register to W register
    movwf prodL ; Move W register to low byte of dividend register
    movwf prodH ; Move W register to high byte of dividend register

; Set LSB of quotient registers
    bsf pwmL, 0 ; Set bit 0 of low byte of quotient register
div16u10u_nop

; Decrement loop counter and repeat until zero
    decfsz tempL, f ; Decrement tempL register and skip next instruction if zero
    goto div16u10u_loop ; If not zero, go to loop routine

; End of division routine

; Write the result to PWM pin (GP5)
    movf pwmL, w ; Move low byte of quotient register to W register
    movwf CCPR1L ; Move W register to PWM duty cycle low byte register
    movf pwmH, w ; Move high byte of quotient register to W register
    andlw b'00000011' ; Mask out all but the two LSBs of W register
    movwf CCP1CON ; Move W register to PWM duty cycle high byte register

; Go back to main loop
    goto mainloop ; Go to main loop routine

; End of main program

; Function to set up ADC module
setupADC

; Set ADC clock source to FOSC/8
    bcf ADCON0, ADCS1 ; Clear bit 7 of ADCON0 register
    bsf ADCON0, ADCS0 ; Set bit 6 of ADCON0 register

; Set ADC result format to right justified
    bsf ADCON0, ADFM ; Set bit 1 of ADCON0 register

; Set ADC input channel to AN0
    bcf ADCON0, CHS1 ; Clear bit 3 of ADCON0 register
    bcf ADCON0, CHS0 ; Clear bit 2 of ADCON0 register

; Enable ADC module
    bsf ADCON0, ADON ; Set bit 0 of ADCON0 register

; Return from function
    return

; Function to read ADC value from channel 1 (AN0) and store in adcL1 and adcH1
readADC1

; Set ADC input channel to AN0
    bcf ADCON0, CHS1 ; Clear bit 3 of ADCON0 register
    bcf ADCON0, CHS0 ; Clear bit 2 of ADCON0 register

; Wait for acquisition time (2.4us)
    nop ; No operation for one instruction cycle (1us)
    nop ; No operation for one instruction cycle (1us)
    nop ; No operation for one instruction cycle (1us)

; Start ADC conversion
    bsf ADCON0, GO ; Set bit 2 of ADCON0 register

; Wait for conversion to finish
readADC1_wait
    btfsc ADCON0, GO ; Test bit 2 of ADCON0 register
    goto readADC1_wait ; If set, go to wait routine

; Store ADC result in adcL1 and adcH1 registers
    movf ADRESL, w ; Move low byte of ADRES register to W register
    movwf adcL1 ; Move W register to low byte of adc1 register
    movf ADRESH, w ; Move high byte of ADRES register to W register
    movwf adcH1 ; Move W register to high byte of adc1 register

; Return from function
    return

; Function to read ADC value from channel 2 (AN1) and store in adcL2 and adcH2
readADC2

; Set ADC input channel to AN1
; Set ADC input channel to AN1
    bcf ADCON0, CHS1 ; Clear bit 3 of ADCON0 register
    bsf ADCON0, CHS0 ; Set bit 2 of ADCON0 register

; Wait for acquisition time (2.4us)
    nop ; No operation for one instruction cycle (1us)
    nop ; No operation for one instruction cycle (1us)
    nop ; No operation for one instruction cycle (1us)

; Start ADC conversion
    bsf ADCON0, GO ; Set bit 2 of ADCON0 register

; Wait for conversion to finish
readADC2_wait
    btfsc ADCON0, GO ; Test bit 2 of ADCON0 register
    goto readADC2_wait ; If set, go to wait routine

; Store ADC result in adcL2 and adcH2 registers
    movf ADRESL, w ; Move low byte of ADRES register to W register
    movwf adcL2 ; Move W register to low byte of adc2 register
    movf ADRESH, w ; Move high byte of ADRES register to W register
    movwf adcH2 ; Move W register to high byte of adc2 register

; Return from function
    return

; Function to read ADC value from channel 3 (AN2) and store in adcL3 and adcH3
readADC3

; Set ADC input channel to AN2
    bsf ADCON0, CHS1 ; Set bit 3 of ADCON0 register
    bcf ADCON0, CHS0 ; Clear bit 2 of ADCON0 register

; Wait for acquisition time (2.4us)
    nop ; No operation for one instruction cycle (1us)
    nop ; No operation for one instruction cycle (1us)
    nop ; No operation for one instruction cycle (1us)

; Start ADC conversion
    bsf ADCON0, GO ; Set bit 2 of ADCON0 register

; Wait for conversion to finish
readADC3_wait
    btfsc ADCON0, GO ; Test bit 2 of ADCON0 register
    goto readADC3_wait ; If set, go to wait routine

; Store ADC result in adcL3 and adcH3 registers
    movf ADRESL, w ; Move low byte of ADRES register to W register
    movwf adcL3 ; Move W register to low byte of adc3 register
    movf ADRESH, w ; Move high byte of ADRES register to W register
    movwf adcH3 ; Move W register to high byte of adc3 register

; Return from function
    return

; Function to set up PWM module
setupPWM

; Set PWM mode to single output on GP5
    movlw b'00001100' ; Load literal value 12 to W register
    movwf CCP1CON ; Move W register to CCP1CON register

; Set PWM duty cycle registers to zero
    clrf CCPR1L ; Clear low byte of PWM duty cycle register
    clrf CCP1CON ; Clear high byte of PWM duty cycle register

; Set Timer 2 prescaler to 4
    bcf T2CON, TOUTPS3 ; Clear bit 6 of T2CON register
    bcf T2CON, TOUTPS2 ; Clear bit 5 of T2CON register
    bcf T2CON, TOUTPS1 ; Clear bit 4 of T2CON register
    bcf T2CON, TOUTPS0 ; Clear bit 3 of T2CON register
    bcf T2CON, TMR2ON ; Clear bit 2 of T2CON register (disable Timer 2)
    bsf T2CON, T2CKPS1 ; Set bit 1 of T2CON register (prescaler bit 1)
    bcf T2CON, T2CKPS0 ; Clear bit 0 of T2CON register (prescaler bit 0)

; Set Timer 2 period register to PR2VAL constant
    movlw PR2VAL ; Move PR2VAL constant to W register
    movwf PR2 ; Move W register to PR2 register

; Enable Timer 2 module
    bsf T2CON, TMR2ON ; Set bit 2 of T2CON register (enable Timer 2)

; Return from function
    return

; End of file
