#!/usr/bin/env python3
"""Baja efectos de sonido de Freesound filtrando por CC0.

    python3 tools/bajar_sonidos.py "stone impact heavy" audio_fuentes/freesound 3

Usa los *previews* públicos, que no piden cuenta. Son mp3 de calidad reducida y
para efectos cortos en un móvil dan de sobra — el original en WAV solo aportaría
peso. La URL del preview no se puede adivinar (lleva un sufijo por sonido), así
que se saca de la propia página.

**El filtro CC0 no es opcional.** Lo demás obliga a citar autor por autor, y una
lista de atribuciones que se lleva a mano acaba desincronizada del día que se
cambió un sonido.
"""

import re, subprocess, sys, urllib.parse, os
UA = "Mozilla/5.0"
def get(u):
    return subprocess.run(["curl","-sL","-m","40","-A",UA,u], capture_output=True).stdout.decode("utf8","ignore")

def buscar(q, n=6):
    u = ("https://freesound.org/search/?q=" + urllib.parse.quote(q) +
         "&f=" + urllib.parse.quote('license:"Creative Commons 0"') + "&s=score+desc")
    h = get(u)
    ids = []
    for m in re.finditer(r'/people/([^/]+)/sounds/(\d+)/', h):
        par = (m.group(1), m.group(2))
        if par not in ids:
            ids.append(par)
    return ids[:n]

def preview(user, sid):
    h = get("https://freesound.org/people/%s/sounds/%s/" % (user, sid))
    m = re.search(r'(previews/\d+/%s_[0-9]+)-lq\.mp3' % sid, h)
    if not m:
        return None
    return "https://cdn.freesound.org/" + m.group(1) + "-hq.mp3"

if __name__ == "__main__":
    q = sys.argv[1]; destino = sys.argv[2]; cuantos = int(sys.argv[3]) if len(sys.argv)>3 else 3
    os.makedirs(destino, exist_ok=True)
    hechos = 0
    for user, sid in buscar(q, 10):
        if hechos >= cuantos: break
        p = preview(user, sid)
        if not p: continue
        f = os.path.join(destino, "%s_%s.mp3" % (q.replace(" ","_")[:22], sid))
        r = subprocess.run(["curl","-sL","-m","60","-A",UA,"-o",f,p], capture_output=True)
        if os.path.exists(f) and os.path.getsize(f) > 8000:
            d = subprocess.run(["ffprobe","-v","error","-show_entries","format=duration","-of","csv=p=0",f],
                               capture_output=True).stdout.decode().strip()
            print("  %s  %ss  (id %s)" % (os.path.basename(f), d[:5], sid))
            hechos += 1
        elif os.path.exists(f):
            os.remove(f)
