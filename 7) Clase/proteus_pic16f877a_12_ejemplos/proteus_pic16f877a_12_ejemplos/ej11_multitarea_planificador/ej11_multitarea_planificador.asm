;===========================================================================
; Ejemplo 11 · Multitarea cooperativa: planificador con un tick de 10 ms (TMR0 + ISR)
; PIC16F877A · cristal 4 MHz
;   La ISR de TMR0 cuenta milisegundos; cada 10 ms suma un "tick". El lazo principal reparte
;   los ticks entre 5 tareas cortas que nunca esperan (no hay retardos bloqueantes):
;     LED1 (RC0) cada 250 ms · LED2 (RC1) cada 400 ms · botón RB0 cada 20 ms (cuenta pulsaciones)
;     ADC (AN0) → PWM en RC2/CCP1 cada 50 ms · LCD cada 500 ms
;   LCD: RS = RD0, E = RD1, D4..D7 = RD4..RD7
;===========================================================================
        LIST    P=16F877A, R=DEC
        #include <p16f877a.inc>
        __CONFIG _XT_OSC & _WDT_OFF & _PWRTE_ON & _BOREN_OFF & _LVP_OFF & _CP_OFF

        CBLOCK  0x20
        TICKS, MS10, C_LED1, C_LED2, C_BOT, C_ADC, C_LCD
        PULSOS, ANTES, POT
        ENDC
        CBLOCK  0x70
        W_TEMP, S_TEMP
        ENDC

        ORG     0x000
        goto    INICIO

        ORG     0x004                   ;================= ISR: base de tiempo
        movwf   W_TEMP
        swapf   STATUS,W
        clrf    STATUS
        movwf   S_TEMP
        bcf     INTCON,T0IF
        movlw   6                       ; 250 cuentas x 4 µs = 1 ms
        addwf   TMR0,F
        incf    MS10,F
        movlw   10
        subwf   MS10,W
        btfss   STATUS,C
        goto    FIN_ISR
        clrf    MS10
        incf    TICKS,F                 ; un tick más de 10 ms pendiente
FIN_ISR swapf   S_TEMP,W
        movwf   STATUS
        swapf   W_TEMP,F
        swapf   W_TEMP,W
        retfie

INICIO
        BANKSEL TRISC
        movlw   b'11111000'             ; RC0, RC1, RC2 salidas
        movwf   TRISC
        movlw   b'00000001'             ; pull-ups, TMR0 interno, preescalador 1:4
        movwf   OPTION_REG
        movlw   0x0E                    ; AN0 analógico, justificado a la izquierda
        movwf   ADCON1
        movlw   255
        movwf   PR2
        BANKSEL PORTC
        clrf    PORTC
        movlw   0x0C
        movwf   CCP1CON
        movlw   0x04
        movwf   T2CON
        movlw   0x41
        movwf   ADCON0
        call    LCD_INIT
        movlw   0x80
        call    LCD_CMD
        movlw   HIGH TXT_L1
        movwf   PTR_H
        movlw   LOW TXT_L1
        movwf   PTR_L
        call    LCD_CADENA
        movlw   0xC0
        call    LCD_CMD
        movlw   HIGH TXT_L2
        movwf   PTR_H
        movlw   LOW TXT_L2
        movwf   PTR_L
        call    LCD_CADENA
        clrf    TICKS
        clrf    MS10
        clrf    PULSOS
        clrf    POT
        movlw   1
        movwf   ANTES
        movwf   C_LED1
        movwf   C_LED2
        movwf   C_BOT
        movwf   C_ADC
        movwf   C_LCD
        bsf     ADCON0,GO
        movlw   b'10100000'             ; GIE, T0IE
        movwf   INTCON

;================= planificador
LAZO    movf    TICKS,W                 ; espera un tick de 10 ms
        btfsc   STATUS,Z
        goto    LAZO
        decf    TICKS,F
        decfsz  C_LED1,F
        goto    T2
        movlw   25                      ; 25 x 10 ms = 250 ms
        movwf   C_LED1
        call    TAREA_LED1
T2      decfsz  C_LED2,F
        goto    T3
        movlw   40                      ; 400 ms
        movwf   C_LED2
        call    TAREA_LED2
T3      decfsz  C_BOT,F
        goto    T4
        movlw   2                       ; 20 ms
        movwf   C_BOT
        call    TAREA_BOTON
T4      decfsz  C_ADC,F
        goto    T5
        movlw   5                       ; 50 ms
        movwf   C_ADC
        call    TAREA_ADC
T5      decfsz  C_LCD,F
        goto    LAZO
        movlw   50                      ; 500 ms
        movwf   C_LCD
        call    TAREA_LCD
        goto    LAZO

;================= tareas (cortas y sin esperas)
TAREA_LED1
        movlw   b'00000001'
        xorwf   PORTC,F
        return
TAREA_LED2
        movlw   b'00000010'
        xorwf   PORTC,F
        return
TAREA_BOTON                             ; cuenta flancos de bajada de RB0 (el muestreo cada 20 ms filtra rebotes)
        btfsc   PORTB,0
        goto    SUELTO
        btfss   ANTES,0
        return
        clrf    ANTES
        incf    PULSOS,F
        return
SUELTO  bsf     ANTES,0
        return
TAREA_ADC                               ; lee el resultado anterior e inicia la siguiente conversión
        btfsc   ADCON0,GO
        return
        movf    ADRESH,W
        movwf   POT
        movwf   CCPR1L                  ; brillo del LED de RC2
        bsf     ADCON0,GO
        return
TAREA_LCD
        movlw   0x88
        call    LCD_CMD
        clrf    NUM_H
        movf    PULSOS,W
        movwf   NUM_L
        call    BCD16
        call    TRES_DIG
        movlw   0xC8
        call    LCD_CMD
        clrf    NUM_H
        movf    POT,W
        movwf   NUM_L
        call    BCD16
        goto    TRES_DIG
TRES_DIG
        movf    DIG2,W
        call    LCD_NUM
        movf    DIG1,W
        call    LCD_NUM
        movf    DIG0,W
        goto    LCD_NUM

TXT_L1  DT      "Pulsos:",0
TXT_L2  DT      "PWM   :",0

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
