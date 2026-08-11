extends State
## Subir desde el canto hasta ponerse de pie encima.
##
## CÓMO SE MUEVE
##
## La posición se INTERPOLA a mano desde donde se estaba colgada hasta el punto
## de arriba, y no se deja a la física ni a la animación:
##
##   · La animación de Mixamo trae su propio desplazamiento, pero al anclarle la
##     cadera para que no se sumara con la física (ver
##     `construir_libreria_animaciones.gd`) ese desplazamiento ya no está.
##   · Y dejárselo a la física obligaría a empujar contra la pared confiando en
##     que la cápsula suba por el borde, que es justo el tipo de cosa que
##     funciona en el sitio donde se prueba y falla en los otros veinte.
##
## Interpolando, el recorrido es el mismo siempre y termina exactamente encima
## del canto.
##
## LA CURVA NO ES RECTA
##
## Primero se sube y luego se avanza, que es como se trepa de verdad: en línea
## recta el personaje entra en diagonal atravesando la esquina del muro. La
## componente vertical va por delante de la horizontal.

## Lo que tarda en subir. Más lento se hace pesado y más rápido no se ve.
const DURACION := 0.75
## Cuánto se mete hacia dentro pasado el canto, para no quedarse en el filo.
const ADENTRO := 0.55
## Cuánto sube: exactamente lo que bajó al agarrarse (`AGARRE_ALTO` de
## `ledge_grab.gd`). Con siete centímetros de más terminaba por encima del canto
## y caía a plomo nada más subir, con su aterrizaje y todo.
const SUBIDA := 1.55

var _tiempo := 0.0
var _desde := Vector3.ZERO
var _hasta := Vector3.ZERO


func enter(_msg: Dictionary = {}) -> void:
	var p := actor as Player
	_tiempo = 0.0
	p.velocity = Vector3.ZERO
	_desde = p.global_position
	# El destino: sobre el canto y un poco hacia dentro, en la dirección a la
	# que mira el personaje (que en el agarre se dejó mirando a la pared).
	var frente := -p.model.global_transform.basis.z
	frente.y = 0.0
	frente = frente.normalized()
	_hasta = _desde + Vector3.UP * SUBIDA + frente * ADENTRO
	p.play("ledge_climb", DURACION)


func physics_update(delta: float) -> String:
	var p := actor as Player
	_tiempo += delta
	var t := clampf(_tiempo / DURACION, 0.0, 1.0)

	# Vertical por delante de horizontal: se sube y DESPUÉS se entra. Con las
	# dos a la vez se atraviesa la esquina del muro en diagonal.
	var subida := clampf(t / 0.65, 0.0, 1.0)
	var avance := clampf((t - 0.45) / 0.55, 0.0, 1.0)
	p.velocity = Vector3.ZERO
	p.global_position = Vector3(
		lerpf(_desde.x, _hasta.x, smoothstep(0.0, 1.0, avance)),
		lerpf(_desde.y, _hasta.y, smoothstep(0.0, 1.0, subida)),
		lerpf(_desde.z, _hasta.z, smoothstep(0.0, 1.0, avance)))

	if t >= 1.0:
		if p.get_move_direction().length_squared() > 0.0001:
			return "Move"
		return "Idle"
	return ""
