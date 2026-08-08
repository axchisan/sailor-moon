# Genera el kit de props del Parque Juuban, low-poly y de estilo coherente.
#
# POR QUÉ PROCEDURAL Y NO GENERADO CON IA
#
# Un árbol de cerezo estilizado es un tronco y cuatro bolas rosas. Pedírselo a
# un generador 3D da 2.000.000 de triángulos que hay que limpiar, un estilo que
# no casa con el resto, y una pieza que no se puede retocar: si el rosa no
# convence, se vuelve a generar y sale otro árbol distinto.
#
# Hechos así, en cambio: pesan lo que decidamos, todos comparten el mismo
# lenguaje de formas, y cambiar el tono de las flores es cambiar un número.
#
# Los props NO llevan colisión: son decorado. Solo colisionan el suelo, los
# bordes y las plataformas (ver docs/07-ESCENARIOS.md §"Orden de montaje").
#
# Uso desde el MCP de Blender:
#   exec(open("tools/blender_kit_parque.py").read())
#   result = generar_kit()

import bpy
import bmesh
import math
import os
from mathutils import Vector

SALIDA = "/Users/mac/Documents/Dev/Games/sailor-moon/assets/models/props"

# Paleta del parque al atardecer. El cel shading se encarga del resto, así que
# los materiales son color plano: ni texturas ni mapas.
PALETA = {
    "corteza":  (0.35, 0.26, 0.24),
    "flor":     (0.98, 0.72, 0.82),
    "flor_alt": (1.00, 0.85, 0.90),
    "hoja":     (0.42, 0.62, 0.36),
    "hoja_alt": (0.34, 0.52, 0.30),
    "piedra":   (0.62, 0.62, 0.58),
    "madera":   (0.55, 0.40, 0.28),
    "metal":    (0.45, 0.47, 0.52),
    "farol":    (1.00, 0.93, 0.72),
    "montana":  (0.47, 0.42, 0.62),
    "madera_oscura": (0.38, 0.26, 0.22),
    "laca_roja": (0.78, 0.24, 0.22),
}

# Cómo se pinta la textura de cada material.
#
#   manchas  cuántas motas de color se salpican (flores, hojas, liquen)
#   vetas    rayas en una dirección (madera, corteza)
#   grano    ruido fino general
#   claro    color de las motas
#
# Un color plano deja los props muertos: el cel shading da el escalón de luz
# pero no da VARIACIÓN, y sin variación una copa de árbol es una mancha rosa.
# Estas texturas son diminutas (256²) y lo que aportan es que cada masa tenga
# vida propia, como en un fondo pintado.
RECETA_TEXTURA = {
    "flor":     {"manchas": 190, "claro": (1.00, 0.90, 0.95), "grano": 0.05},
    "flor_alt": {"manchas": 150, "claro": (1.00, 0.97, 0.99), "grano": 0.04},
    "hoja":     {"manchas": 170, "claro": (0.58, 0.76, 0.46), "grano": 0.06},
    "hoja_alt": {"manchas": 140, "claro": (0.46, 0.66, 0.40), "grano": 0.06},
    "corteza":  {"vetas": 26, "claro": (0.46, 0.35, 0.31), "grano": 0.05},
    "madera":   {"vetas": 20, "claro": (0.66, 0.50, 0.36), "grano": 0.04},
    "madera_oscura": {"vetas": 22, "claro": (0.48, 0.34, 0.29), "grano": 0.04},
    "piedra":   {"manchas": 90, "claro": (0.72, 0.73, 0.68), "grano": 0.07},
    "montana":  {"manchas": 60, "claro": (0.56, 0.51, 0.70), "grano": 0.04},
    "laca_roja": {"vetas": 10, "claro": (0.88, 0.34, 0.30), "grano": 0.03},
    "metal":    {"grano": 0.03, "claro": (0.55, 0.57, 0.62)},
    "farol":    {"grano": 0.02, "claro": (1.00, 0.98, 0.86)},
}

TAM_TEXTURA = 256


def _limpiar():
    for objeto in list(bpy.data.objects):
        bpy.data.objects.remove(objeto, do_unlink=True)
    for bloque in (bpy.data.meshes, bpy.data.materials, bpy.data.images):
        for item in list(bloque):
            if item.users == 0:
                bloque.remove(item)


def _aleatorio(semilla):
    """Ruido reproducible: sin `random`, para que el kit salga idéntico cada
    vez que se regenera y no cambie el aspecto del juego sin querer."""
    x = math.sin(semilla * 12.9898) * 43758.5453
    return x - math.floor(x)


def _textura(nombre):
    """Pinta una textura pequeña para un material de la paleta.

    Se genera aquí y no se pide a ninguna parte porque lo que hace falta es
    ruido de pintura: motas de flor más claras, vetas en la madera, liquen en
    la piedra. Con 256² sobra: estos props se ven a varios metros.
    """
    clave = "tex_" + nombre
    if clave in bpy.data.images:
        return bpy.data.images[clave]

    receta = RECETA_TEXTURA.get(nombre, {})
    base = PALETA[nombre]
    claro = receta.get("claro", base)
    grano = receta.get("grano", 0.04)
    n = TAM_TEXTURA

    # Lienzo del color base, con grano fino
    pixeles = [0.0] * (n * n * 4)
    for y in range(n):
        for x in range(n):
            i = (y * n + x) * 4
            ruido = (_aleatorio(x * 1.7 + y * 3.1) - 0.5) * grano
            pixeles[i] = min(1.0, max(0.0, base[0] + ruido))
            pixeles[i + 1] = min(1.0, max(0.0, base[1] + ruido))
            pixeles[i + 2] = min(1.0, max(0.0, base[2] + ruido))
            pixeles[i + 3] = 1.0

    # Vetas: rayas verticales suaves, para maderas y cortezas
    for v in range(receta.get("vetas", 0)):
        cx = int(_aleatorio(v * 7.3) * n)
        ancho = 1 + int(_aleatorio(v * 3.9) * 3)
        fuerza = 0.35 + _aleatorio(v * 5.1) * 0.4
        for y in range(n):
            desvio = int(math.sin(y * 0.05 + v) * 3.0)
            for dx in range(-ancho, ancho + 1):
                x = (cx + dx + desvio) % n
                i = (y * n + x) * 4
                peso = fuerza * (1.0 - abs(dx) / float(ancho + 1))
                for c in range(3):
                    pixeles[i + c] += (claro[c] - pixeles[i + c]) * peso

    # Manchas: motas redondas más claras. Es lo que convierte una masa rosa
    # plana en una copa con flores.
    for m in range(receta.get("manchas", 0)):
        cx = _aleatorio(m * 2.7) * n
        cy = _aleatorio(m * 5.3 + 1.0) * n
        radio = 2.0 + _aleatorio(m * 9.1) * 5.0
        fuerza = 0.45 + _aleatorio(m * 4.3) * 0.45
        r = int(radio) + 1
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                distancia = math.sqrt(dx * dx + dy * dy)
                if distancia > radio:
                    continue
                x = int(cx + dx) % n
                y = int(cy + dy) % n
                i = (y * n + x) * 4
                peso = fuerza * (1.0 - distancia / radio)
                for c in range(3):
                    pixeles[i + c] += (claro[c] - pixeles[i + c]) * peso

    imagen = bpy.data.images.new(clave, n, n)
    imagen.pixels = pixeles
    return imagen


def _material(nombre):
    if nombre in bpy.data.materials:
        return bpy.data.materials[nombre]
    material = bpy.data.materials.new(nombre)
    material.use_nodes = True
    arbol = material.node_tree
    bsdf = next(n for n in arbol.nodes if n.type == 'BSDF_PRINCIPLED')
    color = PALETA[nombre]
    bsdf.inputs["Base Color"].default_value = (color[0], color[1], color[2], 1.0)
    bsdf.inputs["Roughness"].default_value = 0.9

    nodo = arbol.nodes.new("ShaderNodeTexImage")
    nodo.image = _textura(nombre)
    nodo.location = (-320, 200)
    arbol.links.new(nodo.outputs["Color"], bsdf.inputs["Base Color"])
    return material


def _pieza(nombre, material, malla_bm, suavizar=True):
    malla = bpy.data.meshes.new(nombre)
    malla_bm.to_mesh(malla)
    malla_bm.free()
    objeto = bpy.data.objects.new(nombre, malla)
    objeto.data.materials.append(_material(material))
    bpy.context.collection.objects.link(objeto)

    bpy.ops.object.select_all(action='DESELECT')
    objeto.select_set(True)
    bpy.context.view_layer.objects.active = objeto

    # Sin UV la textura no se ve: todo el objeto muestrearía el mismo píxel.
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.02)
    bpy.ops.object.mode_set(mode='OBJECT')

    if suavizar:
        bpy.ops.object.shade_smooth()
        # Los cantos duros (aristas de una caja, borde de un tejado) se
        # conservan; solo se suaviza lo que de verdad es curvo.
        objeto.data.set_sharp_from_angle(angle=math.radians(46.0))
    return objeto


def _esfera(bm, centro, radio, achatado=1.0, cortes=8, ruido=0.0, suave=True):
    # 2 subdivisiones (320 caras) en vez de 1 (80): con 80 la copa de un árbol
    # se ve como un cristal tallado. Sigue siendo baratísimo y el sombreado
    # suave remata el resto.
    temporal = bmesh.new()
    bmesh.ops.create_icosphere(temporal, subdivisions=2 if suave else 1,
                               radius=radio)
    for vertice in temporal.verts:
        vertice.co.z *= achatado
        if ruido > 0.0:
            # Desorden reproducible: sin `random`, para que el kit salga igual
            # cada vez que se regenera.
            semilla = math.sin(vertice.co.x * 12.9 + vertice.co.y * 78.2
                               + vertice.co.z * 37.7) * 43758.5453
            vertice.co *= 1.0 + (semilla - math.floor(semilla) - 0.5) * ruido
        vertice.co += centro
    bmesh.ops.recalc_face_normals(temporal, faces=temporal.faces)
    malla = bpy.data.meshes.new("tmp")
    temporal.to_mesh(malla)
    temporal.free()
    bm.from_mesh(malla)
    bpy.data.meshes.remove(malla)


def _caja(bm, centro, tam, giro=0.0):
    temporal = bmesh.new()
    bmesh.ops.create_cube(temporal, size=1.0)
    for vertice in temporal.verts:
        vertice.co.x *= tam[0]
        vertice.co.y *= tam[1]
        vertice.co.z *= tam[2]
        if giro != 0.0:
            x, y = vertice.co.x, vertice.co.y
            vertice.co.x = x * math.cos(giro) - y * math.sin(giro)
            vertice.co.y = x * math.sin(giro) + y * math.cos(giro)
        vertice.co += Vector(centro)
    malla = bpy.data.meshes.new("tmp")
    temporal.to_mesh(malla)
    temporal.free()
    bm.from_mesh(malla)
    bpy.data.meshes.remove(malla)


def _cilindro(bm, centro, radio_inf, radio_sup, alto, lados=8):
    temporal = bmesh.new()
    bmesh.ops.create_cone(temporal, cap_ends=True, cap_tris=False, segments=lados,
                          radius1=radio_inf, radius2=radio_sup, depth=alto)
    for vertice in temporal.verts:
        vertice.co += Vector(centro)
    malla = bpy.data.meshes.new("tmp")
    temporal.to_mesh(malla)
    temporal.free()
    bm.from_mesh(malla)
    bpy.data.meshes.remove(malla)


# --- Las piezas ----------------------------------------------------------------

def cerezo():
    """Tronco que se abre en dos ramas y cuatro masas de flor.

    Las copas van en bolas separadas y de dos tonos a propósito: una sola bola
    lisa parece un chupa-chups, y con el contorno del cel shading el recorte
    entre masas es lo que le da la silueta de árbol.
    """
    bm = bmesh.new()
    # Tronco fino y cónico: uno grueso convierte al árbol en una seta. Las
    # ramas arrancan altas y con poca inclinación para que la copa se apoye en
    # ellas en vez de flotar por encima.
    _cilindro(bm, (0, 0, 0.95), 0.15, 0.09, 1.9, lados=10)
    _cilindro(bm, (-0.26, 0.08, 1.95), 0.07, 0.05, 0.75, lados=7)
    _cilindro(bm, (0.24, -0.10, 2.00), 0.07, 0.05, 0.80, lados=7)
    tronco = _pieza("cerezo_tronco", "corteza", bm)

    bm = bmesh.new()
    # Masas bien solapadas. Separadas se ve el interior de las bolas y aparece
    # un agujero en mitad de la copa.
    _esfera(bm, Vector((0.0, 0.0, 2.75)), 1.30, achatado=0.62, ruido=0.16)
    _esfera(bm, Vector((-0.78, 0.22, 2.55)), 0.86, achatado=0.66, ruido=0.18)
    _esfera(bm, Vector((0.74, -0.26, 2.60)), 0.90, achatado=0.66, ruido=0.18)
    _esfera(bm, Vector((0.10, 0.62, 2.62)), 0.80, achatado=0.66, ruido=0.18)
    copa = _pieza("cerezo_copa", "flor", bm)

    bm = bmesh.new()
    # Segundo tono encima: es lo que da el volumen sin depender de la luz.
    _esfera(bm, Vector((0.20, 0.05, 3.25)), 0.72, achatado=0.60, ruido=0.20)
    _esfera(bm, Vector((-0.45, -0.35, 3.05)), 0.58, achatado=0.60, ruido=0.20)
    copa_clara = _pieza("cerezo_copa2", "flor_alt", bm)

    return _unir("arbol_cerezo", [tronco, copa, copa_clara])


def toro():
    """Farol de piedra japonés. La caja de luz va en material propio para que
    pueda emitir de noche sin tocar el resto de la pieza."""
    bm = bmesh.new()
    _cilindro(bm, (0, 0, 0.12), 0.34, 0.30, 0.24, lados=6)
    _cilindro(bm, (0, 0, 0.62), 0.13, 0.12, 0.80, lados=6)
    _cilindro(bm, (0, 0, 1.08), 0.26, 0.24, 0.14, lados=6)
    _cilindro(bm, (0, 0, 1.52), 0.34, 0.10, 0.26, lados=6)   # tejadillo
    _esfera(bm, Vector((0, 0, 1.72)), 0.09, cortes=6)
    piedra = _pieza("toro_piedra", "piedra", bm)

    bm = bmesh.new()
    _cilindro(bm, (0, 0, 1.30), 0.22, 0.22, 0.32, lados=6)
    luz = _pieza("toro_luz", "farol", bm)

    return _unir("farol_piedra", [piedra, luz])


def arbusto():
    bm = bmesh.new()
    _esfera(bm, Vector((0, 0, 0.42)), 0.55, achatado=0.78, ruido=0.22)
    _esfera(bm, Vector((0.35, 0.18, 0.30)), 0.34, achatado=0.80, ruido=0.24)
    verde = _pieza("arbusto_a", "hoja", bm)

    bm = bmesh.new()
    _esfera(bm, Vector((-0.32, -0.20, 0.32)), 0.36, achatado=0.80, ruido=0.24)
    verde2 = _pieza("arbusto_b", "hoja_alt", bm)

    return _unir("arbusto", [verde, verde2])


def valla():
    """Tramo de 3 m que se repite a lo largo del recorrido."""
    bm = bmesh.new()
    for i in range(3):
        _caja(bm, (-1.0 + i * 1.0, 0, 0.55), (0.12, 0.12, 1.1))
    _caja(bm, (0, 0, 0.90), (3.0, 0.07, 0.14))
    _caja(bm, (0, 0, 0.50), (3.0, 0.07, 0.14))
    return _pieza("valla_madera", "madera", bm)


def banco():
    bm = bmesh.new()
    _caja(bm, (0, 0, 0.44), (1.6, 0.5, 0.09))
    _caja(bm, (0, -0.22, 0.72), (1.6, 0.09, 0.46))
    tablas = _pieza("banco_tablas", "madera", bm)

    bm = bmesh.new()
    for signo in (-1, 1):
        _caja(bm, (signo * 0.65, 0, 0.20), (0.09, 0.44, 0.40))
    patas = _pieza("banco_patas", "metal", bm)

    return _unir("banco_parque", [tablas, patas])


def papelera():
    bm = bmesh.new()
    _cilindro(bm, (0, 0, 0.35), 0.24, 0.28, 0.70, lados=8)
    _cilindro(bm, (0, 0, 0.72), 0.30, 0.30, 0.06, lados=8)
    return _pieza("papelera", "metal", bm)


def roca():
    bm = bmesh.new()
    _esfera(bm, Vector((0, 0, 0.28)), 0.45, achatado=0.62, ruido=0.30)
    return _pieza("roca", "piedra", bm)


# --- Piezas de fondo lejano ----------------------------------------------------
#
# Estas no se pisan nunca: viven a 60-200 m, sin colisión y sin proyectar
# sombra. Son las que dan la postal —montañas moradas, una pagoda recortada,
# cerezos gigantes— y, a diferencia de un skybox pintado, se mueven con
# parallax cuando la jugadora camina, que es lo que hace que el mundo parezca
# grande de verdad.

def montana():
    """Cono achatado e irregular. El morado azulado no es un capricho: es la
    perspectiva aérea, lo que hace que se lea como «lejos» sin más trucos."""
    bm = bmesh.new()
    _cilindro(bm, (0, 0, 9.0), 15.0, 0.6, 18.0, lados=6)
    _cilindro(bm, (7.0, 3.0, 5.5), 8.0, 0.5, 11.0, lados=5)
    _cilindro(bm, (-8.0, -2.0, 4.5), 7.0, 0.5, 9.0, lados=5)
    return _pieza("montana_lejana", "montana", bm)


def pagoda():
    """Cinco pisos que se estrechan. Se lee por la silueta, así que no lleva
    ni un detalle: a 80 m no se vería."""
    bm = bmesh.new()
    _caja(bm, (0, 0, 0.6), (4.4, 4.4, 1.2))
    altura = 1.2
    ancho = 3.9
    for piso in range(5):
        _caja(bm, (0, 0, altura + 1.05), (ancho, ancho, 2.1))
        _cilindro(bm, (0, 0, altura + 2.35), ancho * 0.95, ancho * 0.32, 0.85, lados=4)
        altura += 2.7
        ancho *= 0.82
    _cilindro(bm, (0, 0, altura + 1.4), 0.22, 0.05, 2.8, lados=4)
    return _pieza("pagoda_lejana", "madera_oscura", bm)


def torii():
    """La puerta roja. Es el icono que dice «Japón» de un vistazo, así que
    conviene que se vea desde el camino."""
    bm = bmesh.new()
    for signo in (-1, 1):
        _cilindro(bm, (signo * 1.7, 0, 2.3), 0.26, 0.20, 4.6, lados=6)
    _caja(bm, (0, 0, 4.35), (4.9, 0.34, 0.34))
    _cilindro(bm, (0, 0, 4.95), 0.0, 0.0, 0.0, lados=4)
    _caja(bm, (0, 0, 4.95), (5.6, 0.46, 0.42))
    _caja(bm, (0, 0, 5.28), (5.9, 0.30, 0.26))
    return _pieza("torii", "laca_roja", bm)


def cerezo_gigante():
    """El mismo cerezo pero para el fondo: más masa y menos piezas, porque a
    60 m solo cuenta la silueta."""
    bm = bmesh.new()
    _cilindro(bm, (0, 0, 2.4), 0.7, 0.35, 4.8, lados=6)
    _cilindro(bm, (-1.2, 0.4, 5.2), 0.30, 0.18, 2.6, lados=5)
    _cilindro(bm, (1.1, -0.5, 5.4), 0.30, 0.18, 2.8, lados=5)
    tronco = _pieza("gigante_tronco", "corteza", bm)

    bm = bmesh.new()
    _esfera(bm, Vector((0.0, 0.0, 7.6)), 4.6, achatado=0.55, ruido=0.14)
    _esfera(bm, Vector((-3.1, 0.9, 6.9)), 3.0, achatado=0.60, ruido=0.16)
    _esfera(bm, Vector((3.0, -1.0, 7.0)), 3.2, achatado=0.60, ruido=0.16)
    copa = _pieza("gigante_copa", "flor", bm)

    return _unir("cerezo_gigante", [tronco, copa])


def _unir(nombre, objetos):
    bpy.ops.object.select_all(action='DESELECT')
    for objeto in objetos:
        objeto.select_set(True)
    bpy.context.view_layer.objects.active = objetos[0]
    if len(objetos) > 1:
        bpy.ops.object.join()
    resultado = bpy.context.view_layer.objects.active
    resultado.name = nombre
    resultado.data.name = nombre
    return resultado


def _exportar(objeto):
    bpy.ops.object.select_all(action='DESELECT')
    objeto.select_set(True)
    bpy.context.view_layer.objects.active = objeto
    ruta = "%s/%s.glb" % (SALIDA, objeto.name)
    bpy.ops.export_scene.gltf(filepath=ruta, export_format='GLB',
                              use_selection=True, export_apply=True,
                              export_yup=True, export_materials='EXPORT')
    tris = sum(len(p.vertices) - 2 for p in objeto.data.polygons)
    return {"tris": tris, "kb": round(os.path.getsize(ruta) / 1024)}


def generar_kit():
    piezas = {}
    for constructor in (cerezo, toro, arbusto, valla, banco, papelera, roca,
                        montana, pagoda, torii, cerezo_gigante):
        _limpiar()
        objeto = constructor()
        piezas[objeto.name] = _exportar(objeto)
    return piezas
