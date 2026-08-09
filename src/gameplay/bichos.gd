extends Node3D
class_name Bichos
## Mariposas y pajarillos dando vueltas por el parque.
##
## Un parque sin nada que se mueva está muerto: por muy poblado que esté, si
## todo lo que hay es geometría quieta, el sitio se lee como una maqueta. Cuatro
## mariposas revoloteando hacen más por que parezca vivo que cincuenta arbustos
## más.
##
## ## Por qué no son nodos sueltos
##
## Van todos en un `MultiMeshInstance3D` y se mueven escribiendo transformadas.
## Treinta bichos como escenas instanciadas serían treinta nodos con su
## `_process`; así son una llamada de dibujado y un solo bucle.
##
## ## No hacen nada
##
## No se pueden tocar, no dan puntos y no molestan. Es ambiente puro, y por eso
## no tienen colisión ni entran en el presupuesto de nada.

## Cuántos y de qué. `alto` es a qué altura vuelan sobre el suelo.
const ESPECIES := [
	{"pieza": "mariposa", "copias": 22, "alto": 1.3, "vuelo": 0.55,
		"velocidad": 1.5, "escala": 1.0, "aleteo": 15.0},
	{"pieza": "pajarillo", "copias": 9, "alto": 3.4, "vuelo": 1.1,
		"velocidad": 3.2, "escala": 1.0, "aleteo": 0.0},
]

@export var activo: bool = true
## Radio dentro del cual se reparten, desde el centro del nivel.
@export var radio: float = 68.0
@export var semilla: int = 5501

var _rng := RandomNumberGenerator.new()
var _grupos: Array[Dictionary] = []
var _tiempo: float = 0.0


func poblar(centro: Vector3, altura_en: Callable) -> void:
	for hijo in get_children():
		hijo.queue_free()
	_grupos.clear()
	if not activo:
		return
	_rng.seed = semilla

	for especie: Dictionary in ESPECIES:
		var partes := _partes(especie["pieza"])
		if partes.is_empty():
			continue
		var copias: int = especie["copias"]
		var bichos: Array[Dictionary] = []
		for i in copias:
			var angulo := _rng.randf_range(0.0, TAU)
			var r := sqrt(_rng.randf()) * radio
			var sitio := centro + Vector3(cos(angulo), 0.0, sin(angulo)) * r
			sitio.y = altura_en.call(sitio)
			bichos.append({
				"centro": sitio,
				# Cada uno da vueltas a su propio círculo, con su propio ritmo:
				# con parámetros iguales todos giran en formación y se nota.
				"radio": _rng.randf_range(1.2, 4.5),
				"fase": _rng.randf_range(0.0, TAU),
				"ritmo": _rng.randf_range(0.6, 1.4),
				"balanceo": _rng.randf_range(0.0, TAU),
			})

		var nodos: Array[MultiMeshInstance3D] = []
		for indice in partes.size():
			var multi := MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			multi.mesh = partes[indice]["mesh"]
			multi.instance_count = copias
			var nodo := MultiMeshInstance3D.new()
			nodo.name = "%s_%d" % [especie["pieza"], indice]
			nodo.multimesh = multi
			nodo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(nodo)
			nodos.append(nodo)

		_grupos.append({"especie": especie, "bichos": bichos,
			"nodos": nodos, "partes": partes})
	set_process(not _grupos.is_empty())


func _process(delta: float) -> void:
	_tiempo += delta
	for grupo: Dictionary in _grupos:
		var especie: Dictionary = grupo["especie"]
		var bichos: Array = grupo["bichos"]
		var partes: Array = grupo["partes"]
		var velocidad: float = especie["velocidad"]
		var vuelo: float = especie["vuelo"]
		var alto: float = especie["alto"]
		var aleteo: float = especie["aleteo"]
		var escala: float = especie["escala"]

		for i in bichos.size():
			var bicho: Dictionary = bichos[i]
			var t: float = _tiempo * velocidad * float(bicho["ritmo"]) + float(bicho["fase"])
			var r: float = bicho["radio"]
			var centro: Vector3 = bicho["centro"]
			var pos := centro + Vector3(cos(t) * r, 0.0, sin(t) * r)
			# Sube y baja mientras da la vuelta: un círculo plano se lee como un
			# carrusel, y en cuanto hay vaivén vertical parece que vuela.
			pos.y = centro.y + alto + sin(t * 1.7 + float(bicho["balanceo"])) * vuelo

			# Mirando hacia donde va, que es la tangente del círculo.
			var rumbo := atan2(sin(t), cos(t)) + PI * 0.5
			var base := Basis.from_euler(Vector3(0.0, rumbo, 0.0))
			if aleteo > 0.0:
				# Las alas «baten» inclinando el bicho entero de lado. A este
				# tamaño no se distingue de un aleteo de verdad y no cuesta nada.
				base = base * Basis.from_euler(
					Vector3(0.0, 0.0, sin(_tiempo * aleteo + float(bicho["fase"])) * 0.9))
			var pose := Transform3D(base * Basis.from_scale(Vector3.ONE * escala), pos)

			for indice in partes.size():
				var nodo: MultiMeshInstance3D = grupo["nodos"][indice]
				nodo.multimesh.set_instance_transform(
					i, pose * partes[indice]["local"])


func _partes(nombre: String) -> Array:
	var partes: Array = []
	var escena := load("res://assets/models/props/%s.glb" % nombre) as PackedScene
	if escena == null:
		return partes
	var raiz := escena.instantiate()
	_recoger(raiz, Transform3D.IDENTITY, partes)
	raiz.queue_free()
	return partes


static func _recoger(nodo: Node, acumulada: Transform3D, salida: Array) -> void:
	var propia := acumulada
	if nodo is Node3D:
		propia = acumulada * (nodo as Node3D).transform
	if nodo is MeshInstance3D and (nodo as MeshInstance3D).mesh != null:
		salida.append({"mesh": (nodo as MeshInstance3D).mesh, "local": propia})
	for hijo in nodo.get_children():
		_recoger(hijo, propia, salida)
