# Encargo: rendimiento

> **Para quien coja esta tarea.** El objetivo no es bajar la calidad: es que el
> juego se vea igual o mejor y vaya fluido en el móvil. Aquí está todo lo que ya
> se hizo, cómo se midió y por dónde seguir.

## El aparato de medida ya existe: úsalo

**No optimices por corazonada.** Este proyecto ya perdió una tanda entera
atacando la geometría cuando el cuello estaba en los píxeles, y solo se vio al
medir.

- **`F8` — banco de pruebas** ([`modo_desarrollador.gd`](../src/core/modo_desarrollador.gd)).
  Apaga **una cosa cada vez**, siempre desde el juego completo, y se anota qué
  hacen los fps en cada paso. Lo que más suba es lo que más costaba.
- **En el móvil, y de pie en el mismo sitio.** En el Mac todo va a 60 y el
  problema no existe; el número cambia mucho según a dónde mires.
- **`F1`** abre el panel con fps, draw calls y triángulos. En el móvil: tres
  toques en la esquina superior izquierda.
- **`F9`** copia el informe entero al portapapeles.
- **`F10`** salta directo al jefe, que es la escena más cara.

La prueba de **media resolución** no es una opción de calidad —está descartada
por la trampa 63— sino la pregunta decisiva: si al bajarla los fps se disparan,
lo caro es pintar píxeles; si no se mueven, el cuello está en la CPU y no sirve
de nada tocar shaders ni sombras.

## Lo que ya se hizo, para no repetirlo

### Primera pasada — geometría

De 28-35 fps a ~45. El hallazgo que lo ordenó todo fue **separar pantalla de
sombra en el contador**: sumados no decían nada, separados salió que el pase de
sombra costaba casi el triple que la imagen.

1. **Sombras**: de cuatro cascadas a una, alcance de 55 a 24 m, sin sombra en el
   detalle menudo. Quitó 230.000 triángulos
2. **Descarte por frustum**: las multimallas se trocean en parcelas de 70 m.
   Antes cada una tenía una caja que cubría el mapa y no se descartaba nunca
3. **Descarte por oclusión**: cada muro lleva su `OccluderInstance3D`
4. **LOD por distancia** y **LOD de malla** en los cerezos
5. **Menos polígonos en origen**: el decorado bajó de 489.000 a 277.000

### Segunda pasada — píxeles, que era lo que de verdad costaba

De 37-45 fps a **60 en la mayoría de sitios**. Todo esto solo se aplica en el
móvil (`_ajustar_para_el_movil()` en [`nivel.gd`](../src/level/nivel.gd)); en el
PC no se toca nada.

| Qué | Por qué |
|---|---|
| **FXAA fuera** | El más caro de todo lo medido. Relee el fotograma entero varias veces por píxel, y en una GPU de móvil el ancho de banda es el recurso escaso |
| **Niebla cambiada** por la perspectiva aérea que el terreno **ya calculaba** en su shader | La del `Environment` se evalúa en cada píxel de cada material |
| **Sombra de 24 a 18 m** | Se acorta, no se quita |
| **Ajuste de color horneado** en la paleta al cargar | Aplicado al fotograma obliga a releer la pantalla entera, y una GPU por tiles tiene que volcar el búfer a memoria y traérselo de vuelta |
| **Ruido de los shaders sin `sin()`** | El cielo hacía 32 senos por píxel; el terreno, 28 evaluaciones de ruido. Ahora es una textura horneada |

**La regla fue limitar, no eliminar.** Cada recorte deja el efecto con menos
alcance o lo cambia por otro más barato que hace lo mismo donde se nota. Lo único
que se apagó del todo fue el FXAA, porque de ese no hay versión barata.

## Por dónde seguir

Sin medir primero, esto son sospechas ordenadas por lo que más probablemente
pese — **no una lista de tareas**:

1. **El montaje del nivel bloquea el hilo principal.** El `_ready()` genera
   terreno, siembra 1.863 props, trocea multimallas y construye el blockout de
   una vez. Ya hay pantalla de carga que lo tapa, pero **repartirlo entre
   fotogramas** quitaría el tirón de verdad.
2. **Transparencias solapadas.** Las barreras de arena son anillos de paneles
   translúcidos: mirando a través se pintan dos veces, y el overdraw es de lo
   más caro en móvil. Se ve muy opaco desde fuera, que es el síntoma.
3. **Luces.** Cada farol encendido, cada corazón y cada punto de guardado lleva
   su `OmniLight3D`. En el renderizador móvil las luces por píxel se acumulan.
4. **El guardián**: 25.000 triángulos y 19 huesos con `no_depth_test` en la
   flecha guía y en el aviso de área.
5. **Físicas**: nueve repechos, ~112 losas y todos los props con colisión.

## Lo que NO se puede tocar

- **Bajar la resolución.** Descartado (trampa 63): la interfaz y el texto se
  vuelven ilegibles en un móvil, y esto lo va a jugar una niña de ocho años.
- **Quitar el ajuste de color.** Es lo que hace que el parque se vea vivo en vez
  de pálido. Se puede mover de sitio —ya se hizo—, no quitar.
- **El estilo cel shading (MToon).** Es la identidad visual del juego.
- **Los 60 fps como objetivo.** 30 estables es preferible a 45 con tirones, pero
  la referencia es 60.

## Dónde está cada cosa

| Qué | Archivo |
|---|---|
| Recortes de móvil | [`nivel.gd`](../src/level/nivel.gd) → `_ajustar_para_el_movil()` |
| Banco de pruebas | [`modo_desarrollador.gd`](../src/core/modo_desarrollador.gd) |
| Terreno y su shader | `src/level/terreno_nivel.gd`, `src/level/terreno.gdshader` |
| Siembra del decorado | [`decorador_nivel.gd`](../src/level/decorador_nivel.gd) |
| Cielo | `src/level/cielo_anime.gdshader` |
| Presupuestos y objetivos | [`01-ARQUITECTURA.md`](01-ARQUITECTURA.md) |

Y **[`ESTADO.md`](ESTADO.md) §6, «trampas ya pisadas»**: cien entradas de cosas
que ya fallaron una vez. Merece la pena leerlo antes de tocar nada.
