/* Ejemplo 1 · USART: terminal de comandos con interrupción de recepción (MPLAB X + XC8)
   LEDs en RB0..RB7 · 1..8 invierte un LED · A todos · B ninguno · ? estado */
#include <xc.h>
#include <stdint.h>
#pragma config FOSC = XT, WDTE = OFF, PWRTE = ON, BOREN = OFF, LVP = OFF, CPD = OFF, WRT = OFF, CP = OFF
#define _XTAL_FREQ 4000000UL
/* ---------- USART 9600 baudios (4 MHz, BRGH = 1, SPBRG = 25) ---------- */
void uart_init(void) { SPBRG = 25; TXSTA = 0x24; RCSTA = 0x90; }
void uart_tx(char c) { while (!TXIF); TXREG = c; }
void uart_print(const char *s) { while (*s) uart_tx(*s++); }

volatile char dato;
volatile uint8_t llego = 0;

void __interrupt() isr(void) {
    if (RCIF) { dato = RCREG; llego = 1; }   /* leer RCREG limpia RCIF */
}

void informar(void) {
    uart_print("LEDS = ");
    for (int8_t b = 7; b >= 0; b--) uart_tx((PORTB >> b) & 1 ? '1' : '0');
    uart_print("\r\n");
}

void main(void) {
    TRISB = 0x00; PORTB = 0x00;
    uart_init();
    RCIE = 1; PEIE = 1; GIE = 1;
    uart_print("PIC16F877A - USART 9600 8N1\r\n");
    uart_print("1-8: invierte un LED  A: todos  B: ninguno  ?: estado\r\n");
    while (1) {
        if (OERR) { CREN = 0; CREN = 1; }
        if (!llego) continue;
        llego = 0;
        char c = dato;
        if (c == '?') { informar(); continue; }
        if ((c & 0xDF) == 'A') { PORTB = 0xFF; informar(); continue; }
        if ((c & 0xDF) == 'B') { PORTB = 0x00; informar(); continue; }
        if (c >= '1' && c <= '8') { PORTB ^= (uint8_t)(1 << (c - '1')); informar(); }
    }
}
