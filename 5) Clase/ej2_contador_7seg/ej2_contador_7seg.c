/*====================================================================
 * Ejemplo 2 · Contador 0–9 en display de 7 segmentos con pulsador
 * PIC16F877A · XC8 · 4 MHz · display cátodo común a..g = RD0..RD6
 * Pulsador en RB0 con resistencia de 10 kΩ a +5 V (activo en bajo)
 *====================================================================*/
#include <xc.h>
#include <stdint.h>

// Bits de configuración (PIC16F877A). En MPLAB X: Production > Set Configuration Bits
// genera estas mismas líneas para el PIC exacto que use (el PIC16F877 tiene opciones casi iguales).
#pragma config FOSC = XT, WDTE = OFF, PWRTE = ON, BOREN = OFF, LVP = OFF, CPD = OFF, WRT = OFF, CP = OFF
#define _XTAL_FREQ 4000000UL     // cristal de 4 MHz, necesario para __delay_ms()

const uint8_t SEGMENTOS[10] = {0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F};

void main(void) {
    uint8_t cuenta = 0;
    TRISD = 0x00;                       // segmentos
    TRISB = 0xFF;                       // pulsador
    while (1) {
        PORTD = SEGMENTOS[cuenta];
        while (PORTBbits.RB0) { }       // espera la pulsación
        __delay_ms(20);                 // antirrebote
        while (!PORTBbits.RB0) { }      // espera que se suelte
        __delay_ms(20);
        if (++cuenta == 10) cuenta = 0;
    }
}
