"""Terminal serie sencilla para los ejemplos 1 y 12.

Escribe una letra y Enter para enviarla al PIC; lo que el PIC responde aparece solo.
    ejemplo 1:  1..8 invierte un LED · A todos · B ninguno · ? estado
    ejemplo 12: P solicitud peatonal · S estado

Uso:
    pip install pyserial
    python terminal_pic.py --puerto COM3        (Proteus: COMPIM en COM4, par com0com COM3 <-> COM4)
"""
import argparse, threading, sys


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--puerto', default='COM3'); ap.add_argument('--baudios', type=int, default=9600)
    a = ap.parse_args()
    import serial
    s = serial.Serial(a.puerto, a.baudios, timeout=0.1)
    print(f'Conectado a {a.puerto} ({a.baudios} 8N1). Ctrl+C para salir.')

    def leer():
        while True:
            d = s.read(64)
            if d: sys.stdout.write(d.decode('ascii', 'ignore')); sys.stdout.flush()

    threading.Thread(target=leer, daemon=True).start()
    try:
        while True:
            txt = input()
            if txt: s.write(txt.encode('ascii', 'ignore'))
    except (KeyboardInterrupt, EOFError):
        print('\nfin'); s.close()


if __name__ == '__main__':
    main()
