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
}


def _limpiar():
    for objeto in list(bpy.data.objects):
        bpy.data.objects.remove(objeto, do_unlink=True)
    for bloque in (bpy.data.meshes, bpy.data.materials, bpy.data.images):
        for item in list(bloque):
            if item.users == 0:
                bloque.remove(item)


def _material(nombre):
    if nombre in bpy.data.materials:
        return bpy.data.materials[nombre]
    material = bpy.data.materials.new(nombre)
    material.use_nodes = True
    bsdf = next(n for n in material.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    color = PALETA[nombre]
    bsdf.inputs["Base Color"].default_value = (color[0], color[1], color[2], 1.0)
    bsdf.inputs["Roughness"].default_value = 0.9
    return material


def _pieza(nombre, material, malla_bm):
    malla = bpy.data.meshes.new(nombre)
    malla_bm.to_mesh(malla)
    malla_bm.free()
    objeto = bpy.data.objects.new(nombre, malla)
    objeto.data.materials.append(_material(material))
    bpy.context.collection.objects.link(objeto)
    return objeto


def _esfera(bm, centro, radio, achatado=1.0, cortes=8, ruido=0.0):
    temporal = bmesh.new()
    bmesh.ops.create_icosphere(temporal, subdivisions=1 if cortes <= 8 else 2,
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
    _cilindro(bm, (0, 0, 0.95), 0.15, 0.09, 1.9, lados=7)
    _cilindro(bm, (-0.26, 0.08, 1.95), 0.07, 0.05, 0.75, lados=5)
    _cilindro(bm, (0.24, -0.10, 2.00), 0.07, 0.05, 0.80, lados=5)
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
    for constructor in (cerezo, toro, arbusto, valla, banco, papelera, roca):
        _limpiar()
        objeto = constructor()
        piezas[objeto.name] = _exportar(objeto)
    return piezas
