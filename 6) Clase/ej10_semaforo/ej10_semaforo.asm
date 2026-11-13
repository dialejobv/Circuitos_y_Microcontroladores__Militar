;===========================================================================
; Ejemplo 10 · Semáforo con botón peatonal: interrupción externa (RB0/INT) y TMR1 (base de 100 ms)
; PIC16F877A · cristal 4 MHz
;   Vehicular: RD0 = rojo, RD1 = amarillo, RD2 = verde
;   Peatonal:  RD3 = rojo, RD4 = verde,  RD5 = LED "espere" (solicitud registrada)
;   RB0/INT = pulsador peatonal (a tierra, pull-up interno)
;   Ciclo: verde 10 s (3 s si un peatón lo pidió) -> amarillo 2 s -> rojo con peatón 5 s + 3 s parpadeando -> despeje 1 s
;===========================================================================
        LIST    P=16F877A, R=DEC
        #include <p16f877a.inc>
        __CONFIG _XT_OSC & _WDT_OFF & _PWRTE_ON & _BOREN_OFF & _LVP_OFF & _CP_OFF

        CBLOCK  0x20
        DECIMAS, SOLICITUD, LIMITE, VECES
        ENDC
        CBLOCK  0x70
        W_TEMP, S_TEMP
        ENDC

ROJO_V  EQU     0
AMAR_V  EQU     1
VERDE_V EQU     2
ROJO_P  EQU     3
VERDE_P EQU     4
ESPERE  EQU     5

        ORG     0x000
        goto    INICIO
        ORG     0x004                   ;---------- interrupciones
        movwf   W_TEMP
        swapf   STATUS,W
        clrf    STATUS
        movwf   S_TEMP
        btfss   PIR1,TMR1IF
        goto    NO_T1
        bcf     PIR1,TMR1IF             ; TMR1 = 65536 - 12500: 12500 x 8 µs = 100 ms
        bcf     T1CON,TMR1ON
        movlw   HIGH (65536 - 12500)
        movwf   TMR1H
        movlw   LOW (65536 - 12500)
        movwf   TMR1L
        bsf     T1CON,TMR1ON
        incf    DECIMAS,F
NO_T1   btfss   INTCON,INTF
        goto    FIN_ISR
        bcf     INTCON,INTF             ; un peatón presionó el botón
        movlw   1
        movwf   SOLICITUD
FIN_ISR swapf   S_TEMP,W
        movwf   STATUS
        swapf   W_TEMP,F
        swapf   W_TEMP,W
        retfie

INICIO
        BANKSEL TRISD
        clrf    TRISD
        movlw   b'00000000'             ; pull-ups activos, INT en flanco de bajada
        movwf   OPTION_REG
        bsf     PIE1,TMR1IE
        BANKSEL PORTD
        clrf    PORTD
        clrf    SOLICITUD
        movlw   HIGH (65536 - 12500)
        movwf   TMR1H
        movlw   LOW (65536 - 12500)
        movwf   TMR1L
        movlw   b'00110001'             ; TMR1 encendido, preescalador 1:8, reloj interno
        movwf   T1CON
        movlw   b'11010000'             ; GIE, PEIE, INTE
        movwf   INTCON

VERDE   movlw   (1 << VERDE_V) | (1 << ROJO_P)
        movwf   PORTD
        clrf    DECIMAS
V1      btfsc   SOLICITUD,0             ; muestra que la solicitud quedó registrada
        bsf     PORTD,ESPERE
        movlw   100                     ; 10 s como máximo
        subwf   DECIMAS,W
        btfsc   STATUS,C
        goto    AMARILLO
        btfss   SOLICITUD,0
        goto    V1
        movlw   30                      ; con solicitud: al menos 3 s de verde
        subwf   DECIMAS,W
        btfss   STATUS,C
        goto    V1

AMARILLO
        movlw   (1 << AMAR_V) | (1 << ROJO_P)
        btfsc   SOLICITUD,0
        iorlw   (1 << ESPERE)
        movwf   PORTD
        movlw   20
        call    ESPERAR

ROJO    clrf    SOLICITUD
        movlw   (1 << ROJO_V) | (1 << VERDE_P)
        movwf   PORTD
        movlw   50
        call    ESPERAR
        movlw   6                       ; el verde peatonal parpadea 3 s
        movwf   VECES
PARPADEO
        movlw   (1 << VERDE_P)
        xorwf   PORTD,F
        movlw   5
        call    ESPERAR
        decfsz  VECES,F
        goto    PARPADEO
        movlw   (1 << ROJO_V) | (1 << ROJO_P)   ; despeje: todo en rojo
        movwf   PORTD
        movlw   10
        call    ESPERAR
        clrf    SOLICITUD               ; las solicitudes durante el rojo ya se atendieron
        goto    VERDE

ESPERAR                                 ; espera W décimas de segundo usando el contador de la interrupción
        movwf   LIMITE
        clrf    DECIMAS
ES1     movf    LIMITE,W
        subwf   DECIMAS,W
        btfss   STATUS,C
        goto    ES1
        return
        END
