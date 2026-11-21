/* Ejemplo 7 · PWM: dos canales de 10 bits a 1 kHz (CCP1 en RC2 y CCP2 en RC1) (MPLAB X + XC8)
   Pot 1 en AN0 → CCP1 · Pot 2 en AN1 → CCP2 · LCD con el ciclo útil */
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

uint16_t leer_adc(uint8_t canal) {
    ADCON0 = (uint8_t)(0x41 | (canal << 3)); __delay_us(50);
    GO_nDONE = 1; while (GO_nDONE);
    return (uint16_t)((ADRESH << 8) | ADRESL);
}

void pwm1(uint16_t d) { CCPR1L = (uint8_t)(d >> 2); CCP1CON = (uint8_t)(0x0C | ((d & 3) << 4)); }
void pwm2(uint16_t d) { CCPR2L = (uint8_t)(d >> 2); CCP2CON = (uint8_t)(0x0C | ((d & 3) << 4)); }

void pct(uint8_t fila, uint16_t d) {                    /* d de 0 a 1000 → 0..100 % */
    uint8_t p = (uint8_t)(d / 10);
    lcd_goto(fila, 6);
    lcd_char(p >= 100 ? '1' : ' '); lcd_char(p >= 10 ? '0' + (p / 10) % 10 : ' '); lcd_char('0' + p % 10); lcd_char('%');
}

void main(void) {
    TRISC1 = 0; TRISC2 = 0;
    PR2 = 249;                                          /* 1 kHz con preescalador 4 */
    CCP1CON = 0x0C; CCP2CON = 0x0C;
    T2CON = 0x05;
    ADCON1 = 0x84;
    lcd_init();
    lcd_goto(0, 0); lcd_print("PWM1:      1 kHz");
    lcd_goto(1, 0); lcd_print("PWM2:      RC1");
    while (1) {
        uint16_t d1 = leer_adc(0), d2 = leer_adc(1);
        if (d1 > 1000) d1 = 1000;                       /* 1000 = 100 % con PR2 = 249 */
        if (d2 > 1000) d2 = 1000;
        pwm1(d1); pwm2(d2);
        pct(0, d1); pct(1, d2);
        __delay_ms(50);
    }
}
