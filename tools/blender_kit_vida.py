# Tercer kit: lo que convierte un descampado bonito en un parque.
#
# QUÉ FALTABA
#
# Los dos primeros kits daban NATURALEZA —árboles, rocas, flores, agua— y
# mobiliario suelto de camino. Con eso, el parque ampliado seguía leyéndose como
# un campo con cosas puestas encima: bonito, pero sin ninguna señal de que
# alguien lo cuide o lo use.
#
# Lo que dice «parque» no son más árboles. Es lo ARTIFICIAL bien puesto: un
# puesto de dulces, materas alineadas, una fuente, un columpio, un cartel que
# indica por dónde se va. Cosas que solo existen porque hay gente.
#
# CÓMO SE USAN
#
# Ninguna de estas piezas se siembra suelta. Van en RINCONES —conjuntos con una
# composición pensada— que coloca `decorador_nivel.gd`: el puesto lleva sus
# mesas, sus materas y su papelera, y todo junto se lee como un sitio en vez de
# como props repartidos. Un puesto de dulces solo en mitad de un prado es más
# raro que no tener puesto.
#
# Uso desde el MCP de Blender (los TRES, en este orden):
#   exec(open("tools/blender_kit_parque.py").read())      # ayudantes y paleta
#   exec(open("tools/blender_kit_expansion.py").read())   # flor_campo, agua…
#   exec(open("tools/blender_kit_vida.py").read())
#   result = generar_vida()

import bpy
import bmesh
import math
from mathutils import Vector

# Se apoya en los dos kits anteriores: `_pieza`, `_unir`, `_caja`, `_cilindro`,
# `_esfera`, `PALETA` y `RECETA_TEXTURA` vienen del primero, y del segundo salen
# `flor_campo_alt` y `agua`. Hay que haberlos ejecutado antes.
PALETA.update({
    "lona":        (0.94, 0.55, 0.62),
    "lona_clara":  (0.99, 0.93, 0.94),
    "barro":       (0.72, 0.45, 0.34),
    "tierra":      (0.34, 0.25, 0.20),
    "piedra_clara": (0.78, 0.76, 0.70),
    "pintura_azul": (0.42, 0.62, 0.82),
    "pintura_verde": (0.46, 0.70, 0.50),
    "gato_blanco": (0.97, 0.96, 0.93),
})

RECETA_TEXTURA.update({
    # La lona lleva vetas: son las costuras del toldo, y a esta escala una
    # franja fina cada pocos centímetros se lee como tela rayada.
    "lona":        {"vetas": 14, "claro": (1.00, 0.72, 0.78), "grano": 0.03},
    "lona_clara":  {"vetas": 14, "claro": (1.00, 1.00, 1.00), "grano": 0.03},
    "barro":       {"manchas": 70, "claro": (0.84, 0.58, 0.44), "grano": 0.06},
    "tierra":      {"manchas": 120, "claro": (0.44, 0.34, 0.26), "grano": 0.09},
    "piedra_clara": {"manchas": 100, "claro": (0.88, 0.86, 0.80), "grano": 0.06},
    "pintura_azul": {"grano": 0.03, "claro": (0.56, 0.74, 0.92)},
    "pintura_verde": {"grano": 0.03, "claro": (0.60, 0.82, 0.62)},
    "gato_blanco": {"grano": 0.02, "claro": (1.00, 1.00, 0.99)},
})


def _caja_inclinada(bm, centro, tam, eje, angulo):
    """Una caja volcada sobre un eje. `_caja` solo sabe girar en Z.

    Hace falta para todo lo que no está a plomo: la rampa del tobogán, las
    patas en V del columpio. Sin esto hay que escribir el bmesh a mano cada vez.
    """
    from mathutils import Matrix
    temporal = bmesh.new()
    bmesh.ops.create_cube(temporal, size=1.0)
    for vertice in temporal.verts:
        vertice.co.x *= tam[0]
        vertice.co.y *= tam[1]
        vertice.co.z *= tam[2]
    bmesh.ops.rotate(temporal, verts=temporal.verts, cent=(0, 0, 0),
                     matrix=Matrix.Rotation(angulo, 3, eje))
    for vertice in temporal.verts:
        vertice.co += Vector(centro)
    malla = bpy.data.meshes.new("tmp")
    temporal.to_mesh(malla)
    temporal.free()
    bm.from_mesh(malla)
    bpy.data.meshes.remove(malla)


def _mata_de_flores(bm, centro, radio, alto, cuantas=9):
    """Un puñado de bolitas de flor. Se reutiliza en materas y macetas."""
    for i in range(cuantas):
        angulo = math.tau * i / cuantas + 0.3
        r = radio * (0.35 + 0.55 * ((i * 7) % 5) / 4.0)
        z = alto + 0.04 * ((i * 3) % 3)
        _esfera(bm, Vector((math.cos(angulo) * r, math.sin(angulo) * r, z)),
                0.09, achatado=0.8, cortes=6)


# --- Puestos y mobiliario -------------------------------------------------------

def puesto_dulces():
    """Tenderete de feria: mostrador, cuatro postes y toldo a dos aguas.

    El toldo va en dos piezas de color alterno en vez de una textura rayada
    porque a diez metros una raya pintada se pierde y la silueta no. Un puesto
    se tiene que reconocer de lejos: es lo que hace que apetezca ir hasta allí.
    """
    ancho, fondo = 2.80, 1.20

    bm = bmesh.new()
    # Mostrador: tablero y frente cerrado hasta el suelo.
    _caja(bm, (0, 0, 0.98), (ancho, fondo, 0.10))
    _caja(bm, (0, -fondo * 0.5 + 0.06, 0.47), (ancho, 0.12, 0.94))
    for signo in (-1, 1):
        _caja(bm, (signo * (ancho * 0.5 - 0.06), 0, 0.47), (0.12, fondo, 0.94))
    # Cuatro postes que sostienen el toldo.
    for sx in (-1, 1):
        for sy in (-1, 1):
            _caja(bm, (sx * (ancho * 0.5 - 0.09), sy * (fondo * 0.5 - 0.09), 1.30),
                  (0.11, 0.11, 2.60))
    # Y el estante trasero, con sus cajas de género.
    _caja(bm, (0, fondo * 0.5 - 0.10, 1.55), (ancho * 0.92, 0.10, 0.08))
    mueble = _pieza("puesto_mueble", "madera", bm)

    bm = bmesh.new()
    # Toldo a dos aguas de verdad: dos faldones VOLCADOS que se juntan en la
    # cumbrera. Puestos planos —que fue el primer intento— el puesto parecía una
    # mesa con una tapa encima; lo que dice «tenderete» es el pico del tejado.
    caida = 0.42
    for signo in (-1, 1):
        _caja_inclinada(bm, (0, signo * fondo * 0.52, 2.66),
                        (ancho + 0.60, fondo * 1.25, 0.07), 'X', signo * caida)
    lona = _pieza("puesto_lona", "lona", bm)

    bm = bmesh.new()
    # Franja clara colgando del borde: es lo que da el aire de feria.
    for signo in (-1, 1):
        _caja(bm, (0, signo * (fondo * 0.5 + 0.36), 2.42), (ancho + 0.60, 0.06, 0.26))
    # Cartel sobre la cumbrera.
    _caja(bm, (0, 0, 3.10), (1.50, 0.08, 0.42))
    faldon = _pieza("puesto_faldon", "lona_clara", bm)

    bm = bmesh.new()
    # Género en el mostrador: cuatro cajitas de colores.
    for i in range(4):
        x = -0.95 + i * 0.63
        _caja(bm, (x, 0.05, 1.10), (0.44, 0.44, 0.14))
    genero = _pieza("puesto_genero", "flor", bm)

    return _unir("puesto_dulces", [mueble, lona, faldon, genero])


def matera():
    """Jardinera rectangular de madera, con tierra y flores.

    Es la pieza que más trabaja del kit. Una fila de materas convierte
    cualquier borde en «cuidado por alguien», y sirve para cerrar los lados de
    una plaza sin necesidad de muro.
    """
    largo, fondo, alto = 1.70, 0.62, 0.46

    bm = bmesh.new()
    for signo in (-1, 1):
        _caja(bm, (0, signo * (fondo * 0.5 - 0.05), alto * 0.5),
              (largo, 0.10, alto))
        _caja(bm, (signo * (largo * 0.5 - 0.05), 0, alto * 0.5),
              (0.10, fondo, alto))
    # Remate superior: el canto plano de una caja se ve cortado a cuchillo.
    for signo in (-1, 1):
        _caja(bm, (0, signo * (fondo * 0.5 - 0.03), alto + 0.03),
              (largo + 0.10, 0.16, 0.06))
    cajon = _pieza("matera_cajon", "madera", bm)

    bm = bmesh.new()
    _caja(bm, (0, 0, alto - 0.06), (largo - 0.16, fondo - 0.16, 0.12))
    tierra = _pieza("matera_tierra", "tierra", bm)

    bm = bmesh.new()
    for i in range(7):
        x = -largo * 0.36 + i * (largo * 0.72 / 6.0)
        _esfera(bm, Vector((x, 0.06 * (1 if i % 2 else -1), alto + 0.14)),
                0.16, achatado=0.75, cortes=6)
    mata = _pieza("matera_mata", "hoja", bm)

    bm = bmesh.new()
    for i in range(9):
        x = -largo * 0.34 + i * (largo * 0.68 / 8.0)
        _esfera(bm, Vector((x, 0.10 * (1 if i % 2 else -1), alto + 0.24)),
                0.08, achatado=0.8, cortes=5)
    flores = _pieza("matera_flores", "flor_campo_alt", bm)

    return _unir("matera", [cajon, tierra, mata, flores])


def maceta():
    """Maceta de barro con planta. La versión suelta de la matera."""
    bm = bmesh.new()
    _cilindro(bm, (0, 0, 0.24), 0.22, 0.32, 0.48, lados=10)
    _cilindro(bm, (0, 0, 0.50), 0.34, 0.34, 0.08, lados=10)
    tiesto = _pieza("maceta_tiesto", "barro", bm)

    bm = bmesh.new()
    _esfera(bm, Vector((0, 0, 0.66)), 0.30, achatado=0.72, cortes=6)
    _esfera(bm, Vector((0.14, 0.10, 0.80)), 0.19, achatado=0.8, cortes=5)
    mata = _pieza("maceta_mata", "hoja_alt", bm)

    bm = bmesh.new()
    _mata_de_flores(bm, (0, 0, 0), 0.24, 0.86, cuantas=7)
    flores = _pieza("maceta_flores", "flor_campo", bm)

    return _unir("maceta", [tiesto, mata, flores])


def mesa_sombrilla():
    """Mesa redonda con parasol. Va emparejada con el puesto de dulces."""
    bm = bmesh.new()
    _cilindro(bm, (0, 0, 0.36), 0.09, 0.09, 0.72, lados=8)
    _cilindro(bm, (0, 0, 0.05), 0.34, 0.30, 0.10, lados=10)
    _cilindro(bm, (0, 0, 0.75), 0.72, 0.72, 0.07, lados=12)
    mesa = _pieza("mesa_tabla", "madera", bm)

    bm = bmesh.new()
    _cilindro(bm, (0, 0, 1.40), 0.05, 0.05, 1.90, lados=6)
    palo = _pieza("mesa_palo", "madera_oscura", bm)

    bm = bmesh.new()
    # El parasol es un cono muy abierto: seis lados bastan y de paso le da el
    # canto quebrado de una sombrilla de gajos.
    _cilindro(bm, (0, 0, 2.16), 1.45, 0.10, 0.42, lados=8)
    tela = _pieza("mesa_tela", "lona", bm)

    return _unir("mesa_sombrilla", [mesa, palo, tela])


def fuente_piedra():
    """Fuente circular con pilar. El centro natural de una plaza.

    El agua va como una pieza aparte y plana para poder darle el material de
    agua desde Godot si alguna vez interesa; de momento es un disco claro, que
    a esta escala se lee perfectamente como fuente.
    """
    bm = bmesh.new()
    # Pilón: anillo de doce segmentos, más barato y más «tallado» que un toro.
    lados = 14
    radio = 1.55
    for i in range(lados):
        angulo = math.tau * i / lados
        ancho_seg = math.tau * radio / lados * 1.08
        _caja(bm, (math.cos(angulo) * radio, math.sin(angulo) * radio, 0.28),
              (ancho_seg, 0.26, 0.56), giro=angulo + math.pi * 0.5)
    _cilindro(bm, (0, 0, 0.06), radio + 0.14, radio + 0.14, 0.12, lados=16)
    # Pilar central escalonado.
    _cilindro(bm, (0, 0, 0.42), 0.42, 0.34, 0.70, lados=10)
    _cilindro(bm, (0, 0, 0.84), 0.62, 0.58, 0.14, lados=12)
    _cilindro(bm, (0, 0, 1.06), 0.20, 0.14, 0.42, lados=8)
    pilon = _pieza("fuente_pilon", "piedra_clara", bm)

    bm = bmesh.new()
    _cilindro(bm, (0, 0, 0.40), radio - 0.14, radio - 0.14, 0.04, lados=16)
    _esfera(bm, Vector((0, 0, 1.30)), 0.16, achatado=0.9, cortes=6)
    agua = _pieza("fuente_agua", "agua", bm)

    return _unir("fuente_piedra", [pilon, agua])


def cartel_flechas():
    """Poste indicador con dos flechas. Dice que este sitio lleva a alguna parte."""
    bm = bmesh.new()
    _cilindro(bm, (0, 0, 1.10), 0.09, 0.08, 2.20, lados=8)
    _cilindro(bm, (0, 0, 0.06), 0.20, 0.18, 0.12, lados=8)
    poste = _pieza("cartel_poste", "madera_oscura", bm)

    bm = bmesh.new()
    # Dos tablas a distinta altura y apuntando a sitios distintos.
    #
    # El giro tiene que mover la tabla ALREDEDOR del poste, no solo girarla
    # sobre su centro: girándola en el sitio, la de arriba quedaba clavada en
    # el poste y la de abajo salía volando por un lado.
    #
    # La punta es un escalón más estrecho al final. Un triángulo de verdad
    # costaría otra malla y a esta distancia el escalón ya se lee como flecha.
    for alto, giro in [(1.86, 0.0), (1.48, 2.2)]:
        for distancia, ancho, grueso in [(0.46, 0.84, 0.26), (0.94, 0.24, 0.13)]:
            _caja(bm, (math.cos(giro) * distancia, math.sin(giro) * distancia, alto),
                  (ancho, 0.07, grueso), giro=giro)
    tablas = _pieza("cartel_tablas", "madera", bm)

    return _unir("cartel_flechas", [poste, tablas])


def columpio():
    """Dos columpios en estructura de A. Es lo que hace un parque INFANTIL."""
    ancho, alto = 2.70, 2.10

    bm = bmesh.new()
    for signo in (-1, 1):
        for inclina in (-1, 1):
            # Las patas van en V hacia fuera: es lo que aguanta un columpio y
            # además dibuja la silueta que se reconoce de lejos. Con los cuatro
            # postes a plomo se lee como un marco de portería.
            _caja_inclinada(bm,
                            (signo * ancho * 0.5, inclina * 0.34, alto * 0.5),
                            (0.13, 0.13, alto + 0.16), 'X', inclina * 0.17)
    _caja(bm, (0, 0, alto + 0.06), (ancho + 0.34, 0.15, 0.15))
    marco = _pieza("columpio_marco", "metal", bm)

    bm = bmesh.new()
    for signo in (-1, 1):
        x = signo * 0.62
        for lado in (-1, 1):
            _caja(bm, (x + lado * 0.22, 0, alto * 0.62), (0.04, 0.04, alto * 0.76))
        _caja(bm, (x, 0, 0.62), (0.56, 0.26, 0.07))
    asientos = _pieza("columpio_asientos", "pintura_azul", bm)

    return _unir("columpio", [marco, asientos])


def tobogan():
    """Torre con escalera y rampa. La pareja del columpio."""
    bm = bmesh.new()
    for sx in (-1, 1):
        for sy in (-1, 1):
            _caja(bm, (sx * 0.44, sy * 0.44, 0.80), (0.12, 0.12, 1.60))
    _caja(bm, (0, 0, 1.62), (1.10, 1.10, 0.10))
    # Barandilla de la plataforma, solo en tres lados: por el cuarto se tira.
    for x, y, largo, giro in [(-0.5, 0, 1.10, math.pi * 0.5), (0.5, 0, 1.10, math.pi * 0.5),
                              (0, 0.5, 1.10, 0.0)]:
        _caja(bm, (x, y, 1.94), (largo, 0.07, 0.55), giro=giro)
    torre = _pieza("tobogan_torre", "madera", bm)

    bm = bmesh.new()
    # Rampa: una tabla larga volcada, con dos cantos que hacen de bordes para
    # que no se lea como una plancha suelta apoyada en la torre.
    caida = math.atan2(1.50, 2.40)
    largo_rampa = math.sqrt(1.50 ** 2 + 2.40 ** 2)
    _caja_inclinada(bm, (0, -1.72, 0.86), (0.86, largo_rampa, 0.08), 'X', caida)
    for signo in (-1, 1):
        _caja_inclinada(bm, (signo * 0.44, -1.72, 0.96),
                        (0.09, largo_rampa, 0.22), 'X', caida)
    rampa = _pieza("tobogan_rampa", "pintura_verde", bm)

    bm = bmesh.new()
    # Escalera por detrás.
    for i in range(4):
        _caja(bm, (0, 0.86 + i * 0.16, 0.30 + i * 0.36), (0.78, 0.20, 0.07))
    escalera = _pieza("tobogan_escalera", "madera_oscura", bm)

    return _unir("tobogan", [torre, rampa, escalera])


def losa_sendero():
    """Una losa plana de piedra. Puestas en fila hacen un andén.

    Es DELIBERADAMENTE irregular y con el canto en pico: un disco redondo
    repetido cincuenta veces se lee como una fila de monedas, y lo que se busca
    es un empedrado de piedras sueltas.
    """
    bm = bmesh.new()
    lados = 7
    verts = []
    for i in range(lados):
        angulo = math.tau * i / lados
        r = 0.42 * (0.78 + 0.30 * ((i * 5) % 4) / 3.0)
        verts.append(bm.verts.new((math.cos(angulo) * r, math.sin(angulo) * r, 0.05)))
    bm.faces.new(verts)
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=-0.10)
    return _pieza("losa_sendero", "piedra_clara", bm, suavizar=False)


def guirnalda():
    """Dos postes con una cuerda de farolillos entre ellos.

    Mide cinco metros de vano, así que sirve para marcar la entrada de un
    rincón o para cruzar por encima de un sendero.
    """
    vano = 5.0

    bm = bmesh.new()
    for signo in (-1, 1):
        _cilindro(bm, (0, signo * vano * 0.5, 1.35), 0.09, 0.07, 2.70, lados=8)
        _cilindro(bm, (0, signo * vano * 0.5, 0.06), 0.20, 0.18, 0.12, lados=8)
    postes = _pieza("guirnalda_postes", "madera_oscura", bm)

    bm = bmesh.new()
    faroles = 7
    for i in range(faroles):
        t = (i + 0.5) / faroles
        y = -vano * 0.5 + t * vano
        # La cuerda cuelga: una recta entre dos postes se lee como un cable de
        # la luz, y lo que hace «fiesta» es la comba.
        comba = 2.62 - 0.34 * math.sin(math.pi * t)
        _cilindro(bm, (0, y, comba), 0.02, 0.02, 0.10, lados=4)
        _esfera(bm, Vector((0, y, comba - 0.18)), 0.13, achatado=1.25, cortes=6)
    luces = _pieza("guirnalda_luces", "farol", bm)

    return _unir("guirnalda", [postes, luces])


def estatua_gato():
    """Un gato de piedra sobre pedestal, con la pata levantada.

    Es un guiño: en el juego hay dos gatos que hablan. Encontrarse una estatua
    de gato en el parque es el tipo de detalle que una niña de ocho años sí
    mira dos veces.
    """
    bm = bmesh.new()
    _caja(bm, (0, 0, 0.22), (0.78, 0.78, 0.44))
    _caja(bm, (0, 0, 0.48), (0.62, 0.62, 0.10))
    pedestal = _pieza("estatua_pedestal", "piedra", bm)

    bm = bmesh.new()
    # Cuerpo sentado, cabeza, orejas, pata levantada y cola enroscada.
    _esfera(bm, Vector((0, 0, 0.78)), 0.28, achatado=1.15, cortes=6)
    _esfera(bm, Vector((0, 0, 1.14)), 0.22, achatado=0.95, cortes=6)
    for signo in (-1, 1):
        _caja(bm, (signo * 0.13, 0, 1.34), (0.13, 0.05, 0.16),
              giro=signo * 0.3)
    _cilindro(bm, (0.20, -0.06, 0.98), 0.06, 0.05, 0.34, lados=6)
    _cilindro(bm, (-0.24, 0.10, 0.66), 0.05, 0.04, 0.30, lados=6)
    gato = _pieza("estatua_gato_cuerpo", "gato_blanco", bm)

    return _unir("estatua_gato", [pedestal, gato])


def seto_bajo():
    """Un trozo de seto recortado, a la altura de la rodilla.

    Sirve para cerrar los lados de una plaza sin levantar un muro: se ve el
    borde, se entiende que ahí acaba el sitio, y se pasa por encima con la
    vista. Va sin colisión a propósito.
    """
    bm = bmesh.new()
    largo = 1.90
    for i in range(4):
        x = -largo * 0.5 + (i + 0.5) * (largo / 4.0)
        _esfera(bm, Vector((x, 0, 0.34)), 0.34, achatado=0.85, cortes=6)
        _esfera(bm, Vector((x, 0, 0.52)), 0.24, achatado=0.75, cortes=5)
    return _pieza("seto_bajo", "hoja_alt", bm)


def generar_vida():
    _limpiar()
    piezas = {}
    for hacer in (puesto_dulces, matera, maceta, mesa_sombrilla, fuente_piedra,
                  cartel_flechas, columpio, tobogan, losa_sendero, guirnalda,
                  estatua_gato, seto_bajo):
        objeto = hacer()
        piezas[objeto.name] = _exportar(objeto)
    return piezas
