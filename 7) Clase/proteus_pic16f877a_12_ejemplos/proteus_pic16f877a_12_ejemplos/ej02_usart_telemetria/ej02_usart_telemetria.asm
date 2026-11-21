;===========================================================================
; Ejemplo 2 · USART: telemetría (el PIC envía mediciones al PC cada 250 ms)
; PIC16F877A · cristal 4 MHz · 9600 baudios, 8N1
;   Potenciómetro en AN0 (RA0) · LM35 en AN1 (RA1) · RB0 = LED de actividad
;   Formato de cada línea:  AN0=0512 V=2.50 T=025.3C
;   (fácil de leer y graficar en Python con pyserial: ver graficar_serie.py)
;===========================================================================
        LIST    P=16F877A, R=DEC
        #include <p16f877a.inc>
        __CONFIG _XT_OSC & _WDT_OFF & _PWRTE_ON & _BOREN_OFF & _LVP_OFF & _CP_OFF

        CBLOCK  0x20
        ADC_H, ADC_L
        ENDC

        ORG     0x000
        goto    INICIO
        ORG     0x005
INICIO
        BANKSEL TRISB
        clrf    TRISB
        movlw   0x84                    ; AN0, AN1 y AN3 analógicos, justificado a la derecha
        movwf   ADCON1
        BANKSEL PORTB
        clrf    PORTB
        call    UART_INIT
        movlw   HIGH TXT_HOLA
        movwf   PTR_H
        movlw   LOW TXT_HOLA
        movwf   PTR_L
        call    TX_CADENA

LAZO    ;----- AN0: código del ADC y voltaje
        movlw   0x41                    ; Fosc/8, canal 0, ADC encendido
        call    LEER_ADC
        movlw   HIGH TXT_AN0
        movwf   PTR_H
        movlw   LOW TXT_AN0
        movwf   PTR_L
        call    TX_CADENA
        movf    ADC_H,W
        movwf   NUM_H
        movf    ADC_L,W
        movwf   NUM_L
        call    BCD16
        movf    DIG3,W
        call    TX_NUM
        movf    DIG2,W
        call    TX_NUM
        movf    DIG1,W
        call    TX_NUM
        movf    DIG0,W
        call    TX_NUM
        call    A_MILIVOLTIOS           ; NUM = ADC x 625 / 128 = mV
        call    BCD16
        movlw   HIGH TXT_V
        movwf   PTR_H
        movlw   LOW TXT_V
        movwf   PTR_L
        call    TX_CADENA
        movf    DIG3,W
        call    TX_NUM
        movlw   '.'
        call    TX_BYTE
        movf    DIG2,W
        call    TX_NUM
        movf    DIG1,W
        call    TX_NUM
        ;----- AN1: LM35 (10 mV/°C: los mV son décimas de grado)
        movlw   0x49                    ; canal 1
        call    LEER_ADC
        call    A_MILIVOLTIOS
        call    BCD16
        movlw   HIGH TXT_T
        movwf   PTR_H
        movlw   LOW TXT_T
        movwf   PTR_L
        call    TX_CADENA
        movf    DIG3,W
        call    TX_NUM
        movf    DIG2,W
        call    TX_NUM
        movf    DIG1,W
        call    TX_NUM
        movlw   '.'
        call    TX_BYTE
        movf    DIG0,W
        call    TX_NUM
        movlw   'C'
        call    TX_BYTE
        call    TX_CRLF
        movlw   1                       ; LED de actividad
        xorwf   PORTB,F
        movlw   200
        call    RETARDO_MS
        goto    LAZO

LEER_ADC                                ; W = ADCON0; resultado en ADC_H:ADC_L
        movwf   ADCON0
        call    RETARDO_50US
        bsf     ADCON0,GO
ESPERA  btfsc   ADCON0,GO
        goto    ESPERA
        movf    ADRESH,W
        movwf   ADC_H
        BANKSEL ADRESL
        movf    ADRESL,W
        BANKSEL PORTB
        movwf   ADC_L
        return

A_MILIVOLTIOS                           ; NUM_H:NUM_L = ADC x 625 >> 7
        movf    ADC_H,W
        movwf   NUM_H
        movf    ADC_L,W
        movwf   NUM_L
        movlw   HIGH 625
        movwf   K_H
        movlw   LOW 625
        movwf   K_L
        call    MUL16
        rlf     P0,F
        rlf     P1,F
        rlf     P2,F
        movf    P2,W
        movwf   NUM_H
        movf    P1,W
        movwf   NUM_L
        return

TXT_HOLA DT     "PIC16F877A telemetria: AN0 (pot) y AN1 (LM35)",13,10,0
TXT_AN0  DT     "AN0=",0
TXT_V    DT     " V=",0
TXT_T    DT     " T=",0

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

;---------------------------------------------------------------------------
; Aritmética de 16 y 24 bits
;---------------------------------------------------------------------------
        CBLOCK  0x50
        NUM_H, NUM_L, K_H, K_L, TMP_L, CNT
        DIG4, DIG3, DIG2, DIG1, DIG0
        P2, P1, P0, X2, X1, X0
        ENDC
BCD16                           ; NUM_H:NUM_L (0..65535) -> DIG4..DIG0 (decenas de mil .. unidades)
        movlw   HIGH 10000
        movwf   K_H
        movlw   LOW 10000
        movwf   K_L
        call    CONTAR
        movwf   DIG4
        movlw   HIGH 1000
        movwf   K_H
        movlw   LOW 1000
        movwf   K_L
        call    CONTAR
        movwf   DIG3
        clrf    K_H
        movlw   100
        movwf   K_L
        call    CONTAR
        movwf   DIG2
        movlw   10
        movwf   K_L
        call    CONTAR
        movwf   DIG1
        movf    NUM_L,W
        movwf   DIG0
        return
CONTAR                          ; W = cuántas veces cabe K en NUM (y se lo resta)
        clrf    CNT
CT1     movf    K_L,W
        subwf   NUM_L,W         ; W = NUM_L - K_L   (C = 0 si hubo préstamo)
        movwf   TMP_L
        movf    K_H,W
        btfss   STATUS,C
        addlw   1               ; el préstamo se suma al byte alto que se resta
        subwf   NUM_H,W
        btfss   STATUS,C
        goto    CT2             ; ya no cabe
        movwf   NUM_H
        movf    TMP_L,W
        movwf   NUM_L
        incf    CNT,F
        goto    CT1
CT2     movf    CNT,W
        return

MUL16                           ; P2:P1:P0 = NUM_H:NUM_L x K_H:K_L  (resultado menor que 2^24)
        clrf    P0
        clrf    P1
        clrf    P2
        clrf    X2
        movf    NUM_H,W
        movwf   X1
        movf    NUM_L,W
        movwf   X0
        movlw   16
        movwf   CNT
ML1     bcf     STATUS,C
        rrf     K_H,F
        rrf     K_L,F           ; bit menos significativo de K en C
        btfss   STATUS,C
        goto    ML2
        movf    X0,W            ; P = P + X (24 bits)
        addwf   P0,F
        movf    X1,W
        btfsc   STATUS,C
        incfsz  X1,W
        addwf   P1,F
        movf    X2,W
        btfsc   STATUS,C
        incfsz  X2,W
        addwf   P2,F
ML2     bcf     STATUS,C        ; X = X * 2
        rlf     X0,F
        rlf     X1,F
        rlf     X2,F
        decfsz  CNT,F
        goto    ML1
        return

        END
