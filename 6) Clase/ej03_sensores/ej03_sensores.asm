;===========================================================================
; Ejemplo 3 · Sensores: temperatura (LM35 en AN0) y luz (LDR en AN1) en LCD 16x2
; PIC16F877A · cristal 4 MHz
;   LM35: 10 mV/°C -> AN0 (RA0).  LDR entre +5 V y AN1 (RA1), 10 kΩ de AN1 a tierra.
;   RB0 = ventilador (se enciende si T > 30,0 °C) · RB1 = lámpara (se enciende si luz < 30 %)
;   LCD: RS = RD0, E = RD1, D4..D7 = RD4..RD7
;===========================================================================
        LIST    P=16F877A, R=DEC
        #include <p16f877a.inc>
        __CONFIG _XT_OSC & _WDT_OFF & _PWRTE_ON & _BOREN_OFF & _LVP_OFF & _CP_OFF

        CBLOCK  0x20
        ADC_H, ADC_L, T_H, T_L, LUZ
        ENDC

        ORG     0x000
        goto    INICIO
        ORG     0x005
INICIO
        BANKSEL TRISB
        clrf    TRISB                   ; PORTB salidas (actuadores)
        movlw   0x84                    ; justificado a la derecha, AN0, AN1 y AN3 analógicos
        movwf   ADCON1
        BANKSEL PORTB
        clrf    PORTB
        call    LCD_INIT
        movlw   0x80
        call    LCD_CMD
        movlw   HIGH TXT_T
        movwf   PTR_H
        movlw   LOW TXT_T
        movwf   PTR_L
        call    LCD_CADENA
        movlw   0xC0
        call    LCD_CMD
        movlw   HIGH TXT_L
        movwf   PTR_H
        movlw   LOW TXT_L
        movwf   PTR_L
        call    LCD_CADENA

LAZO
        ;----- temperatura: décimas de °C = ADC x 625 / 128  (ADC x 4,883 mV / 10 mV/°C x 10)
        movlw   0x41                    ; Fosc/8, canal 0, ADC encendido
        call    LEER_ADC
        movf    ADC_H,W
        movwf   NUM_H
        movf    ADC_L,W
        movwf   NUM_L
        movlw   HIGH 625
        movwf   K_H
        movlw   LOW 625
        movwf   K_L
        call    MUL16                   ; P2:P1:P0 = ADC x 625
        rlf     P0,F                    ; (P << 1) >> 8 = P >> 7
        rlf     P1,F
        rlf     P2,F
        movf    P2,W
        movwf   T_H
        movwf   NUM_H
        movf    P1,W
        movwf   T_L
        movwf   NUM_L
        call    BCD16
        movlw   0x86                    ; línea 1, columna 6: " 25.3°C"
        call    LCD_CMD
        movf    DIG3,W                  ; centenas (espacio si es 0)
        btfsc   STATUS,Z
        movlw   ' ' - '0'
        call    LCD_NUM
        movf    DIG2,W
        call    LCD_NUM
        movf    DIG1,W
        call    LCD_NUM
        movlw   '.'
        call    LCD_DATO
        movf    DIG0,W
        call    LCD_NUM
        movlw   0xDF                    ; símbolo de grado en la LCD
        call    LCD_DATO
        movlw   'C'
        call    LCD_DATO
        ; ventilador: T > 300 décimas  <=>  T - 301 >= 0
        movlw   LOW 301
        subwf   T_L,W
        movlw   HIGH 301
        btfss   STATUS,C
        addlw   1
        subwf   T_H,W
        btfsc   STATUS,C
        bsf     PORTB,0
        btfss   STATUS,C
        bcf     PORTB,0

        ;----- luz: porcentaje = ADC x 25 / 256  (0..99 %)
        movlw   0x49                    ; Fosc/8, canal 1, ADC encendido
        call    LEER_ADC
        movf    ADC_H,W
        movwf   NUM_H
        movf    ADC_L,W
        movwf   NUM_L
        clrf    K_H
        movlw   25
        movwf   K_L
        call    MUL16
        movf    P1,W                    ; P >> 8 (cabe en un byte)
        movwf   LUZ
        clrf    NUM_H
        movwf   NUM_L
        call    BCD16
        movlw   0xC7
        call    LCD_CMD
        movf    DIG2,W                  ; centenas (espacio si es 0)
        btfsc   STATUS,Z
        movlw   ' ' - '0'
        call    LCD_NUM
        movf    DIG2,W                  ; decenas (espacio si centenas y decenas son 0)
        iorwf   DIG1,W
        btfsc   STATUS,Z
        goto    SIN_DEC
        movf    DIG1,W
        goto    CON_DEC
SIN_DEC movlw   ' ' - '0'
CON_DEC call    LCD_NUM
        movf    DIG0,W
        call    LCD_NUM
        movlw   '%'
        call    LCD_DATO
        movlw   30                      ; lámpara: luz < 30 %
        subwf   LUZ,W
        btfss   STATUS,C
        bsf     PORTB,1
        btfsc   STATUS,C
        bcf     PORTB,1

        movlw   250
        call    RETARDO_MS
        goto    LAZO

LEER_ADC                                ; W = ADCON0; deja el resultado de 10 bits en ADC_H:ADC_L
        movwf   ADCON0
        call    RETARDO_50US            ; tiempo de adquisición (> 20 µs)
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

TXT_T   DT      "Temp:",0
TXT_L   DT      "Luz:",0

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
