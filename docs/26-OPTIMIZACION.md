# Encargo: rendimiento

> **Para quien coja esta tarea.** El objetivo no es bajar la calidad: es que el
> juego se vea igual o mejor y vaya fluido en el móvil. Aquí está todo lo que ya
> se hizo, cómo se midió y por dónde seguir.

## ⚠️ Lo primero: EL MAC NO PUEDE MEDIR ESTO. Está comprobado

No es que en el Mac «se note menos». Es que **el Mac no llega a enterarse de que
hay un problema**, y cualquier número sacado aquí es ruido. Medido con
[`tools/medir_rendimiento.gd`](../tools/medir_rendimiento.gd) y
[`tools/medir_cpu.gd`](../tools/medir_cpu.gd) sobre el Nivel 1, a 1280×720, en un
M5:

| Prueba | fps |
|---|---|
| El juego entero, tal cual | ~180 |
| **Sin dibujar NADA en 3D** (sin terreno, sin decorado, sin personajes, sin cielo) | **~156** |

Quitar el mundo entero **no sube los fps**. Y por el otro lado, el reparto de
tiempo de CPU da una mediana de **2 ms por fotograma**, con los subsistemas
—jugadora, Luna, bichos, interfaz, objetivos— aportando cada uno una décima.

Las dos cosas a la vez significan que aquí no manda ni la GPU ni el juego: manda
el compositor de macOS y el ruido de medición. Repetir la misma prueba dos veces
seguidas da 182 y 138 fps. **Con esa dispersión no se puede atribuir nada a
nada.**

De ahí sale la regla, que ya estaba escrita pero ahora tiene número detrás: **si
la medida no viene del teléfono, no es una medida.** Lo que sí se puede hacer en
el Mac es lo visual —ver un color, un halo, un contorno— y eso es exactamente lo
que se hizo en [`27-CALIDAD-VISUAL.md`](27-CALIDAD-VISUAL.md).

### Medir EN EL TELÉFONO, desde el Mac

Se conecta por USB y se maneja desde aquí. Un solo comando:

```bash
./tools/probar_en_movil.sh              # compila, instala, arranca, abre el puente
./tools/probar_en_movil.sh --final      # con la compilación de release
./tools/probar_en_movil.sh --registro   # y engancha el logcat
```

Lo que hace por dentro, y por qué importa: el juego lleva un servidor
(`McpInteractionServer`) que escucha en el puerto 9090 y acepta órdenes. En el
móvil escucha igual, solo que en el 9090 **del teléfono**. `adb forward` hace que
el 9090 de esta máquina sea el del móvil, y a partir de ahí **todo lo que se sabe
hacer contra el juego del Mac vale contra el del móvil**: ejecutar código dentro,
sacar capturas, y lanzar los dos bancos de medición. Se mide en el aparato que
tiene el problema.

Requisitos en el teléfono, una vez: cable de datos, Ajustes → Información → siete
toques en «Número de compilación», y Opciones de desarrollador → Depuración por
USB. El script avisa con instrucciones si no encuentra ninguno.

### Y ojo: hasta ahora se estaba probando la compilación de DEPURACIÓN

El APK se exportaba con `--export-debug`. Esa compilación lleva el depurador
dentro, las comprobaciones de GDScript activadas y el servidor MCP corriendo. Es
**más lenta que la de release**, y en un juego donde el escenario entero se genera
desde GDScript esa diferencia no es pequeña.

Ahora hay dos presets:

| Preset | APK | Para qué |
|---|---|---|
| `Android (depuracion)` | `export/sailor_moon_debug.apk` | medir, inspeccionar, logcat. Lleva permiso de red para el puente |
| `Android (final)` | `export/sailor_moon.apk` | lo que se le instala a la niña. Release, firmado, sin red |

**Antes de perseguir un fallo de rendimiento, comprobar cuánto de él era el
andamio.** Es la primera medición que hay que hacer en cuanto haya teléfono.

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

## Tercera pasada: por dónde seguir

**El orden de esta lista no es negociable: los dos primeros son mediciones, no
arreglos.** Este proyecto ya perdió una tanda entera optimizando por corazonada
(trampa 66), y el apartado de arriba explica por qué el Mac no puede corregir esa
corazonada.

### 0. Medir la compilación final contra la de depuración

Una sola tarde, dos APK, el mismo sitio del mapa. Puede que una parte del
problema sea andamio y no juego. Hasta saberlo, cualquier optimización se está
midiendo contra un suelo falso.

### 1. Rehacer el banco de pruebas EN EL MÓVIL

`tools/medir_rendimiento.gd` y `tools/medir_cpu.gd` corren igual allí a través del
puente. Salen dos tablas: qué cuesta pintar y qué cuesta pensar. **Sin esas dos
tablas, todo lo de abajo son sospechas.**

La pregunta que decide el resto: en la prueba de **media resolución**, ¿se
disparan los fps?

- **Sí** → el cuello son los píxeles. Toca shaders, transparencias y overdraw.
- **No** → el cuello es la CPU. Toca GDScript, física y número de nodos.

(Bajar la resolución **no es una opción de calidad** aquí: está descartada por la
trampa 63. Es solo el termómetro.)

### 2. Las sospechas, ordenadas por lo que probablemente pese

Con el sobrecalentamiento como pista extra: un móvil que se calienta está
trabajando de verdad y sostenidamente, y además **se autolimita** — de ahí que
haya zonas donde los tirones aparecen a los minutos y no al entrar.

1. **El montaje del nivel bloquea el hilo principal.** El `_ready()` genera
   terreno, siembra 1.999 props, trocea 158 multimallas y construye el blockout
   de una vez. Ya hay pantalla de carga que lo tapa, pero **repartirlo entre
   fotogramas** quitaría el tirón de verdad — y es también la respuesta a «por
   qué tarda tanto en arrancar desde el menú».
2. **El contorno de los personajes cuesta el doble de geometría.** El *inverted
   hull* dibuja cada malla otra vez. El guardián son 25.000 triángulos que pasan
   a 50.000, y en una arena hay varios personajes a la vez. Medir si conviene
   quitarle el contorno a los enemigos lejanos por distancia.
3. **Transparencias solapadas.** Las barreras de arena son anillos de paneles
   translúcidos: mirando a través se pintan dos veces, y el *overdraw* es de lo
   más caro en móvil. Se ve muy opaco desde fuera, que es el síntoma.
4. **Luces.** Cada farol encendido, cada corazón y cada punto de guardado lleva
   su `OmniLight3D`. En el renderizador móvil las luces por píxel se acumulan.
5. **Físicas**: nueve repechos, ~112 losas y todos los props con colisión.
6. **1.999 props sembrados, y 541 descartados por caer encima de otra cosa.**
   Merece una mirada aparte: sembrar y tirar es trabajo de carga, y 1.999 props
   en 180 llamadas de dibujado es mucho reparto.

### 3. Lo que ya se ganó de camino, sin tocar rendimiento

La pasada de calidad de imagen ([`27-CALIDAD-VISUAL.md`](27-CALIDAD-VISUAL.md))
apagó la niebla del `Environment` en las dos plataformas, porque hacía lo mismo
que la perspectiva aérea del terreno. La niebla se evalúa **en cada píxel de cada
material**; la perspectiva aérea ya se calculaba dentro de un shader que se
ejecuta igualmente. O sea que además de verse mejor, se pinta menos.

Y `docs/` salió del APK con un `.gdignore`: eran 8,7 MB de capturas de
documentación importándose como texturas del juego.

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
| **Probar en el móvil desde el Mac** | [`tools/probar_en_movil.sh`](../tools/probar_en_movil.sh) |
| **Banco automático de render** | [`tools/medir_rendimiento.gd`](../tools/medir_rendimiento.gd) |
| **Banco automático de CPU** | [`tools/medir_cpu.gd`](../tools/medir_cpu.gd) |
| Recortes de móvil | [`nivel.gd`](../src/level/nivel.gd) → `_ajustar_para_el_movil()` |
| Banco de pruebas a mano (F8) | [`modo_desarrollador.gd`](../src/core/modo_desarrollador.gd) |
| Calidad de imagen y color | [`27-CALIDAD-VISUAL.md`](27-CALIDAD-VISUAL.md) |
| Terreno y su shader | `src/level/terreno_nivel.gd`, `src/level/terreno.gdshader` |
| Siembra del decorado | [`decorador_nivel.gd`](../src/level/decorador_nivel.gd) |
| Cielo | `src/level/cielo_anime.gdshader` |
| Presupuestos y objetivos | [`01-ARQUITECTURA.md`](01-ARQUITECTURA.md) |

Y **[`ESTADO.md`](ESTADO.md) §6, «trampas ya pisadas»**: cien entradas de cosas
que ya fallaron una vez. Merece la pena leerlo antes de tocar nada.
