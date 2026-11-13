;===========================================================================
; Ejemplo 8 · Cronómetro 00.00-99.99 s en display de 4 dígitos multiplexado
;             con interrupciones de TMR0 (cada 1 ms) y de RB0/INT
; PIC16F877A · cristal 4 MHz
;   Segmentos a..g, dp = RD0..RD7 (con 330 Ω)  ·  comunes de los dígitos 1..4 = RA0..RA3 (activos en 0)
;   RB0/INT = iniciar / detener (interrupción por flanco de bajada) · RB1 = poner en cero
;   RC0 = LED "corriendo"
;===========================================================================
        LIST    P=16F877A, R=DEC
        #include <p16f877a.inc>
        __CONFIG _XT_OSC & _WDT_OFF & _PWRTE_ON & _BOREN_OFF & _LVP_OFF & _CP_OFF

        CBLOCK  0x20
        VALS:4                          ; dígitos de izquierda a derecha: decenas, unidades, décimas, centésimas
        DIGITO, MS, CORRIENDO, REBOTE
        ENDC
        CBLOCK  0x70                    ; RAM común a los cuatro bancos
        W_TEMP, S_TEMP, P_TEMP
        ENDC

        ORG     0x000
        goto    INICIO

        ORG     0x004                   ;---------- vector de interrupción
        movwf   W_TEMP                  ; guarda el contexto
        swapf   STATUS,W
        clrf    STATUS                  ; banco 0
        movwf   S_TEMP
        movf    PCLATH,W
        movwf   P_TEMP
        clrf    PCLATH
        btfsc   INTCON,INTF
        call    ISR_INT
        btfss   INTCON,T0IF
        goto    FIN_ISR
        bcf     INTCON,T0IF
        movlw   6                       ; 256 - 6 = 250 cuentas x 4 µs = 1 ms
        addwf   TMR0,F
        call    MULTIPLEXAR
        call    CONTAR
FIN_ISR movf    P_TEMP,W                ; recupera el contexto
        movwf   PCLATH
        swapf   S_TEMP,W
        movwf   STATUS
        swapf   W_TEMP,F
        swapf   W_TEMP,W
        retfie

SEG7    addwf   PCL,F                   ; código de 7 segmentos (cátodo común) del dígito en W
        DT      0x3F,0x06,0x5B,0x4F,0x66,0x6D,0x7D,0x07,0x7F,0x6F
COMUN   addwf   PCL,F                   ; máscara para encender el dígito W (común en 0)
        DT      b'11111110',b'11111101',b'11111011',b'11110111'

ISR_INT bcf     INTCON,INTF
        movf    REBOTE,W                ; ignora los rebotes durante 200 ms
        btfss   STATUS,Z
        return
        movlw   200
        movwf   REBOTE
        movlw   1
        xorwf   CORRIENDO,F
        return

MULTIPLEXAR
        movlw   0x0F
        iorwf   PORTA,F                 ; apaga los cuatro dígitos
        incf    DIGITO,W
        andlw   3
        movwf   DIGITO
        addlw   VALS
        movwf   FSR
        movf    INDF,W
        call    SEG7
        movwf   PORTD
        movf    DIGITO,W                ; punto decimal después de los segundos
        xorlw   1
        btfsc   STATUS,Z
        bsf     PORTD,7
        movf    DIGITO,W
        call    COMUN
        andwf   PORTA,F                 ; enciende solo el dígito actual
        return

CONTAR  movf    REBOTE,W
        btfss   STATUS,Z
        decf    REBOTE,F
        btfss   CORRIENDO,0
        return
        incf    MS,F                    ; 10 ms = una centésima
        movlw   10
        subwf   MS,W
        btfss   STATUS,C
        return
        clrf    MS
        movlw   VALS+3                  ; suma 1 en BCD empezando por las centésimas
        movwf   FSR
CT1     incf    INDF,F
        movlw   10
        subwf   INDF,W
        btfss   STATUS,C
        return
        clrf    INDF
        decf    FSR,F
        movlw   VALS-1
        xorwf   FSR,W
        btfss   STATUS,Z
        goto    CT1
        return

INICIO
        BANKSEL ADCON1
        movlw   0x06                    ; PORTA digital
        movwf   ADCON1
        movlw   0xF0
        movwf   TRISA
        clrf    TRISD
        bcf     TRISC,0
        movlw   b'00000001'             ; pull-ups, INT por flanco de bajada, TMR0 interno, preescalador 1:4
        movwf   OPTION_REG
        BANKSEL PORTA
        movlw   0x0F
        movwf   PORTA
        clrf    PORTD
        clrf    PORTC
        clrf    VALS+0
        clrf    VALS+1
        clrf    VALS+2
        clrf    VALS+3
        clrf    DIGITO
        clrf    MS
        clrf    CORRIENDO
        clrf    REBOTE
        movlw   b'10110000'             ; GIE, T0IE, INTE
        movwf   INTCON

LAZO    btfsc   PORTB,1                 ; RB1: poner en cero
        goto    LED
        clrf    CORRIENDO
        clrf    MS
        clrf    VALS+0
        clrf    VALS+1
        clrf    VALS+2
        clrf    VALS+3
LED     btfss   CORRIENDO,0
        bcf     PORTC,0
        btfsc   CORRIENDO,0
        bsf     PORTC,0
        goto    LAZO
        END
