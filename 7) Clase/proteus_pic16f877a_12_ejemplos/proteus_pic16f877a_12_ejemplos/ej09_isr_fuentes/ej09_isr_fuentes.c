/* Ejemplo 9 · Interrupciones: INT, cambio en RB4-RB7, ADC y TMR0 en una sola ISR (MPLAB X + XC8) */
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

volatile uint8_t pulsos = 0, tecla = 0, t0cnt = 0, cambio = 1;
volatile uint16_t adc = 0;

void __interrupt() isr(void) {
    if (INTE && INTF) { INTF = 0; pulsos++; cambio = 1; }          /* 1) INT */
    if (RBIF) {                                                    /* 2) cambio en RB4-RB7 */
        uint8_t b = PORTB; RBIF = 0;                               /* leer PORTB termina el cambio */
        for (uint8_t k = 4; k < 8; k++) if (!(b & (1 << k))) tecla = k;
        cambio = 1;
    }
    if (ADIF) { ADIF = 0; adc = (uint16_t)((ADRESH << 8) | ADRESL); cambio = 1; }   /* 3) ADC */
    if (TMR0IF) {                                                  /* 4) TMR0 cada 65,5 ms */
        TMR0IF = 0; GO_nDONE = 1;
        if (++t0cnt >= 4) { t0cnt = 0; RC0 ^= 1; }
    }
}

void main(void) {
    TRISC0 = 0; RC0 = 0;
    OPTION_REG = 0x07;                                  /* pull-ups, INT en bajada, TMR0 1:256 */
    ADCON1 = 0x8E; ADCON0 = 0x41; ADIE = 1;
    lcd_init();
    (void)PORTB; RBIF = 0;
    INTCON = 0xF8;                                      /* GIE PEIE T0IE INTE RBIE */
    while (1) {
        if (!cambio) continue;
        cambio = 0;
        GIE = 0; uint16_t a = adc; uint8_t p = pulsos, t = tecla; GIE = 1;   /* copia atómica */
        lcd_goto(0, 0); lcd_print("INT=");
        lcd_char('0' + p / 100); lcd_char('0' + (p / 10) % 10); lcd_char('0' + p % 10);
        lcd_print("  RB="); lcd_char(t ? '0' + t : '-');
        lcd_goto(1, 0); lcd_print("ADC=");
        lcd_char('0' + a / 1000); lcd_char('0' + (a / 100) % 10); lcd_char('0' + (a / 10) % 10); lcd_char('0' + a % 10);
    }
}
