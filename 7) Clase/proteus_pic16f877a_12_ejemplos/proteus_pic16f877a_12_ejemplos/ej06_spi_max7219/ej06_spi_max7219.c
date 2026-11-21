/* Ejemplo 6 · SPI: display de 8 dígitos con MAX7219 (MPLAB X + XC8)
   SDO → DIN, SCK → CLK, RC0 → LOAD · izquierda: segundos · derecha: ADC de AN0 */
#include <xc.h>
#include <stdint.h>
#pragma config FOSC = XT, WDTE = OFF, PWRTE = ON, BOREN = OFF, LVP = OFF, CPD = OFF, WRT = OFF, CP = OFF
#define _XTAL_FREQ 4000000UL
/* ---------- SPI maestro: SCK = RC3, SDO = RC5, modo 0 a Fosc/4 ---------- */
void spi_init(void) { TRISC3 = 0; TRISC5 = 0; SSPSTAT = 0x40; SSPCON = 0x20; }
uint8_t spi_tx(uint8_t b) { SSPBUF = b; while (!SSPIF); SSPIF = 0; return SSPBUF; }

#define LOAD RC0

void max7219(uint8_t reg, uint8_t dato) { LOAD = 0; spi_tx(reg); spi_tx(dato); LOAD = 1; }

void mostrar4(uint8_t primero, uint16_t n) {           /* 4 dígitos BCD desde el registro 'primero' */
    for (uint8_t i = 0; i < 4; i++) {
        uint8_t d = n % 10; n /= 10;
        max7219((uint8_t)(primero - 3 + i), (uint8_t)(i == 0 ? d | 0x80 : d));   /* punto en el último */
    }
}

void main(void) {
    uint16_t segundos = 0;
    TRISC0 = 0; LOAD = 1;
    ADCON1 = 0x8E; ADCON0 = 0x41;                      /* AN0, 10 bits a la derecha */
    spi_init();
    max7219(0x0F, 0x00);                               /* sin prueba de display */
    max7219(0x09, 0xFF);                               /* decodificación BCD */
    max7219(0x0A, 0x08);                               /* brillo */
    max7219(0x0B, 0x07);                               /* 8 dígitos */
    max7219(0x0C, 0x01);                               /* encendido */
    while (1) {
        for (uint8_t k = 0; k < 10; k++) {
            mostrar4(8, segundos);
            __delay_us(50); GO_nDONE = 1; while (GO_nDONE);
            mostrar4(4, (uint16_t)((ADRESH << 8) | ADRESL));
            __delay_ms(100);
        }
        segundos++;
    }
}
