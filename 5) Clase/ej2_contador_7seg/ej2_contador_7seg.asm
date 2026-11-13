;=====================================================================
; Ejemplo 2 · Contador 0–9 en display de 7 segmentos con pulsador
; PIC16F877A · 4 MHz · display cátodo común: a..g = RD0..RD6
; Pulsador en RB0 con resistencia de 10 kΩ a +5 V (activo en bajo)
;=====================================================================
        LIST    p=16F877A
        #include <p16f877a.inc>
        __CONFIG 0x3F31

        CBLOCK  0x20
        cuenta
        d1
        d3
        ENDC

        ORG     0x0000
        goto    inicio

;--- tabla de segmentos (gfedcba) ------------------------------------
tabla   addwf   PCL,F
        DT      0x3F,0x06,0x5B,0x4F,0x66,0x6D,0x7D,0x07,0x7F,0x6F

inicio  banksel TRISD
        clrf    TRISD           ; PORTD: segmentos
        movlw   0xFF
        movwf   TRISB           ; PORTB: entradas
        banksel PORTD
        clrf    cuenta

mostrar movf    cuenta,W
        call    tabla
        movwf   PORTD
esperaP btfsc   PORTB,0         ; espera la pulsación (RB0 = 0)
        goto    esperaP
        call    rebote
esperaS btfss   PORTB,0         ; espera que se suelte
        goto    esperaS
        call    rebote
        incf    cuenta,F        ; cuenta = cuenta + 1
        movf    cuenta,W
        xorlw   d'10'           ; ¿llegó a 10?
        btfsc   STATUS,Z
        clrf    cuenta          ; sí: vuelve a 0
        goto    mostrar

;--- antirrebote de 20 ms ---------------------------------------------
rebote  movlw   d'20'
        movwf   d3
r1      movlw   d'249'
        movwf   d1
r2      nop
        decfsz  d1,F
        goto    r2
        decfsz  d3,F
        goto    r1
        return

        END
