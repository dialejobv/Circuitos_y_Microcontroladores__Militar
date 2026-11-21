;===========================================================================
; Ejemplo 8 · PWM: melodía con un parlante (la frecuencia del PWM es la nota)
; PIC16F877A · cristal 4 MHz
;   RC2/CCP1 → 100 Ω → parlante (SPEAKER en Proteus) · RB0 = tocar · RC0 = LED "sonando"
;   Nota: f = Fosc / (4 · 16 · (PR2 + 1)) → PR2 = 62500 / f − 1, ciclo útil del 50 %
;   Melodía: "Estrellita, ¿dónde estás?" (tradicional, dominio público)
;===========================================================================
        LIST    P=16F877A, R=DEC
        #include <p16f877a.inc>
        __CONFIG _XT_OSC & _WDT_OFF & _PWRTE_ON & _BOREN_OFF & _LVP_OFF & _CP_OFF

        CBLOCK  0x20
        IDX, NOTA, DUR, VECES
        ENDC

        ORG     0x000
        goto    INICIO
        ORG     0x005
PR2_NOTA                                ; Do4 Re4 Mi4 Fa4 Sol4 La4 Si4 Do5
        addwf   PCL,F
        DT      237, 212, 188, 178, 158, 141, 125, 118
MELODIA                                 ; nota (0..7) y duración (en corcheas de 250 ms) alternadas; 0xFF = fin
        addwf   PCL,F
        DT      0,1, 0,1, 4,1, 4,1, 5,1, 5,1, 4,2
        DT      3,1, 3,1, 2,1, 2,1, 1,1, 1,1, 0,2
        DT      4,1, 4,1, 3,1, 3,1, 2,1, 2,1, 1,2
        DT      4,1, 4,1, 3,1, 3,1, 2,1, 2,1, 1,2
        DT      0,1, 0,1, 4,1, 4,1, 5,1, 5,1, 4,2
        DT      3,1, 3,1, 2,1, 2,1, 1,1, 1,1, 0,2
        DT      0xFF

INICIO
        BANKSEL OPTION_REG
        bcf     OPTION_REG,NOT_RBPU
        bcf     TRISC,2                 ; RC2/CCP1 salida
        bcf     TRISC,0
        BANKSEL PORTC
        clrf    PORTC
        clrf    CCPR1L
        movlw   0x0C                    ; CCP1 en PWM
        movwf   CCP1CON
        movlw   b'00000110'             ; TMR2 encendido, preescalador 1:16
        movwf   T2CON

ESPERAR btfsc   PORTB,0                 ; espera el botón
        goto    ESPERAR
        bsf     PORTC,0
        clrf    IDX
TOCAR   movf    IDX,W
        call    MELODIA
        movwf   NOTA
        xorlw   0xFF
        btfsc   STATUS,Z
        goto    FIN
        incf    IDX,F
        movf    IDX,W
        call    MELODIA
        movwf   DUR
        incf    IDX,F
        movf    NOTA,W                  ; frecuencia de la nota
        call    PR2_NOTA
        BANKSEL PR2
        movwf   PR2
        BANKSEL CCPR1L
        movwf   CCPR1L                  ; 50 %: CCPR1L = (PR2 + 1) / 2
        incf    CCPR1L,F
        bcf     STATUS,C
        rrf     CCPR1L,F
SONAR   movlw   230                     ; duración: DUR x 250 ms (230 sonando + 20 de silencio)
        call    RETARDO_MS
        decfsz  DUR,F
        goto    SONAR_MAS
        clrf    CCPR1L                  ; silencio entre notas
        movlw   20
        call    RETARDO_MS
        goto    TOCAR
SONAR_MAS
        movlw   20
        call    RETARDO_MS
        goto    SONAR
FIN     clrf    CCPR1L
        bcf     PORTC,0
        goto    ESPERAR

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
