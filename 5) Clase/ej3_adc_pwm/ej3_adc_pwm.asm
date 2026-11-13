;=====================================================================
; Ejemplo 3 · Potenciómetro (AN0) → PWM en RC2/CCP1 y valor en PORTB
; PIC16F877A · 4 MHz · PWM de 976,6 Hz (PR2 = 255, preescalador 4)
; ADC justificado a la izquierda: ADRESH = 8 bits más significativos
;=====================================================================
        LIST    p=16F877A
        #include <p16f877a.inc>
        __CONFIG 0x3F31

        CBLOCK  0x20
        d1
        ENDC

        ORG     0x0000
        goto    inicio

inicio  banksel TRISA
        movlw   0xFF
        movwf   TRISA           ; PORTA: entradas (AN0)
        clrf    TRISB           ; PORTB: LEDs con el valor del ADC
        bcf     TRISC,2         ; RC2/CCP1: salida PWM
        movlw   b'00001110'     ; ADFM = 0 (izquierda), PCFG = 1110: solo AN0 analógico
        movwf   ADCON1
        movlw   d'255'
        movwf   PR2             ; periodo PWM = (255+1)·4·Tosc·4 = 1,024 ms
        banksel ADCON0
        movlw   b'01000001'     ; Fosc/8 (Tad = 2 µs), canal 0, ADON = 1
        movwf   ADCON0
        movlw   b'00000101'     ; TMR2 encendido, preescalador 1:4
        movwf   T2CON
        movlw   b'00001100'     ; CCP1 en modo PWM
        movwf   CCP1CON
        clrf    CCPR1L

bucle   movlw   d'7'            ; tiempo de adquisición ≈ 20 µs
        movwf   d1
adq     decfsz  d1,F
        goto    adq
        bsf     ADCON0,GO       ; inicia la conversión
espera  btfsc   ADCON0,GO       ; espera GO/DONE = 0
        goto    espera
        movf    ADRESH,W
        movwf   CCPR1L          ; ciclo útil = ADRESH/256
        movwf   PORTB           ; muestra el valor en los LEDs
        goto    bucle

        END
