/* Ejemplo 9 · Motor paso a paso unipolar con ULN2003A en RD0-RD3, medio paso (MPLAB X + XC8)
   RB0 = horario, RB1 = antihorario. Pot en AN0 = 2..33 ms entre pasos. RC0/RC1 = LED de sentido. */
#include <xc.h>
#include <stdint.h>
#pragma config FOSC = XT, WDTE = OFF, PWRTE = ON, BOREN = OFF, LVP = OFF, CPD = OFF, WRT = OFF, CP = OFF
#define _XTAL_FREQ 4000000UL

const uint8_t SEC[8] = {0x01, 0x03, 0x02, 0x06, 0x04, 0x0C, 0x08, 0x09};

void main(void) {
    uint8_t idx = 0, demora;
    OPTION_REGbits.nRBPU = 0;
    TRISD = 0xF0; TRISC = 0xFC; PORTD = 0; PORTC = 0;
    ADCON1 = 0x0E; ADCON0 = 0x41;
    while (1) {
        __delay_us(50);
        GO_nDONE = 1; while (GO_nDONE);
        demora = (uint8_t)(2 + (ADRESH >> 3));
        if (!RB0)      { idx = (idx + 1) & 7; PORTC = 0x01; }
        else if (!RB1) { idx = (idx - 1) & 7; PORTC = 0x02; }
        else           { PORTC = 0; PORTD = 0; continue; }
        PORTD = SEC[idx];
        while (demora--) __delay_ms(1);
    }
}
