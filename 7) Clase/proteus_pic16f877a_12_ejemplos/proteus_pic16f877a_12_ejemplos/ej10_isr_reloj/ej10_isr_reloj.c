/* Ejemplo 10 · Interrupciones: reloj HH:MM:SS con TMR1 (0,5 s) y ajuste por INT (MPLAB X + XC8) */
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

volatile uint8_t hh = 12, mm = 0, ss = 0, medio = 0, nuevo = 1;

void sumar_hora(void) { if (++hh >= 24) hh = 0; }
void sumar_min(void) { if (++mm >= 60) { mm = 0; sumar_hora(); } }

void __interrupt() isr(void) {
    if (TMR1IF) {
        TMR1IF = 0;
        TMR1ON = 0; TMR1H = 0x0B; TMR1L = 0xDC; TMR1ON = 1;      /* 65536 - 62500 */
        RC0 ^= 1;
        if (++medio >= 2) { medio = 0; if (++ss >= 60) { ss = 0; sumar_min(); } nuevo = 1; }
    }
    if (INTF) { INTF = 0; sumar_min(); nuevo = 1; }
}

void dos(uint8_t v) { lcd_char('0' + v / 10); lcd_char('0' + v % 10); }

void main(void) {
    uint8_t antes = 1;
    TRISC0 = 0; RC0 = 0;
    OPTION_REG = 0x00;                                  /* pull-ups, INT en bajada */
    lcd_init(); lcd_goto(0, 0); lcd_print("Reloj con TMR1");
    TMR1H = 0x0B; TMR1L = 0xDC; T1CON = 0x31; TMR1IE = 1;
    INTCON = 0xD0;                                      /* GIE PEIE INTE */
    while (1) {
        if (!RB1 && antes) { GIE = 0; sumar_hora(); GIE = 1; nuevo = 1; }
        antes = RB1;
        if (nuevo) { nuevo = 0; lcd_goto(1, 4); dos(hh); lcd_char(':'); dos(mm); lcd_char(':'); dos(ss); }
    }
}
