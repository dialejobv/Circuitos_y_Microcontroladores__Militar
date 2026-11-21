/* Ejemplo 11 · Multitarea cooperativa con tick de 10 ms (MPLAB X + XC8)
   LED1 250 ms · LED2 400 ms · botón 20 ms · ADC→PWM 50 ms · LCD 500 ms */
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

volatile uint8_t ticks = 0, ms10 = 0;
uint8_t pulsos = 0, antes = 1, pot = 0;

void __interrupt() isr(void) {
    if (TMR0IF) { TMR0IF = 0; TMR0 += 6; if (++ms10 >= 10) { ms10 = 0; ticks++; } }
}

void tarea_led1(void) { RC0 ^= 1; }
void tarea_led2(void) { RC1 ^= 1; }
void tarea_boton(void) { if (!RB0 && antes) pulsos++; antes = RB0; }
void tarea_adc(void) { if (!GO_nDONE) { pot = ADRESH; CCPR1L = pot; GO_nDONE = 1; } }
void tres(uint8_t v) { lcd_char('0' + v / 100); lcd_char('0' + (v / 10) % 10); lcd_char('0' + v % 10); }
void tarea_lcd(void) { lcd_goto(0, 8); tres(pulsos); lcd_goto(1, 8); tres(pot); }

typedef struct { uint8_t periodo, cuenta; void (*f)(void); } tarea_t;
tarea_t tareas[] = { {25, 1, tarea_led1}, {40, 1, tarea_led2}, {2, 1, tarea_boton}, {5, 1, tarea_adc}, {50, 1, tarea_lcd} };

void main(void) {
    TRISC = 0xF8; PORTC = 0;
    OPTION_REG = 0x01;                                  /* pull-ups, TMR0 1:4 */
    ADCON1 = 0x0E; ADCON0 = 0x41;
    PR2 = 255; CCP1CON = 0x0C; T2CON = 0x04;
    lcd_init(); lcd_goto(0, 0); lcd_print("Pulsos:"); lcd_goto(1, 0); lcd_print("PWM   :");
    GO_nDONE = 1;
    INTCON = 0xA0;                                      /* GIE T0IE */
    while (1) {
        if (!ticks) continue;                           /* espera un tick */
        GIE = 0; ticks--; GIE = 1;
        for (uint8_t i = 0; i < sizeof(tareas) / sizeof(tareas[0]); i++)
            if (--tareas[i].cuenta == 0) { tareas[i].cuenta = tareas[i].periodo; tareas[i].f(); }
    }
}
