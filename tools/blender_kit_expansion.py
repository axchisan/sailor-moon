# Segundo kit del parque: el portal y lo que hace falta para poblar el campo.
#
# POR QUÉ UN KIT NUEVO
#
# El primer kit vestía un pasillo: árboles, vallas, bancos. Con el parque
# extendido y campo abierto alrededor, hace falta otra cosa — sitios a los que
# ir y cosas que se lean como puntos de interés, no como relleno.
#
# EL PORTAL
#
# Era un aro de luz puesto por código, y un aro no dice nada: podría ser un
# charco. Ahora es una **puerta de piedra** con dos pilares tallados, un dintel
# curvo y un cristal flotando en el centro. Se lee como algo antiguo que estaba
# ahí antes que el parque, que es justo la sensación que pide el sitio por el
# que se sale hacia otro mundo.
#
# Reutiliza el estilo del primer kit: mismas paletas, mismas texturas
# procedurales, mismo tamaño de mancha. Un prop que se salga del estilo canta
# más que uno feo.
#
# Uso desde el MCP de Blender:
#   exec(open("tools/blender_kit_parque.py").read())      # trae los ayudantes
#   exec(open("tools/blender_kit_expansion.py").read())
#   result = generar_expansion()

import bpy
import math
import os

# Se apoya en el primer kit: `_pieza`, `_unir`, `_caja`, `_cilindro`, `_esfera`,
# `PALETA` y `RECETA_TEXTURA` vienen de ahí. Hay que haberlo ejecutado antes.
PALETA.update({
    "piedra_antigua": (0.52, 0.50, 0.55),
    "runa":           (0.55, 0.86, 0.92),
    "cristal":        (0.78, 0.62, 0.95),
    "agua":           (0.42, 0.68, 0.82),
    "flor_campo":     (0.96, 0.76, 0.42),
    "flor_campo_alt": (0.92, 0.52, 0.62),
    "musgo":          (0.38, 0.56, 0.32),
})

RECETA_TEXTURA.update({
    "piedra_antigua": {"manchas": 120, "claro": (0.63, 0.61, 0.66), "grano": 0.08},
    "runa":     {"grano": 0.02, "claro": (0.72, 0.96, 1.00)},
    "cristal":  {"grano": 0.03, "claro": (0.92, 0.80, 1.00)},
    "agua":     {"manchas": 40, "claro": (0.58, 0.80, 0.92), "grano": 0.03},
    "flor_campo": {"manchas": 200, "claro": (1.00, 0.90, 0.60), "grano": 0.05},
    "flor_campo_alt": {"manchas": 200, "claro": (1.00, 0.72, 0.80), "grano": 0.05},
    "musgo":    {"manchas": 150, "claro": (0.50, 0.68, 0.40), "grano": 0.07},
})


def portal_antiguo():
    """La puerta a otro escenario: dos pilares, dintel curvo y cristal.

    Va en piedra clara con vetas y algo de musgo, no en el gris del kit normal:
    tiene que leerse como **más viejo que el parque**. El cristal y las runas
    son piezas aparte para poder encenderlos desde el juego sin tocar el resto.
    """
    bm = bmesh.new()
    # Peana escalonada. Tres escalones dicen «esto es importante» mucho mejor
    # que un pedestal liso, y de paso resuelve el encuentro con el suelo.
    _cilindro(bm, (0, 0, 0.10), 2.60, 2.60, 0.20, lados=12)
    _cilindro(bm, (0, 0, 0.30), 2.25, 2.25, 0.22, lados=12)
    _cilindro(bm, (0, 0, 0.50), 1.95, 1.95, 0.20, lados=12)

    # Pilares: dos bloques con la cara interior rebajada, para que la puerta se
    # lea como un hueco y no como dos columnas sueltas.
    for signo in (-1, 1):
        _caja(bm, (signo * 1.45, 0, 1.75), (0.62, 0.62, 2.60))
        _caja(bm, (signo * 1.45, 0, 3.15), (0.78, 0.78, 0.28))
        _caja(bm, (signo * 1.45, 0, 0.72), (0.80, 0.80, 0.26))

    # Dintel en arco, por tramos. Un travesaño recto lo dejaría en portería.
    for i in range(7):
        t = (i + 0.5) / 7.0
        angulo = math.pi * t
        x = math.cos(angulo) * 1.45
        z = 3.30 + math.sin(angulo) * 0.62
        _caja(bm, (x, 0, z), (0.52, 0.62, 0.42), giro=0.0)
    piedra = _pieza("portal_piedra", "piedra_antigua", bm)

    # Runas: tiras finas hundidas en la cara interior de cada pilar.
    bm = bmesh.new()
    for signo in (-1, 1):
        for i in range(4):
            _caja(bm, (signo * 1.12, 0, 1.05 + i * 0.62), (0.06, 0.30, 0.22))
    runas = _pieza("portal_runas", "runa", bm)

    # El cristal, flotando en el centro del hueco. Es lo que se enciende.
    bm = bmesh.new()
    _esfera(bm, Vector((0, 0, 2.30)), 0.42, achatado=1.35, cortes=6, ruido=0.0)
    _esfera(bm, Vector((0, 0, 2.30)), 0.24, achatado=1.6, cortes=5, ruido=0.0)
    cristal = _pieza("portal_cristal", "cristal", bm)

    return _unir("portal_antiguo", [piedra, runas, cristal])


def puente_madera():
    """Puente arqueado de tres metros, para cruzar el arroyo."""
    bm = bmesh.new()
    # Tablero en arco: nueve tablas, cada una un poco más alta hacia el centro.
    for i in range(9):
        t = (i + 0.5) / 9.0
        y = -1.5 + t * 3.0
        z = 0.28 + math.sin(math.pi * t) * 0.42
        _caja(bm, (0, y, z), (1.70, 0.30, 0.10))
    tablero = _pieza("puente_tablero", "madera", bm)

    bm = bmesh.new()
    # Barandillas: postes cortos siguiendo la curva, y pasamanos por tramos.
    for signo in (-1, 1):
        for i in range(5):
            t = (i + 0.5) / 5.0
            y = -1.5 + t * 3.0
            z = 0.28 + math.sin(math.pi * t) * 0.42
            _caja(bm, (signo * 0.78, y, z + 0.34), (0.10, 0.10, 0.58))
            _caja(bm, (signo * 0.78, y, z + 0.62), (0.12, 0.66, 0.09))
    baranda = _pieza("puente_baranda", "madera_oscura", bm)

    return _unir("puente_madera", [tablero, baranda])


def roca_grande():
    """Peñasco. Para los cúmulos que cierran rincones del campo."""
    bm = bmesh.new()
    _esfera(bm, Vector((0, 0, 0.85)), 1.35, achatado=0.72, ruido=0.34, cortes=7)
    _esfera(bm, Vector((0.85, 0.35, 0.45)), 0.70, achatado=0.75, ruido=0.36, cortes=6)
    _esfera(bm, Vector((-0.70, -0.40, 0.38)), 0.58, achatado=0.78, ruido=0.38, cortes=6)
    return _pieza("roca_grande", "piedra", bm)


def macizo_flores():
    """Mancha de flores de campo. Va en multimalla, así que muy pocos tris."""
    bm = bmesh.new()
    _esfera(bm, Vector((0, 0, 0.16)), 0.34, achatado=0.55, ruido=0.28, cortes=6)
    verde = _pieza("flores_mata", "musgo", bm)

    bm = bmesh.new()
    # Las flores son motas encima: a la escala a la que se ven, una corola
    # modelada no aporta nada y multiplica los triángulos por veinte.
    for i in range(7):
        angulo = math.tau * i / 7.0
        r = 0.10 + (i % 3) * 0.08
        _esfera(bm, Vector((math.cos(angulo) * r, math.sin(angulo) * r,
                            0.30 + (i % 2) * 0.06)), 0.075, cortes=4)
    flores = _pieza("flores_corolas", "flor_campo", bm)

    return _unir("macizo_flores", [verde, flores])


def tocon():
    """Tronco cortado con musgo. Sirve de asiento, de plataforma baja y de
    excusa para que un claro parezca un claro."""
    bm = bmesh.new()
    _cilindro(bm, (0, 0, 0.32), 0.52, 0.46, 0.64, lados=9)
    madera = _pieza("tocon_madera", "corteza", bm)

    bm = bmesh.new()
    _cilindro(bm, (0, 0, 0.655), 0.44, 0.44, 0.05, lados=9)
    _esfera(bm, Vector((0.34, 0.18, 0.60)), 0.20, achatado=0.5, ruido=0.3, cortes=5)
    tapa = _pieza("tocon_musgo", "musgo", bm)

    return _unir("tocon", [madera, tapa])


def farolillo():
    """Farolillo de papel colgado de un palo. Marca sendas por el campo."""
    bm = bmesh.new()
    _cilindro(bm, (0, 0, 1.05), 0.06, 0.05, 2.10, lados=6)
    _caja(bm, (0.18, 0, 2.05), (0.40, 0.05, 0.05))
    palo = _pieza("farolillo_palo", "madera_oscura", bm)

    bm = bmesh.new()
    _esfera(bm, Vector((0.34, 0, 1.82)), 0.24, achatado=1.15, cortes=7)
    papel = _pieza("farolillo_papel", "farol", bm)

    return _unir("farolillo", [palo, papel])


def nenufar():
    """Hoja de nenúfar con flor. Para el estanque."""
    bm = bmesh.new()
    _cilindro(bm, (0, 0, 0.03), 0.46, 0.46, 0.06, lados=9)
    hoja = _pieza("nenufar_hoja", "hoja", bm)

    bm = bmesh.new()
    _esfera(bm, Vector((0.10, 0.06, 0.14)), 0.13, achatado=0.9, cortes=5)
    flor = _pieza("nenufar_flor", "flor_campo_alt", bm)

    return _unir("nenufar", [hoja, flor])


def generar_expansion():
    _limpiar()
    piezas = {}
    for hacer in (portal_antiguo, puente_madera, roca_grande, macizo_flores,
                  tocon, farolillo, nenufar):
        objeto = hacer()
        piezas[objeto.name] = _exportar(objeto)
    return piezas
