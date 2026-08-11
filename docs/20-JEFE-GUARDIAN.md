# El Guardián del Portal

Cierre del Acto 1. Aparece cuando la lista de objetivos está completa y se
planta delante de la ruina: la puerta no se abre porque sí, se abre porque
alguien la deja abrir.

## El concepto

**Un guardián de piedra del propio portal.** Está hecho de la misma roca que la
ruina, con las mismas vetas y los mismos cristales rosados incrustados. Lleva
ahí desde antes que el parque, dormido, y lo que lo despierta es que alguien
haya reunido todo lo que hacía falta.

Que sea de la piedra del portal no es decoración: es lo que hace que verlo se
entienda sin una línea de diálogo. Si fuera un monstruo cualquiera, sería un
enemigo más y grande; siendo la puerta la que se levanta, es el último examen.

**No da miedo, impone.** Es para una niña de ocho años: nada de colmillos,
garras ni caras de rabia. La fuerza tiene que venir del tamaño, de lo despacio
que se mueve y de lo que pesa cada golpe — no de la cara. Ojos grandes y
tranquilos, de luz rosa. Un gigante serio, no un monstruo.

Musgo y florecitas en los hombros: llevaba tanto tiempo quieto que el parque le
creció encima. Eso, además de ser bonito, cuenta los siglos sin decirlos.

## El prompt para generar la imagen

Va en inglés, que es donde estos modelos aciertan más. Todo lo de la segunda
mitad son **requisitos del paso imagen → 3D**, no gustos: una imagen bonita con
la pose girada o con sombras duras da un modelo inservible.

```
Full-body character concept of a gentle stone guardian, front view, standing
straight in a symmetrical A-pose with arms held away from the body and hands
open, legs slightly apart, facing the camera directly.

Design: a large ancient guardian carved from pale weathered granite, broad
square shoulders, long heavy arms, short thick legs, no neck. Chunky simplified
anime style, soft rounded shapes, clean readable silhouette. Glowing rose-pink
crystals embedded in its chest, shoulders and knuckles, the same crystal as an
old stone gate. Carved crescent-moon motif on its chest. Soft green moss and
tiny pink flowers growing on its shoulders and forearms. Large calm glowing pink
eyes, no mouth, no teeth, no claws — serene and protective, not scary.
Cel-shaded cartoon rendering with flat pastel colors, thin dark outlines, minimal
shading, in the style of a stylized low-poly mobile game.

Plain flat light-gray background. Even soft frontal lighting, no cast shadows,
no rim light, no dramatic lighting. Entire body visible from head to feet with
margin around it, nothing cropped. No ground, no floor, no pedestal, no scenery,
no particles, no glow effects, no motion blur, no text, no watermark, no
multiple views, single character centered in frame.
```

### Variante, si el primero sale demasiado humano

Cambiar el bloque de diseño por:

```
Design: a floating guardian made of separated stone slabs held together by pink
light — a broad chest slab, two large detached fists hovering where hands would
be, a smooth carved head with no face except two glowing pink eyes, and a
tapering base instead of legs.
```

Se mueve mejor con menos huesos y da un jefe que flota, que pelea distinto a
todo lo del nivel.

## Qué mirar antes de pasarla a 3D

- **La pose.** Brazos despegados del cuerpo y manos abiertas. Si los brazos
  tocan el torso, el reconstructor los funde en un bloque y luego no hay forma
  de separarlos para animar.
- **Que no esté cortada.** Ni un dedo fuera del encuadre.
- **Sin sombras duras ni brillos.** El reconstructor las interpreta como
  relieve y salen bultos donde no los hay.
- **Fondo liso.** Cualquier cosa detrás acaba pegada al modelo.
- **Una sola vista.** Las láminas de «model sheet» con tres poses dan tres
  medio-modelos superpuestos.

## Cuando llegue el modelo

Va al mismo sitio que el resto: `Models/`, y de ahí a una escena en
`scenes/enemies/`. Escala de referencia: **2,6 m de alto** — Serena mide 1,6, y
esa proporción es la que lo hace leerse como jefe sin dejar de caber en la
arena.

Necesitará esqueleto para animar. Los reconstructores de imagen no lo dan, así
que toca ponérselo en Blender (Rigify o Mixamo).

## Lo que queda por decidir

Nada de esto bloquea el modelo — se puede ir haciendo mientras:

- Qué hace en la pelea. La idea de partida: **tres fases**, una por cada cosa
  que ya se sabe hacer (pegar, esquivar, saltar), para que el jefe sea el examen
  de lo aprendido y no una mecánica nueva de última hora.
- Que la barrera del claro se cierre al empezar, que para eso está puesta ya.
- Música propia. Es el único sitio del acto que la pide.
