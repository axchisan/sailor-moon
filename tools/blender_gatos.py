# Arregla y prepara a Luna y Artemis para el juego.
#
# EL PROBLEMA
#
# Los modelos se generaron a partir de una foto de tres cuartos —hacía falta esa
# vista para que el CUERPO saliera bien— y eso deja el modelo partido en dos:
#
#   · La malla está perfecta por los dos lados. La silueta, las patas, la cola
#     y las orejas no hay que tocarlas.
#   · La textura solo es buena en el lado que la foto veía. El otro lado lo
#     inventa estirando píxeles, y salen rayas blancas verticales por el cuerpo
#     y las patas.
#   · La cara sale duplicada: los ojos aparecen dos veces, desplazados, y la
#     luna de la frente queda embarrada.
#
# LA SOLUCIÓN
#
# Un gato de estos es de **color liso**. La textura fotográfica no aporta nada
# que no dé un color plano con algo de grano, así que se tira entera: con eso
# desaparecen de golpe todas las rayas, sin tener que repararlas una a una.
#
# Y la cara se reconstruye con **geometría**, no pintándola: ojos, luna, nariz e
# interior de orejas como piezas propias. Da control exacto, no depende de las
# UV (que es justo lo que está roto) y encaja con el estilo del resto del kit.
#
# Uso desde el MCP de Blender:
#   exec(open("tools/blender_gatos.py").read())
#   result = preparar_gatos()

import bpy
import bmesh
import math
import os
from mathutils import Vector

ENTRADA = "/Users/mac/Downloads"
SALIDA = "/Users/mac/Documents/Dev/Games/sailor-moon/assets/models/characters"

# A escala real un gato mide unos 30 cm de cruz, pero en pantalla se pierde:
# al lado de Serena queda como una mota que no se ve. Se sube a 45 cm, que es
# lo que hace la serie —sus gatos son grandotes— y así tiene presencia sin
# dejar de leerse como un gato. Subido a 52 tras verlo en marcha: a 45 aún se
# perdía junto a Serena.
ALTURA_CRUZ = 0.52
TRIS_OBJETIVO = 4000

GATOS = {
    "luna": {
        "archivo": "Hi3D_Modelo 3D Gato Negro Luna Estilo Anime Sailor Moon_allparts_20260808_112222.glb",
        "pelaje": (0.16, 0.14, 0.22),
        "oreja": (0.62, 0.42, 0.48),
        "iris": (0.72, 0.16, 0.14),
        "nariz": (0.86, 0.55, 0.58),
    },
    "artemis": {
        "archivo": "Hi3D_Untitled_allparts_20260808_112207.glb",
        "pelaje": (0.94, 0.94, 0.96),
        "oreja": (0.96, 0.78, 0.80),
        "iris": (0.86, 0.68, 0.16),
        "nariz": (0.94, 0.72, 0.74),
    },
}

LUNA_DORADA = (0.92, 0.74, 0.24)
BLANCO_OJO = (1.0, 1.0, 1.0)
NEGRO_PUPILA = (0.10, 0.08, 0.12)


def _limpiar():
    for objeto in list(bpy.data.objects):
        bpy.data.objects.remove(objeto, do_unlink=True)
    for bloque in (bpy.data.meshes, bpy.data.materials, bpy.data.images):
        for item in list(bloque):
            if item.users == 0:
                bloque.remove(item)


def _activar(objeto):
    bpy.ops.object.select_all(action='DESELECT')
    objeto.select_set(True)
    bpy.context.view_layer.objects.active = objeto


def _aleatorio(semilla):
    x = math.sin(semilla * 12.9898) * 43758.5453
    return x - math.floor(x)


def _textura_pelaje(nombre, color, grano=0.05):
    """Color liso con grano fino. Sustituye a la textura fotográfica entera."""
    clave = "pelo_" + nombre
    if clave in bpy.data.images:
        return bpy.data.images[clave]
    n = 128
    pixeles = [0.0] * (n * n * 4)
    for y in range(n):
        for x in range(n):
            i = (y * n + x) * 4
            ruido = (_aleatorio(x * 2.3 + y * 5.7) - 0.5) * grano
            pixeles[i] = min(1.0, max(0.0, color[0] + ruido))
            pixeles[i + 1] = min(1.0, max(0.0, color[1] + ruido))
            pixeles[i + 2] = min(1.0, max(0.0, color[2] + ruido))
            pixeles[i + 3] = 1.0
    imagen = bpy.data.images.new(clave, n, n)
    imagen.pixels = pixeles
    return imagen


def _material(nombre, color, textura=None, emision=0.0):
    if nombre in bpy.data.materials:
        return bpy.data.materials[nombre]
    material = bpy.data.materials.new(nombre)
    material.use_nodes = True
    arbol = material.node_tree
    bsdf = next(n for n in arbol.nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs["Base Color"].default_value = (color[0], color[1], color[2], 1.0)
    bsdf.inputs["Roughness"].default_value = 0.75
    if emision > 0.0:
        bsdf.inputs["Emission Color"].default_value = (color[0], color[1], color[2], 1.0)
        bsdf.inputs["Emission Strength"].default_value = emision
    if textura is not None:
        nodo = arbol.nodes.new("ShaderNodeTexImage")
        nodo.image = textura
        arbol.links.new(nodo.outputs["Color"], bsdf.inputs["Base Color"])
    return material


# --- La cara, pintada en la textura -------------------------------------------
#
# El primer intento puso los rasgos como GEOMETRÍA: discos de ojo, iris, nariz.
# Se veían bien de frente pero de perfil eran pegatinas 3D asomando de la cara,
# y no hay forma de arreglar eso hundiéndolos más: o sobresalen, o desaparecen
# dentro del cráneo.
#
# Lo que hace un artista es pintarlos en la textura, y eso es lo que se hace
# aquí. El truco para poder pintarlos sin adivinar dónde caen es **desplegar la
# cara con una proyección plana frontal**: con ese despliegue, la coordenada UV
# de un punto es directamente su (x, z) en el modelo, así que se sabe
# exactamente qué píxel pintar para poner un ojo en su sitio.


def _elipse(pix, n, cx, cy, rx, ry, color, borde=0.0, color_borde=None):
    """Pinta una elipse en la textura. `cx`,`cy`,`rx`,`ry` van en 0..1."""
    x0 = max(0, int((cx - rx - borde) * n))
    x1 = min(n - 1, int((cx + rx + borde) * n))
    y0 = max(0, int((cy - ry - borde) * n))
    y1 = min(n - 1, int((cy + ry + borde) * n))
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            dx = (x / float(n) - cx) / max(rx, 1e-6)
            dy = (y / float(n) - cy) / max(ry, 1e-6)
            d = math.sqrt(dx * dx + dy * dy)
            i = (y * n + x) * 4
            if borde > 0.0 and color_borde is not None and d <= 1.0 + borde / max(rx, 1e-6):
                if d > 1.0:
                    pix[i] = color_borde[0]
                    pix[i + 1] = color_borde[1]
                    pix[i + 2] = color_borde[2]
                    continue
            if d <= 1.0:
                # Antialiasing barato en el último 12 % del radio: sin él los
                # ojos se ven dentados en cuanto la cámara se acerca.
                mezcla = min(1.0, (1.0 - d) / 0.12)
                for c in range(3):
                    pix[i + c] += (color[c] - pix[i + c]) * mezcla


def _luna_pintada(pix, n, cx, cy, radio, color):
    """Media luna: se pinta un disco y se le borra otro desplazado."""
    x0 = max(0, int((cx - radio) * n))
    x1 = min(n - 1, int((cx + radio) * n))
    y0 = max(0, int((cy - radio) * n))
    y1 = min(n - 1, int((cy + radio) * n))
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px = x / float(n)
            py = y / float(n)
            fuera = math.hypot(px - cx, py - cy) / radio
            dentro = math.hypot(px - (cx + radio * 0.42), py - cy) / (radio * 0.78)
            if fuera <= 1.0 and dentro > 1.0:
                mezcla = min(1.0, (1.0 - fuera) / 0.10, (dentro - 1.0) / 0.10)
                i = (y * n + x) * 4
                for c in range(3):
                    pix[i + c] += (color[c] - pix[i + c]) * max(0.0, mezcla)


def _textura_cara(nombre, ficha, n=512):
    """Pinta la cara entera: pelaje de fondo y encima los rasgos."""
    clave = "cara_" + nombre
    if clave in bpy.data.images:
        return bpy.data.images[clave]

    base = ficha["pelaje"]
    pix = [0.0] * (n * n * 4)
    for y in range(n):
        for x in range(n):
            i = (y * n + x) * 4
            ruido = (_aleatorio(x * 2.3 + y * 5.7) - 0.5) * 0.05
            pix[i] = min(1.0, max(0.0, base[0] + ruido))
            pix[i + 1] = min(1.0, max(0.0, base[1] + ruido))
            pix[i + 2] = min(1.0, max(0.0, base[2] + ruido))
            pix[i + 3] = 1.0

    # Coordenadas en el despliegue frontal: u es el ancho de la cara (0,5 es el
    # centro) y v la altura (0 abajo, 1 arriba).
    contorno = (0.13, 0.11, 0.15)
    for lado in (-1, 1):
        cx = 0.5 + lado * 0.180
        cy = 0.575
        # Delineado del ojo. Va grueso ARRIBA y se va perdiendo abajo, que es
        # como se dibuja un ojo de anime: cerrando el círculo entero queda un
        # aro redondo de dibujo animado viejo, y en Artemis cantaba mucho.
        #
        # Se consigue pintando el contorno entero y tapándolo después con el
        # blanco del ojo ligeramente bajado: arriba asoma, abajo no.
        _elipse(pix, n, cx, cy, 0.150, 0.188, contorno)
        _elipse(pix, n, cx, cy - 0.020, 0.146, 0.180, BLANCO_OJO)
        _elipse(pix, n, cx, cy, 0.104, 0.132, ficha["iris"])
        _elipse(pix, n, cx, cy, 0.048, 0.068, NEGRO_PUPILA)
        _elipse(pix, n, cx + lado * 0.042, cy + 0.055, 0.036, 0.042, BLANCO_OJO)
        # Pestañas: un arco FINO en el borde de arriba, no una ceja gruesa
        # flotando por encima —eso en un gato blanco parecen dos orugas.
        _elipse(pix, n, cx, cy + 0.176, 0.132, 0.016, contorno)
        _elipse(pix, n, cx, cy + 0.196, 0.140, 0.018, base)

    _elipse(pix, n, 0.5, 0.385, 0.036, 0.025, ficha["nariz"])
    for lado in (-1, 1):
        _elipse(pix, n, 0.5 + lado * 0.036, 0.335, 0.032, 0.013, contorno)
    # La luna va en la FRENTE, justo encima de los ojos. Más arriba se sube al
    # filo del cráneo y desde el juego parece que flota entre las orejas.
    _luna_pintada(pix, n, 0.5, 0.845, 0.092, LUNA_DORADA)

    imagen = bpy.data.images.new(clave, n, n)
    imagen.pixels = pix
    return imagen


# --- Proceso -------------------------------------------------------------------

def _cargar_y_orientar(ficha):
    _limpiar()
    bpy.ops.import_scene.gltf(filepath=os.path.join(ENTRADA, ficha["archivo"]))
    mallas = [o for o in bpy.data.objects if o.type == 'MESH']
    bpy.ops.object.select_all(action='DESELECT')
    for m in mallas:
        m.select_set(True)
    bpy.context.view_layer.objects.active = mallas[0]
    if len(mallas) > 1:
        bpy.ops.object.join()
    gato = bpy.context.view_layer.objects.active
    bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
    for e in [o for o in bpy.data.objects if o.type == 'EMPTY']:
        bpy.data.objects.remove(e, do_unlink=True)
    _activar(gato)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

    # Hacia dónde mira se MIDE, no se supone: estos modelos salen girados en
    # diagonal (Luna venía a −143°) porque la foto de origen era de tres
    # cuartos, y cada gato puede traer un ángulo distinto.
    #
    # Las orejas son la referencia: son lo más alto del bicho, y su centro
    # respecto al del cuerpo da la dirección de la cabeza.
    vs = gato.data.vertices
    n = len(vs)
    centro = Vector((sum(v.co.x for v in vs) / n, sum(v.co.y for v in vs) / n, 0.0))
    corte = sorted(v.co.z for v in vs)[int(n * 0.985)]
    orejas = [v.co for v in vs if v.co.z >= corte]
    hacia = Vector((sum(c.x for c in orejas) / len(orejas) - centro.x,
                    sum(c.y for c in orejas) / len(orejas) - centro.y, 0.0))
    # Se gira hasta que mire a −Y, que al exportar en Y-up es el +Z que espera
    # el montaje de personajes.
    correccion = -math.pi * 0.5 - math.atan2(hacia.y, hacia.x)
    gato.data.transform(_rotacion_z(correccion))
    gato.data.update()

    # Escala real y apoyado en el suelo
    vs = gato.data.vertices
    alto = max(v.co.z for v in vs) - min(v.co.z for v in vs)
    factor = ALTURA_CRUZ / alto
    gato.data.transform(_escala(factor))
    gato.data.update()
    _activar(gato)
    bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY', center='BOUNDS')
    gato.location = (0, 0, 0)
    gato.location.z -= min((gato.matrix_world @ v.co).z for v in gato.data.vertices)
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
    return gato


def _rotacion_z(angulo):
    from mathutils import Matrix
    return Matrix.Rotation(angulo, 4, 'Z')


def _escala(factor):
    from mathutils import Matrix
    return Matrix.Scale(factor, 4)


def _limpiar_malla(gato, nombre, ficha):
    _activar(gato)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.remove_doubles(threshold=0.0001)
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')

    n = sum(len(p.vertices) - 2 for p in gato.data.polygons)
    if n > TRIS_OBJETIVO:
        m = gato.modifiers.new(name="Dec", type='DECIMATE')
        m.decimate_type = 'COLLAPSE'
        m.ratio = float(TRIS_OBJETIVO) / n
        m.use_symmetry = True
        m.symmetry_axis = 'X'
        bpy.ops.object.modifier_apply(modifier="Dec")

    # Fuera la textura fotográfica: con ella se van todas las rayas del lado
    # que la foto no vio, y también los ojos duplicados de la cara.
    gato.data.materials.clear()
    gato.data.materials.append(_material(
        "pelaje_" + nombre, ficha["pelaje"],
        _textura_pelaje(nombre, ficha["pelaje"])))
    _activar(gato)
    bpy.ops.object.shade_smooth()
    return gato


def _medir_cabeza(gato):
    """Dónde está la cara y cómo de grande es.

    Los dos primeros intentos fallaron por lo mismo: tomar «el trozo más
    adelantado» del gato incluye el pecho, porque estos modelos llevan el
    cuello estirado hacia delante. Los ojos acababan en el pecho.
    """
    vs = gato.data.vertices
    n = len(vs)

    # Las OREJAS son la referencia fiable: son lo más alto del animal y están
    # justo encima de la cara.
    corte = sorted(v.co.z for v in vs)[int(n * 0.99)]
    orejas = [v.co for v in vs if v.co.z >= corte]
    ox = sum(c.x for c in orejas) / len(orejas)
    oy = sum(c.y for c in orejas) / len(orejas)
    oz = sum(c.z for c in orejas) / len(orejas)

    # La cabeza es lo que queda dentro de una esfera colgada de las orejas.
    centro = Vector((ox, oy, oz - 0.06))
    cabeza = [v.co for v in vs if (v.co - centro).length < 0.11]
    if len(cabeza) < 50:
        cabeza = [v.co for v in vs if (v.co - centro).length < 0.18]

    y_morro = min(c.y for c in cabeza)
    z_menton = min(c.z for c in cabeza)
    ancho = max(c.x for c in cabeza) - min(c.x for c in cabeza)
    alto = oz - z_menton

    return {
        "x": ox,
        "y": y_morro,
        # Los ojos van en el tercio superior de la cabeza, no en su centro:
        # es lo que da la cara de gato de dibujos en vez de la de gato real.
        "z": z_menton + alto * 0.56,
        "ancho": ancho,
        "alto": alto,
        "z_orejas": oz,
    }


def _superficie_y(gato, x, z, radio):
    """Hasta dónde llega la cara en ese punto concreto.

    Es lo que faltaba: colocar todos los rasgos a la altura del MORRO los deja
    flotando en el aire, porque el morro sobresale bastante más que la frente
    o los pómulos. Cada pieza tiene que pegarse a la superficie que le toca.
    """
    cerca = [v.co.y for v in gato.data.vertices
             if abs(v.co.x - x) < radio and abs(v.co.z - z) < radio]
    if not cerca:
        cerca = [v.co.y for v in gato.data.vertices
                 if abs(v.co.x - x) < radio * 2.5 and abs(v.co.z - z) < radio * 2.5]
    return min(cerca) if cerca else 0.0


def _pintar_cara(gato, nombre, ficha):
    """Despliega la cara con proyección frontal y le asigna la textura pintada.

    La clave es el despliegue: proyectando de frente, la UV de cada punto es su
    (x, z) normalizado dentro de la caja de la cara. Eso permite pintar un ojo
    «a un 18 % del centro y a un 60 % de altura» y saber que va a caer donde
    tiene que caer, sin adivinar y sin depender de las UV originales, que en
    estos modelos están rotas.
    """
    m = _medir_cabeza(gato)

    # La cara: lo que está en la mitad delantera de la cabeza y mirando al
    # frente. Se pide que la normal apunte hacia −Y para no pillar el cogote,
    # que en la proyección caería encima de los ojos.
    media_x = m["ancho"] * 0.62
    limite_y = m["y"] + m["alto"] * 0.85
    cara = set()
    for poligono in gato.data.polygons:
        centro = poligono.center
        if centro.y > limite_y:
            continue
        if abs(centro.x - m["x"]) > media_x:
            continue
        if centro.z < m["z"] - m["alto"] * 0.75 or centro.z > m["z"] + m["alto"] * 0.85:
            continue
        # Solo lo que mira de frente de verdad. Con un umbral flojo entra el
        # lateral del cráneo, y como la proyección es plana, el ojo se estira
        # envolviendo la mejilla.
        if poligono.normal.y > -0.42:
            continue
        cara.add(poligono.index)
    if not cara:
        return 0

    material = _material("cara_" + nombre, ficha["pelaje"],
                         _textura_cara(nombre, ficha))
    gato.data.materials.append(material)
    indice_cara = len(gato.data.materials) - 1

    # Caja de la cara, para normalizar. Se toma de los polígonos elegidos y no
    # de la cabeza entera: así los rasgos quedan centrados en lo que se ve.
    xs, zs = [], []
    for i in cara:
        for vi in gato.data.polygons[i].vertices:
            co = gato.data.vertices[vi].co
            xs.append(co.x)
            zs.append(co.z)
    x0, x1 = min(xs), max(xs)
    z0, z1 = min(zs), max(zs)
    ancho = max(x1 - x0, 1e-6)
    alto = max(z1 - z0, 1e-6)

    capa = gato.data.uv_layers.active
    if capa is None:
        capa = gato.data.uv_layers.new(name="UVMap")
    for i in cara:
        poligono = gato.data.polygons[i]
        poligono.material_index = indice_cara
        for bucle in range(poligono.loop_start, poligono.loop_start + poligono.loop_total):
            co = gato.data.vertices[gato.data.loops[bucle].vertex_index].co
            capa.data[bucle].uv = ((co.x - x0) / ancho, (co.z - z0) / alto)
    return len(cara)


def preparar(nombre):
    ficha = GATOS[nombre]
    gato = _cargar_y_orientar(ficha)
    gato = _limpiar_malla(gato, nombre, ficha)
    caras = _pintar_cara(gato, nombre, ficha)
    final = gato
    final.name = nombre
    final.data.name = nombre

    if not os.path.isdir(SALIDA):
        os.makedirs(SALIDA)
    ruta = "%s/%s.glb" % (SALIDA, nombre)
    _activar(final)
    bpy.ops.export_scene.gltf(filepath=ruta, export_format='GLB',
                              use_selection=True, export_apply=True,
                              export_yup=True, export_materials='EXPORT')
    return {"caras_pintadas": caras,
            "tris": sum(len(p.vertices) - 2 for p in final.data.polygons),
            "kb": round(os.path.getsize(ruta) / 1024),
            "alto_cm": round(final.dimensions.z * 100),
            "largo_cm": round(final.dimensions.y * 100)}


def preparar_gatos():
    return {n: preparar(n) for n in GATOS}
