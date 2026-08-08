# Animaciones que faltan — qué bajar de Mixamo

> Ampliación de [`08-ANIMACIONES-MIXAMO.md`](08-ANIMACIONES-MIXAMO.md), que
> explica el proceso. Esto es **la lista de la compra** para las mecánicas
> nuevas del [plan maestro](15-PLAN-MAESTRO.md).

## Lo primero: solo hay que bajarlas UNA vez

El auto-rigger de Mixamo le pone **el mismo esqueleto a todos** los personajes.
Por eso el proyecto carga una única librería (`serena_animaciones.res`) y la
usan Serena, Mercury y las demás.

**No hace falta subir a Mercury para tener sus animaciones.** Se sube un
personaje cualquiera —el que ya esté subido vale— y lo que se descargue sirve
para las once. Si alguna vez hace falta un gesto exclusivo de alguien, se baja
igual y se le pone nombre propio; pero de momento, todo es común.

## Ajustes de descarga

Los mismos de siempre, sin cambiarlos:

- **Formato:** FBX Binary
- **FPS:** 30
- **Keyframe Reduction:** none
- **In Place:** activado en TODAS (menos `idle`, que ya está bajada)

Sin *In Place*, la animación arrastra al personaje por el suelo y pelea con el
movimiento del juego.

## Dónde dejarlas

En `assets/animations/serena/`, con **exactamente** el nombre de la tabla. El
nombre es lo que las conecta con el código; si no coincide, no se enteran.

---

## Tanda 1 — Salto y doble salto (prioritaria)

El salto actual se ve raro porque es una sola animación haciendo tres trabajos.
Se parte en piezas:

| Nombre del archivo | Qué buscar en Mixamo | Para qué |
|---|---|---|
| `jump_start.fbx` | `jump` → el impulso, solo la subida | Sustituye la actual. Corta, la salida del suelo |
| `jump_loop.fbx` | `falling idle` | Se repite mientras cae |
| `land.fbx` | `falling to landing` o `hard landing` | El aterrizaje |
| `double_jump.fbx` | `front flip` / `air spin` / `flip` | **Nueva.** El segundo salto, con giro |

Del doble salto: busca `flip` y quédate con una de **medio segundo o menos**,
que gire hacia adelante y termine de pie. Las de acrobacia larga no valen —
mientras dura la voltereta no se controla al personaje y se siente pesado.

## Tanda 2 — Trepar cornisas (prioritaria)

Lo más vistoso de todo lo que has pedido, y lo que más cambia cómo se lee el
mundo: un saliente deja de ser un muro y pasa a ser un camino.

| Nombre del archivo | Qué buscar | Para qué |
|---|---|---|
| `ledge_grab.fbx` | `hanging idle` o `braced hang` | Colgada del borde, quieta |
| `ledge_climb.fbx` | `climbing up` / `climb to top` / `braced hang to crouch` | Sube y se pone de pie |

Que las dos **empiecen y acaben en poses parecidas**: la de subir tiene que
arrancar donde termina la de colgarse, o se ve un salto entre las dos.

Ojo con la altura: Mixamo las hace para un borde a cierta altura del suelo. Al
bajarla, mira en el visor a qué altura queda la mano y dímelo — con eso ajusto
la detección para que la mano caiga en el borde de verdad y no en el aire.

## Tanda 3 — Conversación

Ya está bajada `talk_idle.fbx`, pero **no está conectada**. Con estas se puede
actuar de verdad:

| Nombre del archivo | Qué buscar | Cuándo se usa |
|---|---|---|
| `talk_idle.fbx` | ✅ ya la tienes | Bucle base mientras habla |
| `talk_gesture.fbx` | `talking` (la que mueve más las manos) | Frases con énfasis |
| `nod.fbx` | `head nod yes` | Decir que sí, estar de acuerdo |
| `shake_head.fbx` | `head shake no` | Negar, dudar |
| `point.fbx` | `pointing` | Señalar algo o a alguien |
| `surprised.fbx` | `surprised` / `reaction` | «¡Hay alguien ahí!» |
| `thinking.fbx` | `thinking` | Mercury explicando |

Estas son cortas y baratas. Cuantas más haya, menos se repite la conversación,
que es lo que más cansa de un juego con diálogo.

## Tanda 4 — Transformación

La actual no da la sensación de transformación. Busca en Mixamo:

- `magic spell` / `casting spell` — el gesto de invocar
- `praying` — más recogido, sirve para el arranque
- `standing up to action` — el momento de decisión

| Nombre del archivo | Qué buscar | Para qué |
|---|---|---|
| `transform_start.fbx` | `praying` o `standing idle to action` | Alza el broche |
| `transform_pose.fbx` | `magic spell` o pose de victoria vistosa | La pose final. Ya tienes una: cámbiala si encuentras mejor |

Bájate **dos o tres candidatas** de la pose final y las vemos en el juego. Esta
es de las que hay que ver en marcha para decidir; en el visor de Mixamo todas
parecen buenas.

---

## Orden recomendado

1. **Tanda 1** (salto) — desbloquea el doble salto, que es puro gusto de jugar
2. **Tanda 2** (trepar) — la que más cambia el diseño de nivel
3. **Tanda 3** (conversación) — arregla lo de Mercury saltando de golpe a alerta
4. **Tanda 4** (transformación) — la más de gusto personal, mándame varias

Con la tanda 1 y 2 dentro ya puedo montar la Fase E entera. Las otras dos van
con la Fase F.

## Cuando las tengas

Déjalas en `assets/animations/serena/` y dímelo. Yo me encargo de:

- Reconstruir la librería compartida
- Añadir los estados nuevos a la máquina de animación
- Conectar las mecánicas (doble salto, agarre de cornisa)
- Ajustar los tiempos de mezcla

No hace falta que toques nada de Godot.
