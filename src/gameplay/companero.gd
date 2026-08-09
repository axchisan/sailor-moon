extends CharacterBody3D
class_name Companero
## Un gato que acompaña a alguien: Luna con Serena, Artemis con Venus.
##
## No es un personaje jugable ni un enemigo. Su trabajo es **estar ahí**: que
## el mundo no parezca vacío y que, cuando toque hablar, ya haya alguien a
## quien mirar. Nada de él afecta al combate.
##
## ## Cómo sigue
##
## No va pegado detrás, que es lo que hacen los seguidores mal hechos y acaba
## dando empujones y metiéndose en la cámara. Se queda **a un lado y algo
## atrás**, y solo se mueve cuando se ha quedado demasiado lejos. Si estás
## quieta, él también.
##
## ## La cola no está animada
##
## La mueve `HairPhysics` con la misma `SpringBoneChain` que las coletas de
## Serena. Una cola animada a mano siempre va a destiempo del movimiento; una
## con física reacciona sola a los giros y a los frenazos, que es lo que hace
## una cola de gato de verdad.
##
## ## Es un cuerpo, no un adorno
##
## Es `CharacterBody3D` y no `Node3D` por dos motivos que resultaron ser el
## mismo: se le atravesaba como a un fantasma, y **se hundía en las cuestas**.
## Moviéndose solo en el plano y sin consultar el suelo, en el pasillo empinado
## que sube al guardián se metía dentro del terreno. Con cuerpo, gravedad y
## `move_and_slide` se pega al suelo, sube las rampas y además se le nota el
## bulto.
##
## ## Sin modelo
##
## Funciona sin `modelo` asignado: coloca una cápsula gris. Así el
## comportamiento se prueba y se ajusta antes de tener el 3D, y cuando llega el
## modelo solo hay que arrastrarlo a la ficha.

@export var id: String = "luna"
## El `.glb` o `.fbx` del gato. Vacío = cápsula de sustitución.
@export var modelo: PackedScene
## A quién sigue. Vacío = a la jugadora.
@export var sigue_a: NodePath
## Multiplica el tamaño del modelo. Los gatos se exportan a 52 cm de cruz, que
## junto a Serena todavía se queda corto.
@export_range(0.5, 2.5) var escala: float = 1.18

@export_group("Movimiento")
## Distancia a la que se planta. Menos de esto, se queda quieto.
@export var distancia_comoda: float = 2.4
## Si se queda más lejos que esto, corre.
@export var distancia_carrera: float = 6.0
@export var velocidad: float = 3.2
@export var velocidad_carrera: float = 6.0
@export var giro: float = 8.0
## A qué lado se coloca: −1 izquierda, +1 derecha.
@export_range(-1.0, 1.0) var lado: float = -1.0

@export_group("Vida")
## Reproduce `andar` e `idle` del modelo. Un gato inmóvil parece de piedra.
@export var animar: bool = true
## A qué velocidad avanza el gato cuando el ciclo de `andar` corre a velocidad
## normal. Se usa para acelerar la animación con el desplazamiento y que las
## patas no patinen. Se ajusta a ojo: si resbala, bajarlo.
@export var velocidad_de_la_zancada: float = 1.5
## Tope de aceleración de la animación. Sin él, corriendo a 6 m/s las patas
## giran como un dibujo animado.
@export_range(1.0, 5.0) var zancada_maxima: float = 2.4

@export_group("Cuerpo")
@export var radio_cuerpo: float = 0.17
@export var alto_cuerpo: float = 0.34
## Lo que tira hacia abajo. Un gato no salta, así que con poco basta: solo hace
## falta que no se despegue del suelo al bajar una rampa.
@export var gravedad: float = 14.0

@export_group("Cola")
## La mueve la física, no la animación.
@export var cola_viva: bool = true
@export var cola_raiz: String = "cola_1"
@export_range(1, 6) var cola_huesos: int = 3

var _objetivo: Node3D = null
var _visual: Node3D = null
var _animador: AnimationPlayer = null
var _pelo: HairPhysics = null
var _andando: bool = false
## Segundos seguidos sin acercarse al objetivo. Es lo que detecta el atasco.
var _atascado: float = 0.0
var _distancia_previa: float = 0.0


func _ready() -> void:
	_montar_cuerpo()
	_montar_visual()
	if _animador != null:
		_animador.play("idle")


## Cápsula tumbada, del tamaño del gato, y las capas que le tocan.
##
## Va en `interactable` y no en `world`: si fuera mundo, los enemigos la
## tomarían por un obstáculo del escenario y se quedarían atascados detrás.
func _montar_cuerpo() -> void:
	collision_layer = 128  # interactable
	collision_mask = 1     # solo el escenario: no empuja ni la empujan
	# Un gato no trepa nada, pero tampoco puede quedarse trabado en el bordillo
	# del camino. La pendiente va generosa y el enganche al suelo, largo: entre
	# los dos suben solos casi todos los escalones del parque.
	#
	# `motion_mode` en modo suelo es lo que hace que un tropiezo se resuelva
	# deslizando por encima en vez de frenar en seco contra el canto.
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	floor_max_angle = deg_to_rad(60.0)
	floor_snap_length = 0.7
	floor_block_on_wall = false
	# Sube escalones de hasta medio metro sin necesidad de saltar: es la altura
	# de las losas del blockout, que es justo donde se quedaba clavada.
	floor_constant_speed = true
	safe_margin = 0.02

	var forma := CollisionShape3D.new()
	forma.name = "Forma"
	var capsula := CapsuleShape3D.new()
	capsula.radius = radio_cuerpo
	capsula.height = alto_cuerpo + radio_cuerpo * 2.0
	forma.shape = capsula
	# Tumbada: un gato es más largo que alto.
	forma.rotation.x = PI * 0.5
	forma.position.y = radio_cuerpo
	add_child(forma)


func _physics_process(delta: float) -> void:
	var objetivo := _buscar_objetivo()
	if objetivo == null:
		return

	# El sitio al que quiere ir: al lado del acompañado, no encima.
	var frente := -objetivo.global_transform.basis.z
	frente.y = 0.0
	if frente.length_squared() < 0.001:
		frente = Vector3.FORWARD
	frente = frente.normalized()
	var costado := frente.cross(Vector3.UP).normalized()
	var destino := objetivo.global_position + costado * lado * 0.9 - frente * 1.1

	var hacia := destino - global_position
	hacia.y = 0.0
	var distancia := hacia.length()

	var andaba := _andando
	_andando = distancia > distancia_comoda
	var avance := 0.0
	var paso := Vector3.ZERO
	if _andando:
		var rapido: float = velocidad_carrera if distancia > distancia_carrera else velocidad
		# Cerca del destino afloja, para no quedarse temblando encima del punto.
		var freno: float = clampf((distancia - distancia_comoda * 0.5) / 1.5, 0.0, 1.0)
		avance = rapido * freno
		paso = hacia.normalized() * avance
		var mirando := atan2(-hacia.x, -hacia.z)
		rotation.y = lerp_angle(rotation.y, mirando, minf(delta * giro, 1.0))

	# El desplazamiento pasa por la física en vez de escribir la posición a
	# mano: es lo que le hace subir las rampas en vez de meterse dentro de
	# ellas, y lo que le impide colarse por las paredes.
	velocity.x = paso.x
	velocity.z = paso.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - gravedad * delta
	move_and_slide()
	_desatascar(delta, distancia)

	if animar:
		_animar(andaba, avance)


## Cambia entre `andar` e `idle`, y acompasa la zancada al avance real.
##
## Sin lo segundo el gato patina: las patas van a un ritmo fijo mientras el
## cuerpo se desplaza a otro, y se nota inmediatamente aunque el bicho sea
## pequeño. Con tope, eso sí — a la velocidad de carrera la proporción exacta
## daría siete zancadas por segundo.
func _animar(andaba: bool, avance: float) -> void:
	if _animador == null:
		return
	if _andando != andaba or not _animador.is_playing():
		_animador.play("andar" if _andando else "idle", 0.18)
	if _andando:
		_animador.speed_scale = clampf(
			avance / maxf(velocidad_de_la_zancada, 0.01), 0.7, zancada_maxima)
	else:
		_animador.speed_scale = 1.0


func _montar_visual() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	_visual.scale = Vector3.ONE * escala
	add_child(_visual)

	if modelo != null:
		var toon := Node3D.new()
		toon.name = "ToonRoot"
		toon.set_script(load("res://src/core/toon_root.gd"))
		# Igual que los personajes: los modelos importados miran a +Z.
		toon.rotation.y = PI

		var instancia := modelo.instantiate()
		if cola_viva:
			# El mismo orden que en `personaje_visual.gd`: la física tiene que
			# tener ya al esqueleto colgando cuando entra en el árbol, si no
			# `_ready()` no encuentra nada y no monta la cadena sin avisar.
			_pelo = HairPhysics.new()
			_pelo.name = "Cola"
			_pelo.chain_roots = [cola_raiz] as Array[String]
			_pelo.chain_length = cola_huesos
			# Más tiesa y menos pesada que una melena: una cola de gato tiene
			# músculo, no cuelga muerta.
			_pelo.stiffness = 2.2
			_pelo.drag = 0.5
			_pelo.gravity_power = 0.35
			_pelo.max_angle = 55.0
			_pelo.add_child(instancia)
			toon.add_child(_pelo)
		else:
			toon.add_child(instancia)

		_visual.add_child(toon)
		_animador = _buscar_animador(instancia)
		if _animador == null:
			push_warning("Companero '%s': el modelo no trae AnimationPlayer" % id)
		return

	# Sustituto mientras no hay modelo: una cápsula del tamaño de un gato.
	var malla := MeshInstance3D.new()
	var capsula := CapsuleMesh.new()
	capsula.radius = 0.14
	capsula.height = 0.46
	malla.mesh = capsula
	malla.rotation.x = PI * 0.5
	malla.position.y = 0.16
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.22, 0.20, 0.26) if id == "luna" \
		else Color(0.92, 0.92, 0.95)
	malla.material_override = material
	_visual.add_child(malla)


func _buscar_objetivo() -> Node3D:
	if _objetivo != null and is_instance_valid(_objetivo):
		return _objetivo
	if not sigue_a.is_empty():
		_objetivo = get_node_or_null(sigue_a) as Node3D
	if _objetivo == null:
		_objetivo = get_tree().get_first_node_in_group("player") as Node3D
	return _objetivo


## Saca al gato de donde se haya quedado enganchado.
##
## Un gato no salta, así que cualquier escalón de un palmo —el canto de una
## losa, una raíz, el borde del camino— lo deja empujando contra la pared para
## siempre mientras la jugadora se aleja. Se resuelve en dos escalones:
##
## 1. **Empujón hacia arriba** si está tocando pared y quiere avanzar. Con
##    `floor_snap_length` sube solo la mayoría de bordes, pero no los que pillan
##    con la cápsula ya encajada.
## 2. **Teletransporte** si lleva demasiado tiempo sin avanzar de verdad. Es
##    feo, pero un gato que se queda atrás para siempre es peor: deja de
##    acompañar, que es su único trabajo.
func _desatascar(delta: float, distancia: float) -> void:
	if not _andando:
		_atascado = 0.0
		return

	# «Avanzar de verdad» es haber recortado distancia al objetivo. Mirar solo el
	# desplazamiento no vale: resbalando a lo largo de una pared se mueve mucho
	# y no se acerca nada.
	if distancia < _distancia_previa - 0.02:
		_atascado = 0.0
	else:
		_atascado += delta
	_distancia_previa = distancia

	if _atascado > 0.35 and is_on_wall() and is_on_floor():
		# Saltito corto: lo justo para montar un escalón bajo.
		velocity.y = 3.2
		_atascado = 0.15

	if _atascado > 2.5:
		teletransportar_junto_al_objetivo()
		_atascado = 0.0


static func _buscar_animador(nodo: Node) -> AnimationPlayer:
	if nodo is AnimationPlayer:
		return nodo
	for hijo in nodo.get_children():
		var encontrado := _buscar_animador(hijo)
		if encontrado != null:
			return encontrado
	return null


## Lo llama el nivel al teletransportar: si no, el gato cruza el mapa andando.
func teletransportar_junto_al_objetivo() -> void:
	var objetivo := _buscar_objetivo()
	if objetivo != null:
		global_position = objetivo.global_position
	# Sin esto la cola sale disparada con la inercia del salto de posición.
	if _pelo != null:
		_pelo.reset()
