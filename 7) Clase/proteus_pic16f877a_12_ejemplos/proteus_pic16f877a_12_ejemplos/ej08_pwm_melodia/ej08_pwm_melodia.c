/* Ejemplo 8 · PWM: melodía en un parlante (RC2/CCP1) (MPLAB X + XC8)
   RB0 toca "Estrellita" · f = 62500 / (PR2 + 1) con preescalador 16 · 50 % de ciclo útil */
#include <xc.h>
#include <stdint.h>
#pragma config FOSC = XT, WDTE = OFF, PWRTE = ON, BOREN = OFF, LVP = OFF, CPD = OFF, WRT = OFF, CP = OFF
#define _XTAL_FREQ 4000000UL

const uint8_t PR2_NOTA[8] = {237, 212, 188, 178, 158, 141, 125, 118};   /* Do4 .. Do5 */
const uint8_t MELODIA[] = {0,1, 0,1, 4,1, 4,1, 5,1, 5,1, 4,2,  3,1, 3,1, 2,1, 2,1, 1,1, 1,1, 0,2,
                           4,1, 4,1, 3,1, 3,1, 2,1, 2,1, 1,2,  4,1, 4,1, 3,1, 3,1, 2,1, 2,1, 1,2,
                           0,1, 0,1, 4,1, 4,1, 5,1, 5,1, 4,2,  3,1, 3,1, 2,1, 2,1, 1,1, 1,1, 0,2, 0xFF};

void main(void) {
    OPTION_REGbits.nRBPU = 0;
    TRISC2 = 0; TRISC0 = 0; PORTC = 0;
    CCPR1L = 0; CCP1CON = 0x0C;
    T2CON = 0x06;                                       /* TMR2 encendido, 1:16 */
    while (1) {
        while (RB0);                                    /* espera el botón */
        RC0 = 1;
        for (uint8_t i = 0; MELODIA[i] != 0xFF; i += 2) {
            PR2 = PR2_NOTA[MELODIA[i]];
            CCPR1L = (uint8_t)((PR2 + 1) / 2);          /* 50 % */
            for (uint8_t d = MELODIA[i + 1]; d; d--) __delay_ms(250);
            CCPR1L = 0; __delay_ms(20);                 /* silencio entre notas */
        }
        RC0 = 0;
    }
}
