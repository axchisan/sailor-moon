extends Area3D
class_name Arena
## Arena de combate: se cierra con una barrera mágica, lanza oleadas y se abre
## al limpiarlas.
##
## Es la unidad de contenido del juego. Un nivel es:
##   tramo → arena → tramo → arena → tramo → guardián
##
## Además de ser el formato del género, abarata la producción: las arenas son
## pequeñas y contenidas, no mundos abiertos.

@export var arena_id: String = "arena_1"
## Enemigos por oleada. [2, 3, 4] = tres oleadas de dificultad creciente.
@export var waves: Array[int] = [2, 3, 4]
## Enemigo básico: es el que rellena las oleadas.
@export var enemy_scene: PackedScene
## Enemigos que se mezclan con el básico (Cofrecito, Globito…).
@export var enemy_scenes_extra: Array[PackedScene] = []
## Proporción de enemigos extra dentro de una oleada.
@export_range(0.0, 1.0) var extra_ratio: float = 0.34
## Oleada a partir de la cual aparecen los extra. Con 1, la primera oleada es
## solo del enemigo básico: se aprende a pegar antes de aprender a rodear.
@export var extra_from_wave: int = 1
@export var spawn_radius: float = 7.5
## Pausa entre oleadas para que respire.
@export var wave_delay: float = 1.2

@export_group("Barrera mágica")
@export var barrier_radius: float = 11.0
@export var barrier_height: float = 3.5
## Cuánto sube la COLISIÓN de la barrera por encima de lo que se ve.
##
## La barrera es una cortina translúcida de tres metros y medio, y se saltaba —
## y saltándola se sale de la pelea, que es justo lo que impide. Subir el panel
## de verdad taparía el escenario con una pared rosa en el momento en que más
## falta hace ver a los enemigos, así que sube solo lo que choca.
## Con cuatro metros y medio de más se seguía entrando de vez en cuando: el
## doble salto sube mucho, y basta con tomar carrerilla desde un montículo del
## borde para pasar por encima. Es colisión invisible, así que subirla no cuesta
## nada ni se ve — y una barrera que se salta «solo a veces» es peor que ninguna,
## porque el juego parece roto en vez de difícil.
@export var barrier_extra_collision: float = 11.0
## Más segmentos = círculo más redondo y más draw calls. 16 es buen equilibrio.
@export var barrier_segments: int = 16
@export var barrier_color: Color = Color(1.0, 0.55, 0.85, 0.28)
## Empezar con la barrera puesta, y no dejar entrar hasta que se desbloquee.
##
## La arena del guardián se cerraba con la puerta mágica del pasillo, pero eso
## solo tapa el camino: dando un rodeo por el campo se entraba tan tranquilo y
## el guardián aparecía sin haber encendido un solo farol. Un pasillo cerrado no
## cierra una arena — un anillo sí, y la barrera ya es un anillo completo.
##
## Se abre con `desbloquear()`, a la vez que la puerta.
@export var bloqueada_al_empezar: bool = false

var started: bool = false
var cleared: bool = false
## Mientras esté bloqueada, ni se entra ni se dispara la oleada.
var bloqueada: bool = false

var _wave_index: int = -1
var _spawned: Array[Node] = []
var _delay_timer: float = 0.0
var _waiting: bool = false
var _barrier: Node3D = null


func _ready() -> void:
	monitoring = true
	# En grupo para poder alcanzarlas desde fuera sin cablear NodePaths: el
	# nivel necesita desbloquear la del guardián cuando se encienden los faroles.
	add_to_group("arenas")
	body_entered.connect(_on_body_entered)
	_ajustar_disparador()
	_build_barrier()
	bloqueada = bloqueada_al_empezar
	_set_barrier(bloqueada)
	_montar_zona_de_aviso()
	set_physics_process(false)


## LA PELEA EMPIEZA EN TODA LA ARENA, NO SOLO EN EL CENTRO.
##
## El disparador venía del `.tscn` con seis metros de radio y la barrera con
## once: entre uno y otra quedaba un anillo de cinco metros de arena por el que
## se podía cruzar de lado a lado sin que saltara nada. Y se cruzaba — pegarse al
## borde y bordear era la forma de saltarse las dos primeras peleas enteras.
##
## Que el disparador se ajuste solo al radio de la barrera quita el problema de
## raíz: eran dos números que tenían que ir juntos escritos en sitios distintos,
## y eso siempre acaba desalineándose. Ahora solo hay uno.
func _ajustar_disparador() -> void:
	for hijo in get_children():
		var forma := hijo as CollisionShape3D
		if forma == null or forma.shape == null:
			continue
		# Duplicado ANTES de tocarlo: en la escena del nivel las cuatro arenas
		# comparten el mismo `SubResource`, así que cambiarle el radio a una se
		# lo cambiaba a todas — y con radios de 11, 12 y 13 ganaba la última.
		var cilindro := forma.shape.duplicate() as CylinderShape3D
		if cilindro == null:
			continue
		# Medio metro por dentro del panel, para no arrancar la pelea con la
		# jugadora metida en la propia barrera cuando esta se levanta.
		cilindro.radius = maxf(barrier_radius - 0.6, 1.0)
		forma.shape = cilindro


## Qué se le dice a quien intente entrar mientras está cerrada.
##
## La barrera de la arena es lo que cierra de verdad el paso al guardián —el
## pasillo tiene puerta, pero el campo se rodea—, y quien llega por el campo se
## encontraba una pared rosa muda. La puerta explicaba qué faltaba y la barrera
## no, cuando las dos cierran lo mismo.
##
## Lo rellena `nivel.gd`, que es quien lleva la cuenta de los faroles.
@export var pista: String = ""
## A qué distancia del borde de la barrera se avisa.
@export var margen_aviso: float = 4.0
## Cada cuánto se repite, para no ser pesada.
@export var repetir_aviso: float = 6.0

var _proximo_aviso: float = 0.0


func _montar_zona_de_aviso() -> void:
	if not bloqueada_al_empezar:
		return
	var zona := Area3D.new()
	zona.name = "ZonaAviso"
	zona.collision_layer = 0
	zona.collision_mask = 2
	var forma := CollisionShape3D.new()
	var cilindro := CylinderShape3D.new()
	cilindro.radius = barrier_radius + margen_aviso
	cilindro.height = 8.0
	forma.shape = cilindro
	forma.position.y = 2.0
	zona.add_child(forma)
	zona.body_entered.connect(func(cuerpo: Node3D) -> void:
		if not bloqueada or pista.is_empty():
			return
		if not cuerpo.is_in_group("player"):
			return
		var ahora := Time.get_ticks_msec() / 1000.0
		if ahora < _proximo_aviso:
			return
		_proximo_aviso = ahora + repetir_aviso
		EventBus.show_message.emit(pista, 3.0))
	add_child(zona)


## Construye la barrera como un anillo de paneles. Se genera por código porque
## a mano en el .tscn serían 16 nodos duplicados imposibles de reajustar.
func _build_barrier() -> void:
	_barrier = Node3D.new()
	_barrier.name = "Barrier"
	add_child(_barrier)

	var material := StandardMaterial3D.new()
	material.albedo_color = barrier_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.emission_enabled = true
	material.emission = barrier_color
	material.emission_energy_multiplier = 0.6

	var segment_width := TAU * barrier_radius / float(barrier_segments) * 1.08
	var size := Vector3(segment_width, barrier_height, 0.25)

	var mesh := BoxMesh.new()
	mesh.size = size

	# LA BARRERA CHOCA MÁS ALTO DE LO QUE SE VE.
	#
	# Los tres metros y medio de panel rosa se saltaban, y saltando la barrera
	# se sale de la pelea — que es exactamente lo que la barrera existe para
	# impedir. Subir el panel de verdad no vale: la barrera es una cortina
	# translúcida y hacerla más alta la convierte en un muro que tapa el
	# escenario justo cuando hay que ver a los enemigos.
	#
	# Así que la malla se queda como está y solo crece la caja de choque, hacia
	# arriba. Se ve lo mismo y no hay por dónde escaparse.
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, size.y + barrier_extra_collision, size.z)

	for i in barrier_segments:
		var angle := TAU * float(i) / float(barrier_segments)
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = Vector3(cos(angle), barrier_height * 0.5, sin(angle)) * \
			Vector3(barrier_radius, 1.0, barrier_radius)
		# Tangente al círculo, no radial: rotando `Y` un ángulo φ el eje Z local
		# va a (sin φ, 0, cos φ), y para que mire al centro hay que igualarlo a
		# la normal (cos θ, 0, sin θ) → φ = 90° − θ. Con `−θ` los paneles
		# quedaban de canto y la barrera se veía como los radios de una rueda.
		body.rotation.y = PI * 0.5 - angle

		var visual := MeshInstance3D.new()
		visual.mesh = mesh
		visual.material_override = material
		body.add_child(visual)

		var collider := CollisionShape3D.new()
		collider.shape = shape
		# La caja de choque es más alta que el panel, así que hay que subirla
		# media diferencia: si no, crecería también hacia abajo y dejaría un
		# bloque enterrado que estorba al andar por el borde de la arena.
		collider.position.y = barrier_extra_collision * 0.5
		body.add_child(collider)

		_barrier.add_child(body)


func _on_body_entered(body: Node3D) -> void:
	if started or cleared or bloqueada:
		return
	if not body.is_in_group("player"):
		return
	start()


## Levanta el cierre previo. La pelea no empieza aquí: empieza cuando se entra.
func desbloquear() -> void:
	if not bloqueada:
		return
	bloqueada = false
	_set_barrier(false)


func start() -> void:
	if started or bloqueada:
		return
	# UNA ARENA SIN OLEADAS NO ES UNA ARENA.
	#
	# El claro del portal es un `Arena` con la lista vacía —lo es para heredar la
	# barrera y el disco de suelo, no para pelear—, así que pisarlo anunciaba
	# «¡Aquí vienen!» sin que viniera nadie, y ese cartel se comía al del portal,
	# que es justo lo que hay que leer ahí. Callarlo al terminar no bastaba: el
	# ruido estaba al empezar.
	#
	# Cuando el guardián del portal tenga su oleada, esto dejará de aplicarle
	# solo con rellenarle la lista.
	if waves.is_empty():
		return
	started = true
	set_physics_process(true)
	_set_barrier(true)

	GameManager.set_checkpoint(global_position)
	EventBus.arena_started.emit(arena_id, waves.size())
	_next_wave()


func _physics_process(delta: float) -> void:
	if cleared:
		return

	if _waiting:
		_delay_timer -= delta
		if _delay_timer <= 0.0:
			_waiting = false
			_next_wave()
		return

	if _alive_count() > 0:
		_vigilar_perdidos(delta)
		return
	_sin_bajas = 0.0

	EventBus.wave_cleared.emit(_wave_index)

	if _wave_index + 1 >= waves.size():
		_finish()
	else:
		_waiting = true
		_delay_timer = wave_delay


## NINGÚN ENEMIGO PUEDE COLGAR LA OLEADA PARA SIEMPRE.
##
## La oleada solo avanza cuando no queda nadie vivo, así que **un solo enemigo
## al que no se pueda llegar deja el nivel muerto**: no salen más, no se abre la
## barrera y no hay nada que hacer salvo cerrar el juego. Pasa con más facilidad
## de la que parece — la Hadita vuela y huye, y la del guardián nace en una
## cuesta desde la que se rueda—, y para quien juega no se distingue de que el
## juego esté roto, porque lo está.
##
## Así que se vigila: al que se sale del ruedo o se cae se le trae de vuelta, y
## si pasa un buen rato sin que muera nadie se traen todos junto a la jugadora.
## No se les da por muertos —eso sí sería regalar la pelea—: se les devuelve a
## ella.
const RESCATE_SECO := 25.0

var _sin_bajas: float = 0.0
var _vivos_antes: int = -1


func _vigilar_perdidos(delta: float) -> void:
	var vivos := _alive_count()
	if vivos < _vivos_antes or _vivos_antes < 0:
		# Ha caído alguno: la pelea avanza, no hay nada que rescatar.
		_sin_bajas = 0.0
	_vivos_antes = vivos
	_sin_bajas += delta

	var jugador := get_tree().get_first_node_in_group("player") as Node3D
	var seco := _sin_bajas >= RESCATE_SECO
	var alguno := false

	for nodo in _spawned:
		if not is_instance_valid(nodo):
			continue
		var enemigo := nodo as Enemy
		if enemigo == null or enemigo.defeated:
			continue
		var p := enemigo.global_position
		var lejos := Vector2(p.x - global_position.x, p.z - global_position.z) \
			.length() > barrier_radius
		var caido := p.y < global_position.y - 6.0
		if not (lejos or caido or seco):
			continue
		alguno = true
		# Al lado de la jugadora, no en el centro: si el rescate la deja en la
		# otra punta del ruedo, vuelve a perderse antes de que llegue nadie.
		#
		# Salvo que ella misma esté fuera del ruedo, que en partida no pasa —la
		# pelea arranca al entrar— pero sí al depurar: entonces el rescate los
		# sacaba a todos de la arena en vez de meterlos.
		var destino := global_position
		if jugador != null:
			var d := Vector2(jugador.global_position.x - global_position.x,
				jugador.global_position.z - global_position.z).length()
			if d <= barrier_radius:
				destino = jugador.global_position
		var giro := randf() * TAU
		enemigo.global_position = destino \
			+ Vector3(cos(giro), 0.0, sin(giro)) * 4.0 + Vector3.UP * 0.6
		if enemigo is CharacterBody3D:
			(enemigo as CharacterBody3D).velocity = Vector3.ZERO

	if alguno and seco:
		_sin_bajas = 0.0
		EventBus.show_message.emit("¡Se escondían! Aquí vienen otra vez", 2.5)


func _next_wave() -> void:
	_wave_index += 1
	if _wave_index >= waves.size():
		_finish()
		return

	var count: int = waves[_wave_index]
	for i in count:
		_spawn_enemy(i, count)


func _spawn_enemy(index: int, total: int) -> void:
	var escena := _elegir_enemigo()
	if escena == null:
		push_error("Arena '%s' sin enemy_scene asignada." % arena_id)
		return

	var enemy := escena.instantiate() as Node3D
	if enemy == null:
		return

	# Repartidos en círculo para que no aparezcan todos amontonados encima
	# del jugador. Aparecer pegado a la cara es lo más injusto que hay.
	var angle := TAU * (float(index) / maxf(1.0, float(total))) + randf() * 0.4
	get_parent().add_child(enemy)
	enemy.global_position = _sitio_de_aparicion(angle)

	_spawned.append(enemy)


## APARECER SOBRE EL SUELO QUE HAY, NO SOBRE EL QUE DEBERÍA HABER.
##
## El anillo de aparición se calculaba en plano, a la altura del centro de la
## arena. En la del guardián eso pone tres de cada dieciséis sitios en plena
## cuesta de entrada, con dos metros de desnivel: quien sale ahí nace enterrado
## hasta el pecho o cayéndose, y de ahí sale rodando a cualquier parte.
##
## Se prueba el ángulo pedido y, si no hay suelo firme, se va girando. Nueve
## intentos y se rinde: si no cabe en ninguno, mejor uno mal puesto —al que el
## rescate de más abajo alcanzará— que ningún enemigo y una oleada que no acaba.
func _sitio_de_aparicion(angulo: float) -> Vector3:
	var espacio := get_world_3d().direct_space_state
	for intento in 9:
		var a := angulo + TAU * float(intento) / 9.0
		var p := global_position + Vector3(cos(a), 0.0, sin(a)) * spawn_radius
		if espacio == null:
			return p + Vector3.UP * 0.5
		var consulta := PhysicsRayQueryParameters3D.create(
			p + Vector3.UP * 5.0, p + Vector3.DOWN * 20.0)
		consulta.collision_mask = 1
		var choque := espacio.intersect_ray(consulta)
		if choque.is_empty():
			continue
		var suelo: float = choque["position"].y
		# Un escalón de metro y medio respecto al centro ya no es la arena: es
		# la cuesta de al lado o el techo de un muro.
		if absf(suelo - global_position.y) > 1.5:
			continue
		return Vector3(p.x, suelo + 0.5, p.z)
	return global_position + Vector3(cos(angulo), 0.0, sin(angulo)) * spawn_radius \
		+ Vector3.UP * 0.5


## Mezcla la oleada. Los enemigos extra solo entran a partir de
## `extra_from_wave`, para que cada mecánica nueva llegue de una en una.
func _elegir_enemigo() -> PackedScene:
	if not enemy_scenes_extra.is_empty() and _wave_index >= extra_from_wave:
		if randf() < extra_ratio:
			return enemy_scenes_extra[randi() % enemy_scenes_extra.size()]
	return enemy_scene


func _alive_count() -> int:
	var alive := 0
	var still_valid: Array[Node] = []
	for node in _spawned:
		if node == null or not is_instance_valid(node):
			continue
		still_valid.append(node)
		var enemy := node as Enemy
		if enemy != null and not enemy.defeated:
			alive += 1
	_spawned = still_valid
	return alive


func _finish() -> void:
	cleared = true
	set_physics_process(false)
	_set_barrier(false)
	CombatDirector.reset()
	# Sin oleadas no hay victoria que anunciar. Ver `start()`.
	if waves.is_empty():
		return
	EventBus.arena_cleared.emit(arena_id)


func _set_barrier(active: bool) -> void:
	if _barrier == null:
		return
	_barrier.visible = active
	for body in _barrier.get_children():
		for child in body.get_children():
			if child is CollisionShape3D:
				child.set_deferred("disabled", not active)
