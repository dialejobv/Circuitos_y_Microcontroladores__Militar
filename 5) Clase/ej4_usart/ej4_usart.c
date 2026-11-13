/*====================================================================
 * Ejemplo 4 · USART a 9600 baudios: mensaje de bienvenida y eco
 * PIC16F877A · XC8 · 4 MHz · SPBRG = 25 con BRGH = 1 → 9615 baudios
 *====================================================================*/
#include <xc.h>
#include <stdint.h>

// Bits de configuración (PIC16F877A). En MPLAB X: Production > Set Configuration Bits
// genera estas mismas líneas para el PIC exacto que use (el PIC16F877 tiene opciones casi iguales).
#pragma config FOSC = XT, WDTE = OFF, PWRTE = ON, BOREN = OFF, LVP = OFF, CPD = OFF, WRT = OFF, CP = OFF
#define _XTAL_FREQ 4000000UL     // cristal de 4 MHz, necesario para __delay_ms()

void uart_tx(char c) {
    while (!PIR1bits.TXIF) { }          // espera a que TXREG esté libre
    TXREG = c;
}

void uart_texto(const char *s) {
    while (*s) uart_tx(*s++);
}

void main(void) {
    TRISCbits.TRISC6 = 0;               // TX
    TRISCbits.TRISC7 = 1;               // RX
    TRISB = 0x00;
    SPBRG = 25;                         // 4 MHz / (16 · (25 + 1)) = 9615 baudios
    TXSTA = 0x24;                       // TXEN = 1, BRGH = 1, asíncrono
    RCSTA = 0x90;                       // SPEN = 1, CREN = 1
    PORTB = 0;
    uart_texto("PIC16F877A listo\r\n");
    while (1) {
        if (RCSTAbits.OERR) {           // desbordamiento: reinicia el receptor
            RCSTAbits.CREN = 0;
            RCSTAbits.CREN = 1;
        }
        if (PIR1bits.RCIF) {
            char c = RCREG;
            PORTB = c;                  // muestra el carácter en los LEDs
            uart_tx(c);                 // eco
        }
    }
}
