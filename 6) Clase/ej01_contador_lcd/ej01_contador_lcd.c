/* Ejemplo 1 · Contador 0000-9999 en LCD 16x2 con tres pulsadores (MPLAB X + XC8)
   RB0 = subir, RB1 = bajar, RB2 = reiniciar (pull-ups internos). LCD en PORTD. */
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

void mostrar(uint16_t n) {
    lcd_goto(1, 8);
    lcd_char('0' + n / 1000); lcd_char('0' + (n / 100) % 10);
    lcd_char('0' + (n / 10) % 10); lcd_char('0' + n % 10);
}

void main(void) {
    uint16_t cuenta = 0;
    uint8_t teclas;
    OPTION_REGbits.nRBPU = 0;               /* pull-ups de PORTB */
    TRISB = 0xFF;
    lcd_init();
    lcd_goto(0, 0); lcd_print("Contador 0-9999");
    lcd_goto(1, 0); lcd_print("Cuenta:");
    mostrar(cuenta);
    while (1) {
        teclas = (uint8_t)(~PORTB & 0x07);  /* 1 = presionado */
        if (!teclas) continue;
        __delay_ms(20);                      /* antirrebote */
        teclas = (uint8_t)(~PORTB & 0x07);
        if (!teclas) continue;
        if (teclas & 0x01) cuenta = (cuenta == 9999) ? 0 : cuenta + 1;
        if (teclas & 0x02) cuenta = (cuenta == 0) ? 9999 : cuenta - 1;
        if (teclas & 0x04) cuenta = 0;
        mostrar(cuenta);
        while (~PORTB & 0x07);               /* espera a que se suelten */
        __delay_ms(20);
    }
}
