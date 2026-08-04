"""
Prepara un modelo generado por IA (hi3d.ai, Tripo, Meshy...) para el juego.

Los generadores de IA sueltan mallas de ~2.000.000 de triángulos con texturas
4K. Este script las deja en presupuesto de móvil sin perder la silueta.

QUÉ HACE
    1. Une todas las mallas en una (menos draw calls)
    2. Quita los Empty que mete el importador glTF
    3. Suelda vértices duplicados y arregla las normales
    4. Escala a la altura real en metros y pone el origen en la base
    5. Decima con simetría en X (en un humanoide conserva mucho mejor la cara)
    6. Baja la resolución de las texturas
    7. Exporta GLB (para Godot) y, opcionalmente, FBX (para Mixamo)

CÓMO SE USA
    Blender > pestaña Scripting > abrir este archivo > ajustar CONFIG > Ejecutar.

    O por línea de comandos:
        blender --background --python tools/blender_preparar_modelo.py

PRESUPUESTOS (de docs/01-ARQUITECTURA.md §8)
    Personaje principal   25.000 tris   textura 2048
    Enemigo                5.000 tris   textura 1024
    Prop grande            3.000 tris   textura  512
    Prop pequeño           1.000 tris   textura  512
"""

import bpy
import os

# --------------------------------------------------------------------------
# CONFIG — edita esto y ejecuta
# --------------------------------------------------------------------------
ENTRADA = "/Users/mac/Documents/Dev/Games/sailor-moon/Models/Serena.glb"
SALIDA = "/Users/mac/Documents/Dev/Games/sailor-moon/assets/models/characters/serena_sailor.glb"
NOMBRE = "Serena"
TRIANGULOS = 25000
TEXTURA = 2048
ALTURA_M = 1.55          # altura real del personaje en metros
EXPORTAR_FBX = True      # para subirlo a Mixamo
# --------------------------------------------------------------------------


def preparar(entrada, salida, nombre, triangulos, textura, altura_m, exportar_fbx=False):
    # OJO: `read_homefile` invalida el contexto para los operadores que vengan
    # después en el MISMO script. Por eso importamos aquí y procesamos abajo,
    # y por eso desde el MCP hay que hacerlo en dos llamadas separadas.
    bpy.ops.wm.read_homefile(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=entrada)

    mallas = [o for o in bpy.data.objects if o.type == 'MESH']
    if not mallas:
        raise RuntimeError("El archivo no contiene mallas: %s" % entrada)

    bpy.ops.object.select_all(action='DESELECT')
    for m in mallas:
        m.select_set(True)
    bpy.context.view_layer.objects.active = mallas[0]
    if len(mallas) > 1:
        bpy.ops.object.join()

    ob = bpy.context.view_layer.objects.active
    ob.name = nombre
    ob.data.name = nombre + "Mesh"
    tris_iniciales = _contar_tris(ob)

    # --- Limpiar jerarquía del glTF ---
    bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
    for e in [o for o in bpy.data.objects if o.type == 'EMPTY']:
        bpy.data.objects.remove(e, do_unlink=True)
    # Quitar los Empty limpia la selección: hay que reafirmarla o el siguiente
    # operador falla con "Falta objeto activo en el contexto".
    _activar(ob)

    # --- Soldar duplicados y normales coherentes ---
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.remove_doubles(threshold=0.0001)
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')

    # --- Escala real y origen en la base ---
    # Primero se aplican las transformaciones heredadas del padre; si no, al
    # asignar `scale` se sobrescribe la escala absorbida y el tamaño sale mal.
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    factor = altura_m / ob.dimensions.z
    ob.scale = (factor, factor, factor)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

    bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY', center='BOUNDS')
    ob.location = (0, 0, 0)
    ob.location.z -= min((ob.matrix_world @ v.co).z for v in ob.data.vertices)
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)

    # --- Decimación ---
    tris_ahora = _contar_tris(ob)
    if tris_ahora > triangulos:
        mod = ob.modifiers.new(name="Decimate", type='DECIMATE')
        mod.decimate_type = 'COLLAPSE'
        mod.ratio = triangulos / tris_ahora
        # La simetría reparte los recortes por igual a ambos lados: en una cara
        # es la diferencia entre que quede bien o que salga un ojo torcido.
        mod.use_symmetry = True
        mod.symmetry_axis = 'X'
        bpy.ops.object.modifier_apply(modifier="Decimate")

    # --- Texturas ---
    for img in bpy.data.images:
        if img.size[0] > textura:
            img.scale(textura, textura)

    # --- Exportar ---
    os.makedirs(os.path.dirname(salida), exist_ok=True)
    _activar(ob)
    bpy.ops.export_scene.gltf(
        filepath=salida, export_format='GLB', use_selection=True,
        export_apply=True, export_yup=True, export_materials='EXPORT',
    )

    fbx = None
    if exportar_fbx:
        fbx = os.path.splitext(salida)[0] + "_para_mixamo.fbx"
        bpy.ops.export_scene.fbx(
            filepath=fbx, use_selection=True, apply_scale_options='FBX_SCALE_ALL',
            path_mode='COPY', embed_textures=True, axis_forward='-Z', axis_up='Y',
        )

    return {
        "triangulos": "%d -> %d" % (tris_iniciales, _contar_tris(ob)),
        "altura_m": round(ob.dimensions.z, 3),
        "glb_mb": round(os.path.getsize(salida) / 1048576, 2),
        "fbx": fbx,
    }


def _contar_tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def _activar(ob):
    bpy.ops.object.select_all(action='DESELECT')
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob


if __name__ == "__main__":
    print(preparar(ENTRADA, SALIDA, NOMBRE, TRIANGULOS, TEXTURA, ALTURA_M, EXPORTAR_FBX))
