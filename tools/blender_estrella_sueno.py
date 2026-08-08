# Modela la Estrella de Sueño: el coleccionable del juego, con cara.
#
# La versión anterior eran dos prismas cruzados y un núcleo: se entendía, pero
# era un icono de menú, no un personaje. Con ojos y sonrisa pasa a ser una
# criatura del mundo, que es lo que pide un juego de magical girl — y encima
# la hace mucho más fácil de ver de lejos, porque la cara destaca sobre la
# silueta dorada.
#
# Uso desde el MCP de Blender:
#   exec(open("tools/blender_estrella_sueno.py").read())
#   result = generar_estrella()

import bpy
import bmesh
import math
import os
from mathutils import Vector

SALIDA = "/Users/mac/Documents/Dev/Games/sailor-moon/assets/models/pickups"

COLORES = {
    "estrella_cuerpo": (1.00, 0.84, 0.30),
    "estrella_borde":  (1.00, 0.95, 0.72),
    "estrella_ojo":    (0.16, 0.12, 0.22),
    "estrella_brillo": (1.00, 1.00, 1.00),
    "estrella_mejilla": (1.00, 0.62, 0.66),
}


def _limpiar():
    for objeto in list(bpy.data.objects):
        bpy.data.objects.remove(objeto, do_unlink=True)
    for bloque in (bpy.data.meshes, bpy.data.materials, bpy.data.images):
        for item in list(bloque):
            if item.users == 0:
                bloque.remove(item)


def _material(nombre, emision=0.0):
    if nombre in bpy.data.materials:
        return bpy.data.materials[nombre]
    material = bpy.data.materials.new(nombre)
    material.use_nodes = True
    bsdf = next(n for n in material.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    color = COLORES[nombre]
    bsdf.inputs["Base Color"].default_value = (color[0], color[1], color[2], 1.0)
    bsdf.inputs["Roughness"].default_value = 0.55
    if emision > 0.0:
        bsdf.inputs["Emission Color"].default_value = (color[0], color[1], color[2], 1.0)
        bsdf.inputs["Emission Strength"].default_value = emision
    return material


def _objeto(nombre, material, bm, emision=0.0, suave=False):
    malla = bpy.data.meshes.new(nombre)
    bm.to_mesh(malla)
    bm.free()
    objeto = bpy.data.objects.new(nombre, malla)
    objeto.data.materials.append(_material(material, emision))
    bpy.context.collection.objects.link(objeto)
    if suave:
        bpy.ops.object.select_all(action='DESELECT')
        objeto.select_set(True)
        bpy.context.view_layer.objects.active = objeto
        bpy.ops.object.shade_smooth()
    return objeto


def _cuerpo_estrella(radio_ext=0.5, radio_int=0.21, grosor=0.16):
    """Estrella de cinco puntas, extruida y con el frente abombado.

    El abombado importa: una estrella plana recortada parece una pegatina, y
    en cuanto gira desaparece. Con volumen se lee desde cualquier ángulo.
    """
    bm = bmesh.new()
    vertices = []
    for i in range(10):
        angulo = math.pi / 2.0 + i * math.pi / 5.0
        radio = radio_ext if i % 2 == 0 else radio_int
        vertices.append(bm.verts.new((math.cos(angulo) * radio,
                                      0.0,
                                      math.sin(angulo) * radio)))
    bm.verts.ensure_lookup_table()
    cara = bm.faces.new(vertices)

    resultado = bmesh.ops.extrude_face_region(bm, geom=[cara])
    desplazados = [g for g in resultado["geom"] if isinstance(g, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, verts=desplazados, vec=(0.0, grosor, 0.0))

    # Se abomba llevando cada cara hacia fuera según lo cerca que esté del
    # centro: las puntas quedan finas y el centro gordito.
    for vertice in bm.verts:
        distancia = math.sqrt(vertice.co.x ** 2 + vertice.co.z ** 2)
        curva = 1.0 - min(1.0, distancia / radio_ext)
        vertice.co.y += (grosor * 0.45 * curva) * (1.0 if vertice.co.y > 0.001 else -1.0)

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def _disco(centro, radio, grosor, achatado_y=1.0):
    bm = bmesh.new()
    bmesh.ops.create_circle(bm, cap_ends=True, segments=12, radius=radio)
    # El círculo nace tumbado en el plano XY. Se pasa al plano XZ para que
    # mire al frente (−Y), que es hacia donde da la cara de la estrella.
    for vertice in bm.verts:
        vertice.co.z = vertice.co.y * achatado_y
        vertice.co.y = 0.0
    resultado = bmesh.ops.extrude_face_region(bm, geom=list(bm.faces))
    desplazados = [g for g in resultado["geom"] if isinstance(g, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, verts=desplazados, vec=(0.0, grosor, 0.0))
    bmesh.ops.translate(bm, verts=bm.verts, vec=centro)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def _sonrisa(centro, ancho, alto, grosor):
    """Arco de boca: puntos sobre una parábola, engordados en un rectángulo
    cada uno. Un toro cortado daría lo mismo con el triple de geometría."""
    bm = bmesh.new()
    # Muchos trozos, cortos y bien solapados. Con pocos, la curva se ve como
    # una escalera de píxeles en vez de como una sonrisa.
    pasos = 13
    for i in range(pasos):
        t = i / float(pasos - 1)
        x = (t - 0.5) * ancho
        z = -alto * (1.0 - (2.0 * (t - 0.5)) ** 2)
        # Cada trozo se inclina siguiendo la pendiente de la curva, que es lo
        # que remata el escalonado en las esquinas de la boca.
        pendiente = -alto * 2.0 * (2.0 * (t - 0.5)) * 2.0 / ancho
        angulo = math.atan(pendiente)
        temporal = bmesh.new()
        bmesh.ops.create_cube(temporal, size=1.0)
        for vertice in temporal.verts:
            vertice.co.x *= ancho / float(pasos) * 2.1
            vertice.co.y *= grosor
            vertice.co.z *= alto * 0.30
            vx, vz = vertice.co.x, vertice.co.z
            vertice.co.x = vx * math.cos(angulo) - vz * math.sin(angulo)
            vertice.co.z = vx * math.sin(angulo) + vz * math.cos(angulo)
            vertice.co += Vector((x, 0.0, z))
        malla = bpy.data.meshes.new("tmp")
        temporal.to_mesh(malla)
        temporal.free()
        bm.from_mesh(malla)
        bpy.data.meshes.remove(malla)
    bmesh.ops.translate(bm, verts=bm.verts, vec=centro)
    return bm


def generar_estrella():
    _limpiar()

    cuerpo = _objeto("cuerpo", "estrella_cuerpo", _cuerpo_estrella(), emision=0.35)

    # La cara va en la mitad delantera (−Y): al girar, aparece y desaparece,
    # que es parte de la gracia.
    frente = -0.115
    piezas = [cuerpo]
    for lado in (-1, 1):
        piezas.append(_objeto("ojo%d" % lado, "estrella_ojo",
                              _disco((lado * 0.135, frente, 0.055), 0.075, 0.05, 1.25),
                              suave=True))
        piezas.append(_objeto("brillo%d" % lado, "estrella_brillo",
                              _disco((lado * 0.155, frente - 0.03, 0.085), 0.028, 0.03),
                              emision=0.6, suave=True))
        piezas.append(_objeto("mejilla%d" % lado, "estrella_mejilla",
                              _disco((lado * 0.245, frente + 0.01, -0.035), 0.052, 0.03, 0.7),
                              suave=True))
    piezas.append(_objeto("boca", "estrella_ojo",
                          _sonrisa((0.0, frente, -0.045), 0.15, 0.075, 0.05)))

    bpy.ops.object.select_all(action='DESELECT')
    for pieza in piezas:
        pieza.select_set(True)
    bpy.context.view_layer.objects.active = cuerpo
    bpy.ops.object.join()

    estrella = bpy.context.view_layer.objects.active
    estrella.name = "estrella_sueno"
    estrella.data.name = "estrella_sueno"

    if not os.path.isdir(SALIDA):
        os.makedirs(SALIDA)
    ruta = "%s/estrella_sueno.glb" % SALIDA
    bpy.ops.export_scene.gltf(filepath=ruta, export_format='GLB', use_selection=True,
                              export_apply=True, export_yup=True,
                              export_materials='EXPORT')
    return {"tris": sum(len(p.vertices) - 2 for p in estrella.data.polygons),
            "kb": round(os.path.getsize(ruta) / 1024),
            "alto": round(estrella.dimensions.z, 2)}
