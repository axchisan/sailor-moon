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

# Un gato adulto mide unos 25-30 cm de cruz. Se deja en 0,30: al lado de
# Serena (1,55 m) tiene que leerse como un gato, no como un perro.
ALTURA_CRUZ = 0.30
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


# --- Piezas de la cara ---------------------------------------------------------

def _disco(centro, radio, grosor, normal_y=-1.0, achatado=1.0):
    """Disco mirando al frente (−Y), que es hacia donde mira el gato."""
    bm = bmesh.new()
    bmesh.ops.create_circle(bm, cap_ends=True, segments=14, radius=radio)
    for v in bm.verts:
        v.co.z = v.co.y * achatado
        v.co.y = 0.0
    r = bmesh.ops.extrude_face_region(bm, geom=list(bm.faces))
    movidos = [g for g in r["geom"] if isinstance(g, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, verts=movidos, vec=(0.0, grosor * normal_y, 0.0))
    bmesh.ops.translate(bm, verts=bm.verts, vec=centro)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def _media_luna(centro, radio, grosor):
    """La luna creciente de la frente: un disco al que se le resta otro
    desplazado. Es su seña de identidad, así que va en geometría propia."""
    bm = bmesh.new()
    puntos = []
    pasos = 16
    # borde exterior
    for i in range(pasos + 1):
        a = math.pi * 0.5 + math.pi * (float(i) / pasos)
        puntos.append((math.cos(a) * radio, math.sin(a) * radio))
    # borde interior, de vuelta
    for i in range(pasos, -1, -1):
        a = math.pi * 0.5 + math.pi * (float(i) / pasos)
        puntos.append((math.cos(a) * radio * 0.62 + radio * 0.30,
                       math.sin(a) * radio * 0.78))
    verts = [bm.verts.new((p[0], 0.0, p[1])) for p in puntos]
    bm.verts.ensure_lookup_table()
    try:
        cara = bm.faces.new(verts)
    except ValueError:
        bm.free()
        return None
    r = bmesh.ops.extrude_face_region(bm, geom=[cara])
    movidos = [g for g in r["geom"] if isinstance(g, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, verts=movidos, vec=(0.0, -grosor, 0.0))
    bmesh.ops.translate(bm, verts=bm.verts, vec=centro)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def _objeto(nombre, material, bm, suave=True):
    malla = bpy.data.meshes.new(nombre)
    bm.to_mesh(malla)
    bm.free()
    objeto = bpy.data.objects.new(nombre, malla)
    objeto.data.materials.append(material)
    bpy.context.collection.objects.link(objeto)
    if suave:
        _activar(objeto)
        bpy.ops.object.shade_smooth()
    return objeto


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


def _poner_cara(gato, nombre, ficha):
    m = _medir_cabeza(gato)
    piezas = []
    a = m["ancho"]
    # Proporciones de gato de anime: ojos enormes, separados algo menos de un
    # tercio del ancho de la cara, y colocados en la mitad alta del morro.
    sep = a * 0.25
    alto_ojo = m["z"]
    # Los rasgos van justo POR DELANTE de la cara, no dentro: metidos hacia
    # atrás la geometría del morro los tapa a medias y quedan como cortados.
    frente = m["y"] + a * 0.015
    radio_ojo = a * 0.21

    mat_blanco = _material("ojo_blanco", BLANCO_OJO)
    mat_iris = _material("iris_" + nombre, ficha["iris"])
    mat_pupila = _material("pupila", NEGRO_PUPILA)
    mat_brillo = _material("brillo_ojo", BLANCO_OJO, emision=0.5)
    mat_oreja = _material("oreja_" + nombre, ficha["oreja"])
    mat_nariz = _material("nariz_" + nombre, ficha["nariz"])
    mat_luna = _material("luna_dorada", LUNA_DORADA, emision=0.25)

    for lado in (-1, 1):
        cx = m["x"] + lado * sep
        piezas.append(_objeto("ojo%d" % lado, mat_blanco,
            _disco(Vector((cx, frente + 0.004, alto_ojo)), radio_ojo, 0.012,
                   achatado=1.18)))
        piezas.append(_objeto("iris%d" % lado, mat_iris,
            _disco(Vector((cx, frente, alto_ojo)), radio_ojo * 0.72, 0.010,
                   achatado=1.15)))
        piezas.append(_objeto("pupila%d" % lado, mat_pupila,
            _disco(Vector((cx, frente - 0.004, alto_ojo)), radio_ojo * 0.34, 0.008,
                   achatado=1.3)))
        piezas.append(_objeto("brillo%d" % lado, mat_brillo,
            _disco(Vector((cx + lado * radio_ojo * 0.22, frente - 0.008,
                           alto_ojo + radio_ojo * 0.32)),
                   radio_ojo * 0.20, 0.006)))

    piezas.append(_objeto("nariz", mat_nariz,
        _disco(Vector((m["x"], frente - 0.002, m["z"] - m["alto"] * 0.26)),
               a * 0.06, 0.008, achatado=0.75)))

    # La luna va en la frente, entre los ojos y las orejas.
    for lado in (-1, 1):
        piezas.append(_objeto("boca%d" % lado, mat_pupila,
            _disco(Vector((m["x"] + lado * a * 0.045, frente - 0.001,
                           m["z"] - m["alto"] * 0.36)),
                   a * 0.045, 0.006, achatado=0.42)))

    luna = _media_luna(Vector((m["x"], frente + 0.002,
                               m["z"] + m["alto"] * 0.40)),
                       a * 0.15, 0.008)
    if luna is not None:
        piezas.append(_objeto("luna_frente", mat_luna, luna, suave=False))

    return piezas


def preparar(nombre):
    ficha = GATOS[nombre]
    gato = _cargar_y_orientar(ficha)
    gato = _limpiar_malla(gato, nombre, ficha)
    piezas = _poner_cara(gato, nombre, ficha)

    bpy.ops.object.select_all(action='DESELECT')
    gato.select_set(True)
    for p in piezas:
        p.select_set(True)
    bpy.context.view_layer.objects.active = gato
    bpy.ops.object.join()
    final = bpy.context.view_layer.objects.active
    final.name = nombre
    final.data.name = nombre

    if not os.path.isdir(SALIDA):
        os.makedirs(SALIDA)
    ruta = "%s/%s.glb" % (SALIDA, nombre)
    _activar(final)
    bpy.ops.export_scene.gltf(filepath=ruta, export_format='GLB',
                              use_selection=True, export_apply=True,
                              export_yup=True, export_materials='EXPORT')
    return {"tris": sum(len(p.vertices) - 2 for p in final.data.polygons),
            "kb": round(os.path.getsize(ruta) / 1024),
            "alto_cm": round(final.dimensions.z * 100),
            "largo_cm": round(final.dimensions.y * 100)}


def preparar_gatos():
    return {n: preparar(n) for n in GATOS}
