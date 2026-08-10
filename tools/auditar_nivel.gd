extends SceneTree
## Recorre el nivel entero buscando los fallos de montaje que se ven jugando.
##
## Uso:
##   godot --headless --path . --script tools/auditar_nivel.gd
##
## POR QUÉ EXISTE
##
## Los fallos de este nivel no se encuentran mirando el código: se encuentran
## paseando por el parque y topándose con un seto flotando o con un farol en el
## aire. Eso es lentísimo, se escapan la mitad, y al arreglar uno aparecen otros
## tres en sitios por los que no se pasó.
##
## Aquí se comprueba lo mismo pero por todo el mapa a la vez, y cada aviso sale
## con su coordenada para poder ir con `F5`/`F1` a mirarlo. Lo que mide son las
## cuatro formas que tiene el escenario de quedar mal montado:
##
##   1. Muros flotando — el terreno cae por debajo de su pie
##   2. Muros hundidos — el terreno sube y el muro deja de tapar
##   3. Geometría dentro del camino — un muro o una valla cruzando el paso
##   4. Props en el aire — plantados sobre algo que ya no se dibuja
##
## Las comprobaciones se hacen contra lo que se VE (las poses de las multimallas)
## y contra lo que se PISA (un rayo al terreno), que es justo el par que se
## desincronizó al dejar de dibujarse el blockout.

const ESCENA := "res://scenes/levels/nivel_1_parque.tscn"

## A partir de cuántos metros de hueco bajo un muro se considera que flota.
##
## Se mide contra la cara de abajo de lo que se VE. El pie enterrado
## (`muro_pie`) no cuenta: está ahí justo para que esto no pase.
const FLOTA := 0.25
## Cuánto seto tiene que asomar por encima del terreno para leerse como límite.
##
## No es una comprobación de si se salta —de eso se encarga `muro_tope`, que
## sube la colisión sin subir la malla— sino de si el muro SE VE. Un seto del
## que asoma un palmo no dice «por aquí no se pasa», dice «esto está mal
## montado», y encima el jugador choca con aire.
const ASOMA := 1.2
## Cuánto puede sobresalir un prop del suelo antes de parecer que flota.
const PROP_EN_EL_AIRE := 0.6
## Cuántos puntos se miran a lo largo de cada muro.
const MUESTRAS_MURO := 5

var _nivel: Node = null
var _frames := 0
var _blockout: Node = null
var _apartados: Array[RID] = []
var _avisos := 0


func _initialize() -> void:
	var escena := load(ESCENA) as PackedScene
	if escena == null:
		push_error("No se pudo cargar %s" % ESCENA)
		quit(1)
		return
	_nivel = escena.instantiate()
	root.add_child(_nivel)


func _process(_delta: float) -> bool:
	_frames += 1
	# El nivel se construye en varios `_ready()` encadenados y el decorador
	# espera un ciclo de física. Con unos cuantos fotogramas está todo puesto.
	if _frames < 30:
		return false
	_auditar()
	return true


func _auditar() -> void:
	_blockout = _nivel.get_node_or_null("Blockout")
	if _blockout == null:
		push_error("No hay Blockout")
		quit(1)
		return
	for hijo in _blockout.get_children():
		var cuerpo := hijo as StaticBody3D
		if cuerpo != null:
			_apartados.append(cuerpo.get_rid())

	print("\n================ AUDITORÍA DEL NIVEL ================")
	_revisar_muros()
	_revisar_invasion_del_camino()
	_revisar_cierre_de_arenas()
	_revisar_props()
	_dibujar_plano()
	print("\n---------------------------------------------------")
	if _avisos == 0:
		print("Sin avisos. El escenario está bien montado.")
	else:
		print("%d avisos en total." % _avisos)
	print("===================================================\n")
	quit()


# --- 1 y 2. Muros flotando o hundidos ------------------------------------------

## Los muros se miran contra el terreno EN VARIOS PUNTOS de su largo.
##
## Con mirar solo el centro no vale: un muro de veinte metros cruza varias celdas
## del terreno y puede estar apoyado en medio y flotando en una punta, que es
## justamente lo que pasaba en el pasillo que sube al guardián.
func _revisar_muros() -> void:
	print("\n-- Muros contra el terreno --")
	var flotando := 0
	var hundidos := 0
	var peor_hueco := 0.0
	var peor_sitio := Vector3.ZERO
	var peor_asomo := -1.0
	var peor_asomo_sitio := Vector3.ZERO

	# Se leen los CUERPOS, no las multimallas.
	#
	# `MultiMesh.get_instance_transform()` pregunta al servidor de render, y en
	# `--headless` el driver es de mentira: devuelve la identidad para todas las
	# instancias. Se pasó un rato creyendo que todos los muros del parque medían
	# un metro y estaban en el origen. Los `StaticBody3D` son nodos de verdad y
	# sus formas están en la escena, así que se pueden leer sin render.
	var pie_enterrado: float = float(_blockout.get("muro_pie"))
	var tope_invisible: float = float(_blockout.get("muro_tope"))

	for hijo in _blockout.get_children():
		var cuerpo := hijo as StaticBody3D
		if cuerpo == null or not String(cuerpo.name).begins_with("Borde"):
			continue
		var forma := cuerpo.get_child(0) as CollisionShape3D
		if forma == null or not (forma.shape is BoxShape3D):
			continue
		var caja: Vector3 = (forma.shape as BoxShape3D).size
		var base := cuerpo.global_transform.basis.orthonormalized()
		var centro := cuerpo.global_position
		# Los muros son largos por su X local si vienen de un anillo, y por su Z
		# si vienen de un pasillo. Se recorre el eje más largo.
		var eje := base.x if caja.x >= caja.z else base.z
		var largo: float = maxf(caja.x, caja.z)
		# De la caja de choque a la pieza que se ve: por abajo lleva el pie
		# enterrado y por arriba el tope invisible.
		var fondo: float = centro.y - caja.y * 0.5
		var cima: float = centro.y + caja.y * 0.5 - tope_invisible
		var pie: float = fondo + pie_enterrado

		for m in MUESTRAS_MURO:
			var t := (float(m) / float(MUESTRAS_MURO - 1) - 0.5) * largo * 0.92
			var punto := centro + eje * t
			var suelo: Variant = _altura_del_terreno(punto)
			if suelo == null:
				continue
			var hueco: float = pie - float(suelo)
			if hueco > FLOTA:
				flotando += 1
				if hueco > peor_hueco:
					peor_hueco = hueco
					peor_sitio = punto
			if cima - float(suelo) < ASOMA:
				hundidos += 1
				if peor_asomo < 0.0 or cima - float(suelo) < peor_asomo:
					peor_asomo = cima - float(suelo)
					peor_asomo_sitio = punto

	_contar("muros flotando sobre el terreno", flotando)
	if flotando > 0:
		print("     el peor: %.2f m de hueco en (%.1f, %.1f, %.1f)"
			% [peor_hueco, peor_sitio.x, peor_sitio.y, peor_sitio.z])
	_contar("muros de los que asoma menos de %.1f m" % ASOMA, hundidos)
	if hundidos > 0:
		print("     el peor: asoma %.2f m en (%.1f, %.1f, %.1f)"
			% [peor_asomo, peor_asomo_sitio.x, peor_asomo_sitio.y, peor_asomo_sitio.z])


# --- 3. Geometría metida en el camino ------------------------------------------

## ¿Hay algún muro o plataforma plantado en mitad del paso?
##
## Se recorre el eje de cada tramo y se pregunta si ese punto cae dentro de
## alguno de los `estorbos` que el constructor declaró. Un muro que corta el
## pasillo por la mitad sale aquí inmediatamente, y a ojo cuesta encontrarlo
## porque hay que pasar justo por ese tramo.
func _revisar_invasion_del_camino() -> void:
	print("\n-- Geometría dentro del camino --")
	var constructor := _blockout as Object
	var tramos: Array = constructor.get("tramos")
	var estorbos: Array = constructor.get("estorbos")
	if tramos == null or estorbos == null:
		print("   (no se pudo leer el recorrido)")
		return

	var invasiones := 0
	var vistos := {}
	for indice in tramos.size():
		var tramo: Dictionary = tramos[indice]
		for paso in 21:
			var t := float(paso) / 20.0
			# Se mira el eje y los dos carriles, no solo el centro: un muro que
			# entra media anchura deja el eje libre y corta el paso igualmente.
			for lado: float in [-0.55, 0.0, 0.55]:
				var punto: Vector3 = constructor.call(
					"punto_en_tramo", indice, t, lado, 0.0)
				for e in estorbos.size():
					var estorbo: Dictionary = estorbos[e]
					var centro: Vector3 = estorbo["centro"]
					if absf(centro.y - punto.y) > 3.0:
						continue
					var hacia := Vector2(punto.x - centro.x, punto.z - centro.z)
					var local := hacia.rotated(float(estorbo["giro"]))
					var mitad: Vector2 = estorbo["mitad"]
					if absf(local.x) < mitad.x and absf(local.y) < mitad.y:
						if not vistos.has(e):
							vistos[e] = true
							invasiones += 1
							print("   ⚠ tramo %d (dir %+.0f,%+.0f), t=%.2f, lado=%+.2f"
								% [indice, tramo["direccion"].x, tramo["direccion"].z,
								t, lado])
							print("       el paso está en (%.1f, %.1f, %.1f)"
								% [punto.x, punto.y, punto.z])
							print("       la pieza en (%.1f, %.1f, %.1f), mitad %.1fx%.1f, giro %.0f°"
								% [centro.x, centro.y, centro.z, mitad.x, mitad.y,
								rad_to_deg(float(estorbo["giro"]))])
	_contar("piezas del blockout cortando el paso", invasiones)


# --- 5. El cierre de las arenas ------------------------------------------------

## ¿Se puede escapar de una arena por donde no toca?
##
## Una arena es un anillo de paneles rectos con dos huecos: por uno se entra y
## por el otro se sale. El pasillo que llega es recto y el anillo curvo, así que
## en la unión queda una cuña — y por esa cuña se cuela la jugadora, o peor, se
## queda encajada mientras la barrera de la oleada le dice que no puede salir.
##
## Se mide lanzando rayos radiales desde el centro, a la altura del pecho, y
## viendo por qué ángulos se escapa. Los dos huecos de acceso tienen que salir;
## cualquier otra fuga, o un hueco bastante más ancho que los `hueco_acceso`
## declarados, es un agujero.
func _revisar_cierre_de_arenas() -> void:
	print("\n-- Cierre de las arenas --")
	var centros: Dictionary = _blockout.get("centros_arena")
	var radios: Dictionary = _blockout.get("radios_arena")
	var acceso: float = float(_blockout.get("hueco_acceso"))
	if centros == null or centros.is_empty():
		print("   (no hay arenas)")
		return

	var sospechosas := 0
	for nombre: String in centros:
		# La pradera de arranque es abierta A PROPÓSITO: no tiene muros en los
		# costados, que es lo que la hace explanada y no corredor. Contarla aquí
		# sería avisar de un acierto.
		if nombre.begins_with("Pradera"):
			continue
		var centro: Vector3 = centros[nombre]
		var radio: float = float(radios.get(nombre, 11.0))
		var fugas := _arcos_de_fuga(centro, radio)
		# Se esperan dos bocas. Una tercera, o una mucho más ancha de lo
		# declarado, es un agujero que no estaba en el plan.
		var extra := 0
		for arco: Dictionary in fugas:
			if float(arco["ancho"]) > acceso * 1.6:
				extra += 1
		var texto := "%d bocas" % fugas.size()
		for arco: Dictionary in fugas:
			# Se da el ángulo de inicio además del ancho: sin saber POR DÓNDE
			# está la boca no se puede decidir si es la entrada, la salida o un
			# agujero, y todas se parecen en el recuento.
			texto += " · %.0f°→%.0f°" % [arco["desde"],
				float(arco["desde"]) + float(arco["ancho"])]
		if fugas.size() > 2 or extra > 0:
			sospechosas += 1
			print("   ⚠ %s (r %.0f): %s — declarado %.0f°"
				% [nombre, radio, texto, acceso])
		else:
			print("   ✓ %s (r %.0f): %s" % [nombre, radio, texto])
	_contar("arenas con el cierre sospechoso", sospechosas)


## Los tramos de ángulo por los que un rayo sale del anillo sin chocar.
func _arcos_de_fuga(centro: Vector3, radio: float) -> Array[Dictionary]:
	var espacio := _nivel.get_viewport().world_3d.direct_space_state
	var arcos: Array[Dictionary] = []
	if espacio == null:
		return arcos
	# A la altura del pecho: por debajo tropezaría con el peldaño del suelo y
	# por encima pasaría por encima del seto.
	var desde := centro + Vector3.UP * 1.3
	var abierto := false
	var inicio := 0.0
	var paso := 1.0
	var grados := 0.0
	while grados < 360.0 + paso:
		var a := deg_to_rad(fmod(grados, 360.0))
		var hacia := desde + Vector3(cos(a), 0.0, sin(a)) * (radio + 5.0)
		var consulta := PhysicsRayQueryParameters3D.create(desde, hacia)
		consulta.collision_mask = 1
		var escapa: bool = espacio.intersect_ray(consulta).is_empty()
		if escapa and not abierto:
			abierto = true
			inicio = grados
		elif not escapa and abierto:
			abierto = false
			arcos.append({"desde": inicio, "ancho": grados - inicio})
		grados += paso
	if abierto:
		arcos.append({"desde": inicio, "ancho": grados - inicio})

	# Dos arcos separados por uno o dos grados son LA MISMA boca: por en medio
	# ha pillado el canto de un panel, que no cierra nada. Sin juntarlos, una
	# entrada perfectamente normal se cuenta como dos o tres agujeros.
	var juntos: Array[Dictionary] = []
	for arco: Dictionary in arcos:
		if juntos.size() > 0:
			var previo: Dictionary = juntos[-1]
			var fin: float = float(previo["desde"]) + float(previo["ancho"])
			if float(arco["desde"]) - fin <= 2.0:
				juntos[-1] = {
					"desde": previo["desde"],
					"ancho": float(arco["desde"]) + float(arco["ancho"])
						- float(previo["desde"]),
				}
				continue
		juntos.append(arco)
	arcos = juntos

	# Un arco que cruza el 0° sale partido en dos, y así una boca perfectamente
	# normal se cuenta como dos agujeros. Se vuelven a juntar. (La entrada de la
	# Arena 1 aparecía como «339°→360°» y «0°→22°», y parecía un fallo.)
	if arcos.size() >= 2:
		var primero: Dictionary = arcos[0]
		var ultimo: Dictionary = arcos[-1]
		# Con un poco de holgura: justo en el 0° puede caer el canto de un panel
		# y partir la boca dejando un grado suelto de por medio.
		if float(primero["desde"]) <= 2.0 \
				and float(ultimo["desde"]) + float(ultimo["ancho"]) >= 358.0:
			arcos[0] = {
				"desde": ultimo["desde"],
				"ancho": float(ultimo["ancho"]) + float(primero["ancho"]),
			}
			arcos.remove_at(arcos.size() - 1)
	return arcos


# --- 4. Props en el aire -------------------------------------------------------

## Los props se miran contra el terreno igual que los muros.
##
## Se cuenta solo lo que sobresale bastante: casi todas las piezas llevan su
## `hundir` a propósito y un margen pequeño daría cientos de falsos avisos.
func _revisar_props() -> void:
	print("\n-- Props contra el terreno --")
	var decorado := _nivel.get_node_or_null("Decorado")
	if decorado == null:
		print("   (no hay decorado)")
		return

	var en_el_aire := 0
	var total := 0
	var peor := 0.0
	var peor_sitio := Vector3.ZERO
	var peor_pieza := ""

	for multi in decorado.find_children("*", "MultiMeshInstance3D", true, false):
		var mm := (multi as MultiMeshInstance3D).multimesh
		if mm == null:
			continue
		for i in mm.instance_count:
			var punto := (multi as Node3D).global_transform \
				* mm.get_instance_transform(i).origin
			total += 1
			var suelo: Variant = _altura_del_terreno(punto)
			if suelo == null:
				continue
			var alto: float = punto.y - float(suelo)
			if alto > PROP_EN_EL_AIRE:
				en_el_aire += 1
				if alto > peor:
					peor = alto
					peor_sitio = punto
					peor_pieza = String(multi.name)

	print("   %d copias revisadas" % total)
	_contar("props por encima del suelo", en_el_aire)
	if en_el_aire > 0:
		print("     el peor: %.2f m ('%s') en (%.1f, %.1f, %.1f)"
			% [peor, peor_pieza, peor_sitio.x, peor_sitio.y, peor_sitio.z])


# --- El plano en planta --------------------------------------------------------

## Dibuja el nivel visto desde arriba y lo guarda como PNG.
##
## Es la comprobación que faltaba. Los avisos de texto dicen si una pieza pisa a
## otra, pero no dan la vista de conjunto: para ver que el estanque se ha ido a
## parar debajo del parque, o que un tramo cruza otro, hace falta MIRAR el mapa.
## Y una captura del juego no sirve: desde dentro no se ve el nivel entero, y
## ponerse a volar la cámara para comprobarlo es media hora cada vez.
##
##   gris   el suelo de los tramos          rojo   los muros
##   arena  las arenas                      azul   el estanque
##   verde  el arranque
const PLANO := "res://plano_nivel.png"
const PLANO_LADO := 900


func _dibujar_plano() -> void:
	var tramos: Array = _blockout.get("tramos")
	if tramos == null or tramos.is_empty():
		return

	# El encuadre sale de lo que hay, no de un número a mano: si el nivel crece,
	# el plano lo sigue.
	var minimo := Vector2(INF, INF)
	var maximo := Vector2(-INF, -INF)
	for tramo: Dictionary in tramos:
		var a: Vector3 = tramo["origen"]
		var b: Vector3 = a + tramo["direccion"] * float(tramo["largo"])
		for p in [Vector2(a.x, a.z), Vector2(b.x, b.z)]:
			minimo = minimo.min(p)
			maximo = maximo.max(p)
	var centros: Dictionary = _blockout.get("centros_arena")
	for nombre: String in centros:
		var c: Vector3 = centros[nombre]
		minimo = minimo.min(Vector2(c.x, c.z) - Vector2(18, 18))
		maximo = maximo.max(Vector2(c.x, c.z) + Vector2(18, 18))
	var decorador := _nivel.get_node_or_null("Decorado")
	var sitio_agua := Vector3.ZERO
	var radio_agua := 0.0
	if decorador != null:
		sitio_agua = decorador.get("_sitio_estanque_elegido")
		radio_agua = float(decorador.get("radio_estanque"))
		minimo = minimo.min(Vector2(sitio_agua.x, sitio_agua.z) - Vector2(20, 20))
		maximo = maximo.max(Vector2(sitio_agua.x, sitio_agua.z) + Vector2(20, 20))

	minimo -= Vector2(14, 14)
	maximo += Vector2(14, 14)
	var extension := maximo - minimo
	var escala := float(PLANO_LADO) / maxf(extension.x, extension.y)

	var img := Image.create(PLANO_LADO, PLANO_LADO, false, Image.FORMAT_RGB8)
	img.fill(Color(0.11, 0.13, 0.11))

	# El suelo de cada tramo, como rectángulo orientado.
	for tramo: Dictionary in tramos:
		var a: Vector3 = tramo["origen"]
		var dir: Vector3 = tramo["direccion"]
		var largo: float = float(tramo["largo"])
		var ancho: float = float(tramo["ancho"])
		var costado := Vector2(-dir.z, dir.x)
		for paso in int(largo / 0.4) + 1:
			var t := float(paso) * 0.4
			var eje := Vector2(a.x, a.z) + Vector2(dir.x, dir.z) * t
			for lado in int(ancho / 0.4) + 1:
				var u := (float(lado) * 0.4 - ancho * 0.5)
				_punto(img, eje + costado * u, minimo, escala, Color(0.45, 0.45, 0.45))

	# Las arenas.
	for nombre: String in centros:
		var c: Vector3 = centros[nombre]
		var r: float = float(_blockout.get("radios_arena").get(nombre, 11.0))
		_disco(img, Vector2(c.x, c.z), r, minimo, escala, Color(0.62, 0.55, 0.40))

	# Los muros, por encima de todo lo demás.
	for hijo in _blockout.get_children():
		var cuerpo := hijo as StaticBody3D
		if cuerpo == null or not String(cuerpo.name).begins_with("Borde"):
			continue
		var forma := cuerpo.get_child(0) as CollisionShape3D
		if forma == null or not (forma.shape is BoxShape3D):
			continue
		var caja: Vector3 = (forma.shape as BoxShape3D).size
		var base := cuerpo.global_transform.basis.orthonormalized()
		var centro := cuerpo.global_position
		var eje := base.x if caja.x >= caja.z else base.z
		var largo: float = maxf(caja.x, caja.z)
		for paso in int(largo / 0.3) + 1:
			var t := float(paso) * 0.3 - largo * 0.5
			var p := centro + eje * t
			_punto(img, Vector2(p.x, p.z), minimo, escala, Color(0.85, 0.25, 0.25))

	# El estanque.
	if radio_agua > 0.0:
		_disco(img, Vector2(sitio_agua.x, sitio_agua.z), radio_agua, minimo,
			escala, Color(0.25, 0.55, 0.9))

	# El punto de aparición.
	var inicio: Vector3 = _blockout.get("punto_inicio")
	_disco(img, Vector2(inicio.x, inicio.z), 2.0, minimo, escala, Color(0.3, 1.0, 0.4))

	img.save_png(ProjectSettings.globalize_path(PLANO))
	print("\n-- Plano --\n   guardado en %s (%.0f x %.0f m)"
		% [PLANO, extension.x, extension.y])

	# Y el listado de dónde ha quedado cada cosa. El dibujo enseña que algo se
	# monta encima de otra cosa; los números dicen cuál y por cuántos metros.
	print("   arenas:")
	for nombre: String in centros:
		var c: Vector3 = centros[nombre]
		var r: float = float(_blockout.get("radios_arena").get(nombre, 11.0))
		var linea := "     %-14s (%7.1f, %7.1f) r %.0f" % [nombre, c.x, c.z, r]
		if radio_agua > 0.0:
			var d := Vector2(c.x, c.z).distance_to(
				Vector2(sitio_agua.x, sitio_agua.z))
			if d < r + radio_agua:
				linea += "   ⚠ SE MONTA CON EL ESTANQUE (%.1f m de solape)" \
					% (r + radio_agua - d)
			else:
				linea += "   · %.0f m al estanque" % d
		print(linea)
	print("   tramos:")
	for indice in tramos.size():
		var tramo: Dictionary = tramos[indice]
		var a: Vector3 = tramo["origen"]
		var dir: Vector3 = tramo["direccion"]
		var b := a + dir * float(tramo["largo"])
		var linea := "     %d: (%7.1f, %7.1f) → (%7.1f, %7.1f) ancho %.0f" \
			% [indice, a.x, a.z, b.x, b.z, float(tramo["ancho"])]
		if radio_agua > 0.0:
			var d := _distancia_al_segmento(
				Vector2(sitio_agua.x, sitio_agua.z),
				Vector2(a.x, a.z), Vector2(b.x, b.z))
			if d < float(tramo["ancho"]) * 0.5 + radio_agua:
				linea += "   ⚠ SE MONTA CON EL ESTANQUE"
		print(linea)


func _punto(img: Image, mundo: Vector2, origen: Vector2, escala: float,
		color: Color) -> void:
	var x := int((mundo.x - origen.x) * escala)
	var y := int((mundo.y - origen.y) * escala)
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	img.set_pixel(x, y, color)


func _disco(img: Image, centro: Vector2, radio: float, origen: Vector2,
		escala: float, color: Color) -> void:
	var pasos := int(radio / 0.35) + 1
	for j in range(-pasos, pasos + 1):
		for i in range(-pasos, pasos + 1):
			var d := Vector2(float(i) * 0.35, float(j) * 0.35)
			if d.length() <= radio:
				_punto(img, centro + d, origen, escala, color)


# --- Utilidades ----------------------------------------------------------------

## La altura del TERRENO en un punto, ignorando el blockout.
##
## Apartar el blockout es lo que hace válida la medida: sus losas están en la
## misma capa y ya no se dibujan, así que un rayo que choque con ellas contesta
## por una superficie que no se ve. Devuelve `null` si no hay nada debajo.
func _altura_del_terreno(punto: Vector3):
	var espacio := _nivel.get_viewport().world_3d.direct_space_state
	if espacio == null:
		return null
	var consulta := PhysicsRayQueryParameters3D.create(
		punto + Vector3.UP * 90.0, punto + Vector3.DOWN * 90.0)
	consulta.collision_mask = 1
	consulta.exclude = _apartados
	var choque := espacio.intersect_ray(consulta)
	if choque.is_empty():
		return null
	return choque["position"].y


## Distancia de un punto a un segmento, en el plano.
func _distancia_al_segmento(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var largo2 := ab.length_squared()
	if largo2 < 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / largo2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _contar(que: String, cuantos: int) -> void:
	if cuantos == 0:
		print("   ✓ %s: ninguno" % que)
	else:
		print("   ⚠ %s: %d" % [que, cuantos])
		_avisos += cuantos
