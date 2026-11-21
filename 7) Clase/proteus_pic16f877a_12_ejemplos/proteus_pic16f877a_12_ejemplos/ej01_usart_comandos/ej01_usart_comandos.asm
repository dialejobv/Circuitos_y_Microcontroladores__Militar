;===========================================================================
; Ejemplo 1 · USART: terminal de comandos con interrupción de recepción
; PIC16F877A · cristal 4 MHz · 9600 baudios, 8N1
;   RC6/TX y RC7/RX al VIRTUAL TERMINAL (o a un conversor USB-serie)
;   RB0..RB7: 8 LED
;   Comandos: 1..8 invierte el LED · A enciende todos · B apaga todos · ? informa el estado
;===========================================================================
        LIST    P=16F877A, R=DEC
        #include <p16f877a.inc>
        __CONFIG _XT_OSC & _WDT_OFF & _PWRTE_ON & _BOREN_OFF & _LVP_OFF & _CP_OFF

        CBLOCK  0x20
        DATO, LLEGO, MASCARA, AUX, I
        ENDC
        CBLOCK  0x70                    ; RAM común a los cuatro bancos
        W_TEMP, S_TEMP, P_TEMP
        ENDC

        ORG     0x000
        goto    INICIO

        ORG     0x004                   ;---------- rutina de interrupción (ISR)
        movwf   W_TEMP                  ; guarda W, STATUS y PCLATH
        swapf   STATUS,W
        clrf    STATUS
        movwf   S_TEMP
        movf    PCLATH,W
        movwf   P_TEMP
        clrf    PCLATH
        btfss   PIR1,RCIF               ; ¿llegó un carácter?
        goto    FIN_ISR
        movf    RCREG,W                 ; leer RCREG limpia RCIF
        movwf   DATO
        bsf     LLEGO,0                 ; avisa al programa principal
FIN_ISR movf    P_TEMP,W
        movwf   PCLATH
        swapf   S_TEMP,W
        movwf   STATUS
        swapf   W_TEMP,F
        swapf   W_TEMP,W
        retfie

INICIO
        BANKSEL TRISB
        clrf    TRISB
        BANKSEL PORTB
        clrf    PORTB
        clrf    LLEGO
        call    UART_INIT
        BANKSEL PIE1
        bsf     PIE1,RCIE               ; interrupción de recepción
        BANKSEL PORTB
        movlw   b'11000000'             ; GIE y PEIE
        movwf   INTCON
        movlw   HIGH TXT_MENU
        movwf   PTR_H
        movlw   LOW TXT_MENU
        movwf   PTR_L
        call    TX_CADENA

LAZO    btfss   RCSTA,OERR              ; desbordamiento: reinicia el receptor
        goto    LAZO1
        bcf     RCSTA,CREN
        bsf     RCSTA,CREN
LAZO1   btfss   LLEGO,0                 ; espera un comando
        goto    LAZO
        bcf     LLEGO,0
        movf    DATO,W
        xorlw   '?'
        btfsc   STATUS,Z
        goto    INFORMAR
        movf    DATO,W
        andlw   0xDF                    ; minúscula -> mayúscula
        xorlw   'A'
        btfsc   STATUS,Z
        goto    TODOS
        movf    DATO,W
        andlw   0xDF
        xorlw   'B'
        btfsc   STATUS,Z
        goto    NINGUNO
        movlw   '1'                     ; ¿es un dígito '1'..'8'?
        subwf   DATO,W
        btfss   STATUS,C
        goto    LAZO
        movwf   AUX                     ; AUX = DATO - '1' (0..7)
        movlw   8
        subwf   AUX,W
        btfsc   STATUS,C
        goto    LAZO
        movlw   1                       ; MASCARA = 1 << AUX
        movwf   MASCARA
DESPL   movf    AUX,F
        btfsc   STATUS,Z
        goto    INVERTIR
        bcf     STATUS,C
        rlf     MASCARA,F
        decf    AUX,F
        goto    DESPL
INVERTIR
        movf    MASCARA,W
        xorwf   PORTB,F
        goto    INFORMAR
TODOS   movlw   0xFF
        movwf   PORTB
        goto    INFORMAR
NINGUNO clrf    PORTB

INFORMAR                                ; envía "LEDS = b7..b0"
        movlw   HIGH TXT_LEDS
        movwf   PTR_H
        movlw   LOW TXT_LEDS
        movwf   PTR_L
        call    TX_CADENA
        movf    PORTB,W
        movwf   AUX
        movlw   8
        movwf   I
INF1    rlf     AUX,F                   ; el bit 7 pasa a C
        movlw   '0'
        btfsc   STATUS,C
        movlw   '1'
        call    TX_BYTE
        decfsz  I,F
        goto    INF1
        call    TX_CRLF
        goto    LAZO

TXT_MENU DT     "PIC16F877A - USART 9600 8N1",13,10
         DT     "1-8: invierte un LED  A: todos  B: ninguno  ?: estado",13,10,0
TXT_LEDS DT     "LEDS = ",0

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
