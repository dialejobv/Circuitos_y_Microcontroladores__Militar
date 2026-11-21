;===========================================================================
; Ejemplo 12 · Multitarea: semáforo + latido + comandos por USART al mismo tiempo
; PIC16F877A · cristal 4 MHz · 9600 baudios
;   Tick de 10 ms con TMR0 · la recepción por USART llega por interrupción
;   Tareas: SEMAFORO (máquina de estados, cada 100 ms) · LATIDO (RB7, cada 300 ms) · SERIE (cada 10 ms)
;   RB0 rojo · RB1 amarillo · RB2 verde (vehicular) · RB3 rojo · RB4 verde (peatonal) · RB5 "espere"
;   Comandos: P = solicitud peatonal · S = estado actual. El PIC informa cada cambio de estado.
;===========================================================================
        LIST    P=16F877A, R=DEC
        #include <p16f877a.inc>
        __CONFIG _XT_OSC & _WDT_OFF & _PWRTE_ON & _BOREN_OFF & _LVP_OFF & _CP_OFF

        CBLOCK  0x20
        TICKS, MS10, C_SEM, C_LAT, ESTADO, TIEMPO, SOLICITUD, RXDATO, RXFLAG, AUX
        ENDC
        CBLOCK  0x70
        W_TEMP, S_TEMP, P_TEMP
        ENDC
VERDE    EQU    0
AMARILLO EQU    1
ROJO     EQU    2
DESPEJE  EQU    3

        ORG     0x000
        goto    INICIO

        ORG     0x004                   ;================= ISR
        movwf   W_TEMP
        swapf   STATUS,W
        clrf    STATUS
        movwf   S_TEMP
        movf    PCLATH,W
        movwf   P_TEMP
        clrf    PCLATH
        btfss   INTCON,T0IF
        goto    ISR_RX
        bcf     INTCON,T0IF
        movlw   6
        addwf   TMR0,F
        incf    MS10,F
        movlw   10
        subwf   MS10,W
        btfss   STATUS,C
        goto    ISR_RX
        clrf    MS10
        incf    TICKS,F
ISR_RX  btfss   PIR1,RCIF
        goto    FIN_ISR
        movf    RCREG,W
        movwf   RXDATO
        bsf     RXFLAG,0
FIN_ISR movf    P_TEMP,W
        movwf   PCLATH
        swapf   S_TEMP,W
        movwf   STATUS
        swapf   W_TEMP,F
        swapf   W_TEMP,W
        retfie

LUCES                                   ; LED de cada estado (sin RB5 ni RB7)
        clrf    PCLATH                  ; la tabla está en la página 0x000-0x0FF
        addwf   PCL,F
        DT      b'00001100', b'00001010', b'00010001', b'00001001'

INICIO
        BANKSEL TRISB
        clrf    TRISB
        movlw   b'00000001'             ; TMR0 interno, preescalador 1:4
        movwf   OPTION_REG
        BANKSEL PORTB
        clrf    PORTB
        call    UART_INIT
        BANKSEL PIE1
        bsf     PIE1,RCIE
        BANKSEL PORTB
        clrf    TICKS
        clrf    MS10
        clrf    SOLICITUD
        clrf    RXFLAG
        clrf    TIEMPO
        movlw   VERDE
        movwf   ESTADO
        movlw   10
        movwf   C_SEM
        movlw   30
        movwf   C_LAT
        movlw   HIGH TXT_HOLA
        movwf   PTR_H
        movlw   LOW TXT_HOLA
        movwf   PTR_L
        call    TX_CADENA
        call    PONER_LUCES
        call    ANUNCIAR
        movlw   b'11100000'             ; GIE, PEIE, T0IE
        movwf   INTCON

;================= planificador
LAZO    movf    TICKS,W
        btfsc   STATUS,Z
        goto    LAZO
        decf    TICKS,F
        call    TAREA_SERIE             ; cada 10 ms
        decfsz  C_SEM,F
        goto    L2
        movlw   10                      ; cada 100 ms
        movwf   C_SEM
        call    TAREA_SEMAFORO
L2      decfsz  C_LAT,F
        goto    LAZO
        movlw   30                      ; cada 300 ms
        movwf   C_LAT
        movlw   b'10000000'
        xorwf   PORTB,F
        goto    LAZO

;================= tarea: comandos por la USART
TAREA_SERIE
        btfss   RXFLAG,0
        return
        bcf     RXFLAG,0
        movf    RXDATO,W
        andlw   0xDF
        movwf   AUX
        xorlw   'P'
        btfsc   STATUS,Z
        goto    PEDIR
        movf    AUX,W
        xorlw   'S'
        btfsc   STATUS,Z
        goto    ANUNCIAR
        return
PEDIR   bsf     SOLICITUD,0
        bsf     PORTB,5                 ; LED "espere"
        movlw   HIGH TXT_PED
        movwf   PTR_H
        movlw   LOW TXT_PED
        movwf   PTR_L
        goto    TX_CADENA

;================= tarea: máquina de estados del semáforo (cada 100 ms)
TAREA_SEMAFORO
        incf    TIEMPO,F
        movf    ESTADO,W
        xorlw   VERDE
        btfsc   STATUS,Z
        goto    S_VERDE
        movf    ESTADO,W
        xorlw   AMARILLO
        btfsc   STATUS,Z
        goto    S_AMARILLO
        movf    ESTADO,W
        xorlw   ROJO
        btfsc   STATUS,Z
        goto    S_ROJO
S_DESPEJE                               ; todo en rojo 1 s
        movlw   10
        call    ES_HORA
        btfss   STATUS,C
        return
        movlw   VERDE
        goto    CAMBIAR
S_VERDE                                 ; 8 s, o 3 s si hay solicitud peatonal
        movlw   80
        call    ES_HORA
        btfsc   STATUS,C
        goto    A_AMARILLO
        btfss   SOLICITUD,0
        return
        movlw   30
        call    ES_HORA
        btfss   STATUS,C
        return
A_AMARILLO
        movlw   AMARILLO
        goto    CAMBIAR
S_AMARILLO                              ; 2 s
        movlw   20
        call    ES_HORA
        btfss   STATUS,C
        return
        clrf    SOLICITUD
        bcf     PORTB,5
        movlw   ROJO
        goto    CAMBIAR
S_ROJO                                  ; paso peatonal 5 s
        movlw   50
        call    ES_HORA
        btfss   STATUS,C
        return
        movlw   DESPEJE
CAMBIAR movwf   ESTADO
        clrf    TIEMPO
        call    PONER_LUCES
        goto    ANUNCIAR

ES_HORA                                   ; C = 1 si TIEMPO >= W
        subwf   TIEMPO,W
        return

PONER_LUCES                             ; conserva RB5 (espere) y RB7 (latido)
        movf    PORTB,W
        andlw   b'10100000'
        movwf   AUX
        movf    ESTADO,W
        call    LUCES
        iorwf   AUX,W
        movwf   PORTB
        return

ANUNCIAR                                ; "Semaforo: <estado>"
        movlw   HIGH TXT_SEM
        movwf   PTR_H
        movlw   LOW TXT_SEM
        movwf   PTR_L
        call    TX_CADENA
        movf    ESTADO,W
        xorlw   VERDE
        btfsc   STATUS,Z
        goto    AN_V
        movf    ESTADO,W
        xorlw   AMARILLO
        btfsc   STATUS,Z
        goto    AN_A
        movf    ESTADO,W
        xorlw   ROJO
        btfsc   STATUS,Z
        goto    AN_R
        movlw   HIGH TXT_DESP
        movwf   PTR_H
        movlw   LOW TXT_DESP
        goto    AN_TX
AN_V    movlw   HIGH TXT_VERDE
        movwf   PTR_H
        movlw   LOW TXT_VERDE
        goto    AN_TX
AN_A    movlw   HIGH TXT_AMAR
        movwf   PTR_H
        movlw   LOW TXT_AMAR
        goto    AN_TX
AN_R    movlw   HIGH TXT_ROJO
        movwf   PTR_H
        movlw   LOW TXT_ROJO
AN_TX   movwf   PTR_L
        call    TX_CADENA
        goto    TX_CRLF

TXT_HOLA  DT    "PIC16F877A multitarea: P = solicitud peatonal, S = estado",13,10,0
TXT_SEM   DT    "Semaforo: ",0
TXT_VERDE DT    "VERDE",0
TXT_AMAR  DT    "AMARILLO",0
TXT_ROJO  DT    "ROJO (pasa el peaton)",0
TXT_DESP  DT    "TODO EN ROJO",0
TXT_PED   DT    "Solicitud peatonal registrada",13,10,0

;---------------------------------------------------------------------------
; Lectura de tablas DT en la memoria de programa (cadenas terminadas en 0)
;---------------------------------------------------------------------------
        CBLOCK  0x6C
        PTR_H, PTR_L
        ENDC
LEER_TABLA                      ; W = byte de la tabla en PTR_H:PTR_L
        movf    PTR_H,W
        movwf   PCLATH
        movf    PTR_L,W
        movwf   PCL             ; salta a la RETLW, que vuelve a quien llamó a LEER_TABLA

;---------------------------------------------------------------------------
; USART asíncrona a 9600 baudios (cristal de 4 MHz, BRGH = 1, SPBRG = 25)
;   RC6/TX y RC7/RX
;---------------------------------------------------------------------------
        CBLOCK  0x61
        TX_TMP
        ENDC
UART_INIT
        BANKSEL SPBRG
        movlw   25                      ; 4 MHz / (16 x 26) = 9615 baudios (0,16 % de error)
        movwf   SPBRG
        movlw   b'00100100'             ; TXEN = 1, BRGH = 1, asíncrono
        movwf   TXSTA
        BANKSEL RCSTA
        movlw   b'10010000'             ; SPEN = 1, CREN = 1
        movwf   RCSTA
        return
TX_BYTE                                 ; transmite W (espera a que TXREG esté libre)
        btfss   PIR1,TXIF
        goto    TX_BYTE
        movwf   TXREG
        return
TX_CADENA                               ; transmite la cadena PTR_H:PTR_L
        call    LEER_TABLA
        iorlw   0
        btfsc   STATUS,Z
        return
        call    TX_BYTE
        incf    PTR_L,F
        btfsc   STATUS,Z
        incf    PTR_H,F
        goto    TX_CADENA
TX_NUM                                  ; transmite el dígito 0..9 en W
        addlw   '0'
        goto    TX_BYTE
TX_CRLF movlw   13
        call    TX_BYTE
        movlw   10
        goto    TX_BYTE

        END
