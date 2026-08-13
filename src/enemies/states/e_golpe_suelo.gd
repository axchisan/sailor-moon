extends State
## El puñetazo al suelo del guardián: el ataque que no se esquiva quedándose.
##
## ## Por qué existe
##
## El golpe normal se evita rodeándolo, y con eso solo la pelea se resuelve
## dando vueltas a su izquierda hasta que se acaba. Este castiga justo eso:
## cubre un círculo entero alrededor de él, así que la respuesta no es rodear
## sino **irse lejos**. Entre los dos obligan a moverse de verdad — acercarse,
## pegar, salir corriendo cuando levanta los dos brazos.
##
## ## El aviso es la mitad del ataque
##
## Un golpe de área sin avisar es una trampa: no hay forma de reaccionar a algo
## que no se ve venir, solo de aprendérselo a base de morir. Aquí se dibuja el
## círculo en el suelo y crece durante segundo y medio largo antes de que pase
## nada. A los ocho años ese tiempo no sobra.
##
## Y el círculo se dibuja **del tamaño exacto** al que va a hacer daño. Un aviso
## que miente es peor que no avisar.

## Cuánto dura cada parte.
const AVISO := 1.55
const IMPACTO := 0.24
const RECUPERACION := 1.15

## Hasta dónde llega. Se sale corriendo, no se rodea.
const RADIO := 6.2

var _fase: int = 0
var _tiempo: float = 0.0
var _marca: MeshInstance3D = null
var _material: StandardMaterial3D = null
var _forma_guardada: Shape3D = null
var _sitio_guardado: Vector3 = Vector3.ZERO


func enter(_msg: Dictionary = {}) -> void:
	var e := actor as Enemy
	_fase = 0
	_tiempo = 0.0
	e.brake(0.016, 20.0)
	_pintar_el_aviso()


func exit() -> void:
	var e := actor as Enemy
	e.hitbox.disable()
	_devolver_la_caja()
	if _marca != null and is_instance_valid(_marca):
		_marca.queue_free()
	_marca = null


func physics_update(delta: float) -> String:
	var e := actor as Enemy
	_tiempo += delta
	e.brake(delta, 14.0)

	match _fase:
		0:
			# Mira hacia la jugadora mientras carga: aunque el golpe sea circular,
			# un jefe que levanta los brazos mirando a otro lado no da miedo.
			e.face_target(delta)
			var t := clampf(_tiempo / AVISO, 0.0, 1.0)
			_crecer_el_aviso(t)
			if _tiempo >= AVISO:
				_fase = 1
				_tiempo = 0.0
				_agrandar_la_caja()
				e.hitbox.enable(e.attack)
				CombatFeel.shake(0.85, 0.5)
				AudioManager.play_sfx(GuardianPortal.SFX_TEMBLOR, 1.0, 0.0)
				if _material != null:
					_material.albedo_color = Color(1.0, 0.95, 0.75, 0.75)
		1:
			if _tiempo >= IMPACTO:
				_fase = 2
				_tiempo = 0.0
				e.hitbox.disable()
				_devolver_la_caja()
				if _marca != null:
					var t := create_tween()
					t.tween_property(_marca, "scale", Vector3(1.3, 1.0, 1.3), 0.25)
					t.parallel().tween_property(_material, "albedo_color:a", 0.0, 0.25)
		2:
			if _tiempo >= RECUPERACION:
				CombatDirector.release_token(e)
				return "Wait"
	return ""


## El círculo en el suelo. Un disco plano, no un anillo: relleno se ve de un
## vistazo dónde NO hay que estar, que es lo único que hace falta entender.
func _pintar_el_aviso() -> void:
	var e := actor as Enemy
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(1.0, 0.42, 0.52, 0.30)
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Sin escribir en profundidad y un pelo levantado: si no, se pelea con el
	# suelo y sale a rayas.
	_material.no_depth_test = false
	_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED

	var malla := CylinderMesh.new()
	malla.top_radius = RADIO
	malla.bottom_radius = RADIO
	malla.height = 0.06
	malla.radial_segments = 28

	_marca = MeshInstance3D.new()
	_marca.mesh = malla
	_marca.material_override = _material
	_marca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	e.get_parent().add_child(_marca)
	_marca.global_position = e.global_position + Vector3.UP * 0.06
	_marca.scale = Vector3(0.05, 1.0, 0.05)


func _crecer_el_aviso(t: float) -> void:
	if _marca == null or not is_instance_valid(_marca):
		return
	var e := actor as Enemy
	_marca.global_position = e.global_position + Vector3.UP * 0.06
	# Arranca de golpe y frena al final: así se ve enseguida de qué tamaño va a
	# ser, en vez de enterarte del alcance justo cuando ya es tarde.
	var crecido := 1.0 - pow(1.0 - t, 2.4)
	_marca.scale = Vector3(maxf(crecido, 0.05), 1.0, maxf(crecido, 0.05))
	if _material != null:
		_material.albedo_color.a = 0.22 + 0.30 * t


## Durante el impacto, la caja de golpe del guardián pasa a ser un círculo a su
## alrededor. Se reutiliza la suya en vez de montar otra área: así el golpe pasa
## por el mismo sitio que todos los demás —invulnerabilidad, empujón, parpadeo—
## y no hay una segunda forma de hacer daño que se comporte distinto.
func _agrandar_la_caja() -> void:
	var e := actor as Enemy
	var forma := _caja_del_golpe()
	if forma == null:
		return
	_forma_guardada = forma.shape
	_sitio_guardado = forma.position
	var cilindro := CylinderShape3D.new()
	cilindro.radius = RADIO
	cilindro.height = 3.0
	forma.shape = cilindro
	# El nodo del golpe cuelga metro y medio POR DELANTE del guardián, que es
	# donde tiene que estar para un puñetazo. Para el círculo hay que traerlo al
	# centro, o el área saldría descentrada y pillaría a quien esté detrás de él
	# y no a quien tenga al lado.
	_sitio_guardado = e.hitbox.position
	e.hitbox.position = Vector3(0.0, 1.0, 0.0)


func _devolver_la_caja() -> void:
	if _forma_guardada == null:
		return
	var e := actor as Enemy
	var forma := _caja_del_golpe()
	if forma != null:
		forma.shape = _forma_guardada
	if e.hitbox != null:
		e.hitbox.position = _sitio_guardado
	_forma_guardada = null


func _caja_del_golpe() -> CollisionShape3D:
	var e := actor as Enemy
	if e.hitbox == null:
		return null
	for hijo in e.hitbox.get_children():
		if hijo is CollisionShape3D:
			return hijo as CollisionShape3D
	return null
