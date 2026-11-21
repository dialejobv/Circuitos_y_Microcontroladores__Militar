;===========================================================================
; Ejemplo 10 · Interrupciones: reloj HH:MM:SS con TMR1 y ajuste por INT
; PIC16F877A · cristal 4 MHz
;   TMR1 con preescalador 1:8 y precarga 65536 - 62500 → interrumpe cada 0,5 s
;   RB0/INT: suma un minuto · RB1 (leído en el lazo): suma una hora · RC0: LED de segundos
;   LCD: RS = RD0, E = RD1, D4..D7 = RD4..RD7
;===========================================================================
        LIST    P=16F877A, R=DEC
        #include <p16f877a.inc>
        __CONFIG _XT_OSC & _WDT_OFF & _PWRTE_ON & _BOREN_OFF & _LVP_OFF & _CP_OFF

        CBLOCK  0x20
        HH, MM, SS, MEDIO, NUEVO, DEC, ANTES
        ENDC
        CBLOCK  0x70
        W_TEMP, S_TEMP, P_TEMP
        ENDC
PRECARGA EQU    65536 - 62500           ; 62500 x 8 µs = 0,5 s

        ORG     0x000
        goto    INICIO

        ORG     0x004                   ;================= ISR
        movwf   W_TEMP
        swapf   STATUS,W
        clrf    STATUS
        movwf   S_TEMP
        movf    PCLATH,W
        movwf   P_TEMP
        clrf    PCLATH
        btfss   PIR1,TMR1IF
        goto    ISR_INT
        bcf     PIR1,TMR1IF
        bcf     T1CON,TMR1ON            ; recarga el temporizador
        movlw   HIGH PRECARGA
        movwf   TMR1H
        movlw   LOW PRECARGA
        movwf   TMR1L
        bsf     T1CON,TMR1ON
        movlw   1
        xorwf   PORTC,F                 ; LED que cambia cada 0,5 s
        incf    MEDIO,F
        btfss   MEDIO,1                 ; dos medios segundos = 1 s
        goto    ISR_INT
        clrf    MEDIO
        call    SUMAR_SEG
        bsf     NUEVO,0
ISR_INT btfss   INTCON,INTF
        goto    FIN_ISR
        bcf     INTCON,INTF
        call    SUMAR_MIN
        bsf     NUEVO,0
FIN_ISR movf    P_TEMP,W
        movwf   PCLATH
        swapf   S_TEMP,W
        movwf   STATUS
        swapf   W_TEMP,F
        swapf   W_TEMP,W
        retfie

SUMAR_SEG                               ; SS, MM, HH en binario
        incf    SS,F
        movlw   60
        subwf   SS,W
        btfss   STATUS,C
        return
        clrf    SS
SUMAR_MIN
        incf    MM,F
        movlw   60
        subwf   MM,W
        btfss   STATUS,C
        return
        clrf    MM
SUMAR_HORA
        incf    HH,F
        movlw   24
        subwf   HH,W
        btfsc   STATUS,C
        clrf    HH
        return

INICIO
        BANKSEL TRISC
        bcf     TRISC,0
        movlw   b'00000000'             ; pull-ups, INT en flanco de bajada
        movwf   OPTION_REG
        bsf     PIE1,TMR1IE
        BANKSEL PORTC
        clrf    PORTC
        movlw   12
        movwf   HH
        clrf    MM
        clrf    SS
        clrf    MEDIO
        movlw   1
        movwf   ANTES
        call    LCD_INIT
        movlw   0x80
        call    LCD_CMD
        movlw   HIGH TXT_T
        movwf   PTR_H
        movlw   LOW TXT_T
        movwf   PTR_L
        call    LCD_CADENA
        movlw   HIGH PRECARGA
        movwf   TMR1H
        movlw   LOW PRECARGA
        movwf   TMR1L
        movlw   b'00110001'             ; TMR1: 1:8, reloj interno, encendido
        movwf   T1CON
        movlw   b'11010000'             ; GIE, PEIE, INTE
        movwf   INTCON
        bsf     NUEVO,0

LAZO    btfsc   PORTB,1                 ; RB1: suma una hora (por sondeo, con flanco)
        goto    RB1_SUELTO
        btfss   ANTES,0
        goto    MOSTRAR
        clrf    ANTES
        bcf     INTCON,GIE
        call    SUMAR_HORA
        bsf     INTCON,GIE
        bsf     NUEVO,0
        goto    MOSTRAR
RB1_SUELTO
        bsf     ANTES,0
MOSTRAR btfss   NUEVO,0
        goto    LAZO
        bcf     NUEVO,0
        movlw   0xC4
        call    LCD_CMD
        movf    HH,W
        call    LCD_2DIG
        movlw   ':'
        call    LCD_DATO
        movf    MM,W
        call    LCD_2DIG
        movlw   ':'
        call    LCD_DATO
        movf    SS,W
        call    LCD_2DIG
        goto    LAZO

LCD_2DIG                                ; W (0..99) en dos dígitos
        clrf    DEC
        movwf   NUM_L
D2      movlw   10
        subwf   NUM_L,W
        btfss   STATUS,C
        goto    D3
        movwf   NUM_L
        incf    DEC,F
        goto    D2
D3      movf    DEC,W
        call    LCD_NUM
        movf    NUM_L,W
        goto    LCD_NUM

TXT_T   DT      "Reloj con TMR1",0

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
