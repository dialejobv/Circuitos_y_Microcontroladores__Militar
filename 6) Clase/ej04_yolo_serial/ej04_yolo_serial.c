/* Ejemplo 4 · YOLO + PIC por USART 9600 baudios (MPLAB X + XC8)
   'C' carro -> LED verde RB0, 'M' moto -> LED rojo RB1, 'P' persona -> LED amarillo RB2, 'N' -> apagar. */
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

void uart_init(void) {
    SPBRG = 25; TXSTA = 0x24; RCSTA = 0x90;    /* 9615 baudios, BRGH = 1 */
}
void uart_tx(char c) { while (!TXIF); TXREG = c; }
void uart_print(const char *s) { while (*s) uart_tx(*s++); }

void main(void) {
    char c;
    TRISB = 0x00; PORTB = 0x00;
    uart_init();
    lcd_init();
    lcd_goto(0, 0); lcd_print("YOLO + PIC16F877");
    lcd_goto(1, 0); lcd_print("Esperando...    ");
    uart_print("PIC listo: envie C, M, P o N\r\n");
    while (1) {
        if (OERR) { CREN = 0; CREN = 1; }       /* reinicia el receptor si se desbordó */
        if (!RCIF) continue;
        c = (char)(RCREG & 0xDF);               /* a mayúscula */
        lcd_goto(1, 0);
        switch (c) {
            case 'C': PORTB = 0x01; lcd_print("Objeto: CARRO   "); break;
            case 'M': PORTB = 0x02; lcd_print("Objeto: MOTO    "); break;
            case 'P': PORTB = 0x04; lcd_print("Objeto: PERSONA "); break;
            case 'N': PORTB = 0x00; lcd_print("Objeto: ninguno "); break;
            default: continue;                  /* \r, \n u otros: se ignoran */
        }
        uart_print("OK:"); uart_tx(c); uart_print("\r\n");
    }
}
