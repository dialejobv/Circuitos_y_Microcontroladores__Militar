/* Ejemplo 3 · LM35 en AN0 y LDR en AN1 con LCD 16x2 (MPLAB X + XC8)
   RB0 = ventilador (T > 30 °C), RB1 = lámpara (luz < 30 %). */
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
    ADCON0 = (uint8_t)(0x41 | (canal << 3));   /* Fosc/8, canal, ADC encendido */
    __delay_us(50);                            /* adquisición */
    GO_nDONE = 1;
    while (GO_nDONE);
    return (uint16_t)((ADRESH << 8) | ADRESL);
}

void main(void) {
    uint16_t adc, decimas;
    uint8_t luz;
    TRISB = 0x00; PORTB = 0x00;
    ADCON1 = 0x84;                             /* justificado a la derecha; AN0, AN1, AN3 analógicos */
    lcd_init();
    lcd_goto(0, 0); lcd_print("Temp:");
    lcd_goto(1, 0); lcd_print("Luz:");
    while (1) {
        adc = leer_adc(0);
        decimas = (uint16_t)(((uint32_t)adc * 625) >> 7);   /* 4,883 mV por paso / 10 mV/°C */
        lcd_goto(0, 6);
        lcd_char(decimas >= 1000 ? '0' + decimas / 1000 : ' ');
        lcd_char('0' + (decimas / 100) % 10);
        lcd_char('0' + (decimas / 10) % 10);
        lcd_char('.');
        lcd_char('0' + decimas % 10);
        lcd_char((char)0xDF); lcd_char('C');
        RB0 = (decimas > 300);

        adc = leer_adc(1);
        luz = (uint8_t)(((uint32_t)adc * 25) >> 8);         /* 0..99 % */
        lcd_goto(1, 7);
        lcd_char(luz >= 100 ? '1' : ' ');
        lcd_char(luz >= 10 ? '0' + (luz / 10) % 10 : ' ');
        lcd_char('0' + luz % 10);
        lcd_char('%');
        RB1 = (luz < 30);
        __delay_ms(250);
    }
}
