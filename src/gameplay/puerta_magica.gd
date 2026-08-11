extends Node3D
class_name PuertaMagica
## Cortina de energía que corta el paso hasta que se cumple algo.
##
## En el Nivel 1 tapa la entrada del guardián hasta que los tres faroles están
## encendidos. Es lo que convierte «hay tres faroles por ahí» en un objetivo:
## sin algo que se abra al terminar, encenderlos no significa nada.
##
## Se ve **a través** a propósito. Una pared opaca parece el final del nivel;
## una cortina translúcida deja ver que hay algo más allá y que falta abrirla.

signal abierta

@export var ancho: float = 9.0
@export var alto: float = 3.6
@export var color: Color = Color(0.72, 0.55, 1.0, 0.35)
## Cuántos segmentos verticales. Más = más suave y más draw calls.
@export var segmentos: int = 5

## Qué falta para que se abra, en una frase.
##
## LO QUE DICE IMPORTA MÁS DE LO QUE PARECE
##
## Una puerta cerrada sin explicación manda a la jugadora a dar vueltas hasta que
## se cansa. Y el aviso tiene que decir **qué falta**, no que no se puede pasar:
## «Faltan 2 faroles por encender» manda a jugar, «no puedes pasar» manda a
## irse. A los ocho años esa diferencia es toda la diferencia.
##
## Lo rellena quien lleve la cuenta —en el Nivel 1, `nivel.gd` con los faroles—
## porque la puerta no tiene por qué saber de qué va el objetivo.
@export var pista: String = ""
## A qué distancia se avisa.
@export var radio_aviso: float = 5.5
## Cada cuánto se repite el aviso, para no ser pesada.
@export var repetir_aviso: float = 6.0

var esta_abierta: bool = false

var _cuerpo: StaticBody3D = null
var _material: StandardMaterial3D = null
var _tiempo: float = 0.0
var _proximo_aviso: float = 0.0


func _ready() -> void:
	_construir()
	_montar_detector()


## Área que avisa al acercarse. Se monta por código para que colocar una puerta
## siga siendo poner el nodo y nada más.
func _montar_detector() -> void:
	var zona := Area3D.new()
	zona.name = "ZonaAviso"
	zona.collision_layer = 0
	zona.collision_mask = 2
	var forma := CollisionShape3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = radio_aviso
	forma.shape = esfera
	zona.add_child(forma)
	zona.body_entered.connect(_al_acercarse)
	add_child(zona)


func _al_acercarse(cuerpo: Node3D) -> void:
	if esta_abierta or pista.is_empty():
		return
	if not cuerpo.is_in_group("player"):
		return
	# Con enfriamiento: entrar y salir del área tres veces seguidas no tiene por
	# qué soltar el mismo cartel tres veces.
	var ahora := Time.get_ticks_msec() / 1000.0
	if ahora < _proximo_aviso:
		return
	_proximo_aviso = ahora + repetir_aviso
	EventBus.show_message.emit(pista, 3.0)


func _process(delta: float) -> void:
	if esta_abierta or _material == null:
		return
	# Latido lento: una barrera quieta se lee como pared del escenario, y así
	# se entiende que es algo que se puede quitar.
	_tiempo += delta
	var pulso := 0.75 + 0.25 * sin(_tiempo * 2.2)
	_material.emission_energy_multiplier = 0.5 * pulso


func _construir() -> void:
	_material = StandardMaterial3D.new()
	_material.albedo_color = color
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.emission_enabled = true
	_material.emission = color
	_material.emission_energy_multiplier = 0.5

	_cuerpo = StaticBody3D.new()
	_cuerpo.name = "Cuerpo"
	_cuerpo.collision_layer = 1
	_cuerpo.collision_mask = 0
	add_child(_cuerpo)

	var ancho_seg := ancho / float(segmentos)
	var malla := BoxMesh.new()
	malla.size = Vector3(ancho_seg * 0.94, alto, 0.18)
	for i in segmentos:
		var visual := MeshInstance3D.new()
		visual.mesh = malla
		visual.material_override = _material
		visual.position = Vector3(
			-ancho * 0.5 + ancho_seg * (float(i) + 0.5), alto * 0.5, 0.0)
		_cuerpo.add_child(visual)

	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(ancho, alto, 0.4)
	forma.shape = caja
	forma.position.y = alto * 0.5
	_cuerpo.add_child(forma)
	set_process(true)


func abrir() -> void:
	if esta_abierta:
		return
	esta_abierta = true
	set_process(false)

	# Se retira hacia arriba desvaneciéndose. Desaparecer de golpe deja la duda
	# de si se ha abierto o si ha fallado algo.
	var t := create_tween().set_parallel(true)
	t.tween_property(_cuerpo, "position:y", alto * 1.2, 0.55) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_property(_material, "albedo_color:a", 0.0, 0.55)
	t.chain().tween_callback(func() -> void:
		_cuerpo.visible = false
		for hijo in _cuerpo.get_children():
			if hijo is CollisionShape3D:
				(hijo as CollisionShape3D).set_deferred("disabled", true)
		abierta.emit()
	)
