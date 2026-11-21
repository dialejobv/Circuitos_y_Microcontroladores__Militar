/* Ejemplo 3 · I2C: 8 LED en un PCF8574 (dirección 0x20) (MPLAB X + XC8)
   LED de +5 V a cada salida (se encienden con 0) · RB0 cambia el efecto · RC0 = error de bus */
#include <xc.h>
#include <stdint.h>
#pragma config FOSC = XT, WDTE = OFF, PWRTE = ON, BOREN = OFF, LVP = OFF, CPD = OFF, WRT = OFF, CP = OFF
#define _XTAL_FREQ 4000000UL
/* ---------- I2C maestro a 100 kHz (4 MHz): SCL = RC3, SDA = RC4, pull-ups de 4,7 kΩ ---------- */
void i2c_espera(void) { while (!SSPIF); SSPIF = 0; }
void i2c_init(void) { TRISC3 = 1; TRISC4 = 1; SSPADD = 9; SSPSTAT = 0x80; SSPCON2 = 0; SSPCON = 0x28; }
void i2c_start(void) { SEN = 1; i2c_espera(); }
void i2c_restart(void) { RSEN = 1; i2c_espera(); }
void i2c_stop(void) { PEN = 1; i2c_espera(); }
uint8_t i2c_escribir(uint8_t b) { SSPBUF = b; i2c_espera(); return !ACKSTAT; }   /* 1 = el esclavo respondió */
uint8_t i2c_leer(uint8_t ack) {
    RCEN = 1; i2c_espera();
    ACKDT = ack ? 0 : 1; ACKEN = 1; i2c_espera();
    return SSPBUF;
}

#define PCF8574_W 0x40

void enviar(uint8_t patron) {
    i2c_start();
    if (i2c_escribir(PCF8574_W)) { RC0 = 0; i2c_escribir((uint8_t)~patron); }
    else RC0 = 1;                                        /* nadie respondió (NACK) */
    i2c_stop();
}

void main(void) {
    uint8_t modo = 0, patron = 1, dir = 0, cuenta = 0, antes = 1;
    OPTION_REGbits.nRBPU = 0;
    TRISC0 = 0; RC0 = 0;
    i2c_init();
    while (1) {
        enviar(patron);
        switch (modo) {
            case 0:                                      /* barrido */
                patron = dir ? patron >> 1 : (uint8_t)(patron << 1);
                if (patron & 0x80) dir = 1;
                if (patron & 0x01) dir = 0;
                if (!patron) patron = 1;
                break;
            case 1: patron = ++cuenta; break;            /* contador binario */
            default: patron = (patron == 0x55) ? 0xAA : 0x55;
        }
        if (!RB0 && antes) { modo = (modo + 1) % 3; patron = 1; }
        antes = RB0;
        __delay_ms(120);
    }
}
