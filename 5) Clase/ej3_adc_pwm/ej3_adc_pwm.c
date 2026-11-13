/*====================================================================
 * Ejemplo 3 · Potenciómetro (AN0) → PWM en RC2/CCP1 y valor en PORTB
 * PIC16F877A · XC8 · 4 MHz · PWM de 976,6 Hz (PR2 = 255, preescalador 4)
 *====================================================================*/
#include <xc.h>
#include <stdint.h>

// Bits de configuración (PIC16F877A). En MPLAB X: Production > Set Configuration Bits
// genera estas mismas líneas para el PIC exacto que use (el PIC16F877 tiene opciones casi iguales).
#pragma config FOSC = XT, WDTE = OFF, PWRTE = ON, BOREN = OFF, LVP = OFF, CPD = OFF, WRT = OFF, CP = OFF
#define _XTAL_FREQ 4000000UL     // cristal de 4 MHz, necesario para __delay_ms()

void main(void) {
    TRISA = 0xFF;                       // AN0 entrada
    TRISB = 0x00;                       // LEDs
    TRISCbits.TRISC2 = 0;               // salida PWM
    ADCON1 = 0x0E;                      // justificado a la izquierda, solo AN0 analógico
    ADCON0 = 0x41;                      // Fosc/8 (Tad = 2 µs), canal 0, ADON = 1
    PR2 = 255;                          // periodo = (PR2 + 1)·4·Tosc·4 = 1,024 ms
    T2CON = 0x05;                       // TMR2 encendido, preescalador 1:4
    CCP1CON = 0x0C;                     // CCP1 en modo PWM
    CCPR1L = 0;
    while (1) {
        __delay_us(20);                 // tiempo de adquisición
        ADCON0bits.GO_nDONE = 1;        // inicia la conversión
        while (ADCON0bits.GO_nDONE) { } // espera el final
        CCPR1L = ADRESH;                // ciclo útil = ADRESH / 256
        PORTB = ADRESH;
    }
}
