# Pone esqueleto y animaciones a Luna y Artemis.
#
# POR QUÉ A MANO
#
# Mixamo, que es lo que se usa para las once Sailors, solo sabe de bípedos: le
# das un gato y te devuelve un humano descoyuntado. Un cuadrúpedo hay que
# montarlo a mano. La buena noticia es que un gato de fondo necesita muy poco:
# cuatro patas que alternen, una columna que respire y una cola.
#
# LAS MEDIDAS SE MIDEN, NO SE ESCRIBEN
#
# Luna y Artemis salieron del mismo generador pero no son la misma malla: las
# patas no caen en el mismo sitio ni la cola nace a la misma altura. Escribir
# las coordenadas de Luna y aplicárselas a Artemis deja los huesos fuera de la
# carne y el pintado de pesos hace cosas muy raras. Así que cada cota se saca
# de la geometría:
#
#   · Hacia dónde mira → las orejas, que son lo más alto.
#   · Dónde pisa cada pata → el 12% de vértices más bajo, en cuatro grupos.
#   · Dónde nace la cola → por dónde el cuerpo pasa de ancho a fino.
#
# LA COLA NO SE ANIMA
#
# Ninguna acción toca los huesos de la cola: la mueve `HairPhysics` en Godot,
# con la misma `SpringBoneChain` que ya llevan las coletas de Serena. Una cola
# animada a mano siempre va a destiempo del movimiento; una con física
# reacciona a los giros y a los frenazos sola, que es justo lo que hace una
# cola de gato de verdad.
#
# Uso desde el MCP de Blender:
#   exec(open("tools/blender_riguear_gatos.py").read())
#   result = riguear_gatos()

import bpy
import math
import os
from mathutils import Vector, Matrix

MODELOS = "/Users/mac/Documents/Dev/Games/sailor-moon/assets/models/characters"
GATOS = ["luna", "artemis"]

# 24 fps es de sobra para un gato que se ve de lejos, y deja las curvas
# legibles si hay que retocarlas a mano en el editor.
FPS = 24
CICLO_ANDAR = 16      # dos zancadas completas
CICLO_IDLE = 72       # 3 s de respiración


def _limpiar():
    for objeto in list(bpy.data.objects):
        bpy.data.objects.remove(objeto, do_unlink=True)
    for acc in list(bpy.data.actions):
        bpy.data.actions.remove(acc)


def _activar(objeto):
    bpy.ops.object.select_all(action='DESELECT')
    objeto.select_set(True)
    bpy.context.view_layer.objects.active = objeto


def _cargar(nombre):
    _limpiar()
    bpy.ops.import_scene.gltf(filepath="%s/%s.glb" % (MODELOS, nombre))
    mallas = [o for o in bpy.data.objects if o.type == 'MESH']
    _activar(mallas[0])
    if len(mallas) > 1:
        for m in mallas:
            m.select_set(True)
        bpy.ops.object.join()
    gato = bpy.context.view_layer.objects.active
    bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
    for e in [o for o in bpy.data.objects if o.type == 'EMPTY']:
        bpy.data.objects.remove(e, do_unlink=True)
    _activar(gato)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    # Limpieza mínima: vértices duplicados, geometría suelta y normales al
    # revés. El exportador avisaba de «Mesh is not valid» sin decir de qué, y
    # una malla sucia también ensucia el reparto de pesos.
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.remove_doubles(threshold=0.0002)
    bpy.ops.mesh.delete_loose()
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')

    gato.name = nombre
    gato.data.name = nombre
    return gato


# --- Medir el bicho -------------------------------------------------------------

def _medir(gato):
    """Saca de la malla todo lo que hace falta para colocar los huesos."""
    vs = [v.co.copy() for v in gato.data.vertices]
    n = len(vs)
    alto = max(v.z for v in vs)

    # Hacia dónde mira: las orejas son lo más alto del animal.
    corte = sorted(v.z for v in vs)[int(n * 0.985)]
    orejas = [v for v in vs if v.z >= corte]
    frente = -1.0 if sum(v.y for v in orejas) / len(orejas) < 0.0 else 1.0

    # Las cuatro patas: el 12% más bajo, partido por lados. El corte en Y es el
    # punto medio entre la huella más adelantada y la más atrasada, que separa
    # limpiamente el tren delantero del trasero.
    zpie = sorted(v.z for v in vs)[int(n * 0.12)]
    pies = [v for v in vs if v.z <= zpie]
    ys = [v.y for v in pies]
    ycorte = (min(ys) + max(ys)) * 0.5
    huellas = {}
    for etiqueta, delante, izquierda in [
            ("del_izq", True, True), ("del_der", True, False),
            ("tra_izq", False, True), ("tra_der", False, False)]:
        # `frente` vale −1 o +1 según hacia dónde mire: multiplicar por él
        # convierte «más adelante» en «mayor», sea cual sea la orientación.
        sel = [v for v in pies
               if (((v.y - ycorte) * frente > 0.0) == delante)
               and ((v.x < 0.0) == izquierda)]
        if not sel:
            continue
        huellas[etiqueta] = Vector((
            sum(v.x for v in sel) / len(sel),
            sum(v.y for v in sel) / len(sel),
            sum(v.z for v in sel) / len(sel)))

    # Dónde nace la cola: recorriendo el cuerpo desde la punta trasera hacia
    # dentro, la cola es la parte FINA. En cuanto una sección se ensancha por
    # encima de la mitad del ancho del torso, ya es grupa.
    cola = _medir_cola(vs, frente)

    # Cabeza y torso, por secciones
    cuerpo = [v for v in vs if (v.y - cola["base"].y) * frente > 0.0]
    ycab = sorted(v.y * frente for v in cuerpo)[int(len(cuerpo) * 0.92)]
    cabeza = [v for v in cuerpo if v.y * frente >= ycab]
    centro_cabeza = Vector((0.0,
                            sum(v.y for v in cabeza) / len(cabeza),
                            sum(v.z for v in cabeza) / len(cabeza)))

    # La columna va alta, como en un gato de verdad, pero no pegada a la piel:
    # el mapa de calor del pintado automático necesita el hueso DENTRO de la
    # carne, y a ras de lomo reparte mal el peso del costado.
    lomo = [v for v in cuerpo if abs(v.x) < 0.03]
    z_lomo = sorted(v.z for v in lomo)[int(len(lomo) * 0.58)]

    return {
        "frente": frente, "alto": alto, "huellas": huellas,
        "cola": cola, "cabeza": centro_cabeza, "z_lomo": z_lomo,
        "cadera": Vector((0.0, cola["base"].y, cola["base"].z)),
        "pecho": Vector((0.0,
                         (huellas["del_izq"].y + huellas["del_der"].y) * 0.5,
                         z_lomo)),
    }


def _medir_cola(vs, frente):
    """La base de la cola y tres puntos repartidos por ella.

    La cola está en el extremo OPUESTO a la cara, de ahí el `-frente`. Con el
    signo al revés se mide el hocico, que también es fino, y el esqueleto sale
    con la cola saliéndole de la nariz.
    """
    punta = max(vs, key=lambda v: v.y * -frente)
    ancho_torso = max(abs(v.x) for v in vs) * 2.0

    # De la punta hacia el cuerpo, en tramos, hasta que deja de ser fina
    largo = max(v.y for v in vs) - min(v.y for v in vs)
    paso = largo / 40.0
    base = punta.copy()
    for i in range(40):
        y = punta.y + frente * paso * i
        sec = [v for v in vs if abs(v.y - y) < paso * 0.7]
        if not sec:
            continue
        ancho = max(v.x for v in sec) - min(v.x for v in sec)
        if ancho > ancho_torso * 0.42:
            break
        base = Vector((0.0, y, sum(v.z for v in sec) / len(sec)))

    puntos = [base]
    for t in (0.34, 0.67, 1.0):
        y = base.y + (punta.y - base.y) * t
        sec = [v for v in vs if abs(v.y - y) < paso * 0.9]
        z = sum(v.z for v in sec) / len(sec) if sec else base.z
        puntos.append(Vector((0.0, y, z)))
    return {"base": base, "puntos": puntos}


# --- Esqueleto ------------------------------------------------------------------

def _armadura(gato, m):
    """Quince huesos: columna, cuello, cabeza, cola de tres y cuatro patas."""
    arm_data = bpy.data.armatures.new("esqueleto")
    arm = bpy.data.objects.new("esqueleto", arm_data)
    bpy.context.collection.objects.link(arm)
    _activar(arm)
    bpy.ops.object.mode_set(mode='EDIT')
    huesos = arm_data.edit_bones

    def nuevo(nombre, cabeza, cola, padre=None, mirando=Vector((0.0, 0.0, 1.0))):
        h = huesos.new(nombre)
        h.head = cabeza
        h.tail = cola
        if padre is not None:
            h.parent = huesos[padre]
        # El `roll` decide dónde cae el eje X local, que es sobre el que giran
        # todas las animaciones. Alineándolo siempre a la misma referencia, un
        # giro en X es «hacia adelante» tanto en una pata como en la columna,
        # sin tener que pensar en cada hueso por separado.
        h.align_roll(mirando)
        return h

    f = m["frente"]
    cadera = m["cadera"]
    pecho = m["pecho"]

    # Raíz a ras de suelo: es lo que Godot mueve para desplazar al bicho entero
    # y lo que el exportador usa de referencia.
    nuevo("raiz", Vector((0.0, cadera.y, 0.0)), Vector((0.0, cadera.y, cadera.z)))
    nuevo("columna", Vector((0.0, cadera.y, cadera.z)),
          Vector((0.0, pecho.y, pecho.z)), "raiz")
    cuello_fin = Vector((0.0,
                         (pecho.y + m["cabeza"].y) * 0.5,
                         (pecho.z + m["cabeza"].z) * 0.5))
    nuevo("cuello", Vector((0.0, pecho.y, pecho.z)), cuello_fin, "columna")
    nuevo("cabeza", cuello_fin,
          Vector((0.0, m["cabeza"].y + f * 0.04, m["cabeza"].z + 0.01)), "cuello")

    # Cola: tres huesos en cadena, sin animación. Los mueve la física.
    puntos = m["cola"]["puntos"]
    padre = "raiz"
    for i in range(3):
        nombre = "cola_%d" % (i + 1)
        nuevo(nombre, puntos[i], puntos[i + 1], padre)
        padre = nombre

    # Patas: dos huesos cada una, del cuerpo a la huella. El de arriba nace a la
    # altura del lomo para que el peso de la paletilla caiga donde debe.
    for etiqueta, lado in [("del_izq", "L"), ("del_der", "R"),
                           ("tra_izq", "L"), ("tra_der", "R")]:
        if etiqueta not in m["huellas"]:
            continue
        huella = m["huellas"][etiqueta]
        delantera = etiqueta.startswith("del")
        anclaje = pecho if delantera else cadera
        arriba = Vector((huella.x, anclaje.y, anclaje.z - 0.01))
        codo = Vector((huella.x, (anclaje.y + huella.y) * 0.5,
                       (anclaje.z + huella.z) * 0.52))
        raiz_nombre = "%s_alto_%s" % ("pata_del" if delantera else "pata_tra", lado)
        baja_nombre = "%s_bajo_%s" % ("pata_del" if delantera else "pata_tra", lado)
        # El «mirando» apunta al frente del animal: así el eje X local queda
        # atravesado y girar en X es dar la zancada.
        nuevo(raiz_nombre, arriba, codo, "columna" if delantera else "raiz",
              Vector((0.0, f, 0.0)))
        nuevo(baja_nombre, codo, Vector((huella.x, huella.y, huella.z * 0.35)),
              raiz_nombre, Vector((0.0, f, 0.0)))

    bpy.ops.object.mode_set(mode='OBJECT')
    return arm


# Reparto de pesos. `EXPONENTE` alto = cada hueso manda solo en lo suyo (rígido);
# bajo = todo se contagia y la malla se derrite al moverse. 4 es el punto donde
# la pata se lleva su pata entera sin arrastrar el vientre.
EXPONENTE = 4.0
RADIO_MIN = 0.02
HUESOS_POR_VERTICE = 4
PASADAS_SUAVIZADO = 2


def _distancia_al_hueso(punto, cabeza, cola):
    """Distancia de un punto al segmento del hueso, no a su centro.

    Al centro, un hueso largo como la columna parece lejísimos desde el cuello
    aunque le pase justo por al lado.
    """
    eje = cola - cabeza
    largo2 = eje.length_squared
    if largo2 < 1e-9:
        return (punto - cabeza).length
    t = max(0.0, min(1.0, (punto - cabeza).dot(eje) / largo2))
    return (punto - (cabeza + eje * t)).length


def _pesar(gato, arm):
    """Reparte los pesos por distancia a cada hueso.

    NO se usa el mapa de calor de Blender (`ARMATURE_AUTO`). Es mejor cuando
    funciona, pero necesita una malla cerrada y sana: con la de Luna falla en
    silencio («Falla al buscar solución para uno o más huesos»), deja los 3135
    vértices sin grupo y el exportador saca el `.glb` **sin skin ninguno** —
    modelo que se ve bien, no da error, y no se mueve.

    El reparto por distancia no es tan fino, pero es determinista, da igual lo
    rota que esté la malla, y para un gato de fondo con quince huesos no se
    nota la diferencia.

    `raiz` se queda fuera del reparto a propósito: atraviesa el cuerpo de arriba
    abajo por el centro y le robaría a las patas traseras la mitad del peso.
    Sigue existiendo como padre de la columna y de la cola, que es su trabajo.
    """
    for hueso in arm.data.bones:
        if gato.vertex_groups.get(hueso.name) is None:
            gato.vertex_groups.new(name=hueso.name)

    segmentos = [(b.name, b.head_local.copy(), b.tail_local.copy())
                 for b in arm.data.bones if b.name != "raiz"]

    pesos = []
    for v in gato.data.vertices:
        candidatos = [(n, 1.0 / max(_distancia_al_hueso(v.co, h, t), RADIO_MIN)
                       ** EXPONENTE) for n, h, t in segmentos]
        candidatos.sort(key=lambda par: -par[1])
        mejores = candidatos[:HUESOS_POR_VERTICE]
        total = sum(p for _, p in mejores)
        pesos.append({n: p / total for n, p in mejores})

    # Suavizado por aristas: sin él se ven costuras justo donde un vértice se
    # decide por un hueso y su vecino por otro.
    vecinos = [[] for _ in gato.data.vertices]
    for arista in gato.data.edges:
        a, b = arista.vertices
        vecinos[a].append(b)
        vecinos[b].append(a)
    for _ in range(PASADAS_SUAVIZADO):
        nuevos = []
        for i, propio in enumerate(pesos):
            mezcla = dict(propio)
            for j in vecinos[i]:
                for nombre, peso in pesos[j].items():
                    mezcla[nombre] = mezcla.get(nombre, 0.0) + peso
            total = sum(mezcla.values())
            recorte = sorted(mezcla.items(), key=lambda par: -par[1])[:HUESOS_POR_VERTICE]
            total = sum(p for _, p in recorte)
            nuevos.append({n: p / total for n, p in recorte})
        pesos = nuevos

    for i, reparto in enumerate(pesos):
        for nombre, peso in reparto.items():
            gato.vertex_groups[nombre].add([i], peso, 'REPLACE')

    # `ARMATURE_NAME` cuelga la malla del esqueleto y crea el modificador, pero
    # respeta los grupos que ya están puestos. `ARMATURE_AUTO` los repintaría.
    _activar(gato)
    gato.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type='ARMATURE_NAME')

    sueltos = sum(1 for v in gato.data.vertices
                  if not any(g.weight > 0.0001 for g in v.groups))
    return sueltos


# --- Animación ------------------------------------------------------------------

def _clave(pose, nombre, frame, giro_x=0.0, mueve=None):
    hueso = pose.bones.get(nombre)
    if hueso is None:
        return
    hueso.rotation_mode = 'XYZ'
    hueso.rotation_euler = (math.radians(giro_x), 0.0, 0.0)
    hueso.keyframe_insert("rotation_euler", frame=frame)
    if mueve is not None:
        hueso.location = mueve
        hueso.keyframe_insert("location", frame=frame)


def _accion(arm, nombre):
    accion = bpy.data.actions.new(nombre)
    if arm.animation_data is None:
        arm.animation_data_create()
    arm.animation_data.action = accion
    return accion


def _animar_andar(arm):
    """Trote diagonal: delantera izquierda con trasera derecha, y al revés.

    Es como andan los cuadrúpedos de verdad y es lo que hace que se lea como
    «anda» en vez de como «vibra». Con las cuatro patas a la vez el bicho da
    saltitos de conejo.
    """
    _accion(arm, "andar")
    pose = arm.pose
    n = CICLO_ANDAR
    zancada = 26.0
    for i in range(n + 1):
        frame = i + 1
        fase = math.tau * i / n
        for grupo, desfase in [("del_izq", 0.0), ("tra_der", 0.0),
                               ("del_der", math.pi), ("tra_izq", math.pi)]:
            lado = "L" if grupo.endswith("izq") else "R"
            raiz = "pata_%s_alto_%s" % (grupo[:3], lado)
            baja = "pata_%s_bajo_%s" % (grupo[:3], lado)
            angulo = math.sin(fase + desfase) * zancada
            _clave(pose, raiz, frame, angulo)
            # La parte baja va retrasada y solo dobla hacia un lado: una pata
            # que se dobla al revés se ve rota aunque pase rápido.
            _clave(pose, baja, frame,
                   max(0.0, math.sin(fase + desfase - 0.9)) * zancada * 0.8)
        # El lomo sube dos veces por ciclo, una por cada apoyo
        _clave(pose, "columna", frame, math.sin(fase * 2.0) * 3.0)
        _clave(pose, "raiz", frame, 0.0,
               mueve=(0.0, 0.0, abs(math.sin(fase * 2.0)) * 0.012))
        _clave(pose, "cabeza", frame, math.sin(fase * 2.0 + 1.2) * 4.0)


def _animar_idle(arm):
    """Respirar. Nada más: un gato parado está parado."""
    _accion(arm, "idle")
    pose = arm.pose
    n = CICLO_IDLE
    for i in range(n + 1):
        frame = i + 1
        fase = math.tau * i / n
        _clave(pose, "columna", frame, math.sin(fase) * 1.6)
        _clave(pose, "cuello", frame, math.sin(fase + 0.6) * 1.2)
        # La cabeza mira alrededor de vez en cuando, no al ritmo del pecho
        _clave(pose, "cabeza", frame, math.sin(fase * 0.5) * 3.0)
        for grupo in ("del_izq", "del_der", "tra_izq", "tra_der"):
            lado = "L" if grupo.endswith("izq") else "R"
            _clave(pose, "pata_%s_alto_%s" % (grupo[:3], lado), frame, 0.0)
            _clave(pose, "pata_%s_bajo_%s" % (grupo[:3], lado), frame, 0.0)


# --- Todo junto -----------------------------------------------------------------

def riguear(nombre):
    gato = _cargar(nombre)
    medidas = _medir(gato)
    arm = _armadura(gato, medidas)
    sueltos = _pesar(gato, arm)

    _animar_andar(arm)
    _animar_idle(arm)
    # Sin esto el exportador solo saca la acción activa y se pierde `andar`.
    for accion in bpy.data.actions:
        accion.use_fake_user = True

    bpy.context.scene.render.fps = FPS
    ruta = "%s/%s.glb" % (MODELOS, nombre)
    bpy.ops.object.select_all(action='DESELECT')
    gato.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(
        filepath=ruta, export_format='GLB', use_selection=True,
        export_yup=True, export_materials='EXPORT',
        export_animations=True, export_animation_mode='ACTIONS',
        export_bake_animation=True, export_skins=True)

    return {
        "huesos": len(arm.data.bones),
        "vertices_sueltos": sueltos,
        "acciones": sorted(a.name for a in bpy.data.actions),
        "cola_base_z": round(medidas["cola"]["base"].z, 3),
        "kb": round(os.path.getsize(ruta) / 1024),
    }


def riguear_gatos():
    return {n: riguear(n) for n in GATOS}
