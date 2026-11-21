;===========================================================================
; Ejemplo 9 · Interrupciones: cuatro fuentes atendidas por una sola ISR
; PIC16F877A · cristal 4 MHz
;   INT (RB0, flanco de bajada): cuenta pulsaciones
;   Cambio en RB4..RB7 (RBIF): indica qué tecla se presionó
;   TMR0 (cada 65,5 ms): inicia una conversión del ADC y hace parpadear el LED de RC0
;   ADC terminado (ADIF): guarda la lectura de AN0
;   LCD: RS = RD0, E = RD1, D4..D7 = RD4..RD7
;   El orden en que la ISR revisa las banderas define la prioridad: INT, RB, ADC, TMR0
;===========================================================================
        LIST    P=16F877A, R=DEC
        #include <p16f877a.inc>
        __CONFIG _XT_OSC & _WDT_OFF & _PWRTE_ON & _BOREN_OFF & _LVP_OFF & _CP_OFF

        CBLOCK  0x20
        PULSOS, TECLA, ADC_H, ADC_L, T0CNT, CAMBIO, AUX
        ENDC
        CBLOCK  0x70
        W_TEMP, S_TEMP, P_TEMP
        ENDC

        ORG     0x000
        goto    INICIO

        ORG     0x004                   ;================= ISR
        movwf   W_TEMP
        swapf   STATUS,W
        clrf    STATUS                  ; banco 0
        movwf   S_TEMP
        movf    PCLATH,W
        movwf   P_TEMP
        clrf    PCLATH
        ;----- 1) INT: pulsador en RB0
        btfss   INTCON,INTE
        goto    ISR_RB
        btfss   INTCON,INTF
        goto    ISR_RB
        bcf     INTCON,INTF
        incf    PULSOS,F
        bsf     CAMBIO,0
        ;----- 2) cambio en RB4..RB7
ISR_RB  btfss   INTCON,RBIF
        goto    ISR_AD
        movf    PORTB,W                 ; leer PORTB termina la condición de cambio
        movwf   AUX
        bcf     INTCON,RBIF
        movlw   4
        btfss   AUX,4
        movwf   TECLA
        movlw   5
        btfss   AUX,5
        movwf   TECLA
        movlw   6
        btfss   AUX,6
        movwf   TECLA
        movlw   7
        btfss   AUX,7
        movwf   TECLA
        bsf     CAMBIO,0
        ;----- 3) fin de conversión del ADC
ISR_AD  btfss   PIR1,ADIF
        goto    ISR_T0
        bcf     PIR1,ADIF
        movf    ADRESH,W
        movwf   ADC_H
        BANKSEL ADRESL
        movf    ADRESL,W
        BANKSEL PIR1
        movwf   ADC_L
        bsf     CAMBIO,0
        ;----- 4) desbordamiento de TMR0
ISR_T0  btfss   INTCON,T0IF
        goto    FIN_ISR
        bcf     INTCON,T0IF
        bsf     ADCON0,GO               ; nueva conversión (la adquisición ya pasó)
        incf    T0CNT,F
        movlw   4                       ; 4 x 65,5 ms ≈ 262 ms
        subwf   T0CNT,W
        btfss   STATUS,C
        goto    FIN_ISR
        clrf    T0CNT
        movlw   1
        xorwf   PORTC,F                 ; LED de latido
FIN_ISR movf    P_TEMP,W
        movwf   PCLATH
        swapf   S_TEMP,W
        movwf   STATUS
        swapf   W_TEMP,F
        swapf   W_TEMP,W
        retfie

INICIO
        BANKSEL TRISC
        bcf     TRISC,0
        movlw   b'00000111'             ; pull-ups, INT en bajada, TMR0 interno con preescalador 1:256
        movwf   OPTION_REG
        movlw   0x8E                    ; AN0 analógico, justificado a la derecha
        movwf   ADCON1
        bsf     PIE1,ADIE               ; interrupción del ADC
        BANKSEL PORTC
        clrf    PORTC
        clrf    PULSOS
        clrf    TECLA
        clrf    ADC_H
        clrf    ADC_L
        clrf    T0CNT
        movlw   0x41
        movwf   ADCON0
        call    LCD_INIT
        movf    PORTB,W                 ; referencia para el cambio en RB4..RB7
        bcf     INTCON,RBIF
        movlw   b'11111000'             ; GIE, PEIE, T0IE, INTE, RBIE
        movwf   INTCON
        movlw   1
        movwf   CAMBIO

LAZO    btfss   CAMBIO,0                ; el programa principal solo muestra
        goto    LAZO
        bcf     CAMBIO,0
        movlw   0x80
        call    LCD_CMD
        movlw   HIGH TXT_L1
        movwf   PTR_H
        movlw   LOW TXT_L1
        movwf   PTR_L
        call    LCD_CADENA
        clrf    NUM_H
        movf    PULSOS,W
        movwf   NUM_L
        call    BCD16
        movf    DIG2,W
        call    LCD_NUM
        movf    DIG1,W
        call    LCD_NUM
        movf    DIG0,W
        call    LCD_NUM
        movlw   HIGH TXT_TEC
        movwf   PTR_H
        movlw   LOW TXT_TEC
        movwf   PTR_L
        call    LCD_CADENA
        movf    TECLA,W
        btfsc   STATUS,Z
        movlw   '-' - '0'
        call    LCD_NUM
        movlw   0xC0
        call    LCD_CMD
        movlw   HIGH TXT_L2
        movwf   PTR_H
        movlw   LOW TXT_L2
        movwf   PTR_L
        call    LCD_CADENA
        bcf     INTCON,GIE              ; copia atómica de los 16 bits del ADC
        movf    ADC_H,W
        movwf   NUM_H
        movf    ADC_L,W
        movwf   NUM_L
        bsf     INTCON,GIE
        call    BCD16
        movf    DIG3,W
        call    LCD_NUM
        movf    DIG2,W
        call    LCD_NUM
        movf    DIG1,W
        call    LCD_NUM
        movf    DIG0,W
        call    LCD_NUM
        goto    LAZO

TXT_L1  DT      "INT=",0
TXT_TEC DT      "  RB=",0
TXT_L2  DT      "ADC=",0

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
