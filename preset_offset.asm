; PIC12F675 assembly code for gpasm
; Functions for setting up and reading ADC pins, setting up PWM pin
; Main program reading first ADC pin, subtracting constant, writing to PWM pin

; Define constants
    #define OSCCAL 0x90 ; OSCCAL register address
    #define ANS0 0x00 ; AN0 analog input select bit
    #define ANS1 0x01 ; AN1 analog input select bit
    #define ANS2 0x02 ; AN2 analog input select bit
    #define ADCON0 0x1F ; ADCON0 register address
    #define ADON 0x00 ; ADON bit in ADCON0 register
    #define GO_nDONE 0x02 ; GO/nDONE bit in ADCON0 register
    #define CHS0 0x03 ; CHS0 bit in ADCON0 register
    #define CHS1 0x04 ; CHS1 bit in ADCON0 register
    #define ADFM 0x07 ; ADFM bit in ADCON0 register
    #define ADRESH 0x1E ; ADRESH register address
    #define ADRESL 0x1D ; ADRESL register address
    #define CCPR1L 0x15 ; CCPR1L register address
    #define CCP1CON 0x17 ; CCP1CON register address
    #define P1M1 0x07 ; P1M1 bit in CCP1CON register
    #define P1M0 0x06 ; P1M0 bit in CCP1CON register
    #define DCB1 0x05 ; DCB1 bit in CCP1CON register
    #define DCB0 0x04 ; DCB0 bit in CCP1CON register
    #define PR2 0x92 ; PR2 register address
    #define T2CON 0x12 ; T2CON register address
    #define TMR2ON 0x02 ; TMR2ON bit in T2CON register

; Define variables
    cblock 20h ; Start of general purpose registers
        temp ; Temporary variable for calculations
        const ; Constant value to subtract from ADC value
        adcvalh ; High byte of ADC value
        adcvalL ; Low byte of ADC value
        pwmvalh ; High byte of PWM value
        pwmvalL ; Low byte of PWM value
    endc

; Initialize oscillator calibration value from factory setting
    pagesel OSCCAL ; Select page containing OSCCAL register
    movlw OSCCAL & 7Fh ; Mask out upper bit of OSCCAL address (GP3)
    movwf FSR ; Load FSR with OSCCAL address
    bcf STATUS, RP0 ; Bank 0 selected (STATUS<RP0> = 0)
    bcf STATUS, RP1 ; Bank 0 selected (STATUS<RP1> = 0)
    movf INDF, W ; Copy factory calibration value to W register
    movwf OSCCAL ; Write factory calibration value to OSCCAL register

; Initialize I/O ports and peripherals

; Set GP4 as analog input (AN2), GP3 as analog input (AN3), GP2 as PWM output (CCP1)
; Set GP5 as digital output, GP1 as digital input, GP0 as analog input (AN0)
; Set all outputs low

; Set GPIO direction bits: GP4, GP3 and GP2 are inputs, GP5, GP1 and GP0 are outputs 
; GPIO<5:4> are always read as '0'
; GPIO<3:2> are read as '1' when configured as analog inputs 
; GPIO<3:2> are read as '0' when configured as digital inputs 
; GPIO<3:2> are read as 'X' when configured as outputs 
; GPIO<1:0> are read as 'X' when configured as analog inputs 
; GPIO<1:0> are read as 'X' when configured as digital inputs 
; GPIO<1:0> are read as 'X' when configured as outputs 

; Set TRISIO direction bits: TRISIO<5:4> = '00', TRISIO<3:2> = '11', TRISIO<1:0> = '01'
; TRISIO<5:4> are always read as '00'
; TRISIO<3:2> are written as '11' when configured as analog inputs 
; TRISIO<3:2> are written as '00' when configured as digital inputs 
; TRISIO<3:2> are written as '00' when configured as outputs 
; TRISIO<1:0> are written as '11' when configured as analog inputs 
; TRISIO<1:0> are written as '01' when configured as digital inputs 
; TRISIO<1:0> are written as '00' when configured as outputs 

    movlw b'00110001' ; Load W with TRISIO direction bits
    movwf TRISIO ; Write W to TRISIO register

; Set ANSEL analog select bits: ANS2 = '1', ANS1 = '0', ANS0 = '1'
; ANS2 = '1' selects GP4 as analog input (AN2)
; ANS1 = '0' selects GP3 as analog input (AN3)
; ANS0 = '1' selects GP0 as analog input (AN0)

    movlw b'00000101' ; Load W with ANSEL analog select bits
    movwf ANSEL ; Write W to ANSEL register

; Set GPIO output bits: GP5 = '0', GP1 = '0', GP0 = '0'
; GP5 = '0' sets GP5 low
; GP1 = '0' sets GP1 low
; GP0 = '0' sets GP0 low

    movlw b'00000000' ; Load W with GPIO output bits
    movwf GPIO ; Write W to GPIO register

; Set up ADC module
    call ADC_Init ; Call ADC_Init function

; Set up PWM module
    call PWM_Init ; Call PWM_Init function

; Main program loop
MainLoop:

; Read ADC value from AN0 (GP0)
    call ADC_Read ; Call ADC_Read function
    movf ADRESH, W ; Copy high byte of ADC value to W register
    movwf adcvalh ; Store high byte of ADC value in adcvalh variable
    movf ADRESL, W ; Copy low byte of ADC value to W register
    movwf adcvalL ; Store low byte of ADC value in adcvalL variable

; Subtract constant value from ADC value
    movlw 10 ; Load W with constant value to subtract
    movwf const ; Store constant value in const variable
    subwf adcvalL, F ; Subtract constant value from low byte of ADC value and store result in adcvalL variable
    btfss STATUS, C ; Check if borrow occurred (STATUS<C> = 0)
    decf adcvalh, F ; If borrow occurred, decrement high byte of ADC value and store result in adcvalh variable

; Write PWM value to CCP1 (GP2)
    movf adcvalh, W ; Copy high byte of ADC value to W register
    movwf pwmvalh ; Store high byte of PWM value in pwmvalh variable
    movf adcvalL, W ; Copy low byte of ADC value to W register
    movwf pwmvalL ; Store low byte of PWM value in pwmvalL variable
    call PWM_Write ; Call PWM_Write function

; Repeat main loop
    goto MainLoop ; Jump to MainLoop label

; End of program
    end ; End of program directive

; Function definitions

; ADC_Init function: Initializes the ADC module
ADC_Init:

; Set ADCON0 control bits: ADON = '1', GO/nDONE = '0', CHS1:CHS0 = '00', ADFM = '1'
; ADON = '1' enables the ADC module
; GO/nDONE = '0' clears the A/D conversion status bit
; CHS1:CHS0 = '00' selects channel AN0 as the analog input source
; ADFM = '1' selects right justified result format

    movlw b'10000001' ; Load W with ADCON0 control bits
    movwf ADCON0 ; Write W to ADCON0 register

; Return from function
    return ; Return from function directive

; ADC_Read function: Reads the ADC value from the selected channel and stores it in ADRESH and ADRESL registers
ADC_Read:

; Start A/D conversion by setting GO/nDONE bit in ADCON0 register
    bsf ADCON0, GO_nDONE ; Set GO/nDONE bit (ADCON0<GO_nDONE> = 1)

; Wait for A/D conversion to complete by polling GO/nDONE bit in ADCON0 register
ADC_Wait:
    btfsc ADCON0, GO_nDONE ; Check if GO/nDONE bit is clear (ADCON0<GO/nDONE> = 0)
    goto ADC_Wait ; If
;TODO : truncated, put proper ADC read function here
    return ;
