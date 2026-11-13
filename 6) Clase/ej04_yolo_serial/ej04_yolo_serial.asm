;===========================================================================
; Ejemplo 4 · Integración con YOLO por puerto serie (USART 9600 baudios, 8N1)
; PIC16F877A · cristal 4 MHz
;   Un programa en Python con YOLO detecta el objeto y envía una letra:
;     'C' = carro -> LED verde (RB0)   'M' = moto -> LED rojo (RB1)
;     'P' = persona -> LED amarillo (RB2)   'N' = nada -> apaga los LED
;   El PIC muestra el objeto en la LCD y responde "OK:x" (x = letra recibida).
;   RC6/TX y RC7/RX al conversor USB-serie (o COMPIM / VIRTUAL TERMINAL en Proteus)
;   LCD: RS = RD0, E = RD1, D4..D7 = RD4..RD7
;===========================================================================
        LIST    P=16F877A, R=DEC
        #include <p16f877a.inc>
        __CONFIG _XT_OSC & _WDT_OFF & _PWRTE_ON & _BOREN_OFF & _LVP_OFF & _CP_OFF

        CBLOCK  0x20
        DATO, TOTAL
        ENDC

        ORG     0x000
        goto    INICIO
        ORG     0x005
INICIO
        BANKSEL TRISB
        clrf    TRISB
        movlw   25                      ; 9600 baudios con BRGH = 1: 4 MHz / (16 x 26) = 9615
        movwf   SPBRG
        movlw   0x24                    ; TXEN = 1, BRGH = 1, asíncrono
        movwf   TXSTA
        BANKSEL RCSTA
        movlw   0x90                    ; SPEN = 1, CREN = 1
        movwf   RCSTA
        clrf    PORTB
        clrf    TOTAL
        call    LCD_INIT
        movlw   0x80
        call    LCD_CMD
        movlw   HIGH TXT_TIT
        movwf   PTR_H
        movlw   LOW TXT_TIT
        movwf   PTR_L
        call    LCD_CADENA
        movlw   HIGH TXT_ESP
        call    LINEA2
        movlw   HIGH TXT_LISTO
        movwf   PTR_H
        movlw   LOW TXT_LISTO
        movwf   PTR_L
        call    TX_CADENA

LAZO    btfsc   RCSTA,OERR              ; si hubo desbordamiento, reinicia el receptor
        call    LIMPIAR_OERR
        btfss   PIR1,RCIF               ; ¿llegó un carácter?
        goto    LAZO
        movf    RCREG,W
        andlw   0xDF                    ; minúscula -> mayúscula
        movwf   DATO
        xorlw   'C'
        btfsc   STATUS,Z
        goto    CARRO
        movf    DATO,W
        xorlw   'M'
        btfsc   STATUS,Z
        goto    MOTO
        movf    DATO,W
        xorlw   'P'
        btfsc   STATUS,Z
        goto    PERSONA
        movf    DATO,W
        xorlw   'N'
        btfsc   STATUS,Z
        goto    NADA
        goto    LAZO                    ; cualquier otro carácter (\r, \n...) se ignora

CARRO   movlw   b'00000001'             ; verde
        movwf   PORTB
        movlw   HIGH TXT_CARRO
        movwf   PTR_H
        movlw   LOW TXT_CARRO
        goto    RESPONDER
MOTO    movlw   b'00000010'             ; rojo
        movwf   PORTB
        movlw   HIGH TXT_MOTO
        movwf   PTR_H
        movlw   LOW TXT_MOTO
        goto    RESPONDER
PERSONA movlw   b'00000100'             ; amarillo
        movwf   PORTB
        movlw   HIGH TXT_PERS
        movwf   PTR_H
        movlw   LOW TXT_PERS
        goto    RESPONDER
NADA    clrf    PORTB
        movlw   HIGH TXT_NADA
        movwf   PTR_H
        movlw   LOW TXT_NADA

RESPONDER
        movwf   PTR_L
        movlw   0xC0
        call    LCD_CMD
        call    LCD_CADENA
        incf    TOTAL,F
        movlw   'O'
        call    TX_BYTE
        movlw   'K'
        call    TX_BYTE
        movlw   ':'
        call    TX_BYTE
        movf    DATO,W
        call    TX_BYTE
        movlw   13
        call    TX_BYTE
        movlw   10
        call    TX_BYTE
        goto    LAZO

LINEA2  movwf   PTR_H                   ; escribe la cadena TXT_ESP en la línea 2
        movlw   LOW TXT_ESP
        movwf   PTR_L
        movlw   0xC0
        call    LCD_CMD
        goto    LCD_CADENA

LIMPIAR_OERR
        bcf     RCSTA,CREN
        bsf     RCSTA,CREN
        return

TX_BYTE                                 ; transmite W cuando el buffer está libre
        btfss   PIR1,TXIF
        goto    TX_BYTE
        movwf   TXREG
        return

TX_CADENA                               ; transmite la cadena de PTR_H:PTR_L
        call    LEER_TABLA
        iorlw   0
        btfsc   STATUS,Z
        return
        call    TX_BYTE
        incf    PTR_L,F
        btfsc   STATUS,Z
        incf    PTR_H,F
        goto    TX_CADENA

TXT_TIT   DT    "YOLO + PIC16F877",0
TXT_ESP   DT    "Esperando...    ",0
TXT_CARRO DT    "Objeto: CARRO   ",0
TXT_MOTO  DT    "Objeto: MOTO    ",0
TXT_PERS  DT    "Objeto: PERSONA ",0
TXT_NADA  DT    "Objeto: ninguno ",0
TXT_LISTO DT    "PIC listo: envie C, M, P o N",13,10,0

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
; LCD 16x2 (HD44780 / LM016L) en modo de 4 bits sobre PORTD
;   RS = RD0, E = RD1, D4..D7 = RD4..RD7, RW a tierra
;---------------------------------------------------------------------------
        CBLOCK  0x6A
        LCD_TMP, LCD_DAT, PTR_H, PTR_L
        ENDC
LCD_INIT
        BANKSEL TRISD
        clrf    TRISD
        BANKSEL PORTD
        clrf    PORTD
        movlw   20
        call    RETARDO_MS      ; más de 15 ms después del encendido
        movlw   0x30
        call    LCD_NIB
        movlw   5
        call    RETARDO_MS
        movlw   0x30
        call    LCD_NIB
        call    RETARDO_50US
        call    RETARDO_50US
        movlw   0x30
        call    LCD_NIB
        call    RETARDO_50US
        movlw   0x20            ; pasa a modo de 4 bits
        call    LCD_NIB
        call    RETARDO_50US
        movlw   0x28            ; 4 bits, 2 líneas, caracteres de 5x8
        call    LCD_CMD
        movlw   0x0C            ; display encendido, sin cursor
        call    LCD_CMD
        movlw   0x06            ; la dirección aumenta después de cada carácter
        call    LCD_CMD
        movlw   0x01            ; borrar pantalla
        goto    LCD_CMD

LCD_CMD                         ; envía el comando que está en W
        bcf     PORTD,0         ; RS = 0
        goto    LCD_BYTE
LCD_NUM                         ; escribe el dígito 0..9 que está en W
        addlw   '0'
LCD_DATO                        ; escribe el carácter que está en W
        bsf     PORTD,0         ; RS = 1
LCD_BYTE
        movwf   LCD_DAT
        call    LCD_NIB         ; nibble alto
        swapf   LCD_DAT,W
        call    LCD_NIB         ; nibble bajo
        call    RETARDO_50US
        btfsc   PORTD,0         ; datos: listo
        return
        movlw   3               ; borrar (1) e inicio (2) tardan 1,52 ms
        subwf   LCD_DAT,W
        btfsc   STATUS,C
        return
        movlw   2
        goto    RETARDO_MS

LCD_NIB                         ; pone W<7:4> en D7..D4 y da un pulso en E
        andlw   0xF0
        movwf   LCD_TMP
        movf    PORTD,W
        andlw   0x0F
        iorwf   LCD_TMP,W
        movwf   PORTD
        bsf     PORTD,1         ; E = 1
        nop
        bcf     PORTD,1         ; E = 0: la LCD lee el dato en el flanco de bajada
        return

LCD_CADENA                      ; escribe la cadena (DT "...",0) que empieza en PTR_H:PTR_L
        call    LEER_TABLA
        iorlw   0
        btfsc   STATUS,Z
        return
        call    LCD_DATO
        incf    PTR_L,F
        btfsc   STATUS,Z
        incf    PTR_H,F
        goto    LCD_CADENA

LEER_TABLA                      ; W = byte de la tabla en PTR_H:PTR_L
        movf    PTR_H,W
        movwf   PCLATH
        movf    PTR_L,W
        movwf   PCL             ; salta a la RETLW, que vuelve a quien llamó a LEER_TABLA

        END
