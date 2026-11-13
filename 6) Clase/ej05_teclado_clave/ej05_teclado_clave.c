/* Ejemplo 5 · Cerradura con teclado 4x4 (filas RB0-RB3, columnas RB4-RB7) y LCD (MPLAB X + XC8)
   Clave 1234, 'C' borra, '=' confirma. RC0 = verde, RC1 = rojo, RC2 = relé. */
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

const char TECLAS[16] = "789/456*123-C0=+";

char escanear(void) {                        /* devuelve la tecla o 0 */
    for (uint8_t f = 0; f < 4; f++) {
        PORTB = (uint8_t)~(1 << f);          /* solo la fila f en 0 */
        __delay_us(5);
        uint8_t col = (uint8_t)((~PORTB >> 4) & 0x0F);
        for (uint8_t c = 0; c < 4; c++)
            if (col & (1 << c)) return TECLAS[f * 4 + c];
    }
    return 0;
}

void esperar_250ms(uint8_t n) { while (n--) __delay_ms(250); }

void main(void) {
    char clave[4], t;
    uint8_t n = 0, intentos = 0;
    OPTION_REGbits.nRBPU = 0;
    TRISB = 0xF0; TRISC = 0xF8; PORTC = 0;
    lcd_init();
nueva:
    PORTC = 0; n = 0;
    lcd_cmd(0x01); lcd_print("Ingrese la clave");
    lcd_goto(1, 0); lcd_print("> ");
    while (1) {
        t = escanear();
        if (!t) continue;
        __delay_ms(20);
        while (escanear());                  /* espera a soltar */
        __delay_ms(20);
        if (t == 'C') goto nueva;
        if (t == '=') break;
        if (t >= '0' && t <= '9' && n < 4) { clave[n++] = t; lcd_char('*'); }
    }
    lcd_goto(1, 0);
    if (n == 4 && clave[0] == '1' && clave[1] == '2' && clave[2] == '3' && clave[3] == '4') {
        intentos = 0; PORTC = 0x05;          /* verde + relé */
        lcd_print("ACCESO CONCEDIDO"); esperar_250ms(12);
    } else if (++intentos < 3) {
        PORTC = 0x02; lcd_print("CLAVE INCORRECTA"); esperar_250ms(8);
    } else {
        intentos = 0; lcd_print("BLOQUEADO  10 s ");
        for (uint8_t i = 0; i < 20; i++) { PORTC ^= 0x02; esperar_250ms(2); }
    }
    goto nueva;
}
