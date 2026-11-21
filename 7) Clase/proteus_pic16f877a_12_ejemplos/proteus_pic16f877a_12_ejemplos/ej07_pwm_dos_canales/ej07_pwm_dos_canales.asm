;===========================================================================
; Ejemplo 7 · PWM: dos canales de 10 bits (CCP1 y CCP2) a 1 kHz controlados por potenciómetros
; PIC16F877A · cristal 4 MHz
;   Pot 1 en AN0 → PWM en RC2/CCP1 · Pot 2 en AN1 → PWM en RC1/CCP2 · cada salida: 330 Ω + LED (y osciloscopio)
;   Periodo = (PR2 + 1) · 4 · Tosc · preescalador = 250 · 4 · 0,25 µs · 4 = 1 ms
;   LCD: RS = RD0, E = RD1, D4..D7 = RD4..RD7 muestra el ciclo útil de cada canal
;===========================================================================
        LIST    P=16F877A, R=DEC
        #include <p16f877a.inc>
        __CONFIG _XT_OSC & _WDT_OFF & _PWRTE_ON & _BOREN_OFF & _LVP_OFF & _CP_OFF

        CBLOCK  0x20
        ADC_H, ADC_L, AUX
        ENDC

        ORG     0x000
        goto    INICIO
        ORG     0x005
INICIO
        BANKSEL TRISC
        bcf     TRISC,1                 ; RC1/CCP2 y RC2/CCP1 salidas
        bcf     TRISC,2
        movlw   249                     ; PR2 = 249 → 1 kHz con preescalador 4
        movwf   PR2
        movlw   0x84                    ; AN0, AN1 analógicos, justificado a la derecha
        movwf   ADCON1
        BANKSEL PORTC
        clrf    CCPR1L
        clrf    CCPR2L
        movlw   0x0C                    ; CCP1 y CCP2 en modo PWM
        movwf   CCP1CON
        movwf   CCP2CON
        movlw   b'00000101'             ; TMR2 encendido, preescalador 1:4
        movwf   T2CON
        call    LCD_INIT
        movlw   0x80
        call    LCD_CMD
        movlw   HIGH TXT_P1
        movwf   PTR_H
        movlw   LOW TXT_P1
        movwf   PTR_L
        call    LCD_CADENA
        movlw   0xC0
        call    LCD_CMD
        movlw   HIGH TXT_P2
        movwf   PTR_H
        movlw   LOW TXT_P2
        movwf   PTR_L
        call    LCD_CADENA

LAZO    ;----- canal 1
        movlw   0x41
        call    LEER_ADC
        call    LIMITAR                 ; 0..1000 (1000 = 100 % con PR2 = 249)
        movf    AUX,W                   ; 2 bits bajos → CCP1CON<5:4>
        iorlw   0x0C
        movwf   CCP1CON
        movf    ADC_L,W                 ; 8 bits altos → CCPR1L
        movwf   CCPR1L
        movlw   0x86
        call    MOSTRAR_PCT
        ;----- canal 2
        movlw   0x49
        call    LEER_ADC
        call    LIMITAR
        movf    AUX,W
        iorlw   0x0C
        movwf   CCP2CON
        movf    ADC_L,W
        movwf   CCPR2L
        movlw   0xC6
        call    MOSTRAR_PCT
        movlw   50
        call    RETARDO_MS
        goto    LAZO

LEER_ADC                                ; W = ADCON0; resultado de 10 bits en ADC_H:ADC_L
        movwf   ADCON0
        call    RETARDO_50US
        bsf     ADCON0,GO
ESPERA  btfsc   ADCON0,GO
        goto    ESPERA
        movf    ADRESH,W
        movwf   ADC_H
        BANKSEL ADRESL
        movf    ADRESL,W
        BANKSEL PORTC
        movwf   ADC_L
        return

LIMITAR                                 ; ADC (10 bits) → ciclo útil D; deja D>>2 en ADC_L y (D & 3) << 4 en AUX
        movf    ADC_H,W                 ; si ADC > 1000 (0x3E8) usa 1000
        movwf   NUM_H
        movf    ADC_L,W
        movwf   NUM_L
        movlw   LOW 1001
        subwf   ADC_L,W
        movlw   HIGH 1001
        btfss   STATUS,C
        addlw   1
        subwf   ADC_H,W
        btfss   STATUS,C
        goto    LIM1
        movlw   HIGH 1000
        movwf   ADC_H
        movwf   NUM_H
        movlw   LOW 1000
        movwf   ADC_L
        movwf   NUM_L
LIM1    swapf   ADC_L,W                 ; AUX = (D & 3) << 4
        andlw   0x30
        movwf   AUX
        rrf     ADC_H,F                 ; D >> 2
        rrf     ADC_L,F
        rrf     ADC_H,F
        rrf     ADC_L,F
        return

MOSTRAR_PCT                             ; W = posición; escribe D / 10 en % (D ya está en NUM)
        call    LCD_CMD
        clrf    K_H
        movlw   10
        movwf   K_L
        call    CONTAR                  ; NUM / 10 = porcentaje (0..100)
        clrf    NUM_H
        movwf   NUM_L
        call    BCD16
        movf    DIG2,W
        btfsc   STATUS,Z
        movlw   ' ' - '0'
        call    LCD_NUM
        movf    DIG2,W
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
        goto    LCD_DATO

TXT_P1  DT      "PWM1:      1 kHz",0
TXT_P2  DT      "PWM2:      RC1",0

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
