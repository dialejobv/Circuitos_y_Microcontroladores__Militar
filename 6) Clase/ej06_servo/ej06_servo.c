/* Ejemplo 6 · Servomotor en RC2 controlado con potenciómetro en AN0 + LCD (MPLAB X + XC8)
   Pulso de 1000 a 2020 µs cada ~20 ms. */
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

void main(void) {
    uint8_t pos = 128, angulo;
    uint16_t ancho;
    TRISCbits.TRISC2 = 0; RC2 = 0;
    ADCON1 = 0x0E;                           /* AN0, justificado a la izquierda */
    ADCON0 = 0x41;
    lcd_init();
    lcd_goto(0, 0); lcd_print("Angulo:");
    lcd_goto(1, 0); lcd_print("Pulso:      us");
    while (1) {
        RC2 = 1;                             /* pulso de 1000 + 4·pos µs */
        __delay_us(1000);
        for (uint8_t i = pos; i; i--) __delay_us(3);   /* ~4 µs por vuelta */
        RC2 = 0;
        GO_nDONE = 1; while (GO_nDONE);
        pos = ADRESH;
        angulo = (uint8_t)(((uint16_t)pos * 180) >> 8);
        ancho = 1000 + 4u * pos;
        lcd_goto(0, 8);
        lcd_char('0' + angulo / 100); lcd_char('0' + (angulo / 10) % 10); lcd_char('0' + angulo % 10); lcd_char((char)0xDF);
        lcd_goto(1, 7);
        lcd_char('0' + ancho / 1000); lcd_char('0' + (ancho / 100) % 10); lcd_char('0' + (ancho / 10) % 10); lcd_char('0' + ancho % 10);
        __delay_ms(17);                      /* completa el periodo */
    }
}
