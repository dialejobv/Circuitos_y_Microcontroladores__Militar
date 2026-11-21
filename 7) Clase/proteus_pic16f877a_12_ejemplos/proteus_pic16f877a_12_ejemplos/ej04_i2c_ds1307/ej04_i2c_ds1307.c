/* Ejemplo 4 · I2C: reloj DS1307 (dirección 0x68) en LCD 16x2 (MPLAB X + XC8)
   SQW a 1 Hz · RB0 suma un minuto */
#include <xc.h>
#include <stdint.h>
#pragma config FOSC = XT, WDTE = OFF, PWRTE = ON, BOREN = OFF, LVP = OFF, CPD = OFF, WRT = OFF, CP = OFF
#define _XTAL_FREQ 4000000UL
/* ---------- LCD 16x2 (HD44780) en modo de 4 bits: RS = RD0, E = RD1, D4..D7 = RD4..RD7, RW a tierra ---------- */
#define LCD_RS PORTDbits.RD0
#define LCD_E  PORTDbits.RD1

void lcd_nibble(uint8_t n) {            /* pone n<7:4> en D7..D4 y da un pulso en E */
    PORTD = (uint8_t)((PORTD & 0x0F) | (n & 0xF0));
    LCD_E = 1; __delay_us(1); LCD_E = 0;
}
void lcd_cmd(uint8_t c) {
    LCD_RS = 0; lcd_nibble(c); lcd_nibble((uint8_t)(c << 4));
    if (c < 3) __delay_ms(2); else __delay_us(50);
}
void lcd_char(char d) {
    LCD_RS = 1; lcd_nibble((uint8_t)d); lcd_nibble((uint8_t)(d << 4)); __delay_us(50);
}
void lcd_init(void) {
    TRISD = 0x00; PORTD = 0x00;
    __delay_ms(20);
    lcd_nibble(0x30); __delay_ms(5);
    lcd_nibble(0x30); __delay_us(150);
    lcd_nibble(0x30); __delay_us(50);
    lcd_nibble(0x20); __delay_us(50);     /* modo de 4 bits */
    lcd_cmd(0x28);                        /* 2 líneas, 5x8 */
    lcd_cmd(0x0C);                        /* display encendido, sin cursor */
    lcd_cmd(0x06);                        /* incremento automático */
    lcd_cmd(0x01);                        /* borrar */
}
void lcd_goto(uint8_t fila, uint8_t col) { lcd_cmd((uint8_t)((fila ? 0xC0 : 0x80) + col)); }
void lcd_print(const char *s) { while (*s) lcd_char(*s++); }
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

#define DS_W 0xD0
#define DS_R 0xD1
uint8_t reg[7];

void ds_escribir(uint8_t dir, const uint8_t *d, uint8_t n) {
    i2c_start(); i2c_escribir(DS_W); i2c_escribir(dir);
    while (n--) i2c_escribir(*d++);
    i2c_stop();
}
void ds_leer(uint8_t dir, uint8_t *d, uint8_t n) {
    i2c_start(); i2c_escribir(DS_W); i2c_escribir(dir);
    i2c_restart(); i2c_escribir(DS_R);
    while (n--) *d++ = i2c_leer(n != 0);                 /* NACK en el último */
    i2c_stop();
}
void lcd_bcd(uint8_t b) { lcd_char('0' + (b >> 4)); lcd_char('0' + (b & 0x0F)); }

void main(void) {
    const uint8_t inicial[7] = {0x00, 0x00, 0x12, 0x05, 0x19, 0x11, 0x26};   /* 12:00:00 19/11/26 */
    const uint8_t sqw = 0x10;
    OPTION_REGbits.nRBPU = 0;
    lcd_init(); i2c_init();
    lcd_goto(0, 0); lcd_print("Hora:");
    lcd_goto(1, 0); lcd_print("Fecha:");
    ds_leer(0, reg, 1);
    if (reg[0] & 0x80) ds_escribir(0, inicial, 7);       /* CH = 1: reloj detenido */
    ds_escribir(7, &sqw, 1);                            /* SQW a 1 Hz */
    while (1) {
        ds_leer(0, reg, 7);
        lcd_goto(0, 7); lcd_bcd(reg[2] & 0x3F); lcd_char(':'); lcd_bcd(reg[1]); lcd_char(':'); lcd_bcd(reg[0] & 0x7F);
        lcd_goto(1, 7); lcd_bcd(reg[4]); lcd_char('/'); lcd_bcd(reg[5]); lcd_char('/'); lcd_bcd(reg[6]);
        if (!RB0) {                                     /* suma un minuto (BCD) */
            uint8_t m = reg[1] + 1;
            if ((m & 0x0F) == 0x0A) m += 6;
            if (m == 0x60) m = 0;
            ds_escribir(1, &m, 1);
            while (!RB0);
        }
        __delay_ms(200);
    }
}
