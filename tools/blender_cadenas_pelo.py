# Crea cadenas de huesos para el pelo y la capa sobre un modelo ya rigueado.
#
# Mixamo riguea SOLO el esqueleto humanoide: ni un hueso para el pelo. Todo lo
# que cuelga se queda rígido, y lo que es peor, Mixamo lo pesa por cercanía: la
# melena de Mars que llega a la cintura acaba pegada a `Hips` y se mueve con las
# caderas en vez de con la cabeza.
#
# Este script hace lo mismo que se hizo a mano para Serena, pero automatizado:
#
#   1. Encuentra la geometría del pelo por CRECIMIENTO DE REGIÓN desde el cuero
#      cabelludo, siguiendo el color de la textura. Es lo único fiable: por
#      pesos no vale (están mal) y por posición tampoco (la ropa estorba).
#   2. Reparte esa geometría en cadenas (izquierda/centro/derecha, o los
#      sectores que se pidan).
#   3. Traza el recorrido real de cada mechón con el centroide por franjas.
#   4. Crea los huesos siguiendo ese recorrido, colgando del ancla.
#   5. Repinta los pesos con transición suave: la raíz sigue pegada al ancla
#      para que el cuero cabelludo no se despegue del cráneo.
#
# Uso desde el MCP de Blender:
#   exec(open("tools/blender_cadenas_pelo.py").read())
#   result = procesar("sailor_mars", MELENA_SUELTA)
#
# El movimiento lo pone `SpringBoneChain` en Godot; aquí solo se prepara el
# esqueleto. Ver docs/09-FISICA-PELO.md.

import bpy
import bmesh
import math
import collections
from mathutils import Vector

CARPETA = "/Users/mac/Documents/Dev/Games/sailor-moon/assets/models/characters"

# --- Recetas ------------------------------------------------------------------
#
# `sectores` son los cortes en X (en fracción del ancho del pelo) que separan
# unas cadenas de otras. `huesos` es cuántas falanges tiene cada cadena.

MELENA_SUELTA = {          # Mars, Pluto, Venus, Neptuno: pelo largo suelto
    "ancla": "mixamorig:Head",
    "cadenas": [("L", -1.00, -0.28), ("C", -0.28, 0.28), ("R", 0.28, 1.00)],
    "huesos": 5,
    "caida_minima": 0.12,
}

COLETAS = {                # Chibi Moon: dos coletas bien separadas
    "ancla": "mixamorig:Head",
    "cadenas": [("L", -1.00, -0.10), ("R", 0.10, 1.00)],
    "huesos": 5,
    "caida_minima": 0.10,
}

COLETA_ALTA = {            # Jupiter: una sola coleta detrás
    "ancla": "mixamorig:Head",
    "cadenas": [("C", -1.00, 1.00)],
    "huesos": 4,
    "caida_minima": 0.08,
}

CAPA = {                   # Tuxedo Mask: superficie ancha colgando de la espalda
    "ancla": "mixamorig:Spine2",
    "cadenas": [("L", -1.00, -0.50), ("CL", -0.50, 0.00),
                ("CR", 0.00, 0.50), ("R", 0.50, 1.00)],
    "huesos": 4,
    "caida_minima": 0.15,
    "prefijo": "Cape",
}


# --- Carga --------------------------------------------------------------------

def _limpiar():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for bloque in (bpy.data.meshes, bpy.data.materials, bpy.data.images,
                   bpy.data.armatures, bpy.data.actions):
        for item in list(bloque):
            if item.users == 0:
                bloque.remove(item)


def _cargar(nombre):
    _limpiar()
    bpy.ops.import_scene.fbx(filepath="%s/%s_rigged.fbx" % (CARPETA, nombre))
    malla = next(o for o in bpy.data.objects if o.type == 'MESH')
    arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    return malla, arm


def _colores_por_vertice(malla):
    """Muestrea la textura en el UV de cada vértice. Devuelve {indice: (r,g,b)}."""
    img = None
    for mat in malla.data.materials:
        if mat and mat.use_nodes:
            for nodo in mat.node_tree.nodes:
                if nodo.type == 'TEX_IMAGE' and nodo.image and nodo.image.size[0] > 0:
                    img = nodo.image
                    break
        if img:
            break
    if img is None:
        return {}, None
    ancho, alto = img.size
    pixeles = list(img.pixels)

    bm = bmesh.new()
    bm.from_mesh(malla.data)
    bm.verts.ensure_lookup_table()
    capa_uv = bm.loops.layers.uv.active
    colores = {}
    for v in bm.verts:
        for bucle in v.link_loops:
            u, w = bucle[capa_uv].uv
            x = min(ancho - 1, max(0, int(u * ancho)))
            y = min(alto - 1, max(0, int(w * alto)))
            i = (y * ancho + x) * 4
            colores[v.index] = (pixeles[i], pixeles[i + 1], pixeles[i + 2])
            break
    bm.free()
    return colores, img.name


# --- Detección ----------------------------------------------------------------

def distancias_al_esqueleto(malla, arm):
    """Para cada vértice, a qué distancia está del hueso más cercano.

    Es lo que separa de verdad el pelo de la ropa: el uniforme va ceñido al
    cuerpo, a menos de 13 cm de algún hueso, mientras que una melena suelta
    cuelga mucho más lejos. El color por sí solo no vale — el naranja del
    uniforme de Venus y su pelo rubio tienen exactamente el mismo tono, y la
    región se desbordaba al traje entero.
    """
    a_malla = malla.matrix_world.inverted() @ arm.matrix_world
    segmentos = [(a_malla @ b.head_local, a_malla @ b.tail_local)
                 for b in arm.data.bones]
    fuera = {}
    for v in malla.data.vertices:
        p = v.co
        menor = 1e9
        for a, b in segmentos:
            ab = b - a
            largo = ab.length_squared
            t = 0.0 if largo == 0 else max(0.0, min(1.0, (p - a).dot(ab) / largo))
            dist = (p - (a + ab * t)).length
            if dist < menor:
                menor = dist
        fuera[v.index] = menor
    return fuera


def detectar_region(malla, arm, ancla, colores, tolerancia=0.13, corte_cuerpo=0.13):
    """Crece desde el cuero cabelludo (o el cuello de la capa) por color.

    Crecer por adyacencia y no por «todo lo que tenga este color» evita llevarse
    otras partes del mismo tono: las botas negras de Mars son del color de su
    pelo, pero no tocan la melena.

    Y aun así hace falta la barrera de `corte_cuerpo`: donde el pelo roza la
    ropa, la región saltaba al uniforme y de ahí al modelo entero.
    """
    d = malla.data
    nom = {g.index: g.name for g in malla.vertex_groups}
    a_malla = malla.matrix_world.inverted() @ arm.matrix_world
    origen = a_malla @ arm.data.bones[ancla].head_local

    def dominante(vi):
        grupos = d.vertices[vi].groups
        return nom[max(grupos, key=lambda g: g.weight).group] if grupos else None

    if ancla.endswith("Head"):
        semilla = [i for i in colores
                   if d.vertices[i].co.z > origen.z + 0.04 and dominante(i) == ancla]
    else:
        # la capa: arranca en los hombros, por detrás
        semilla = [i for i in colores
                   if abs(d.vertices[i].co.z - origen.z) < 0.10
                   and d.vertices[i].co.y > 0.0]
    if not semilla:
        return set(), None, origen

    # Se compara el TONO, no el color a secas. La textura del pelo trae la
    # iluminación horneada, así que un mismo mechón va de (0,4 0,3 0,1) en la
    # sombra a (0,7 0,6 0,4) en la luz: por color absoluto la mitad del pelo se
    # queda fuera. Normalizando por el canal más alto, ambos son el mismo rubio.
    def tono(c):
        m = max(c)
        return (1.0, 1.0, 1.0) if m < 0.02 else (c[0] / m, c[1] / m, c[2] / m)

    # Y no basta con UN tono de referencia: el pelo de Venus tiene mechones
    # dorados sobre una masa color crema, y con una sola referencia se queda
    # fuera justo la mitad. Se toman los tonos más repetidos del cuero
    # cabelludo, que es pelo con seguridad, y vale parecerse a cualquiera.
    frecuencia = collections.Counter(
        tuple(round(q, 1) for q in tono(colores[i])) for i in semilla)
    referencias = [t for t, _ in frecuencia.most_common(4)]
    canal = lambda k: sorted(colores[i][k] for i in semilla)[len(semilla) // 2]
    referencia = (canal(0), canal(1), canal(2))
    luz_ref = max(referencia)

    def parecido(c):
        t = tono(c)
        if all(max(abs(t[k] - r[k]) for k in range(3)) > tolerancia
               for r in referencias):
            return False
        return abs(max(c) - luz_ref) < 0.45

    lejania = distancias_al_esqueleto(malla, arm)

    def transitable(i):
        # el cuero cabelludo va pegado al cráneo, así que ahí no se aplica la
        # barrera; de cuello para abajo, lo que va ceñido al hueso es ropa
        if d.vertices[i].co.z > origen.z:
            return True
        return lejania.get(i, 0.0) >= corte_cuerpo

    bm = bmesh.new()
    bm.from_mesh(d)
    bm.verts.ensure_lookup_table()
    frontera = [i for i in semilla if parecido(colores[i])]
    region = set(frontera)
    while frontera:
        siguiente = []
        for i in frontera:
            for arista in bm.verts[i].link_edges:
                otro = arista.other_vert(bm.verts[i]).index
                if (otro not in region and otro in colores
                        and parecido(colores[otro]) and transitable(otro)):
                    region.add(otro)
                    siguiente.append(otro)
        frontera = siguiente

    # Cierre de huecos: la textura del pelo trae sombras horneadas entre mechón
    # y mechón, y esas franjas oscuras no pasan el filtro de color. Se quedarían
    # fuera de la región y, por tanto, pegadas al hueso que les puso Mixamo:
    # medio pelo se movería y medio no. Se absorbe todo vértice rodeado de
    # región, que es geometría de pelo aunque su color diga otra cosa.
    for _ in range(4):
        nuevos = set()
        for v in bm.verts:
            if v.index in region or not transitable(v.index):
                continue
            vecinos = [a.other_vert(v).index for a in v.link_edges]
            if not vecinos:
                continue
            dentro = sum(1 for n in vecinos if n in region)
            if dentro / len(vecinos) >= 0.6:
                nuevos.add(v.index)
        if not nuevos:
            break
        region |= nuevos
    bm.free()
    return region, referencia, origen


# --- Trazado ------------------------------------------------------------------

def trazar(puntos, origen, n_huesos):
    """Saca la polilínea que recorre un mechón, por centroides en franjas.

    Devuelve n_huesos+1 puntos: el nacimiento y las n articulaciones.
    """
    if len(puntos) < 8:
        return None
    z_alto = max(p.z for p in puntos)
    z_bajo = min(p.z for p in puntos)
    if z_alto - z_bajo < 0.05:
        return None

    recorrido = [Vector((origen.x, origen.y, z_alto))]
    for k in range(1, n_huesos + 1):
        z0 = z_alto - (z_alto - z_bajo) * (k - 0.5) / n_huesos
        franja = [p for p in puntos if abs(p.z - z0) < (z_alto - z_bajo) / n_huesos]
        if not franja:
            franja = sorted(puntos, key=lambda p: abs(p.z - z0))[:20]
        cx = sum(p.x for p in franja) / len(franja)
        cy = sum(p.y for p in franja) / len(franja)
        cz = z_alto - (z_alto - z_bajo) * k / n_huesos
        recorrido.append(Vector((cx, cy, cz)))
    return recorrido


# --- Huesos y pesos -----------------------------------------------------------

def crear_huesos(arm, malla, nombre_base, recorrido, ancla):
    """Cuelga la cadena del ancla. El primer hueso va SIN conectar, para que
    moverlo no arrastre la cabeza."""
    m_a_arm = arm.matrix_world.inverted() @ malla.matrix_world
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode='EDIT')
    huesos = arm.data.edit_bones
    padre = huesos[ancla]
    creados = []
    for i in range(len(recorrido) - 1):
        nombre = "%s_%d" % (nombre_base, i + 1)
        h = huesos.new(nombre)
        h.head = m_a_arm @ recorrido[i]
        h.tail = m_a_arm @ recorrido[i + 1]
        h.parent = padre
        h.use_connect = (i > 0)
        padre = h
        creados.append(nombre)
    bpy.ops.object.mode_set(mode='OBJECT')
    return creados


def pintar_pesos(malla, arm, indices, recorrido, nombres_huesos, ancla,
                 raiz_fija=0.12, transicion=0.30):
    """Reparte cada vértice entre los dos huesos más cercanos de la cadena.

    Hasta `raiz_fija` del recorrido manda el ancla (es cuero cabelludo y no
    puede despegarse del cráneo); entre ahí y `transicion` se mezcla; después
    manda la cadena. Sin esa transición el pelo se separa de la cabeza.
    """
    d = malla.data
    grupos = {g.name: g for g in malla.vertex_groups}
    for n in nombres_huesos:
        if n not in grupos:
            grupos[n] = malla.vertex_groups.new(name=n)
    if ancla not in grupos:
        grupos[ancla] = malla.vertex_groups.new(name=ancla)

    tramos = [(recorrido[i], recorrido[i + 1]) for i in range(len(recorrido) - 1)]
    largos = [(b - a).length for a, b in tramos]
    total = sum(largos) or 1.0

    pintados = 0
    for vi in indices:
        p = d.vertices[vi].co
        # ¿en qué punto del recorrido cae este vértice?
        mejor, mejor_d, recorrido_acum = 0, 1e9, 0.0
        for k, (a, b) in enumerate(tramos):
            ab = b - a
            t = 0.0 if ab.length_squared == 0 else max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
            dist = (p - (a + ab * t)).length
            if dist < mejor_d:
                mejor_d, mejor = dist, k
                recorrido_acum = sum(largos[:k]) + largos[k] * t
        u = recorrido_acum / total

        for g in list(d.vertices[vi].groups):
            nombre = malla.vertex_groups[g.group].name
            if nombre in nombres_huesos or nombre == ancla:
                continue
            malla.vertex_groups[g.group].remove([vi])

        if u <= raiz_fija:
            peso_cadena = 0.0
        elif u >= transicion:
            peso_cadena = 1.0
        else:
            peso_cadena = (u - raiz_fija) / (transicion - raiz_fija)

        grupos[ancla].add([vi], 1.0 - peso_cadena, 'REPLACE')
        if peso_cadena > 0.0:
            # reparte entre el hueso en el que cae y el siguiente, sin saltos
            pos = u * len(nombres_huesos)
            i = min(len(nombres_huesos) - 1, int(pos))
            frac = pos - i
            grupos[nombres_huesos[i]].add([vi], peso_cadena * (1.0 - frac), 'REPLACE')
            if i + 1 < len(nombres_huesos):
                grupos[nombres_huesos[i + 1]].add([vi], peso_cadena * frac, 'REPLACE')
        pintados += 1
    return pintados


def _rescatar_huerfanos(malla, arm, recorridos, origen, caida_minima,
                        radio=0.14, lejania_minima=0.20):
    """Asigna a su cadena el pelo que la detección por color dejó atrás.

    `radio` es lo que decide si algo es pelo o no: como se mide contra el
    recorrido de la cadena, que va por dentro de la melena, 14 cm cubre el
    grosor de un mechón sin llegar a la falda.
    """
    if not recorridos:
        return 0
    d = malla.data
    nom = {g.index: g.name for g in malla.vertex_groups}
    grupos = {g.name: g for g in malla.vertex_groups}
    lejania = distancias_al_esqueleto(malla, arm)

    rescatados = 0
    for v in d.vertices:
        if not v.groups:
            continue
        dominante = nom[max(v.groups, key=lambda g: g.weight).group]
        if dominante.startswith("Hair") or dominante.startswith("Cape"):
            continue
        if (origen.z - v.co.z) <= caida_minima:
            continue
        if lejania[v.index] < lejania_minima:
            continue

        mejor_cadena, mejor_dist, mejor_u = None, 1e9, 0.0
        for recorrido, huesos in recorridos.values():
            largos = [(recorrido[k + 1] - recorrido[k]).length
                      for k in range(len(recorrido) - 1)]
            total = sum(largos) or 1.0
            for k in range(len(recorrido) - 1):
                a, b = recorrido[k], recorrido[k + 1]
                ab = b - a
                largo = ab.length_squared
                t = 0.0 if largo == 0 else max(0.0, min(1.0, (v.co - a).dot(ab) / largo))
                dist = (v.co - (a + ab * t)).length
                if dist < mejor_dist:
                    mejor_dist = dist
                    mejor_cadena = huesos
                    mejor_u = (sum(largos[:k]) + largos[k] * t) / total
        if mejor_cadena is None or mejor_dist > radio:
            continue

        for g in list(v.groups):
            malla.vertex_groups[g.group].remove([v.index])
        pos = mejor_u * len(mejor_cadena)
        i = min(len(mejor_cadena) - 1, int(pos))
        frac = pos - i
        grupos[mejor_cadena[i]].add([v.index], 1.0 - frac, 'REPLACE')
        if i + 1 < len(mejor_cadena):
            grupos[mejor_cadena[i + 1]].add([v.index], frac, 'REPLACE')
        rescatados += 1
    return rescatados


# --- Todo junto ---------------------------------------------------------------

def procesar(nombre, receta, tolerancia=0.13, guardar=True):
    malla, arm = _cargar(nombre)
    d = malla.data
    colores, textura = _colores_por_vertice(malla)
    ancla = receta["ancla"]
    prefijo = receta.get("prefijo", "Hair")

    region, referencia, origen = detectar_region(malla, arm, ancla, colores, tolerancia)
    if not region:
        return {"error": "no se encontró la región de partida"}

    # solo la parte que CUELGA: lo de arriba es cuero cabelludo y se queda quieto
    colgante = [i for i in region if (origen.z - d.vertices[i].co.z) > receta["caida_minima"]]
    if len(colgante) < 30:
        return {"error": "cuelga muy poco (%d vértices): no hace falta física" % len(colgante)}

    xs = [d.vertices[i].co.x for i in colgante]
    x_min, x_max = min(xs), max(xs)
    medio = (x_min + x_max) / 2.0
    semi = max(x_max - medio, medio - x_min) or 1.0

    informe = {"textura": textura, "color": [round(q, 2) for q in referencia],
               "region": len(region), "colgante": len(colgante), "cadenas": {}}
    raices = []
    recorridos = {}
    for etiqueta, desde, hasta in receta["cadenas"]:
        trozo = [i for i in colgante
                 if desde <= (d.vertices[i].co.x - medio) / semi < hasta]
        puntos = [d.vertices[i].co.copy() for i in trozo]
        recorrido = trazar(puntos, origen, receta["huesos"])
        if recorrido is None:
            informe["cadenas"][etiqueta] = "sin geometría suficiente"
            continue
        base = "%s_%s" % (prefijo, etiqueta)
        huesos = crear_huesos(arm, malla, base, recorrido, ancla)
        n = pintar_pesos(malla, arm, trozo, recorrido, huesos, ancla)
        raices.append(huesos[0])
        recorridos[etiqueta] = (recorrido, huesos)
        informe["cadenas"][etiqueta] = {
            "verts": len(trozo), "pintados": n, "huesos": len(huesos),
            "largo_cm": round(sum((recorrido[k + 1] - recorrido[k]).length
                                  for k in range(len(recorrido) - 1)) * 100)}

    # Red de seguridad: recoger el pelo que se quedó fuera de la región.
    #
    # La detección por color nunca captura el 100 %: quedan mechones sueltos que
    # siguen pesados a `Hips` o a las piernas, donde los puso Mixamo. En reposo
    # no se nota, pero en cuanto la animación mueve las caderas esos vértices
    # tiran para un lado mientras el resto del pelo sigue a la cabeza, la melena
    # se rasga y se ve el hueco negro del interior.
    #
    # Se buscan por geometría, sin mirar el color: lo que esté metido dentro del
    # volumen que ya ocupa una cadena y siga colgando de un hueso del cuerpo, es
    # pelo. El límite de distancia impide que se lleve la falda por delante.
    informe["rescatados"] = _rescatar_huerfanos(
        malla, arm, recorridos, origen, receta["caida_minima"])

    informe["raices"] = raices
    informe["huesos_totales"] = len(arm.data.bones)

    if guardar:
        bpy.ops.object.select_all(action='DESELECT')
        arm.select_set(True)
        malla.select_set(True)
        bpy.context.view_layer.objects.active = arm
        bpy.ops.export_scene.fbx(
            filepath="%s/%s_rigged.fbx" % (CARPETA, nombre), use_selection=True,
            add_leaf_bones=False, primary_bone_axis='Y', secondary_bone_axis='X',
            bake_anim=True, bake_anim_use_all_actions=False,
            bake_anim_use_nla_strips=False, path_mode='COPY', embed_textures=True,
            apply_scale_options='FBX_SCALE_ALL', axis_forward='-Z', axis_up='Y',
            object_types={'ARMATURE', 'MESH'})
    return informe
