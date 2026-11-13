/*====================================================================
 * Ejemplo 1 · Secuencia de LEDs «ida y vuelta» en PORTB
 * PIC16F877A · compilador MPLAB XC8 · cristal de 4 MHz
 *====================================================================*/
#include <xc.h>
#include <stdint.h>

// Bits de configuración (PIC16F877A). En MPLAB X: Production > Set Configuration Bits
// genera estas mismas líneas para el PIC exacto que use (el PIC16F877 tiene opciones casi iguales).
#pragma config FOSC = XT, WDTE = OFF, PWRTE = ON, BOREN = OFF, LVP = OFF, CPD = OFF, WRT = OFF, CP = OFF
#define _XTAL_FREQ 4000000UL     // cristal de 4 MHz, necesario para __delay_ms()

void main(void) {
    uint8_t led = 0x01;
    TRISB = 0x00;                       // PORTB: salidas
    while (1) {
        while (led != 0x80) {           // hacia RB7
            PORTB = led;
            __delay_ms(100);
            led <<= 1;
        }
        while (led != 0x01) {           // hacia RB0
            PORTB = led;
            __delay_ms(100);
            led >>= 1;
        }
    }
}
