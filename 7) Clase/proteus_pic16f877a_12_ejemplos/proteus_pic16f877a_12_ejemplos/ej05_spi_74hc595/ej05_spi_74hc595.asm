;===========================================================================
; Ejemplo 5 · SPI: 8 LED con un registro de desplazamiento 74HC595
; PIC16F877A · cristal 4 MHz · SPI maestro a 1 MHz
;   RC5/SDO → DS (14) · RC3/SCK → SH_CP (11) · RC0 → ST_CP (12, latch)
;   OE (13) a tierra · MR (10) a +5 V · Q0..Q7 → 330 Ω → LED → tierra
;   RB0 = cambia de modo: contador binario ↔ barra con el potenciómetro de AN0
;===========================================================================
        LIST    P=16F877A, R=DEC
        #include <p16f877a.inc>
        __CONFIG _XT_OSC & _WDT_OFF & _PWRTE_ON & _BOREN_OFF & _LVP_OFF & _CP_OFF

        CBLOCK  0x20
        MODO, CUENTA, ANTES, DATO
        ENDC

        ORG     0x000
        goto    INICIO
        ORG     0x005
BARRA                                   ; 0..8 LED encendidos
        addwf   PCL,F
        DT      0x00,0x01,0x03,0x07,0x0F,0x1F,0x3F,0x7F,0xFF

INICIO
        BANKSEL OPTION_REG
        bcf     OPTION_REG,NOT_RBPU
        bcf     TRISC,0                 ; RC0 = latch del 74HC595
        movlw   0x0E                    ; AN0 analógico, justificado a la izquierda
        movwf   ADCON1
        BANKSEL PORTC
        bsf     PORTC,0
        movlw   0x41
        movwf   ADCON0
        call    SPI_INIT
        clrf    MODO
        clrf    CUENTA
        movlw   1
        movwf   ANTES

LAZO    btfsc   PORTB,0                 ; flanco de bajada en RB0: cambia de modo
        goto    SUELTO
        btfss   ANTES,0
        goto    CALCULAR
        clrf    ANTES
        movlw   1
        xorwf   MODO,F
        goto    CALCULAR
SUELTO  bsf     ANTES,0
CALCULAR
        btfsc   MODO,0
        goto    MODO_BARRA
        incf    CUENTA,F
        movf    CUENTA,W
        goto    MOSTRAR
MODO_BARRA
        call    RETARDO_50US
        bsf     ADCON0,GO
ESPERA  btfsc   ADCON0,GO
        goto    ESPERA
        movf    ADRESH,W                ; LED encendidos = (ADRESH + 16) / 32  →  0..8
        addlw   16
        btfsc   STATUS,C
        goto    LLENO
        movwf   DATO
        swapf   DATO,W
        andlw   0x0F
        movwf   DATO
        bcf     STATUS,C
        rrf     DATO,W
        call    BARRA
        goto    MOSTRAR
LLENO   movlw   8
        call    BARRA
MOSTRAR call    HC595_ENVIAR
        movlw   150
        call    RETARDO_MS
        goto    LAZO

HC595_ENVIAR                            ; W → Q7..Q0
        bcf     PORTC,0                 ; ST_CP en 0
        call    SPI_TX                  ; 8 bits por SDO con reloj en SCK
        bsf     PORTC,0                 ; flanco de subida: las salidas toman el dato
        return

;---------------------------------------------------------------------------
; SPI maestro con el MSSP: SCK = RC3, SDO = RC5 (SDI = RC4 no se usa)
;   Modo 0: el dato cambia en el flanco de bajada y se lee en el de subida
;---------------------------------------------------------------------------
SPI_INIT
        BANKSEL TRISC
        bcf     TRISC,3                 ; SCK salida
        bcf     TRISC,5                 ; SDO salida
        movlw   b'01000000'             ; CKE = 1
        movwf   SSPSTAT
        BANKSEL SSPCON
        movlw   b'00100000'             ; SSPEN = 1, SPI maestro a Fosc/4 (1 MHz)
        movwf   SSPCON
        return
SPI_TX                                  ; envía W y espera a que termine
        movwf   SSPBUF
SPI1    btfss   PIR1,SSPIF
        goto    SPI1
        bcf     PIR1,SSPIF
        movf    SSPBUF,W                ; leer SSPBUF limpia BF
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
