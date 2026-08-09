extends Node3D
class_name CamaraApertura
## El plano aéreo con el que empieza el nivel.
##
## Arranca mirando el parque desde arriba y baja hasta ponerse detrás de la
## jugadora, donde le pasa el control a la cámara de siempre.
##
## No es solo presentación. Hace dos cosas de diseño:
##
## - **Enseña el sitio.** En un nivel donde ahora hay campo abierto, colinas y
##   un cruce con dos caminos, empezar pegada a la nuca no cuenta nada. Un
##   plano de tres segundos deja claro que hay un parque y que se puede salir de
##   él.
## - **Da un principio.** Sin esto la partida empieza de golpe, sin respirar.
##
## Se puede saltar tocando la pantalla: la segunda vez que se juega un nivel,
## una cinemática obligatoria es un peaje.

signal terminada

@export var activa: bool = true
## Segundos que dura el descenso.
@export var duracion: float = 3.6
## Altura desde la que arranca, sobre el parque.
@export var altura_inicial: float = 46.0
## Cuánto se retrasa respecto a la jugadora al empezar, en metros.
@export var distancia_inicial: float = 34.0
## Se congela a la jugadora mientras dura. Si no, se puede mover a ciegas
## durante el plano y aparecer donde no toca al recuperar la cámara.
@export var congelar_jugador: bool = true

var _camara: Camera3D = null
var _jugador: Node3D = null
var _camara_jugador: Camera3D = null
var _tiempo: float = 0.0
var _desde: Transform3D
var _hasta: Transform3D
var _corriendo: bool = false


func arrancar(centro_parque: Vector3) -> void:
	if not activa:
		terminada.emit()
		return
	_jugador = get_tree().get_first_node_in_group("player") as Node3D
	if _jugador == null:
		terminada.emit()
		return

	var camaras := _jugador.find_children("*", "Camera3D", true, false)
	if camaras.is_empty():
		terminada.emit()
		return
	_camara_jugador = camaras[0] as Camera3D

	_camara = Camera3D.new()
	_camara.name = "CamaraApertura"
	_camara.fov = _camara_jugador.fov
	_camara.far = _camara_jugador.far
	add_child(_camara)

	# Punto de partida: alto y atrás, mirando al parque. La jugadora entra en
	# cuadro pequeña, y el sitio se lee entero.
	var atras := _jugador.global_position - _mirando() * distancia_inicial
	atras.y = _jugador.global_position.y + altura_inicial
	_camara.global_position = atras
	_camara.look_at(centro_parque)
	_desde = _camara.global_transform
	# El final se toma de la cámara de la jugadora tal como está AHORA, para que
	# el salto al devolver el control sea exactamente cero.
	_hasta = _camara_jugador.global_transform

	_camara.make_current()
	if congelar_jugador and _jugador.has_method("set_control_enabled"):
		_jugador.call("set_control_enabled", false)
	_corriendo = true
	_tiempo = 0.0
	set_process(true)


func _process(delta: float) -> void:
	if not _corriendo:
		return
	_tiempo += delta
	var t := clampf(_tiempo / maxf(duracion, 0.1), 0.0, 1.0)
	# Suave al entrar y al salir: un descenso lineal se nota mecánico, y el
	# frenazo del final es lo que hace que el plano «aterrice» en vez de cortar.
	var suave := t * t * (3.0 - 2.0 * t)

	_camara.global_position = _desde.origin.lerp(_hasta.origin, suave)
	# La orientación se interpola por cuaternión: mezclando las bases a pelo, la
	# cámara pasa por rotaciones imposibles a mitad de camino.
	var giro := Quaternion(_desde.basis.orthonormalized()).slerp(
		Quaternion(_hasta.basis.orthonormalized()), suave)
	_camara.global_transform.basis = Basis(giro)

	if t >= 1.0:
		_terminar()


func _unhandled_input(evento: InputEvent) -> void:
	if not _corriendo:
		return
	var salta := false
	if evento is InputEventScreenTouch:
		salta = (evento as InputEventScreenTouch).pressed
	elif evento is InputEventMouseButton:
		salta = (evento as InputEventMouseButton).pressed
	elif evento is InputEventKey:
		salta = (evento as InputEventKey).pressed and not (evento as InputEventKey).echo
	if salta:
		get_viewport().set_input_as_handled()
		_terminar()


func _terminar() -> void:
	if not _corriendo:
		return
	_corriendo = false
	set_process(false)
	if _camara_jugador != null:
		_camara_jugador.make_current()
	if congelar_jugador and _jugador != null and _jugador.has_method("set_control_enabled"):
		_jugador.call("set_control_enabled", true)
	if _camara != null:
		_camara.queue_free()
		_camara = null
	terminada.emit()


## Hacia dónde mira la jugadora, en el plano. Es la dirección desde la que se
## acerca la cámara, para que el plano acabe encarado con el camino.
func _mirando() -> Vector3:
	if _jugador == null:
		return Vector3.FORWARD
	var frente := -_jugador.global_transform.basis.z
	frente.y = 0.0
	if frente.length_squared() < 0.01:
		return Vector3.FORWARD
	return frente.normalized()
