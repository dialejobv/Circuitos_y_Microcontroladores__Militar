;=====================================================================
; Ejemplo 1 · Secuencia de LEDs «ida y vuelta» en PORTB
; PIC16F877A · cristal de 4 MHz (ciclo de instrucción = 1 µs)
; LEDs en RB0..RB7 con resistencias de 330 Ω a tierra
;=====================================================================
        LIST    p=16F877A
        #include <p16f877a.inc>
        __CONFIG 0x3F31         ; XT, WDT off, PWRT on, BOR off, LVP off, sin protección

        CBLOCK  0x20
        d1                      ; contador del lazo interno
        d3                      ; contador de milisegundos
        ENDC

        ORG     0x0000
        goto    inicio

inicio  banksel TRISB
        clrf    TRISB           ; PORTB: las 8 líneas como salidas
        banksel PORTB
        movlw   b'00000001'
        movwf   PORTB           ; enciende RB0

izq     call    retardo         ; desplaza hacia RB7
        bcf     STATUS,C
        rlf     PORTB,F
        btfss   PORTB,7
        goto    izq
der     call    retardo         ; desplaza hacia RB0
        bcf     STATUS,C
        rrf     PORTB,F
        btfss   PORTB,0
        goto    der
        goto    izq

;--- retardo de 100 ms: 100 × 1 ms ----------------------------------
retardo movlw   d'100'
        movwf   d3
r1      movlw   d'249'          ; 249 × 4 ciclos ≈ 1 ms
        movwf   d1
r2      nop
        decfsz  d1,F
        goto    r2
        decfsz  d3,F
        goto    r1
        return

        END
