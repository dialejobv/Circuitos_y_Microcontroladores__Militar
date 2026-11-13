/* Ejemplo 8 · Cronómetro 00.00-99.99 s en 4 displays multiplexados (MPLAB X + XC8)
   TMR0 interrumpe cada 1 ms; RB0/INT inicia/detiene; RB1 pone en cero.
   Segmentos en PORTD (a = RD0 ... dp = RD7), comunes en RA0-RA3 (activos en 0). RC0 = LED corriendo. */
#include <xc.h>
#include <stdint.h>
#pragma config FOSC = XT, WDTE = OFF, PWRTE = ON, BOREN = OFF, LVP = OFF, CPD = OFF, WRT = OFF, CP = OFF
#define _XTAL_FREQ 4000000UL

const uint8_t SEG7[10] = {0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F};
volatile uint8_t vals[4];                    /* decenas, unidades, décimas, centésimas */
volatile uint8_t digito, ms, corriendo, rebote;

void __interrupt() isr(void) {
    if (INTF) {                              /* botón iniciar / detener */
        INTF = 0;
        if (!rebote) { rebote = 200; corriendo ^= 1; }
    }
    if (TMR0IF) {
        TMR0IF = 0;
        TMR0 += 6;                           /* 250 cuentas x 4 µs = 1 ms */
        PORTA |= 0x0F;                       /* apaga los dígitos */
        digito = (digito + 1) & 3;
        PORTD = SEG7[vals[digito]] | (digito == 1 ? 0x80 : 0);
        PORTA &= (uint8_t)~(1 << digito);    /* enciende el actual */
        if (rebote) rebote--;
        if (corriendo && ++ms >= 10) {       /* una centésima */
            ms = 0;
            for (int8_t i = 3; i >= 0; i--) { if (++vals[i] < 10) break; vals[i] = 0; }
        }
    }
}

void main(void) {
    ADCON1 = 0x06;                           /* PORTA digital */
    TRISA = 0xF0; TRISD = 0x00; TRISCbits.TRISC0 = 0;
    PORTA = 0x0F; PORTD = 0;
    OPTION_REG = 0x01;                       /* pull-ups, INT flanco de bajada, TMR0 1:4 */
    INTCON = 0xB0;                           /* GIE, T0IE, INTE */
    while (1) {
        if (!RB1) { corriendo = 0; ms = 0; vals[0] = vals[1] = vals[2] = vals[3] = 0; }
        RC0 = corriendo;
    }
}
