;===========================================================================
; Ejemplo 4 · I2C: reloj de tiempo real DS1307 (dirección 0x68 → 0xD0 / 0xD1) en LCD 16x2
; PIC16F877A · cristal 4 MHz · I2C a 100 kHz
;   SCL = RC3, SDA = RC4 con pull-ups de 4,7 kΩ · DS1307 con cristal de 32,768 kHz y batería de 3 V
;   SOUT/SQW del DS1307: onda de 1 Hz (pull-up de 4,7 kΩ y LED) · RB0 = suma un minuto
;   LCD: RS = RD0, E = RD1, D4..D7 = RD4..RD7
;===========================================================================
        LIST    P=16F877A, R=DEC
        #include <p16f877a.inc>
        __CONFIG _XT_OSC & _WDT_OFF & _PWRTE_ON & _BOREN_OFF & _LVP_OFF & _CP_OFF

        CBLOCK  0x20
        SEG, MIN, HORA, DIA, FECHA, MES, ANO, AUX
        ENDC
DS_W    EQU     0xD0
DS_R    EQU     0xD1

        ORG     0x000
        goto    INICIO
        ORG     0x005
INICIO
        BANKSEL OPTION_REG
        bcf     OPTION_REG,NOT_RBPU
        BANKSEL PORTB
        call    LCD_INIT
        call    I2C_INIT
        movlw   0x80
        call    LCD_CMD
        movlw   HIGH TXT_HORA
        movwf   PTR_H
        movlw   LOW TXT_HORA
        movwf   PTR_L
        call    LCD_CADENA
        movlw   0xC0
        call    LCD_CMD
        movlw   HIGH TXT_FECHA
        movwf   PTR_H
        movlw   LOW TXT_FECHA
        movwf   PTR_L
        call    LCD_CADENA
        ;----- si el oscilador está detenido (CH = 1), pone la hora inicial
        call    I2C_START
        movlw   DS_W
        call    I2C_ESCRIBIR
        movlw   0x00                    ; registro 0: segundos
        call    I2C_ESCRIBIR
        call    I2C_RESTART
        movlw   DS_R
        call    I2C_ESCRIBIR
        call    I2C_LEER_NACK
        movwf   AUX
        call    I2C_STOP
        btfsc   AUX,7
        call    PONER_HORA
        ;----- salida SQW de 1 Hz (registro de control 0x07 = 0x10)
        call    I2C_START
        movlw   DS_W
        call    I2C_ESCRIBIR
        movlw   0x07
        call    I2C_ESCRIBIR
        movlw   0x10
        call    I2C_ESCRIBIR
        call    I2C_STOP

LAZO    call    LEER_RELOJ
        call    MOSTRAR
        btfsc   PORTB,0                 ; RB0: suma un minuto
        goto    PAUSA
        call    SUMAR_MINUTO
SOLTAR  btfss   PORTB,0
        goto    SOLTAR
PAUSA   movlw   200
        call    RETARDO_MS
        goto    LAZO

PONER_HORA                              ; 12:00:00, jueves 19/11/26 (en BCD)
        call    I2C_START
        movlw   DS_W
        call    I2C_ESCRIBIR
        movlw   0x00
        call    I2C_ESCRIBIR
        movlw   0x00                    ; segundos (CH = 0: el reloj arranca)
        call    I2C_ESCRIBIR
        movlw   0x00                    ; minutos
        call    I2C_ESCRIBIR
        movlw   0x12                    ; horas (formato de 24 h)
        call    I2C_ESCRIBIR
        movlw   0x05                    ; día de la semana
        call    I2C_ESCRIBIR
        movlw   0x19                    ; fecha
        call    I2C_ESCRIBIR
        movlw   0x11                    ; mes
        call    I2C_ESCRIBIR
        movlw   0x26                    ; año
        call    I2C_ESCRIBIR
        goto    I2C_STOP

LEER_RELOJ                              ; lectura secuencial de los registros 0 a 6
        call    I2C_START
        movlw   DS_W
        call    I2C_ESCRIBIR
        movlw   0x00
        call    I2C_ESCRIBIR
        call    I2C_RESTART
        movlw   DS_R
        call    I2C_ESCRIBIR
        call    I2C_LEER_ACK
        andlw   0x7F
        movwf   SEG
        call    I2C_LEER_ACK
        movwf   MIN
        call    I2C_LEER_ACK
        andlw   0x3F
        movwf   HORA
        call    I2C_LEER_ACK
        movwf   DIA
        call    I2C_LEER_ACK
        movwf   FECHA
        call    I2C_LEER_ACK
        movwf   MES
        call    I2C_LEER_NACK           ; último byte: NACK
        movwf   ANO
        goto    I2C_STOP

SUMAR_MINUTO                            ; MIN = MIN + 1 en BCD (59 → 00) y se escribe
        incf    MIN,F
        movf    MIN,W
        andlw   0x0F
        xorlw   0x0A
        btfss   STATUS,Z
        goto    SM1
        movlw   6                       ; ajuste decimal: x9 + 1 = (x+1)0
        addwf   MIN,F
SM1     movf    MIN,W
        xorlw   0x60
        btfsc   STATUS,Z
        clrf    MIN
        call    I2C_START
        movlw   DS_W
        call    I2C_ESCRIBIR
        movlw   0x01
        call    I2C_ESCRIBIR
        movf    MIN,W
        call    I2C_ESCRIBIR
        goto    I2C_STOP

MOSTRAR movlw   0x87
        call    LCD_CMD
        movf    HORA,W
        call    LCD_BCD
        movlw   ':'
        call    LCD_DATO
        movf    MIN,W
        call    LCD_BCD
        movlw   ':'
        call    LCD_DATO
        movf    SEG,W
        call    LCD_BCD
        movlw   0xC7
        call    LCD_CMD
        movf    FECHA,W
        call    LCD_BCD
        movlw   '/'
        call    LCD_DATO
        movf    MES,W
        call    LCD_BCD
        movlw   '/'
        call    LCD_DATO
        movf    ANO,W
        goto    LCD_BCD

LCD_BCD                                 ; escribe los dos dígitos del byte BCD en W
        movwf   AUX
        swapf   AUX,W
        andlw   0x0F
        call    LCD_NUM
        movf    AUX,W
        andlw   0x0F
        goto    LCD_NUM

TXT_HORA  DT    "Hora:",0
TXT_FECHA DT    "Fecha:",0

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
; LCD 16x2 (HD44780 / LM016L) en modo de 4 bits sobre PORTD
;   RS = RD0, E = RD1, D4..D7 = RD4..RD7, RW a tierra
;---------------------------------------------------------------------------
        CBLOCK  0x6A
        LCD_TMP, LCD_DAT
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

;---------------------------------------------------------------------------
; I2C maestro con el MSSP a 100 kHz (cristal de 4 MHz): SCL = RC3, SDA = RC4
;   Resistencias de pull-up de 4,7 kΩ a +5 V en SCL y SDA
;---------------------------------------------------------------------------
I2C_INIT
        BANKSEL TRISC
        bsf     TRISC,3                 ; SCL y SDA como entradas: el MSSP los maneja
        bsf     TRISC,4
        movlw   9                       ; SSPADD = Fosc / (4 x 100 kHz) - 1
        movwf   SSPADD
        movlw   b'10000000'             ; SMP = 1 (velocidad estándar)
        movwf   SSPSTAT
        clrf    SSPCON2
        BANKSEL SSPCON
        movlw   b'00101000'             ; SSPEN = 1, modo I2C maestro
        movwf   SSPCON
        return
I2C_ESPERA                              ; espera a que termine la operación (SSPIF = 1)
        btfss   PIR1,SSPIF
        goto    I2C_ESPERA
        bcf     PIR1,SSPIF
        return
I2C_START
        BANKSEL SSPCON2
        bsf     SSPCON2,SEN
        BANKSEL PIR1
        goto    I2C_ESPERA
I2C_RESTART
        BANKSEL SSPCON2
        bsf     SSPCON2,RSEN
        BANKSEL PIR1
        goto    I2C_ESPERA
I2C_STOP
        BANKSEL SSPCON2
        bsf     SSPCON2,PEN
        BANKSEL PIR1
        goto    I2C_ESPERA
I2C_ESCRIBIR                            ; envía W; al volver, ACKSTAT (SSPCON2,6) = 0 si el esclavo respondió
        movwf   SSPBUF
        goto    I2C_ESPERA
I2C_LEER_ACK                            ; W = byte leído y responde ACK (habrá más bytes)
        BANKSEL SSPCON2
        bcf     SSPCON2,ACKDT
        goto    I2C_LEER
I2C_LEER_NACK                           ; W = byte leído y responde NACK (último byte)
        BANKSEL SSPCON2
        bsf     SSPCON2,ACKDT
I2C_LEER
        bsf     SSPCON2,RCEN
        BANKSEL PIR1
        call    I2C_ESPERA
        BANKSEL SSPCON2
        bsf     SSPCON2,ACKEN
        BANKSEL PIR1
        call    I2C_ESPERA
        movf    SSPBUF,W
        return

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
