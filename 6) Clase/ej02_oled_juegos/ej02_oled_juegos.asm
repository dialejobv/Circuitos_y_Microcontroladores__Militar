;===========================================================================
; Ejemplo 2 · Tres juegos en una pantalla OLED 128x64 (SSD1306 por SPI) con pulsadores
;             1) PONG   2) CARRERA (esquivar obstáculos)   3) SALTO (dinosaurio)
; PIC16F877A · cristal de 20 MHz (1 ciclo = 0,2 µs)
;   OLED (UG-2864HSWEG01 en Proteus): D0/SCK = RC3, D1/SDA = RC5, CS = RC0, D/C = RC1, RES = RC2
;   Pulsadores a tierra (pull-ups internos): RB0 = ARRIBA, RB1 = ABAJO, RB2 = OK / SALTAR
;===========================================================================
        LIST    P=16F877A, R=DEC
        #include <p16f877a.inc>
        __CONFIG _HS_OSC & _WDT_OFF & _PWRTE_ON & _BOREN_OFF & _LVP_OFF & _CP_OFF

        CBLOCK  0x20
        BTN, PREV, NUEVO, SEL                   ; pulsadores y menú
        PX, PY, N, PAT, AUX, CH, I              ; dibujo
        PTR_H, PTR_L, FP_H, FP_L                ; punteros a cadenas y a la fuente
        R1, R2, R3, RND, SCORE, D100, D10
        BX, BY, DIRX, DIRY, PAD, VIDAS          ; pong
        CAR, NUEVA_P, SPAWN, OX, OP             ; carrera
        OBS:6                                   ; carrera: tres obstáculos (x, página)
        DINO, JUMP, CX, ESPERA                  ; salto
        ENDC

#define CS      PORTC,0
#define DC      PORTC,1
#define RES     PORTC,2

        ORG     0x000
        goto    INICIO
        ORG     0x005

;===================== tablas (cerca del inicio) =====================
TABLA_SALTO                                     ; página del dinosaurio en cada cuadro del salto
        clrf    PCLATH                          ; las tablas están en las direcciones 0x000-0x0FF
        addwf   PCL,F
        DT      4,3,2,2,2,3,4,5
SPR_CARRO
        clrf    PCLATH
        addwf   PCL,F
        DT      0x24,0x5A,0xFF,0xFF,0xFF,0xFF,0x5A,0x24
SPR_ROCA
        clrf    PCLATH
        addwf   PCL,F
        DT      0x1E,0x3F,0x7F,0x7F,0x7F,0x7E,0x3C,0x18
SPR_DINO
        clrf    PCLATH
        addwf   PCL,F
        DT      0x18,0x30,0xE0,0x78,0xFF,0x3D,0x17,0x07
SPR_CACTUS
        clrf    PCLATH
        addwf   PCL,F
        DT      0x1C,0x10,0xFF,0x08,0x0E,0x00

TABLA_INIT                                      ; secuencia de inicio del SSD1306
        clrf    PCLATH
        addwf   PCL,F
        DT      0xAE, 0xD5,0x80, 0xA8,0x3F, 0xD3,0x00, 0x40, 0x8D,0x14, 0x20,0x00
        DT      0xA1, 0xC8, 0xDA,0x12, 0x81,0xCF, 0xD9,0xF1, 0xDB,0x40, 0xA4, 0xA6, 0xAF
FIN_INIT

;===================== inicio =====================
INICIO
        BANKSEL OPTION_REG
        bcf     OPTION_REG,NOT_RBPU             ; pull-ups de PORTB
        movlw   b'11010000'                     ; RC0, RC1, RC2, RC3, RC5 salidas; RC4 (SDI) entrada
        movwf   TRISC
        movlw   b'01000000'                     ; CKE = 1 (dato estable en el flanco de subida)
        movwf   SSPSTAT
        BANKSEL PORTC
        movlw   b'00100000'                     ; SSPEN = 1, SPI maestro, reloj Fosc/4 = 5 MHz
        movwf   SSPCON
        movlw   0xA5
        movwf   RND
        clrf    SEL
        clrf    PREV
        call    OLED_INIT

;===================== menú =====================
MENU    call    BORRAR
        movlw   28
        movwf   PX
        clrf    PY
        movlw   HIGH TXT_TITULO
        movwf   PTR_H
        movlw   LOW TXT_TITULO
        call    TEXTO
        movlw   22
        movwf   PX
        movlw   2
        movwf   PY
        movlw   HIGH TXT_PONG
        movwf   PTR_H
        movlw   LOW TXT_PONG
        call    TEXTO
        movlw   22
        movwf   PX
        movlw   3
        movwf   PY
        movlw   HIGH TXT_CARRERA
        movwf   PTR_H
        movlw   LOW TXT_CARRERA
        call    TEXTO
        movlw   22
        movwf   PX
        movlw   4
        movwf   PY
        movlw   HIGH TXT_SALTO
        movwf   PTR_H
        movlw   LOW TXT_SALTO
        call    TEXTO
        clrf    PX
        movlw   7
        movwf   PY
        movlw   HIGH TXT_AYUDA
        movwf   PTR_H
        movlw   LOW TXT_AYUDA
        call    TEXTO
MENU_LAZO
        call    CURSOR_DIBUJAR
        movlw   30
        call    RET_MS
        call    RANDOM                          ; el azar depende de cuánto tarda el jugador
        call    LEER_BOTONES
        btfsc   NUEVO,0
        goto    MENU_ARRIBA
        btfsc   NUEVO,1
        goto    MENU_ABAJO
        btfss   NUEVO,2
        goto    MENU_LAZO
        movf    SEL,W                           ; OK: inicia el juego elegido
        btfsc   STATUS,Z
        goto    PONG
        xorlw   1
        btfsc   STATUS,Z
        goto    CARRERA
        goto    SALTO
MENU_ARRIBA
        call    CURSOR_BORRAR
        decf    SEL,F
        btfss   SEL,7
        goto    MENU_LAZO
        movlw   2
        movwf   SEL
        goto    MENU_LAZO
MENU_ABAJO
        call    CURSOR_BORRAR
        incf    SEL,F
        movlw   3
        xorwf   SEL,W
        btfsc   STATUS,Z
        clrf    SEL
        goto    MENU_LAZO

CURSOR_DIBUJAR
        movlw   '>'
        goto    CURSOR
CURSOR_BORRAR
        movlw   ' '
CURSOR  movwf   CH
        movlw   12
        movwf   PX
        movf    SEL,W
        addlw   2
        movwf   PY
        call    VENTANA
        movf    CH,W
        goto    CARACTER

;===================== juego 1: PONG =====================
PONG    call    BORRAR
        clrf    SCORE
        movlw   3
        movwf   VIDAS
        movlw   3
        movwf   PAD
        movlw   127                             ; pared derecha
        movwf   PX
        clrf    PY
        call    VENTANA
        movlw   8
        movwf   N
        movlw   0xFF
        call    RELLENAR_COL
PONG_BOLA
        movlw   64
        movwf   BX
        movlw   32
        movwf   BY
        movlw   1
        movwf   DIRX                            ; hacia la izquierda
        call    RANDOM
        andlw   1
        movwf   DIRY
PONG_LAZO
        call    LEER_BOTONES
        btfss   BTN,0                           ; raqueta arriba
        goto    PONG_B1
        movf    PAD,W
        btfss   STATUS,Z
        decf    PAD,F
PONG_B1 btfss   BTN,1                           ; raqueta abajo
        goto    PONG_B2
        movlw   6
        subwf   PAD,W
        btfss   STATUS,C
        incf    PAD,F
PONG_B2 call    BOLA_BORRAR
        ;--- movimiento vertical
        btfsc   DIRY,0
        goto    PONG_SUBE
        movlw   60
        xorwf   BY,W
        btfsc   STATUS,Z
        goto    PONG_REBOTE_Y
        movlw   4
        addwf   BY,F
        goto    PONG_X
PONG_SUBE
        movf    BY,W
        btfsc   STATUS,Z
        goto    PONG_REBOTE_Y
        movlw   4
        subwf   BY,F
        goto    PONG_X
PONG_REBOTE_Y
        movlw   1
        xorwf   DIRY,F
        ;--- movimiento horizontal
PONG_X  btfsc   DIRX,0
        goto    PONG_IZQ
        movlw   120
        xorwf   BX,W
        btfsc   STATUS,Z
        goto    PONG_REBOTE_X
        movlw   4
        addwf   BX,F
        goto    PONG_DIBUJO
PONG_IZQ
        movlw   8                               ; ¿la bola llegó a la raqueta?
        xorwf   BX,W
        btfss   STATUS,Z
        goto    PONG_IZQ2
        rrf     BY,W                            ; página de la bola = BY / 8
        movwf   AUX
        rrf     AUX,F
        rrf     AUX,W
        andlw   7
        movwf   AUX
        movf    PAD,W
        subwf   AUX,W                           ; página - PAD debe ser 0 o 1
        sublw   1
        btfss   STATUS,C
        goto    PONG_IZQ2
        incf    SCORE,F                         ; golpe: un punto
        goto    PONG_REBOTE_X
PONG_IZQ2
        movf    BX,W
        btfsc   STATUS,Z
        goto    PONG_FALLA
        movlw   4
        subwf   BX,F
        goto    PONG_DIBUJO
PONG_REBOTE_X
        movlw   1
        xorwf   DIRX,F
        goto    PONG_DIBUJO
PONG_FALLA
        decfsz  VIDAS,F
        goto    PONG_BOLA
        goto    FIN_JUEGO
PONG_DIBUJO
        call    RAQUETA
        call    BOLA_DIBUJAR
        movlw   25
        call    RET_MS
        goto    PONG_LAZO

RAQUETA                                         ; raqueta de 3x16 px en x = 2..4, páginas PAD y PAD+1
        movlw   2
        movwf   PX
        movf    PAD,W
        btfsc   STATUS,Z
        goto    RAQ1
        movwf   PY
        decf    PY,F
        movlw   0x00                            ; borra la página de arriba
        call    COLUMNA3
RAQ1    movf    PAD,W
        movwf   PY
        movlw   0xFF
        call    COLUMNA3
        incf    PY,F
        movlw   0xFF
        call    COLUMNA3
        incf    PY,F
        btfsc   PY,3                            ; PY = 8: no hay página de abajo
        return
        movlw   0x00
COLUMNA3                                        ; 3 bytes con el patrón W en (PX, PY)
        movwf   PAT
        call    VENTANA
        movlw   3
        movwf   N
        movf    PAT,W
        goto    RELLENAR

BOLA_BORRAR
        clrw
        goto    BOLA
BOLA_DIBUJAR
        movlw   0x0F                            ; mitad superior o inferior de la página
        btfsc   BY,2
        movlw   0xF0
BOLA    movwf   PAT
        movf    BX,W
        movwf   PX
        rrf     BY,W
        movwf   PY
        rrf     PY,F
        rrf     PY,W
        andlw   7
        movwf   PY
        call    VENTANA
        movlw   4
        movwf   N
        movf    PAT,W
        goto    RELLENAR

;===================== juego 2: CARRERA =====================
CARRERA call    BORRAR
        clrf    SCORE
        call    MARCADOR_TEXTO
        movlw   4
        movwf   CAR
        clrf    OBS+1                           ; página 0 = obstáculo inactivo
        clrf    OBS+3
        clrf    OBS+5
        movlw   1
        movwf   SPAWN
CAR_LAZO
        call    LEER_BOTONES
        movf    CAR,W
        movwf   NUEVA_P
        btfss   NUEVO,0
        goto    CAR_B1
        movlw   1
        xorwf   CAR,W
        btfss   STATUS,Z
        decf    NUEVA_P,F
CAR_B1  btfss   NUEVO,1
        goto    CAR_B2
        movlw   7
        xorwf   CAR,W
        btfss   STATUS,Z
        incf    NUEVA_P,F
CAR_B2  movf    CAR,W                           ; si cambió de carril, borra el carro
        xorwf   NUEVA_P,W
        btfsc   STATUS,Z
        goto    CAR_OBS
        movlw   4
        movwf   PX
        movf    CAR,W
        movwf   PY
        call    VENTANA
        movlw   8
        movwf   N
        clrw
        call    RELLENAR
        movf    NUEVA_P,W
        movwf   CAR
CAR_OBS movlw   OBS                             ; mueve los tres obstáculos
        call    OBSTACULO
        movlw   OBS+2
        call    OBSTACULO
        movlw   OBS+4
        call    OBSTACULO
        decfsz  SPAWN,F                         ; ¿aparece un obstáculo nuevo?
        goto    CAR_DIBUJO
        call    RANDOM
        andlw   7
        addlw   5
        movwf   SPAWN
        movlw   OBS+1
        movwf   FSR
        movf    INDF,W
        btfsc   STATUS,Z
        goto    CAR_ACTIVAR
        movlw   OBS+3
        movwf   FSR
        movf    INDF,W
        btfsc   STATUS,Z
        goto    CAR_ACTIVAR
        movlw   OBS+5
        movwf   FSR
        movf    INDF,W
        btfss   STATUS,Z
        goto    CAR_DIBUJO                      ; los tres están en pantalla
CAR_ACTIVAR
        call    RANDOM                          ; carril aleatorio 1..7
        andlw   7
        btfsc   STATUS,Z
        movlw   7
        movwf   INDF
        decf    FSR,F
        movlw   116
        movwf   INDF
CAR_DIBUJO
        movlw   4                               ; dibuja el carro del jugador
        movwf   PX
        movf    CAR,W
        movwf   PY
        call    VENTANA
        clrf    I
CAR_SPR movf    I,W
        call    SPR_CARRO
        call    SPI
        incf    I,F
        btfss   I,3
        goto    CAR_SPR
        call    MARCADOR
        movlw   30
        call    RET_MS
        goto    CAR_LAZO

OBSTACULO                                       ; W = dirección del obstáculo (x, página)
        movwf   FSR
        movf    INDF,W
        movwf   OX
        incf    FSR,F
        movf    INDF,W
        movwf   OP
        btfsc   STATUS,Z
        return                                  ; inactivo
        movf    OX,W
        movwf   PX
        movf    OP,W
        movwf   PY
        movf    OX,W
        btfss   STATUS,Z
        goto    OBS_MOVER
        clrf    INDF                            ; llegó al borde: desaparece y suma un punto
        incf    SCORE,F
        call    VENTANA
        movlw   12
        movwf   N
        clrw
        goto    RELLENAR
OBS_MOVER
        movlw   4
        subwf   OX,F
        decf    FSR,F
        movf    OX,W
        movwf   INDF
        movwf   PX
        call    VENTANA                         ; roca de 8 px y 4 columnas en blanco detrás
        clrf    I
OBS_SPR movf    I,W
        call    SPR_ROCA
        call    SPI
        incf    I,F
        btfss   I,3
        goto    OBS_SPR
        movlw   4
        movwf   N
        clrw
        call    RELLENAR
        movf    OP,W                            ; choque: mismo carril y x < 12
        xorwf   CAR,W
        btfss   STATUS,Z
        return
        movlw   12
        subwf   OX,W
        btfsc   STATUS,C
        return
        goto    FIN_JUEGO_POP

;===================== juego 3: SALTO =====================
SALTO   call    BORRAR
        clrf    SCORE
        call    MARCADOR_TEXTO
        clrf    PX                              ; suelo
        movlw   6
        movwf   PY
        call    VENTANA
        movlw   128
        movwf   N
        movlw   0x01
        call    RELLENAR
        movlw   5
        movwf   DINO
        clrf    JUMP
        movlw   116
        movwf   CX
        movlw   10
        movwf   ESPERA
SAL_LAZO
        call    LEER_BOTONES
        movf    NUEVO,W                         ; OK o ARRIBA: saltar
        andlw   b'00000101'
        btfsc   STATUS,Z
        goto    SAL_AIRE
        movf    JUMP,W
        btfsc   STATUS,Z
        incf    JUMP,F
SAL_AIRE
        movf    JUMP,W
        btfsc   STATUS,Z
        goto    SAL_CACTUS
        addlw   255                             ; W = JUMP - 1
        call    TABLA_SALTO
        movwf   NUEVA_P
        incf    JUMP,F
        movlw   9
        xorwf   JUMP,W
        btfsc   STATUS,Z
        clrf    JUMP
        movf    DINO,W                          ; borra el dinosaurio en su página anterior
        xorwf   NUEVA_P,W
        btfsc   STATUS,Z
        goto    SAL_CACTUS
        movlw   8
        movwf   PX
        movf    DINO,W
        movwf   PY
        call    VENTANA
        movlw   8
        movwf   N
        clrw
        call    RELLENAR
        movf    NUEVA_P,W
        movwf   DINO
SAL_CACTUS
        movf    ESPERA,W
        btfsc   STATUS,Z
        goto    SAL_MOVER
        decf    ESPERA,F
        goto    SAL_DINO
SAL_MOVER
        movf    CX,W
        movwf   PX
        movlw   5
        movwf   PY
        movf    CX,W
        btfss   STATUS,Z
        goto    SAL_AVANZA
        call    VENTANA                         ; salió de la pantalla: punto y nuevo cactus
        movlw   10
        movwf   N
        clrw
        call    RELLENAR
        incf    SCORE,F
        movlw   116
        movwf   CX
        call    RANDOM
        andlw   15
        movwf   ESPERA
        goto    SAL_DINO
SAL_AVANZA
        movlw   4
        subwf   CX,F
        movf    CX,W
        movwf   PX
        call    VENTANA
        clrf    I
SAL_SPR movf    I,W
        call    SPR_CACTUS
        call    SPI
        incf    I,F
        movlw   6
        xorwf   I,W
        btfss   STATUS,Z
        goto    SAL_SPR
        movlw   4
        movwf   N
        clrw
        call    RELLENAR
        movlw   5                               ; choque: dinosaurio en el suelo y 4 <= CX < 16
        xorwf   DINO,W
        btfss   STATUS,Z
        goto    SAL_DINO
        movlw   16
        subwf   CX,W
        btfsc   STATUS,C
        goto    SAL_DINO
        movlw   4
        subwf   CX,W
        btfsc   STATUS,C
        goto    FIN_JUEGO
SAL_DINO
        movlw   8
        movwf   PX
        movf    DINO,W
        movwf   PY
        call    VENTANA
        clrf    I
SAL_DSPR
        movf    I,W
        call    SPR_DINO
        call    SPI
        incf    I,F
        btfss   I,3
        goto    SAL_DSPR
        call    MARCADOR
        movlw   35
        call    RET_MS
        goto    SAL_LAZO

;===================== fin del juego =====================
FIN_JUEGO_POP                                   ; se llega desde una subrutina: descarta su retorno
FIN_JUEGO
        movlw   250
        call    RET_MS
        call    BORRAR
        movlw   22
        movwf   PX
        movlw   2
        movwf   PY
        movlw   HIGH TXT_FIN
        movwf   PTR_H
        movlw   LOW TXT_FIN
        call    TEXTO
        movlw   28
        movwf   PX
        movlw   4
        movwf   PY
        movlw   HIGH TXT_PUNTOS
        movwf   PTR_H
        movlw   LOW TXT_PUNTOS
        call    TEXTO
        call    NUMERO
        movlw   34
        movwf   PX
        movlw   6
        movwf   PY
        movlw   HIGH TXT_OK
        movwf   PTR_H
        movlw   LOW TXT_OK
        call    TEXTO
FIN_ESPERA
        movlw   30
        call    RET_MS
        call    LEER_BOTONES
        btfss   NUEVO,2
        goto    FIN_ESPERA
        goto    MENU

MARCADOR_TEXTO                                  ; "PUNTOS" en la página 0
        clrf    PX
        clrf    PY
        movlw   HIGH TXT_PUNTOS
        movwf   PTR_H
        movlw   LOW TXT_PUNTOS
        goto    TEXTO
MARCADOR                                        ; número en la página 0
        movlw   48
        movwf   PX
        clrf    PY
        call    VENTANA
NUMERO                                          ; escribe SCORE con 3 dígitos en la posición actual
        movf    SCORE,W
        movwf   AUX
        clrf    D100
        clrf    D10
NUM1    movlw   100
        subwf   AUX,W
        btfss   STATUS,C
        goto    NUM2
        movwf   AUX
        incf    D100,F
        goto    NUM1
NUM2    movlw   10
        subwf   AUX,W
        btfss   STATUS,C
        goto    NUM3
        movwf   AUX
        incf    D10,F
        goto    NUM2
NUM3    movf    D100,W
        addlw   '0'
        call    CARACTER
        movf    D10,W
        addlw   '0'
        call    CARACTER
        movf    AUX,W
        addlw   '0'
        goto    CARACTER

;===================== utilidades =====================
LEER_BOTONES                                    ; BTN = presionados, NUEVO = recién presionados
        comf    PORTB,W
        andlw   0x07
        movwf   BTN
        comf    PREV,W
        andwf   BTN,W
        movwf   NUEVO
        movf    BTN,W
        movwf   PREV
        return

RANDOM                                          ; registro de desplazamiento con realimentación (LFSR)
        bcf     STATUS,C
        rrf     RND,F
        movlw   0xB8
        btfsc   STATUS,C
        xorwf   RND,F
        movf    RND,W
        return

RET_MS                                          ; W milisegundos a 20 MHz (5000 ciclos por ms)
        movwf   R1
RM1     movlw   5
        movwf   R2
RM2     movlw   249
        movwf   R3
RM3     nop
        decfsz  R3,F
        goto    RM3
        decfsz  R2,F
        goto    RM2
        decfsz  R1,F
        goto    RM1
        return

;===================== controlador SSD1306 =====================
SPI                                             ; envía W por SPI y espera a que termine
        movwf   SSPBUF
SPI1    btfss   PIR1,SSPIF
        goto    SPI1
        bcf     PIR1,SSPIF
        movf    SSPBUF,W                        ; lee el dato recibido para limpiar BF
        return

COMANDO bcf     DC
        goto    SPI

OLED_INIT
        bcf     CS                              ; la pantalla queda seleccionada
        bcf     RES                             ; reinicio por hardware
        movlw   10
        call    RET_MS
        bsf     RES
        movlw   10
        call    RET_MS
        clrf    I
OI1     movf    I,W
        call    TABLA_INIT
        call    COMANDO
        incf    I,F
        movlw   FIN_INIT - TABLA_INIT - 2
        xorwf   I,W
        btfss   STATUS,Z
        goto    OI1
        goto    BORRAR

VENTANA                                         ; escribe a partir de la columna PX y la página PY
        bcf     DC
        movlw   0x21
        call    SPI
        movf    PX,W
        call    SPI
        movlw   127
        call    SPI
        movlw   0x22
        call    SPI
        movf    PY,W
        call    SPI
        movlw   7
        call    SPI
        bsf     DC                              ; lo siguiente son datos
        return

RELLENAR                                        ; envía N bytes iguales a W
        movwf   PAT
RL1     movf    PAT,W
        call    SPI
        decfsz  N,F
        goto    RL1
        return

RELLENAR_COL                                    ; N páginas de una sola columna (PX fijo)
        movwf   PAT
RC1     bcf     DC
        movlw   0x21
        call    SPI
        movf    PX,W
        call    SPI
        movf    PX,W
        call    SPI
        bsf     DC
        movf    PAT,W
        call    SPI
        decfsz  N,F
        goto    RC1
        return

BORRAR  clrf    PX
        clrf    PY
        call    VENTANA
        movlw   4
        movwf   AUX
BO1     clrf    N                               ; 256 bytes
        clrw
        call    RELLENAR
        decfsz  AUX,F
        goto    BO1
        return

TEXTO                                           ; cadena PTR_H:W en (PX, PY)
        movwf   PTR_L
        call    VENTANA
TX1     call    LEER_PTR
        iorlw   0
        btfsc   STATUS,Z
        return
        call    CARACTER
        incf    PTR_L,F
        btfsc   STATUS,Z
        incf    PTR_H,F
        goto    TX1

CARACTER                                        ; dibuja el carácter W (5x7 + 1 columna de espacio)
        addlw   -32
        movwf   FP_L
        clrf    FP_H
        bcf     STATUS,C                        ; FP = (W - 32) x 5 + FUENTE
        rlf     FP_L,F
        rlf     FP_H,F
        rlf     FP_L,F
        rlf     FP_H,F
        addwf   FP_L,F
        btfsc   STATUS,C
        incf    FP_H,F
        movlw   LOW FUENTE
        addwf   FP_L,F
        btfsc   STATUS,C
        incf    FP_H,F
        movlw   HIGH FUENTE
        addwf   FP_H,F
        movlw   5
        movwf   I
CA1     call    LEER_FUENTE
        call    SPI
        incf    FP_L,F
        btfsc   STATUS,Z
        incf    FP_H,F
        decfsz  I,F
        goto    CA1
        movlw   0
        goto    SPI

LEER_PTR
        movf    PTR_H,W
        movwf   PCLATH
        movf    PTR_L,W
        movwf   PCL
LEER_FUENTE
        movf    FP_H,W
        movwf   PCLATH
        movf    FP_L,W
        movwf   PCL

;===================== textos y fuente =====================
TXT_TITULO  DT  "PIC JUEGOS",0
TXT_PONG    DT  "1 PONG",0
TXT_CARRERA DT  "2 CARRERA",0
TXT_SALTO   DT  "3 SALTO",0
TXT_AYUDA   DT  "ARRIBA/ABAJO  OK",0
TXT_FIN     DT  "FIN DEL JUEGO",0
TXT_PUNTOS  DT  "PUNTOS ",0
TXT_OK      DT  "OK: MENU",0

FUENTE                                          ; ASCII 32 (espacio) a 90 (Z), 5 columnas por carácter
        DT 0x00,0x00,0x00,0x00,0x00, 0x00,0x00,0x5F,0x00,0x00, 0x00,0x07,0x00,0x07,0x00, 0x14,0x7F,0x14,0x7F,0x14
        DT 0x24,0x2A,0x7F,0x2A,0x12, 0x23,0x13,0x08,0x64,0x62, 0x36,0x49,0x55,0x22,0x50, 0x00,0x05,0x03,0x00,0x00
        DT 0x00,0x1C,0x22,0x41,0x00, 0x00,0x41,0x22,0x1C,0x00, 0x08,0x2A,0x1C,0x2A,0x08, 0x08,0x08,0x3E,0x08,0x08
        DT 0x00,0x50,0x30,0x00,0x00, 0x08,0x08,0x08,0x08,0x08, 0x00,0x60,0x60,0x00,0x00, 0x20,0x10,0x08,0x04,0x02
        DT 0x3E,0x51,0x49,0x45,0x3E, 0x00,0x42,0x7F,0x40,0x00, 0x42,0x61,0x51,0x49,0x46, 0x21,0x41,0x45,0x4B,0x31
        DT 0x18,0x14,0x12,0x7F,0x10, 0x27,0x45,0x45,0x45,0x39, 0x3C,0x4A,0x49,0x49,0x30, 0x01,0x71,0x09,0x05,0x03
        DT 0x36,0x49,0x49,0x49,0x36, 0x06,0x49,0x49,0x29,0x1E, 0x00,0x36,0x36,0x00,0x00, 0x00,0x56,0x36,0x00,0x00
        DT 0x08,0x14,0x22,0x41,0x00, 0x14,0x14,0x14,0x14,0x14, 0x00,0x41,0x22,0x14,0x08, 0x02,0x01,0x51,0x09,0x06
        DT 0x32,0x49,0x79,0x41,0x3E, 0x7E,0x11,0x11,0x11,0x7E, 0x7F,0x49,0x49,0x49,0x36, 0x3E,0x41,0x41,0x41,0x22
        DT 0x7F,0x41,0x41,0x22,0x1C, 0x7F,0x49,0x49,0x49,0x41, 0x7F,0x09,0x09,0x01,0x01, 0x3E,0x41,0x41,0x51,0x32
        DT 0x7F,0x08,0x08,0x08,0x7F, 0x00,0x41,0x7F,0x41,0x00, 0x20,0x40,0x41,0x3F,0x01, 0x7F,0x08,0x14,0x22,0x41
        DT 0x7F,0x40,0x40,0x40,0x40, 0x7F,0x02,0x04,0x02,0x7F, 0x7F,0x04,0x08,0x10,0x7F, 0x3E,0x41,0x41,0x41,0x3E
        DT 0x7F,0x09,0x09,0x09,0x06, 0x3E,0x41,0x51,0x21,0x5E, 0x7F,0x09,0x19,0x29,0x46, 0x46,0x49,0x49,0x49,0x31
        DT 0x01,0x01,0x7F,0x01,0x01, 0x3F,0x40,0x40,0x40,0x3F, 0x1F,0x20,0x40,0x20,0x1F, 0x7F,0x20,0x18,0x20,0x7F
        DT 0x63,0x14,0x08,0x14,0x63, 0x03,0x04,0x78,0x04,0x03, 0x61,0x51,0x49,0x45,0x43
        END
