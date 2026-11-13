/* Ejemplo 2 · Tres juegos (PONG, CARRERA, SALTO) en OLED SSD1306 128x64 por SPI (MPLAB X + XC8)
   Cristal de 20 MHz. SCK = RC3, SDO = RC5, CS = RC0, D/C = RC1, RES = RC2.
   Pulsadores (pull-ups internos): RB0 = ARRIBA, RB1 = ABAJO, RB2 = OK / SALTAR.
   La RAM del PIC (368 bytes) no alcanza para una copia de la pantalla (1024 bytes):
   cada objeto se borra y se vuelve a dibujar directamente en la memoria del SSD1306. */
#include <xc.h>
#include <stdint.h>
#pragma config FOSC = HS, WDTE = OFF, PWRTE = ON, BOREN = OFF, LVP = OFF, CPD = OFF, WRT = OFF, CP = OFF
#define _XTAL_FREQ 20000000UL
#define OLED_CS  RC0
#define OLED_DC  RC1
#define OLED_RES RC2

const uint8_t FUENTE[59][5] = {               /* ASCII 32..90 */
 {0x00,0x00,0x00,0x00,0x00},{0x00,0x00,0x5F,0x00,0x00},{0x00,0x07,0x00,0x07,0x00},{0x14,0x7F,0x14,0x7F,0x14},
 {0x24,0x2A,0x7F,0x2A,0x12},{0x23,0x13,0x08,0x64,0x62},{0x36,0x49,0x55,0x22,0x50},{0x00,0x05,0x03,0x00,0x00},
 {0x00,0x1C,0x22,0x41,0x00},{0x00,0x41,0x22,0x1C,0x00},{0x08,0x2A,0x1C,0x2A,0x08},{0x08,0x08,0x3E,0x08,0x08},
 {0x00,0x50,0x30,0x00,0x00},{0x08,0x08,0x08,0x08,0x08},{0x00,0x60,0x60,0x00,0x00},{0x20,0x10,0x08,0x04,0x02},
 {0x3E,0x51,0x49,0x45,0x3E},{0x00,0x42,0x7F,0x40,0x00},{0x42,0x61,0x51,0x49,0x46},{0x21,0x41,0x45,0x4B,0x31},
 {0x18,0x14,0x12,0x7F,0x10},{0x27,0x45,0x45,0x45,0x39},{0x3C,0x4A,0x49,0x49,0x30},{0x01,0x71,0x09,0x05,0x03},
 {0x36,0x49,0x49,0x49,0x36},{0x06,0x49,0x49,0x29,0x1E},{0x00,0x36,0x36,0x00,0x00},{0x00,0x56,0x36,0x00,0x00},
 {0x08,0x14,0x22,0x41,0x00},{0x14,0x14,0x14,0x14,0x14},{0x00,0x41,0x22,0x14,0x08},{0x02,0x01,0x51,0x09,0x06},
 {0x32,0x49,0x79,0x41,0x3E},{0x7E,0x11,0x11,0x11,0x7E},{0x7F,0x49,0x49,0x49,0x36},{0x3E,0x41,0x41,0x41,0x22},
 {0x7F,0x41,0x41,0x22,0x1C},{0x7F,0x49,0x49,0x49,0x41},{0x7F,0x09,0x09,0x01,0x01},{0x3E,0x41,0x41,0x51,0x32},
 {0x7F,0x08,0x08,0x08,0x7F},{0x00,0x41,0x7F,0x41,0x00},{0x20,0x40,0x41,0x3F,0x01},{0x7F,0x08,0x14,0x22,0x41},
 {0x7F,0x40,0x40,0x40,0x40},{0x7F,0x02,0x04,0x02,0x7F},{0x7F,0x04,0x08,0x10,0x7F},{0x3E,0x41,0x41,0x41,0x3E},
 {0x7F,0x09,0x09,0x09,0x06},{0x3E,0x41,0x51,0x21,0x5E},{0x7F,0x09,0x19,0x29,0x46},{0x46,0x49,0x49,0x49,0x31},
 {0x01,0x01,0x7F,0x01,0x01},{0x3F,0x40,0x40,0x40,0x3F},{0x1F,0x20,0x40,0x20,0x1F},{0x7F,0x20,0x18,0x20,0x7F},
 {0x63,0x14,0x08,0x14,0x63},{0x03,0x04,0x78,0x04,0x03},{0x61,0x51,0x49,0x45,0x43}};
const uint8_t CARRO[8]  = {0x24,0x5A,0xFF,0xFF,0xFF,0xFF,0x5A,0x24};
const uint8_t ROCA[8]   = {0x1E,0x3F,0x7F,0x7F,0x7F,0x7E,0x3C,0x18};
const uint8_t DINO[8]   = {0x18,0x30,0xE0,0x78,0xFF,0x3D,0x17,0x07};
const uint8_t CACTUS[6] = {0x1C,0x10,0xFF,0x08,0x0E,0x00};
const uint8_t SALTO_P[8] = {4,3,2,2,2,3,4,5};
const uint8_t INIT[] = {0xAE,0xD5,0x80,0xA8,0x3F,0xD3,0x00,0x40,0x8D,0x14,0x20,0x00,
                        0xA1,0xC8,0xDA,0x12,0x81,0xCF,0xD9,0xF1,0xDB,0x40,0xA4,0xA6,0xAF};

uint8_t prev, nuevo, btn, rnd = 0xA5, puntos;

/* ---------- SPI y SSD1306 ---------- */
void spi(uint8_t b) { SSPBUF = b; while (!SSPIF); SSPIF = 0; (void)SSPBUF; }
void comando(uint8_t c) { OLED_DC = 0; spi(c); }
void ventana(uint8_t x, uint8_t pag) {         /* escribe desde la columna x, página pag */
    comando(0x21); comando(x); comando(127);
    comando(0x22); comando(pag); comando(7);
    OLED_DC = 1;
}
void rellenar(uint8_t x, uint8_t pag, uint8_t n, uint8_t v) { ventana(x, pag); while (n--) spi(v); }
void sprite(uint8_t x, uint8_t pag, const uint8_t *s, uint8_t n, uint8_t vacio) {
    ventana(x, pag);
    while (n--) spi(*s++);
    while (vacio--) spi(0);                    /* borra lo que quedó detrás */
}
void borrar(void) { ventana(0, 0); for (uint16_t i = 0; i < 1024; i++) spi(0); }
void caracter(char c) { for (uint8_t i = 0; i < 5; i++) spi(FUENTE[c - 32][i]); spi(0); }
void texto(uint8_t x, uint8_t pag, const char *s) { ventana(x, pag); while (*s) caracter(*s++); }
void numero(uint8_t n) { caracter('0' + n / 100); caracter('0' + (n / 10) % 10); caracter('0' + n % 10); }
void oled_init(void) {
    OLED_CS = 0; OLED_RES = 0; __delay_ms(10); OLED_RES = 1; __delay_ms(10);
    for (uint8_t i = 0; i < sizeof(INIT); i++) comando(INIT[i]);
    borrar();
}

/* ---------- utilidades ---------- */
void leer_botones(void) { btn = (uint8_t)(~PORTB & 0x07); nuevo = btn & (uint8_t)~prev; prev = btn; }
uint8_t aleatorio(void) { uint8_t c = rnd & 1; rnd >>= 1; if (c) rnd ^= 0xB8; return rnd; }

void fin_del_juego(void) {
    __delay_ms(250);
    borrar();
    texto(22, 2, "FIN DEL JUEGO");
    texto(28, 4, "PUNTOS "); numero(puntos);
    texto(34, 6, "OK: MENU");
    do { __delay_ms(30); leer_botones(); } while (!(nuevo & 4));
}

/* ---------- juego 1: PONG ---------- */
void pong(void) {
    uint8_t bx, by, dx, dy, pad = 3, vidas = 3, pag;
    borrar(); puntos = 0;
    for (uint8_t p = 0; p < 8; p++) rellenar(127, p, 1, 0xFF);          /* pared derecha */
    while (vidas) {
        bx = 64; by = 32; dx = 1; dy = aleatorio() & 1;                  /* dx = 1: hacia la izquierda */
        while (1) {
            leer_botones();
            if ((btn & 1) && pad > 0) pad--;
            if ((btn & 2) && pad < 6) pad++;
            rellenar(bx, by >> 3, 4, 0);                                  /* borra la bola */
            if (dy) { if (by == 0) dy = 0; else by -= 4; } else { if (by == 60) dy = 1; else by += 4; }
            if (!dx) { if (bx == 120) dx = 1; else bx += 4; }
            else if (bx == 8 && (uint8_t)((by >> 3) - pad) < 2) { dx = 0; puntos++; }   /* golpe */
            else if (bx == 0) { vidas--; break; }                        /* falla */
            else bx -= 4;
            if (pad) rellenar(2, pad - 1, 3, 0);                         /* raqueta */
            rellenar(2, pad, 3, 0xFF); rellenar(2, pad + 1, 3, 0xFF);
            if (pad < 6) rellenar(2, pad + 2, 3, 0);
            pag = by >> 3;
            rellenar(bx, pag, 4, (by & 4) ? 0xF0 : 0x0F);                /* bola de 4x4 */
            __delay_ms(25);
        }
    }
}

/* ---------- juego 2: CARRERA ---------- */
void carrera(void) {
    uint8_t carro = 4, ox[3], op[3] = {0, 0, 0}, spawn = 1;
    borrar(); puntos = 0; texto(0, 0, "PUNTOS ");
    while (1) {
        leer_botones();
        uint8_t nueva = carro;
        if ((nuevo & 1) && carro > 1) nueva--;
        if ((nuevo & 2) && carro < 7) nueva++;
        if (nueva != carro) { rellenar(4, carro, 8, 0); carro = nueva; }
        for (uint8_t i = 0; i < 3; i++) {
            if (!op[i]) continue;                                         /* inactivo */
            if (ox[i] == 0) { rellenar(0, op[i], 12, 0); op[i] = 0; puntos++; continue; }
            ox[i] -= 4;
            sprite(ox[i], op[i], ROCA, 8, 4);
            if (op[i] == carro && ox[i] < 12) { fin_del_juego(); return; }
        }
        if (--spawn == 0) {
            spawn = (uint8_t)((aleatorio() & 7) + 5);
            for (uint8_t i = 0; i < 3; i++)
                if (!op[i]) { uint8_t c = aleatorio() & 7; op[i] = c ? c : 7; ox[i] = 116; break; }
        }
        sprite(4, carro, CARRO, 8, 0);
        ventana(48, 0); numero(puntos);
        __delay_ms(30);
    }
}

/* ---------- juego 3: SALTO ---------- */
void salto(void) {
    uint8_t dino = 5, salto = 0, cx = 116, espera = 10, nueva;
    borrar(); puntos = 0; texto(0, 0, "PUNTOS ");
    rellenar(0, 6, 128, 0x01);                                            /* suelo */
    while (1) {
        leer_botones();
        if ((nuevo & 5) && !salto) salto = 1;
        if (salto) {
            nueva = SALTO_P[salto - 1];
            if (++salto == 9) salto = 0;
            if (nueva != dino) { rellenar(8, dino, 8, 0); dino = nueva; }
        }
        if (espera) espera--;
        else if (cx == 0) { rellenar(0, 5, 10, 0); puntos++; cx = 116; espera = aleatorio() & 15; }
        else {
            cx -= 4;
            sprite(cx, 5, CACTUS, 6, 4);
            if (dino == 5 && cx >= 4 && cx < 16) { fin_del_juego(); return; }
        }
        sprite(8, dino, DINO, 8, 0);
        ventana(48, 0); numero(puntos);
        __delay_ms(35);
    }
}

void main(void) {
    uint8_t sel = 0;
    OPTION_REGbits.nRBPU = 0;
    TRISC = 0b11010000;
    SSPSTAT = 0x40;                          /* CKE = 1 */
    SSPCON = 0x20;                           /* SPI maestro, Fosc/4 */
    oled_init();
    while (1) {
        borrar();
        texto(28, 0, "PIC JUEGOS");
        texto(22, 2, "1 PONG"); texto(22, 3, "2 CARRERA"); texto(22, 4, "3 SALTO");
        texto(0, 7, "ARRIBA/ABAJO  OK");
        while (1) {
            ventana(12, sel + 2); caracter('>');
            __delay_ms(30); aleatorio(); leer_botones();
            if (nuevo & 3) {
                ventana(12, sel + 2); caracter(' ');
                if (nuevo & 1) sel = sel ? sel - 1 : 2; else sel = (sel == 2) ? 0 : sel + 1;
            }
            if (nuevo & 4) break;
        }
        if (sel == 0) { pong(); fin_del_juego(); }
        else if (sel == 1) carrera();
        else salto();
    }
}
