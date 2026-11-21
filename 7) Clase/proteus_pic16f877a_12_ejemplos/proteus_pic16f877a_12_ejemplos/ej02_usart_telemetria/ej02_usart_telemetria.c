/* Ejemplo 2 · USART: telemetría cada 250 ms (MPLAB X + XC8)
   Pot en AN0, LM35 en AN1. Línea: AN0=0512 V=2.50 T=025.3C */
#include <xc.h>
#include <stdint.h>
#pragma config FOSC = XT, WDTE = OFF, PWRTE = ON, BOREN = OFF, LVP = OFF, CPD = OFF, WRT = OFF, CP = OFF
#define _XTAL_FREQ 4000000UL
/* ---------- USART 9600 baudios (4 MHz, BRGH = 1, SPBRG = 25) ---------- */
void uart_init(void) { SPBRG = 25; TXSTA = 0x24; RCSTA = 0x90; }
void uart_tx(char c) { while (!TXIF); TXREG = c; }
void uart_print(const char *s) { while (*s) uart_tx(*s++); }

uint16_t leer_adc(uint8_t canal) {
    ADCON0 = (uint8_t)(0x41 | (canal << 3));
    __delay_us(50);
    GO_nDONE = 1; while (GO_nDONE);
    return (uint16_t)((ADRESH << 8) | ADRESL);
}

void uart_num(uint16_t n, uint8_t digitos) {           /* n con 'digitos' cifras */
    char b[5];
    for (int8_t i = (int8_t)digitos - 1; i >= 0; i--) { b[i] = '0' + n % 10; n /= 10; }
    for (uint8_t i = 0; i < digitos; i++) uart_tx(b[i]);
}

void main(void) {
    TRISB = 0x00; PORTB = 0;
    ADCON1 = 0x84;                                       /* AN0, AN1, AN3; justificado a la derecha */
    uart_init();
    uart_print("PIC16F877A telemetria: AN0 (pot) y AN1 (LM35)\r\n");
    while (1) {
        uint16_t a0 = leer_adc(0);
        uint16_t mv = (uint16_t)(((uint32_t)a0 * 625) >> 7);
        uart_print("AN0="); uart_num(a0, 4);
        uart_print(" V="); uart_num(mv / 1000, 1); uart_tx('.'); uart_num((mv / 10) % 100, 2);
        uint16_t t = (uint16_t)(((uint32_t)leer_adc(1) * 625) >> 7);   /* décimas de °C */
        uart_print(" T="); uart_num(t / 10, 3); uart_tx('.'); uart_num(t % 10, 1);
        uart_print("C\r\n");
        PORTB ^= 1;
        __delay_ms(200);
    }
}
