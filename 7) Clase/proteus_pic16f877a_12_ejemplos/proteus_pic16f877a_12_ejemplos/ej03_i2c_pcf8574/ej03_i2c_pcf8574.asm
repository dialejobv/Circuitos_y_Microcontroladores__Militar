;===========================================================================
; Ejemplo 3 · I2C: 8 LED en un expansor PCF8574 (dirección 0x20 → 0x40 para escribir)
; PIC16F877A · cristal 4 MHz · I2C a 100 kHz
;   SCL = RC3, SDA = RC4 con pull-ups de 4,7 kΩ · A0, A1, A2 del PCF8574 a tierra
;   LED: +5 V → 330 Ω → LED → P0..P7 (el PCF8574 enciende el LED con un 0)
;   RB0 = cambia el efecto (barrido, contador, alternado) · RC0 = LED de error (el esclavo no responde)
;===========================================================================
        LIST    P=16F877A, R=DEC
        #include <p16f877a.inc>
        __CONFIG _XT_OSC & _WDT_OFF & _PWRTE_ON & _BOREN_OFF & _LVP_OFF & _CP_OFF

        CBLOCK  0x20
        MODO, PATRON, DIR, CUENTA, ANTES
        ENDC
PCF_ESCRIBIR EQU 0x40                   ; 0100 A2 A1 A0 R/W

        ORG     0x000
        goto    INICIO
        ORG     0x005
INICIO
        BANKSEL OPTION_REG
        bcf     OPTION_REG,NOT_RBPU     ; pull-up de RB0
        bcf     TRISC,0                 ; LED de error
        BANKSEL PORTC
        bcf     PORTC,0
        call    I2C_INIT
        clrf    MODO
        clrf    CUENTA
        clrf    DIR
        movlw   1
        movwf   PATRON
        movlw   1
        movwf   ANTES

LAZO    call    ENVIAR
        call    SIGUIENTE
        btfsc   PORTB,0                 ; ¿se presionó RB0? (flanco de bajada)
        goto    SUELTO
        btfss   ANTES,0
        goto    ESPERAR
        clrf    ANTES
        incf    MODO,F                  ; siguiente efecto (0, 1, 2)
        movlw   3
        xorwf   MODO,W
        btfsc   STATUS,Z
        clrf    MODO
        movlw   1
        movwf   PATRON
        goto    ESPERAR
SUELTO  bsf     ANTES,0
ESPERAR movlw   120
        call    RETARDO_MS
        goto    LAZO

ENVIAR                                  ; START · 0x40 · ~PATRON · STOP
        call    I2C_START
        movlw   PCF_ESCRIBIR
        call    I2C_ESCRIBIR
        BANKSEL SSPCON2
        btfsc   SSPCON2,ACKSTAT         ; ACKSTAT = 1: nadie respondió
        goto    SIN_ACK
        BANKSEL PORTC
        bcf     PORTC,0
        comf    PATRON,W                ; el LED enciende con 0
        call    I2C_ESCRIBIR
        goto    I2C_STOP
SIN_ACK BANKSEL PORTC
        bsf     PORTC,0
        goto    I2C_STOP

SIGUIENTE                               ; calcula el próximo patrón según MODO
        movf    MODO,W
        btfsc   STATUS,Z
        goto    BARRIDO
        xorlw   1
        btfsc   STATUS,Z
        goto    CONTADOR
        movlw   0x55                    ; alternado 01010101 / 10101010
        xorwf   PATRON,W
        btfsc   STATUS,Z
        goto    ALT2
        movlw   0x55
        movwf   PATRON
        return
ALT2    movlw   0xAA
        movwf   PATRON
        return
CONTADOR
        incf    CUENTA,F
        movf    CUENTA,W
        movwf   PATRON
        return
BARRIDO                                 ; una luz que va y vuelve
        btfsc   DIR,0
        goto    BAR_DER
        bcf     STATUS,C
        rlf     PATRON,F
        btfsc   PATRON,7
        bsf     DIR,0
        movf    PATRON,F
        btfsc   STATUS,Z
        bsf     PATRON,0
        return
BAR_DER bcf     STATUS,C
        rrf     PATRON,F
        btfsc   PATRON,0
        bcf     DIR,0
        movf    PATRON,F
        btfsc   STATUS,Z
        bsf     PATRON,0
        return

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
