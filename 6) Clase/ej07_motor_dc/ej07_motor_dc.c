/* Ejemplo 7 · Motor DC con L293D: PWM en RC2/CCP1 (EN1), sentido con RC0 (IN1) y RC1 (IN2) (MPLAB X + XC8)
   Pot en AN0 = velocidad. RB0 adelante, RB1 atrás, RB2 parar. */
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

void sentido(uint8_t in1, uint8_t in2, const char *txt) {
    RC0 = in1; RC1 = in2;
    lcd_goto(1, 0); lcd_print(txt);
}

void main(void) {
    uint8_t vel, pct, teclas;
    OPTION_REGbits.nRBPU = 0;
    TRISC = 0xF8; PORTC = 0;
    ADCON1 = 0x0E; ADCON0 = 0x41;
    PR2 = 255;                               /* 3,9 kHz con preescalador 1 */
    CCPR1L = 0; CCP1CON = 0x0C;              /* PWM */
    T2CON = 0x04;                            /* TMR2 encendido */
    lcd_init();
    lcd_goto(0, 0); lcd_print("Motor DC  L293D");
    sentido(0, 0, "PARADO  ");
    while (1) {
        __delay_us(50);
        GO_nDONE = 1; while (GO_nDONE);
        vel = ADRESH;
        CCPR1L = vel;                        /* ciclo útil = vel / 256 */
        teclas = (uint8_t)(~PORTB & 0x07);
        if (teclas & 1) sentido(1, 0, "ADELANTE");
        if (teclas & 2) sentido(0, 1, "ATRAS   ");
        if (teclas & 4) sentido(0, 0, "PARADO  ");
        pct = (uint8_t)(((uint16_t)vel * 101) >> 8);
        lcd_goto(1, 11);
        lcd_char(pct >= 100 ? '1' : ' '); lcd_char('0' + (pct / 10) % 10); lcd_char('0' + pct % 10); lcd_char('%');
        __delay_ms(100);
    }
}
