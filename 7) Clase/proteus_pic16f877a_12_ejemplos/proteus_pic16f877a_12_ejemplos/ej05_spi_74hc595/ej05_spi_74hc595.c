/* Ejemplo 5 · SPI: 8 LED con un 74HC595 (MPLAB X + XC8)
   SDO → DS, SCK → SH_CP, RC0 → ST_CP · RB0 alterna contador / barra con el pot de AN0 */
#include <xc.h>
#include <stdint.h>
#pragma config FOSC = XT, WDTE = OFF, PWRTE = ON, BOREN = OFF, LVP = OFF, CPD = OFF, WRT = OFF, CP = OFF
#define _XTAL_FREQ 4000000UL
/* ---------- SPI maestro: SCK = RC3, SDO = RC5, modo 0 a Fosc/4 ---------- */
void spi_init(void) { TRISC3 = 0; TRISC5 = 0; SSPSTAT = 0x40; SSPCON = 0x20; }
uint8_t spi_tx(uint8_t b) { SSPBUF = b; while (!SSPIF); SSPIF = 0; return SSPBUF; }

#define LATCH RC0

void hc595(uint8_t v) { LATCH = 0; spi_tx(v); LATCH = 1; }   /* flanco de subida en ST_CP */

void main(void) {
    uint8_t modo = 0, cuenta = 0, antes = 1;
    OPTION_REGbits.nRBPU = 0;
    TRISC0 = 0; LATCH = 1;
    ADCON1 = 0x0E; ADCON0 = 0x41;
    spi_init();
    while (1) {
        if (!RB0 && antes) modo ^= 1;
        antes = RB0;
        if (modo == 0) hc595(++cuenta);
        else {
            __delay_us(50); GO_nDONE = 1; while (GO_nDONE);
            uint8_t n = (uint8_t)(((uint16_t)ADRESH + 16) >> 5);   /* 0..8 LED */
            hc595((uint8_t)((1u << n) - 1));
        }
        __delay_ms(150);
    }
}
