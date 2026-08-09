extends GPUParticles3D
## Estallido de partículas **reutilizable**.
##
## Antes se instanciaba uno por impacto y se autodestruía. En un beat 'em up eso
## se dispara decenas de veces por segundo, y cada disparo hacía tres cosas
## caras: instanciar la escena, **duplicar el material de proceso** —que obliga
## a subir un material nuevo a la GPU— y liberar el nodo. Era el tirón que se
## notaba al coger una Estrella y al pelear.
##
## Ahora hay una reserva fija que monta `CombatFeel` al arrancar el nivel. Cada
## emisor duplica su material **una sola vez**, en `_ready`, y a partir de ahí
## solo se le cambian los valores. Emitir pasa a ser gratis.

var _ajustes: ParticleProcessMaterial = null


func _ready() -> void:
	one_shot = true
	emitting = false
	# El material se duplica aquí y solo aquí: si se duplicara en cada estallido
	# volvería el problema, y si no se duplicara, todos los emisores de la
	# reserva compartirían color y se pisarían entre ellos.
	var original := process_material as ParticleProcessMaterial
	if original != null:
		_ajustes = original.duplicate() as ParticleProcessMaterial
		process_material = _ajustes


## Lanza el estallido en un punto. El emisor se queda en la escena esperando al
## siguiente.
func burst(color: Color, count: int = 18, scale_factor: float = 1.0) -> void:
	amount = maxi(1, count)
	if _ajustes != null:
		_ajustes.color = color
		_ajustes.scale_min = 0.10 * scale_factor
		_ajustes.scale_max = 0.28 * scale_factor
		_ajustes.initial_velocity_min = 2.0 * scale_factor
		_ajustes.initial_velocity_max = 5.5 * scale_factor
	# Reiniciar antes de emitir: si el emisor venía de un estallido a medias,
	# `emitting = true` no lo reinicia por sí solo y salen partículas a destiempo.
	restart()
	emitting = true


## Se llama una vez al montar la reserva, para que el motor compile el shader y
## suba los recursos ANTES del primer golpe. Sin esto, el primer impacto de la
## partida sigue dando el tirón por mucha reserva que haya.
func precalentar() -> void:
	amount = 1
	restart()
	emitting = true
