;===========================================================================
; Ejemplo 6 · SPI: display de 8 dígitos con MAX7219
; PIC16F877A · cristal 4 MHz · SPI maestro a 1 MHz
;   RC5/SDO → DIN (1) · RC3/SCK → CLK (13) · RC0 → LOAD/CS (12)
;   DIG0..DIG7 y SEG A..G, DP del MAX7219 → display 7SEG-MPX8-CC · RSET de 10 kΩ a +5 V
;   Izquierda: segundos desde el encendido (0000-9999) · derecha: lectura del ADC en AN0 (0000-1023)
;===========================================================================
        LIST    P=16F877A, R=DEC
        #include <p16f877a.inc>
        __CONFIG _XT_OSC & _WDT_OFF & _PWRTE_ON & _BOREN_OFF & _LVP_OFF & _CP_OFF

        CBLOCK  0x20
        REG, DATO_MAX, DIEZ, SEG_H, SEG_L
        ENDC

        ORG     0x000
        goto    INICIO
        ORG     0x005
INICIO
        BANKSEL TRISC
        bcf     TRISC,0                 ; RC0 = LOAD
        movlw   0x8E                    ; AN0 analógico, justificado a la derecha (10 bits)
        movwf   ADCON1
        BANKSEL PORTC
        bsf     PORTC,0
        movlw   0x41
        movwf   ADCON0
        call    SPI_INIT
        movlw   0x0F                    ; prueba de display: no
        movwf   REG
        movlw   0x00
        call    MAX_ESCRIBIR
        movlw   0x09                    ; decodificación BCD en los 8 dígitos
        movwf   REG
        movlw   0xFF
        call    MAX_ESCRIBIR
        movlw   0x0A                    ; brillo 8/15
        movwf   REG
        movlw   0x08
        call    MAX_ESCRIBIR
        movlw   0x0B                    ; mostrar los dígitos 0 a 7
        movwf   REG
        movlw   0x07
        call    MAX_ESCRIBIR
        movlw   0x0C                    ; salir del modo de apagado
        movwf   REG
        movlw   0x01
        call    MAX_ESCRIBIR
        clrf    SEG_H
        clrf    SEG_L
        movlw   10
        movwf   DIEZ

LAZO    ;----- segundos en los dígitos 7..4 (izquierda)
        movf    SEG_H,W
        movwf   NUM_H
        movf    SEG_L,W
        movwf   NUM_L
        call    BCD16
        movlw   8
        call    ENVIAR_4
        ;----- ADC en los dígitos 3..0 (derecha)
        call    RETARDO_50US
        bsf     ADCON0,GO
ESPERA  btfsc   ADCON0,GO
        goto    ESPERA
        movf    ADRESH,W
        movwf   NUM_H
        BANKSEL ADRESL
        movf    ADRESL,W
        BANKSEL PORTC
        movwf   NUM_L
        call    BCD16
        movlw   4
        call    ENVIAR_4
        movlw   100                     ; 10 vueltas de 100 ms = 1 s
        call    RETARDO_MS
        decfsz  DIEZ,F
        goto    LAZO
        movlw   10
        movwf   DIEZ
        incf    SEG_L,F
        btfsc   STATUS,Z
        incf    SEG_H,F
        goto    LAZO

ENVIAR_4                                ; W = registro del dígito más significativo (8 o 4); DIG3..DIG0
        movwf   REG
        movf    DIG3,W
        call    MAX_ESCRIBIR
        decf    REG,F
        movf    DIG2,W
        call    MAX_ESCRIBIR
        decf    REG,F
        movf    DIG1,W
        call    MAX_ESCRIBIR
        decf    REG,F
        movlw   0x80                    ; el último dígito de cada grupo lleva punto
        iorwf   DIG0,W
        goto    MAX_ESCRIBIR

MAX_ESCRIBIR                            ; REG ← W (16 bits: dirección y dato; LOAD sube al final)
        movwf   DATO_MAX
        bcf     PORTC,0
        movf    REG,W
        call    SPI_TX
        movf    DATO_MAX,W
        call    SPI_TX
        bsf     PORTC,0                 ; flanco de subida en LOAD: el MAX7219 guarda el dato
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
