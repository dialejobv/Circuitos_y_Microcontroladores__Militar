;===========================================================================
; Ejemplo 5 · Cerradura electrónica con teclado matricial 4x4 y LCD 16x2
; PIC16F877A · cristal 4 MHz
;   Teclado (KEYPAD-SMALLCALC): filas A..D = RB0..RB3 (salidas), columnas 1..4 = RB4..RB7 (entradas, pull-up interno)
;       7 8 9 /
;       4 5 6 x
;       1 2 3 -
;       C 0 = +      C = borrar, = = confirmar.   Clave: 1234
;   RC0 = LED verde, RC1 = LED rojo, RC2 = relé de la cerradura
;   LCD: RS = RD0, E = RD1, D4..D7 = RD4..RD7
;===========================================================================
        LIST    P=16F877A, R=DEC
        #include <p16f877a.inc>
        __CONFIG _XT_OSC & _WDT_OFF & _PWRTE_ON & _BOREN_OFF & _LVP_OFF & _CP_OFF

        CBLOCK  0x20
        TECLA, FILA, COL, MASCARA, AUX, N, INTENTOS, VECES
        CLAVE:4                         ; dígitos escritos
        ENDC

        ORG     0x000
        goto    INICIO
        ORG     0x005
INICIO
        BANKSEL OPTION_REG
        bcf     OPTION_REG,NOT_RBPU     ; pull-ups en las columnas
        movlw   0xF0                    ; RB0-RB3 salidas (filas), RB4-RB7 entradas (columnas)
        movwf   TRISB
        movlw   0xF8                    ; RC0-RC2 salidas
        movwf   TRISC
        BANKSEL PORTC
        clrf    PORTC
        clrf    INTENTOS
        call    LCD_INIT

NUEVA   clrf    PORTC
        clrf    N
        movlw   0x01
        call    LCD_CMD
        movlw   HIGH TXT_CLAVE
        movwf   PTR_H
        movlw   LOW TXT_CLAVE
        movwf   PTR_L
        call    LCD_CADENA
        movlw   0xC0
        call    LCD_CMD
        movlw   '>'
        call    LCD_DATO
        movlw   ' '
        call    LCD_DATO

LAZO    call    ESCANEAR                ; W = carácter de la tecla o 0
        iorlw   0
        btfsc   STATUS,Z
        goto    LAZO
        movwf   TECLA
        movlw   20
        call    RETARDO_MS
SOLTAR  call    ESCANEAR                ; espera a que se suelte la tecla
        iorlw   0
        btfss   STATUS,Z
        goto    SOLTAR
        movlw   20
        call    RETARDO_MS

        movf    TECLA,W
        xorlw   'C'
        btfsc   STATUS,Z
        goto    NUEVA                   ; borrar
        movf    TECLA,W
        xorlw   '='
        btfsc   STATUS,Z
        goto    VERIFICAR
        movlw   '0'                     ; ¿es un dígito '0'..'9'?
        subwf   TECLA,W
        btfss   STATUS,C
        goto    LAZO
        sublw   9
        btfss   STATUS,C
        goto    LAZO
        movlw   4                       ; máximo 4 dígitos
        subwf   N,W
        btfsc   STATUS,C
        goto    LAZO
        movlw   CLAVE                   ; CLAVE[N] = tecla (direccionamiento indirecto)
        addwf   N,W
        movwf   FSR
        movf    TECLA,W
        movwf   INDF
        incf    N,F
        movlw   '*'
        call    LCD_DATO
        goto    LAZO

VERIFICAR
        movlw   4
        xorwf   N,W
        btfss   STATUS,Z
        goto    MAL
        movf    CLAVE+0,W
        xorlw   '1'
        btfss   STATUS,Z
        goto    MAL
        movf    CLAVE+1,W
        xorlw   '2'
        btfss   STATUS,Z
        goto    MAL
        movf    CLAVE+2,W
        xorlw   '3'
        btfss   STATUS,Z
        goto    MAL
        movf    CLAVE+3,W
        xorlw   '4'
        btfss   STATUS,Z
        goto    MAL
BIEN    clrf    INTENTOS
        movlw   b'00000101'             ; LED verde y relé
        movwf   PORTC
        movlw   HIGH TXT_OK
        movwf   PTR_H
        movlw   LOW TXT_OK
        call    MENSAJE
        movlw   12                      ; 3 s abierta
        call    ESPERAR
        goto    NUEVA
MAL     movlw   b'00000010'             ; LED rojo
        movwf   PORTC
        incf    INTENTOS,F
        movlw   3
        subwf   INTENTOS,W
        btfsc   STATUS,C
        goto    BLOQUEO
        movlw   HIGH TXT_MAL
        movwf   PTR_H
        movlw   LOW TXT_MAL
        call    MENSAJE
        movlw   8                       ; 2 s
        call    ESPERAR
        goto    NUEVA
BLOQUEO clrf    INTENTOS
        movlw   HIGH TXT_BLOQ
        movwf   PTR_H
        movlw   LOW TXT_BLOQ
        call    MENSAJE
        movlw   20                      ; 10 s con el LED rojo parpadeando
        movwf   VECES
PARPADEO
        movlw   b'00000010'
        xorwf   PORTC,F
        movlw   2
        call    ESPERAR
        decfsz  VECES,F
        goto    PARPADEO
        goto    NUEVA

MENSAJE                                 ; escribe en la línea 2 la cadena PTR_H:W
        movwf   PTR_L
        movlw   0xC0
        call    LCD_CMD
        goto    LCD_CADENA

ESPERAR                                 ; espera W x 250 ms
        movwf   AUX
ESP1    movlw   250
        call    RETARDO_MS
        decfsz  AUX,F
        goto    ESP1
        return

ESCANEAR                                ; devuelve en W el carácter de la tecla presionada (0 = ninguna)
        clrf    FILA
        movlw   b'11111110'
        movwf   MASCARA
ESC1    movf    MASCARA,W               ; pone en 0 solo la fila que se revisa
        movwf   PORTB
        nop
        nop
        swapf   PORTB,W                 ; columnas en el nibble bajo
        andlw   0x0F
        xorlw   0x0F                    ; columna presionada = bit en 1
        btfss   STATUS,Z
        goto    HAY
        incf    FILA,F
        bsf     STATUS,C
        rlf     MASCARA,F
        movlw   4
        xorwf   FILA,W
        btfss   STATUS,Z
        goto    ESC1
        retlw   0
HAY     movwf   AUX
        clrf    COL
HAY1    rrf     AUX,F                   ; busca el número de la columna
        btfsc   STATUS,C
        goto    HAY2
        incf    COL,F
        goto    HAY1
HAY2    bcf     STATUS,C                ; índice = FILA x 4 + COL
        rlf     FILA,F
        rlf     FILA,W
        addwf   COL,W
        addlw   LOW TECLAS
        movwf   PTR_L
        movlw   HIGH TECLAS
        btfsc   STATUS,C
        addlw   1
        movwf   PTR_H
        goto    LEER_TABLA

TECLAS    DT    "789/456*123-C0=+"
TXT_CLAVE DT    "Ingrese la clave",0
TXT_OK    DT    "ACCESO CONCEDIDO",0
TXT_MAL   DT    "CLAVE INCORRECTA",0
TXT_BLOQ  DT    "BLOQUEADO  10 s ",0

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
