;===========================================================================
; Ejemplo 9 · Motor paso a paso unipolar con ULN2003A (secuencia de medio paso)
; PIC16F877A · cristal 4 MHz
;   RD0..RD3 -> IN1..IN4 del ULN2003A -> bobinas A, B, C, D del motor (MOTOR-STEPPER)
;   RB0 = girar en sentido horario, RB1 = antihorario (mientras se mantenga presionado)
;   Potenciómetro en AN0: tiempo entre pasos de 2 a 33 ms
;   RC0 = LED horario, RC1 = LED antihorario
;===========================================================================
        LIST    P=16F877A, R=DEC
        #include <p16f877a.inc>
        __CONFIG _XT_OSC & _WDT_OFF & _PWRTE_ON & _BOREN_OFF & _LVP_OFF & _CP_OFF

        CBLOCK  0x20
        IDX, DEMORA
        ENDC

        ORG     0x000
        goto    INICIO
        ORG     0x005
SECUENCIA                               ; medio paso: A, AB, B, BC, C, CD, D, DA
        addwf   PCL,F
        DT      b'0001',b'0011',b'0010',b'0110',b'0100',b'1100',b'1000',b'1001'

INICIO
        BANKSEL OPTION_REG
        bcf     OPTION_REG,NOT_RBPU
        movlw   0xF0
        movwf   TRISD
        movlw   0xFC
        movwf   TRISC
        movlw   0x0E                    ; AN0 analógico, justificado a la izquierda
        movwf   ADCON1
        BANKSEL PORTD
        clrf    PORTD
        clrf    PORTC
        clrf    IDX
        movlw   0x41
        movwf   ADCON0

LAZO    call    RETARDO_50US            ; lee la velocidad
        bsf     ADCON0,GO
ESPERA  btfsc   ADCON0,GO
        goto    ESPERA
        rrf     ADRESH,W                ; DEMORA = 2 + ADRESH / 8
        movwf   DEMORA
        rrf     DEMORA,F
        rrf     DEMORA,W
        andlw   0x1F
        addlw   2
        movwf   DEMORA

        btfss   PORTB,0
        goto    HORARIO
        btfss   PORTB,1
        goto    ANTIHORARIO
        clrf    PORTC                   ; ningún botón: LED apagados, bobinas sin corriente
        clrf    PORTD
        goto    LAZO

HORARIO incf    IDX,W
        andlw   7
        movwf   IDX
        movlw   b'00000001'
        goto    MOVER
ANTIHORARIO
        decf    IDX,W
        andlw   7
        movwf   IDX
        movlw   b'00000010'
MOVER   movwf   PORTC
        movf    IDX,W
        call    SECUENCIA
        movwf   PORTD
        movf    DEMORA,W
        call    RETARDO_MS
        goto    LAZO

;---------------------------------------------------------------------------
; Retardos para cristal de 4 MHz (1 ciclo de instrucción = 1 µs)
;---------------------------------------------------------------------------
        CBLOCK  0x68
        R_MS, R_US
        ENDC
RETARDO_MS                      ; espera W milisegundos (W = 1..255)
        movwf   R_MS
RMS1    movlw   249             ; 2 + 248*4 + 3 + 3 = 1000 ciclos por milisegundo
        movwf   R_US
RMS2    nop
        decfsz  R_US,F
        goto    RMS2
        decfsz  R_MS,F
        goto    RMS1
        return
RETARDO_50US                    ; 50 µs contando el call y el return
        movlw   15
        movwf   R_US
R50     decfsz  R_US,F
        goto    R50
        return

        END
