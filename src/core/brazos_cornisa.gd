extends SkeletonModifier3D
class_name BrazosCornisa
## Dobla los brazos para que las manos alcancen el canto de la cornisa.
##
## POR QUÉ HACE FALTA
##
## La animación de colgarse de Mixamo (`Hanging Idle`) supone un personaje
## pegado a la pared, y el nuestro no puede estarlo del todo: la cápsula de
## colisión tiene 32 cm de radio y no se le puede meter dentro del muro. Se
## arrima el modelo lo que se puede sin que la cara entre en la piedra, pero con
## eso las manos se quedan a veinte centímetros del borde — agarrada al aire.
##
## No se arregla acercándola más: lo que sobra es el cuerpo, no los brazos. Lo
## que hace falta es que los brazos vayan HACIA el borde, que es lo que hace
## cualquiera al colgarse.
##
## POR QUÉ ES UN `SkeletonModifier3D`
##
## Porque tiene que escribir DESPUÉS de la animación. Poniendo la rotación a
## mano desde un `_process` la pisa el `AnimationTree` en cuanto avanza un
## fotograma, y desactivar el árbol para escribir devuelve el esqueleto a la
## pose de reposo — que en un rigueado de Mixamo es la T, así que en vez de
## brazos doblados sale una T con las manos donde no van. Un modificador se
## ejecuta en el sitio correcto de la cadena.
##
## Los ángulos están calibrados MIDIENDO dónde acaba el hueso de la mano
## respecto al canto, no a ojo.

## Los huesos a los que se les da el empujón, y en qué sentido.
##
## El signo va al revés en cada brazo: el rig de Mixamo es simétrico, así que lo
## que en el izquierdo acerca la mano a la pared, en el derecho la aleja.
const BRAZOS := {
	"mixamorig_LeftArm": 1.0,
	"mixamorig_RightArm": -1.0,
}

## Cuánto se doblan. A 0 no hace nada y el modificador se puede dejar puesto.
@export var grados: float = 25.0
## Se enciende solo mientras se está colgada.
@export var activo: bool = false


func _process_modification() -> void:
	if not activo or is_zero_approx(grados):
		return
	var esqueleto := get_skeleton()
	if esqueleto == null:
		return
	for hueso: String in BRAZOS:
		var indice := esqueleto.find_bone(hueso)
		if indice < 0:
			continue
		# Se COMPONE sobre lo que dejó la animación, no se sustituye: así el
		# gesto de colgarse se conserva y esto solo lo corrige.
		var pose := esqueleto.get_bone_pose_rotation(indice)
		var giro := Quaternion(Vector3(0.0, 0.0, 1.0),
			deg_to_rad(grados) * float(BRAZOS[hueso]))
		esqueleto.set_bone_pose_rotation(indice, pose * giro)
