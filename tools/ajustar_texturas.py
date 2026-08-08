# Pone límite de tamaño y compresión de vídeo a las texturas del juego.
#
# POR QUÉ HACE FALTA
#
# Mixamo devuelve los personajes con texturas de 4096, y Godot las importa tal
# cual y sin comprimir. Con once personajes eso son 191 MB solo de PNG, y el
# APK se fue a 224 MB cuando antes pesaba 39.
#
# En un móvil el personaje ocupa como mucho un tercio de la pantalla, así que
# 1024 sobra de largo: la diferencia con 4096 no se ve, y el ahorro es de dos
# órdenes de magnitud.
#
# `compress/mode = 2` es compresión de VRAM (ETC2 en Android). Además de
# ocupar mucho menos en el APK, la GPU la descomprime sola, así que también
# ahorra memoria de vídeo mientras se juega.
#
# Uso:  python3 tools/ajustar_texturas.py  &&  Godot --headless --path . --import

import glob
import os
import re

# carpeta -> lado máximo en píxeles
LIMITES = [
    ("assets/models/characters", 1024),   # se ven a media distancia
    ("assets/models/props", 512),         # decorado, casi siempre lejos
    ("assets/models/pickups", 512),
]

AJUSTES = {
    "compress/mode": "2",          # VRAM comprimida
    "mipmaps/generate": "true",    # sin mipmaps, lo lejano hormiguea
    "detect_3d/compress_to": "0",  # ya está puesto a mano: que no lo cambie
}


def ajustar(ruta_import, limite):
    with open(ruta_import) as f:
        texto = f.read()

    claves = dict(AJUSTES)
    claves["process/size_limit"] = str(limite)

    cambiado = False
    for clave, valor in claves.items():
        patron = re.compile(r"^%s=.*$" % re.escape(clave), re.MULTILINE)
        linea = "%s=%s" % (clave, valor)
        if patron.search(texto):
            nuevo = patron.sub(linea, texto)
        elif "[params]" in texto:
            nuevo = texto.replace("[params]", "[params]\n" + linea, 1)
        else:
            continue
        if nuevo != texto:
            texto = nuevo
            cambiado = True

    if cambiado:
        with open(ruta_import, "w") as f:
            f.write(texto)
    return cambiado


def main():
    total, tocados = 0, 0
    for carpeta, limite in LIMITES:
        for png in glob.glob(os.path.join(carpeta, "*.png")):
            imp = png + ".import"
            if not os.path.isfile(imp):
                continue
            total += 1
            if ajustar(imp, limite):
                tocados += 1
    print("texturas revisadas: %d, ajustadas: %d" % (total, tocados))
    print("ahora hay que reimportar para que Godot las vuelva a generar")


if __name__ == "__main__":
    main()
