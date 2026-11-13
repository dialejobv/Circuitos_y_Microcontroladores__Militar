"""
YOLO + PIC16F877A (ejemplo 4): detecta carros, motos y personas con la cámara (o un video / imagen)
y envía una letra al PIC por el puerto serie a 9600 baudios.

    C = carro (LED verde)   M = moto (LED rojo)   P = persona (LED amarillo)   N = nada

Instalación (en el PC):   pip install ultralytics pyserial opencv-python
Uso:
    python yolo_pic.py --puerto COM3                 # cámara web
    python yolo_pic.py --puerto COM3 --fuente video.mp4
    python yolo_pic.py --listar                      # muestra los puertos serie disponibles
    python yolo_pic.py --sin-pic                     # solo detección, sin puerto serie

Con Proteus: instale un par de puertos virtuales (com0com en Windows, p. ej. COM3 <-> COM4),
ponga un COMPIM en el esquema con Physical Port = COM4, 9600 baudios, y ejecute este programa con --puerto COM3.
Con el PIC real: use un conversor USB-serie TTL (CH340, CP2102, FT232) conectado a RC6/TX y RC7/RX.
"""
import argparse, time

CLASES = {'car': 'C', 'truck': 'C', 'bus': 'C', 'motorcycle': 'M', 'bicycle': 'M', 'person': 'P'}
PRIORIDAD = ['M', 'C', 'P']          # si hay varios objetos, la moto tiene prioridad, luego el carro


def decidir(nombres_detectados):
    letras = {CLASES[n] for n in nombres_detectados if n in CLASES}
    for l in PRIORIDAD:
        if l in letras: return l
    return 'N'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--puerto', default='COM3')
    ap.add_argument('--baudios', type=int, default=9600)
    ap.add_argument('--fuente', default='0', help='0 = cámara web, o la ruta de un video o imagen')
    ap.add_argument('--modelo', default='yolov8n.pt')
    ap.add_argument('--confianza', type=float, default=0.45)
    ap.add_argument('--listar', action='store_true')
    ap.add_argument('--sin-pic', action='store_true')
    a = ap.parse_args()

    if a.listar:
        from serial.tools import list_ports
        for p in list_ports.comports(): print(p.device, '-', p.description)
        return

    import cv2
    from ultralytics import YOLO
    pic = None
    if not a.sin_pic:
        import serial
        pic = serial.Serial(a.puerto, a.baudios, timeout=0.05)
        time.sleep(2)                                   # el PIC termina de arrancar
        print('PIC:', pic.read(200).decode(errors='ignore').strip())

    modelo = YOLO(a.modelo)
    fuente = int(a.fuente) if a.fuente.isdigit() else a.fuente
    ultima = None
    for r in modelo.predict(source=fuente, stream=True, conf=a.confianza, verbose=False):
        nombres = [modelo.names[int(c)] for c in r.boxes.cls]
        letra = decidir(nombres)
        if letra != ultima:                             # solo envía cuando cambia la decisión
            print(f'{time.strftime("%H:%M:%S")}  detectado: {sorted(set(nombres)) or "-"}  ->  envía {letra}')
            if pic:
                pic.write(letra.encode())
                time.sleep(0.05)
                resp = pic.read(20).decode(errors='ignore').strip()
                if resp: print('   PIC responde:', resp)
            ultima = letra
        cv2.imshow('YOLO -> PIC16F877A (q para salir)', r.plot())
        if cv2.waitKey(1) & 0xFF == ord('q'): break
    cv2.destroyAllWindows()
    if pic: pic.close()


if __name__ == '__main__':
    main()
