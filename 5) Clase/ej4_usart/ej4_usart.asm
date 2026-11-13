;=====================================================================
; Ejemplo 4 · USART a 9600 baudios: mensaje de bienvenida y eco
; PIC16F877A · 4 MHz · SPBRG = 25 con BRGH = 1 → 9615 baudios (0,16 %)
; TX = RC6, RX = RC7 · el último carácter recibido se ve en PORTB
;=====================================================================
        LIST    p=16F877A
        #include <p16f877a.inc>
        __CONFIG 0x3F31

        CBLOCK  0x20
        indice
        ENDC

        ORG     0x0000
        goto    inicio

;--- mensaje terminado en 0 -------------------------------------------
mensaje addwf   PCL,F
        DT      "PIC16F877A listo", 0x0D, 0x0A, 0

inicio  banksel TRISC
        bcf     TRISC,6         ; TX salida
        bsf     TRISC,7         ; RX entrada
        clrf    TRISB
        movlw   d'25'
        movwf   SPBRG           ; 4 MHz / (16 · 26) = 9615 baudios
        movlw   b'00100100'     ; TXEN = 1, BRGH = 1, asíncrono
        movwf   TXSTA
        banksel RCSTA
        movlw   b'10010000'     ; SPEN = 1, CREN = 1
        movwf   RCSTA
        clrf    PORTB

        clrf    indice
enviar  movf    indice,W
        call    mensaje
        iorlw   0               ; ¿fin del texto?
        btfsc   STATUS,Z
        goto    eco
        call    tx
        incf    indice,F
        goto    enviar

eco     btfss   PIR1,RCIF       ; espera un carácter
        goto    eco
        movf    RCREG,W
        movwf   PORTB           ; lo muestra en los LEDs
        call    tx              ; y lo devuelve
        goto    eco

tx      btfss   PIR1,TXIF       ; espera que TXREG esté libre
        goto    tx
        movwf   TXREG
        return

        END
