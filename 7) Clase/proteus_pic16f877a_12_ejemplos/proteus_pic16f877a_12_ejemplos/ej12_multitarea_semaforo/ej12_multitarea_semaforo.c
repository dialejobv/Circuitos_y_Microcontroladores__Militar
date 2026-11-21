/* Ejemplo 12 · Multitarea: semáforo + latido + comandos por USART (MPLAB X + XC8)
   P = solicitud peatonal · S = estado · RB0..RB4 semáforo · RB5 espere · RB7 latido */
#include <xc.h>
#include <stdint.h>
#pragma config FOSC = XT, WDTE = OFF, PWRTE = ON, BOREN = OFF, LVP = OFF, CPD = OFF, WRT = OFF, CP = OFF
#define _XTAL_FREQ 4000000UL
/* ---------- USART 9600 baudios (4 MHz, BRGH = 1, SPBRG = 25) ---------- */
void uart_init(void) { SPBRG = 25; TXSTA = 0x24; RCSTA = 0x90; }
void uart_tx(char c) { while (!TXIF); TXREG = c; }
void uart_print(const char *s) { while (*s) uart_tx(*s++); }

enum { VERDE, AMARILLO, ROJO, DESPEJE };
const uint8_t LUCES[4] = {0x0C, 0x0A, 0x11, 0x09};
const char *NOMBRE[4] = {"VERDE", "AMARILLO", "ROJO (pasa el peaton)", "TODO EN ROJO"};
volatile uint8_t ticks = 0, ms10 = 0, rxflag = 0;
volatile char rxdato;
uint8_t estado = VERDE, tiempo = 0, solicitud = 0;

void __interrupt() isr(void) {
    if (TMR0IF) { TMR0IF = 0; TMR0 += 6; if (++ms10 >= 10) { ms10 = 0; ticks++; } }
    if (RCIF) { rxdato = RCREG; rxflag = 1; }
}

void anunciar(void) { uart_print("Semaforo: "); uart_print(NOMBRE[estado]); uart_print("\r\n"); }
void cambiar(uint8_t e) {
    estado = e; tiempo = 0;
    PORTB = (uint8_t)((PORTB & 0xA0) | LUCES[estado]);
    anunciar();
}

void tarea_serie(void) {
    if (!rxflag) return;
    rxflag = 0;
    char c = (char)(rxdato & 0xDF);
    if (c == 'P') { solicitud = 1; RB5 = 1; uart_print("Solicitud peatonal registrada\r\n"); }
    if (c == 'S') anunciar();
}

void tarea_semaforo(void) {                            /* cada 100 ms */
    tiempo++;
    switch (estado) {
        case VERDE:    if (tiempo >= 80 || (solicitud && tiempo >= 30)) cambiar(AMARILLO); break;
        case AMARILLO: if (tiempo >= 20) { solicitud = 0; RB5 = 0; cambiar(ROJO); } break;
        case ROJO:     if (tiempo >= 50) cambiar(DESPEJE); break;
        default:       if (tiempo >= 10) cambiar(VERDE);
    }
}

void main(void) {
    uint8_t c_sem = 10, c_lat = 30;
    TRISB = 0; PORTB = 0;
    OPTION_REG = 0x01;
    uart_init(); RCIE = 1;
    uart_print("PIC16F877A multitarea: P = solicitud peatonal, S = estado\r\n");
    cambiar(VERDE);
    INTCON = 0xE0;                                      /* GIE PEIE T0IE */
    while (1) {
        if (!ticks) continue;
        GIE = 0; ticks--; GIE = 1;
        tarea_serie();                                  /* cada 10 ms */
        if (--c_sem == 0) { c_sem = 10; tarea_semaforo(); }
        if (--c_lat == 0) { c_lat = 30; RB7 ^= 1; }
    }
}
