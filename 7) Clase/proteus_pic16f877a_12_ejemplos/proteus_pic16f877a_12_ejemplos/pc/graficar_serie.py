"""Grafica en vivo la telemetría del ejemplo 2 (líneas "AN0=0512 V=2.50 T=025.3C").

Uso:
    pip install pyserial matplotlib
    python graficar_serie.py --puerto COM3          (Windows, par virtual com0com COM3 <-> COM4)
    python graficar_serie.py --puerto /dev/ttyUSB0  (PIC real con conversor USB-serie)
    python graficar_serie.py --demo                 (sin PIC: datos simulados)

En Proteus el COMPIM usa el otro extremo del par (COM4), 9600 baudios, 8N1.
"""
import argparse, re, math, random, time, collections

PATRON = re.compile(r'AN0=(\d+)\s+V=([\d.]+)\s+T=([\d.]+)C')


def lineas_demo():
    t = 0
    while True:
        an0 = int(512 + 400 * math.sin(t / 10))
        temp = 25 + 3 * math.sin(t / 25) + random.uniform(-0.2, 0.2)
        yield f'AN0={an0:04d} V={an0 * 5 / 1023:.2f} T={temp:05.1f}C'
        t += 1; time.sleep(0.25)


def lineas_serie(puerto, baudios):
    import serial
    with serial.Serial(puerto, baudios, timeout=1) as s:
        while True:
            txt = s.readline().decode('ascii', 'ignore').strip()
            if txt: yield txt


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--puerto', default='COM3'); ap.add_argument('--baudios', type=int, default=9600)
    ap.add_argument('--demo', action='store_true'); ap.add_argument('--csv', default='telemetria.csv')
    a = ap.parse_args()
    import matplotlib.pyplot as plt
    N = 200
    tt, vv, cc = (collections.deque(maxlen=N) for _ in range(3))
    plt.ion(); fig, (ax1, ax2) = plt.subplots(2, 1, sharex=True, figsize=(8, 5))
    l1, = ax1.plot([], [], color='#1f6fb2'); ax1.set_ylabel('AN0 (V)'); ax1.set_ylim(0, 5.2); ax1.grid(alpha=.3)
    l2, = ax2.plot([], [], color='#d1495b'); ax2.set_ylabel('LM35 (°C)'); ax2.set_xlabel('tiempo (s)'); ax2.grid(alpha=.3)
    fig.suptitle('Telemetría del PIC16F877A (ejemplo 2)')
    t0 = time.time(); fuente = lineas_demo() if a.demo else lineas_serie(a.puerto, a.baudios)
    with open(a.csv, 'w') as f:
        f.write('t,an0,v,t_c\n')
        for txt in fuente:
            m = PATRON.search(txt)
            if not m: print('?', txt); continue
            an0, v, temp = int(m.group(1)), float(m.group(2)), float(m.group(3))
            t = time.time() - t0; f.write(f'{t:.2f},{an0},{v},{temp}\n'); f.flush()
            tt.append(t); vv.append(v); cc.append(temp)
            l1.set_data(tt, vv); l2.set_data(tt, cc)
            ax1.set_xlim(max(0, t - 50), t + 1); ax2.relim(); ax2.autoscale_view(scalex=False)
            plt.pause(0.001)
            if not plt.fignum_exists(fig.number): break


if __name__ == '__main__':
    main()
