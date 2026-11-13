/* Ejemplo 10 · Semáforo con botón peatonal (RB0/INT) y base de tiempo con TMR1 cada 100 ms (MPLAB X + XC8)
   PORTD: RD0 rojo, RD1 amarillo, RD2 verde (vehicular); RD3 rojo, RD4 verde (peatonal); RD5 espere. */
#include <xc.h>
#include <stdint.h>
#pragma config FOSC = XT, WDTE = OFF, PWRTE = ON, BOREN = OFF, LVP = OFF, CPD = OFF, WRT = OFF, CP = OFF
#define _XTAL_FREQ 4000000UL

volatile uint8_t decimas, solicitud;

void __interrupt() isr(void) {
    if (TMR1IF) {
        TMR1IF = 0;
        TMR1ON = 0; TMR1H = 0xCF; TMR1L = 0x2C; TMR1ON = 1;   /* 65536 - 12500 */
        decimas++;
    }
    if (INTF) { INTF = 0; solicitud = 1; }
}

void esperar(uint8_t d) { decimas = 0; while (decimas < d); }

void main(void) {
    TRISD = 0x00; PORTD = 0;
    OPTION_REG = 0x00;                       /* pull-ups, INT por flanco de bajada */
    TMR1H = 0xCF; TMR1L = 0x2C;
    T1CON = 0x31;                            /* preescalador 1:8, encendido */
    TMR1IE = 1;
    INTCON = 0xD0;                           /* GIE, PEIE, INTE */
    while (1) {
        PORTD = 0b00001100;                  /* verde vehicular + rojo peatonal */
        decimas = 0;
        while (decimas < 100 && !(solicitud && decimas >= 30)) if (solicitud) RD5 = 1;
        PORTD = 0b00001010 | (solicitud ? 0x20 : 0);   /* amarillo */
        esperar(20);
        solicitud = 0;
        PORTD = 0b00010001;                  /* rojo vehicular + verde peatonal */
        esperar(50);
        for (uint8_t i = 0; i < 6; i++) { PORTD ^= 0x10; esperar(5); }
        PORTD = 0b00001001;                  /* despeje */
        esperar(10);
        solicitud = 0;
    }
}
