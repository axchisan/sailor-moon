# Encargo: rendimiento

> **Para quien coja esta tarea.** El objetivo no es bajar la calidad: es que el
> juego se vea igual o mejor y vaya fluido en el móvil. Aquí está todo lo que ya
> se hizo, cómo se midió y por dónde seguir.

## El resumen, si solo se lee un párrafo

**El terreno ES el fotograma, y lo caro es que esté iluminado.** Medido en el
teléfono con la vista congelada: quitar el terreno rinde exactamente lo mismo que
quitar el mundo entero (+108 %, los dos topando con el vsync), y dejarlo donde
está pero sin iluminar rinde lo mismo también. En cambio quitarle el patrón
triplanar no mueve ni un fps, y un material que no hace nada pero SÍ está
iluminado sigue costando el 86 % de lo que costaba el shader completo. No es la
geometría, no es el patrón, no son las texturas: es pasar por la iluminación
sobre la superficie que ocupa media pantalla.

Con eso ya se ha ganado un **+25 %** quitándole al shader las dos muestras de
cubemap que hacía por píxel (`ambient_light_disabled`, ver
[`terreno.gdshader`](../src/level/terreno.gdshader)). El sitio de arranque pasó
de 35-44 fps a **57,7 jugando**. Lo que queda por ganar ahí —otro +108 %— está en
dejar el terreno sin iluminar del todo y pintarle la luz a mano, que es una
sesión entera porque hay que resolver antes las sombras.

### El teléfono con el que se mide

HONOR LGN-NX3 · Android 16 · Snapdragon (Adreno 619) · **1610×720**. Ocho núcleos,
11 GB. Es un gama media-baja de 2022, y ese es el aparato objetivo.

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

Y para hablar con él, [`tools/hablar_con_el_juego.py`](../tools/hablar_con_el_juego.py):

```bash
./tools/hablar_con_el_juego.py eval 'return Engine.get_frames_per_second()'
./tools/hablar_con_el_juego.py captura foto.png
./tools/hablar_con_el_juego.py banco tools/medir_rendimiento.gd --nodo MedirRendimiento
```

Existe porque el MCP de Godot **solo atiende al proceso que ha lanzado él**:
contra el juego del teléfono contesta «No active Godot process». Y `banco`
INYECTA el `.gd` en el juego en marcha en vez de cargarlo del APK, así que afinar
un banco de medición ya no cuesta una reexportación por iteración.

> ⚠️ **Un Godot en el Mac y el puente no caben a la vez.** Los dos quieren el
> 9090 de esta máquina. Si se va a probar en el Mac: `adb forward --remove-all`
> primero. Si no, el juego local no consigue escuchar, y lo peor es que las
> órdenes siguen funcionando —van al TELÉFONO— así que se está mirando el aparato
> equivocado sin enterarse. Pasó, y la pista fue que la captura salía a 1610×720.

### El calor no es un detalle, es parte de la medida

El teléfono **se estrangula solo**, y eso no es una metáfora: tras una hora de
pruebas seguidas, `dumpsys thermalservice` da `Thermal Status: 1` con las CPU
entre 53 y 61 °C. Y en ese estado el mismo sitio del mapa que daba **57,7 fps en
frío da 45**.

Es exactamente el síntoma que se describía como «hay zonas con muchos tirones» y
«el teléfono se recalienta»: no son zonas, es el rato que llevas jugando.

```bash
./tools/probar_en_movil.sh --temperatura
```

**Mirarlo antes de cualquier tanda que vaya a servir de referencia.** Dos
mediciones tomadas con el aparato a distinta temperatura no se pueden comparar, y
la diferencia (−22 %) es mayor que la mayoría de las optimizaciones que se van a
intentar.

### Las tres trampas de medir en un teléfono

Ninguna es obvia y las tres invalidan la tabla entera en silencio. Están
resueltas dentro de [`medir_rendimiento.gd`](../tools/medir_rendimiento.gd), pero
conviene conocerlas antes de escribir cualquier medición nueva.

1. **El vsync no se puede quitar.** Se pide y el driver responde «The requested
   V-Sync mode Disabled is not available». O sea que el techo son 60 fps pase lo
   que pase. Con la referencia a 40, cualquier mejora del 50 % marcaba «59,9» —
   quitar el terreno y quitar el decorado daban los dos «+47 %», que es el número
   que sale cuando los dos han topado con la pared. La salida es una **lupa**:
   subir la resolución de render hasta que la referencia caiga a ~30 fps, y así
   caben mejoras de hasta el doble antes de tocar el techo. Ojo al leer: la lupa
   multiplica el coste **por píxel** y no el de CPU ni el de llamadas de dibujado.
2. **El aparato no rinde igual dos minutos seguidos.** En el mismo sitio y sin
   tocar nada ha dado 35, 47 y 60 fps: gobernador de frecuencia y calentamiento.
   Esa deriva (±40 %) es más grande que casi todo lo que se quiere medir. La
   salida es **intercalar la referencia entre prueba y prueba** y comparar cada
   una con la de antes y la de después. La deriva pasó del 39 % al 1 %.
3. **Se mueve lo que no debería.** La primera tanda buena salió inservible: la
   jugadora se había desplazado once metros a mitad de medición —basta un roce en
   la pantalla, que está boca arriba sobre la mesa— y cada prueba miraba a otro
   sitio. **Se ve en los draw calls**, que saltaban de 52 a 156. Ahora el banco
   clava una cámara propia y congela el árbol, y si los draw calls no salen
   iguales en todas las filas, el número no vale.

### Las dos compilaciones

| Preset | APK | Para qué |
|---|---|---|
| `Android (depuracion)` | `export/sailor_moon_debug.apk` | medir, inspeccionar, logcat. Lleva permiso de red para el puente |
| `Android (final)` | `export/sailor_moon.apk` | lo que se le instala a la niña. Release, sin red, sin servidor |

Van **firmadas con la misma llave**, así que se instalan una encima de otra sin
desinstalar y sin perder las partidas guardadas. Antes había que desinstalar para
cambiar de una a otra, que es una forma tonta de borrarle el progreso a la niña.

La diferencia de rendimiento entre las dos está medida y es pequeña: ver §4 de
«por dónde seguir».

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

## Cuarta pasada: por dónde seguir, ya con números

Esto ya no son sospechas. Cada punto lleva detrás la medición que lo pone ahí.

### 1. Sacar el terreno del camino iluminado — vale otro +108 %

Es, con diferencia, lo que más queda por ganar, y está cuantificado: el mismo
terreno **sin iluminar** duplica los fps.

La forma de hacerlo es `render_mode unshaded` en
[`terreno.gdshader`](../src/level/terreno.gdshader) y pintarle la luz del sol a
mano: un `dot(normal, direccion_del_sol)` partido en dos o tres bandas. Para un
juego cel shaded eso además **se ve mejor**, no peor — una ladera con dos tonos
planos es más de anime que un degradado lambert.

**Lo que hay que resolver antes: las sombras.** Un material sin iluminar no las
recibe, y se perderían la de Serena sobre el camino y las de los cerezos sobre la
hierba, que son de lo que mejor se ve del parque. Dos ideas, y la segunda es la
buena:

- Una mancha oscura bajo la jugadora. Barato, pero se pierden las de los árboles.
- **Hornear las sombras de lo que no se mueve en la máscara del terreno.** Esa
  textura YA EXISTE y ya se usa para pintar el camino (1024 px, 25 cm por texel,
  ver la trampa 70): el decorador sabe dónde acabó cada árbol, así que puede
  dibujar su sombra ahí mismo al montar el nivel. Coste por fotograma: **cero**,
  porque es una lectura de textura que ya se estaba haciendo. Y para la jugadora
  —lo único que se mueve de verdad— una mancha.

Es una sesión entera y toca cosas delicadas, por eso va sola.

### 2. Los tirones sueltos

Con el sitio de arranque ya a 57,7 fps de media, lo que queda de molesto son los
picos: **4,6 % de fotogramas por encima de 20 ms, y alguno de 71 ms**. Una media
buena con un tirón cada dos segundos se juega peor que 45 fps clavados.

El banco de CPU dice que no es lógica de juego: a un cuarto de resolución el
teléfono se planta en el techo de 60 con **todo** corriendo, y apagar la
jugadora, a Luna, los bichos, la interfaz o los objetivos no cambia nada (p50 de
16,7 ms en todos los casos, que es justo el periodo del vsync). Pero el p99 se va
a 220 ms y el peor a 390.

Sospechoso principal: **compilación de shaders y pipelines la primera vez que se
ve cada material**. La caché viene activada, pero en un móvil recién instalado
está vacía. Encaja con «hay zonas con muchos tirones». **Se comprueba fácil:
medir la primera partida tras instalar y luego la segunda.** Si la segunda va
fina, la solución es tocar todos los materiales una vez durante la pantalla de
carga, no optimizar la zona.

### 3. El arranque: 18,6 s la primera vez, 1,9 s la segunda

Medido en el teléfono, del menú al nivel jugable:

| | Primera vez tras instalar | Segunda |
|---|---|---|
| Total | **18,6 s** | **1,9 s** |
| …de eso, montar el nivel | 7,25 s | 1,48 s |

Y el montaje por dentro, la primera vez frente a la segunda:

```
  malla del terreno         1325 ms  →   739 ms
  esperar a la física       5077 ms  →   111 ms   ← ¡45 veces!
  sembrar el decorado        743 ms  →   530 ms
```

**Los 11 segundos que no son montaje son cargar recursos en frío** —modelos,
animaciones, texturas— y desaparecen enteros la segunda vez. Y los 5 segundos de
«esperar a la física» tampoco eran física: `await get_tree().physics_frame` espera
un fotograma COMPLETO, y ese fotograma es el primero que dibuja el nivel recién
creado, con la caché de shaders vacía. Es el punto 2 otra vez, disfrazado.

O sea que de los 18,6 s, **unos 16 son coste de estrenar** y solo ~2,5 son trabajo
de verdad. Lo que hay que atacar:

- **Precalentar durante la pantalla de carga.** Es donde de verdad se gana.
- **La malla del terreno** (739 ms en caliente): consulta las 53 zonas elevadas
  por cada uno de sus 6.724 vértices, unas 356.000 comprobaciones. Con una
  rejilla, como ya hace el decorador con los huecos, se queda en nada.
- **La siembra** (530 ms): 1.996 props con rayo al suelo, más 541 que se colocan
  y se tiran por caer encima de otra cosa.

### 4. La compilación final NO era el problema — comprobado

Se midió, y el resultado es un no rotundo. Montaje del nivel en frío, mismo
teléfono, mismo sitio:

| | Depuración | Final (release) |
|---|---|---|
| Montaje total | 7.254 ms | **6.818 ms** (−6 %) |
| malla del terreno | 1.325 ms | 1.174 ms (−11 %) |
| sembrar el decorado | 743 ms | 622 ms (−16 %) |
| **esperar a la física** | 5.077 ms | **4.929 ms** (igual) |

O sea: la de release corre el GDScript entre un 11 y un 16 % más rápido, y **el
trozo que domina no se mueve nada** porque no es GDScript. Es una diferencia
real pero pequeña, y la conclusión que importa es la otra: **todo lo medido con
la compilación de depuración es representativo.** No hay que rehacer nada.

Las dos compilaciones van ahora **firmadas con la misma llave**, así que se
instalan una encima de otra sin desinstalar y **sin perder las partidas
guardadas**. Antes había que desinstalar para cambiar de una a otra, que es una
forma tonta de borrarle el progreso a la niña.

### 5. Los 15 segundos de arranque, desmenuzados

Es lo que de verdad se nota al jugar, y ya está medido del todo. Compilación
final, del toque en JUGAR a nivel montado, **segundo arranque** (o sea con la
caché de shaders ya escrita en disco):

```
  15,4 s  del toque a nivel jugable
   ├─  9,5 s  cargar recursos            ← modelos, animaciones, texturas, audio
   └─  5,9 s  montar el nivel
        ├─ 4,8 s  «esperar a la física»  ← ver abajo, no es física
        ├─ 0,6 s  malla del terreno
        └─ 0,5 s  sembrar el decorado
```

**Dos cosas se llevan el 93 %, y ninguna es lógica del juego.**

**Los 9,5 s de recursos se pagan en CADA arranque.** Dentro de una misma sesión,
volver a cargar el nivel cuesta 0,4 s —los recursos ya están en memoria— pero al
abrir la aplicación se cargan enteros otra vez. La escena del nivel arrastra a la
jugadora con su librería de 56 animaciones, tres enemigos, el guardián, Luna,
Mercury, la interfaz y los diálogos, y **todo eso se carga antes de empezar a
montar nada**. La idea evidente: cargarlo **mientras se ve el menú**, que está
ahí parado sin hacer nada, en vez de después de pulsar JUGAR.

**Los 4,8 s de «esperar a la física» no son física.** `await
get_tree().physics_frame` espera un fotograma COMPLETO, y ese es el primero que
dibuja el nivel recién creado. Dentro de una misma sesión ese mismo `await`
cuesta **111 ms**; entre arranques distintos vuelve a costar 4,8 s aunque la
caché de shaders esté escrita en disco. O sea que se paga **una vez por proceso**,
no una vez por instalación.

Eso apunta a la caché de *pipelines* de Vulkan, que Godot guarda al cerrar
limpiamente — y `am force-stop` mata el proceso sin dejarle guardar nada. **La
comprobación pendiente es salir del juego por las buenas y volver a entrar.** Si
entonces baja, la solución es asegurarse de que la caché se escribe; si no baja,
hay que precalentar los materiales durante la pantalla de carga.

Y hasta que eso se resuelva, la pantalla de carga **puede al menos no mentir**:
ahora la barra se queda clavada casi cinco segundos en el mismo sitio.

### 5. Lo que ha quedado descartado por medición

No volver a perseguirlos sin una medida nueva que lo justifique:

- **El contorno de los personajes** (*inverted hull*): +1 %. Se sospechaba que
  duplicar la geometría de cada personaje pesaba. No pesa.
- **El triplanar del terreno**: +4 %. Tres muestras de textura por píxel en media
  pantalla, y da igual.
- **Los personajes enteros**: +2 %.
- **El cielo**: +2 %. Ya está optimizado de la pasada anterior.
- **Las transparencias de las barreras de arena**: no se han medido todavía
  porque no hay ninguna en el sitio canónico. Pendiente, pero con la lección
  aprendida: medirlo antes de tocarlo.

## Lo que NO se puede tocar

- **Bajar la resolución.** Sigue descartado, pero **por el motivo correcto, que
  no era el que estaba escrito.** La trampa 63 decía que la interfaz y el texto
  se volvían ilegibles. Eso es falso: `scaling_3d_scale` en Godot escala **solo
  el búfer 3D**, y el 2D —el HUD, los corazones, los botones, todo el texto— se
  dibuja después a resolución nativa. Comprobado en el teléfono a 0,6: la
  interfaz sale idéntica de nítida (`docs/img/render/15_media_resolucion.png`).

  Lo que sí es verdad es la otra mitad: **el 3D se emborrona**, y en cel shading
  eso se nota más que en un juego fotográfico porque lo que define el estilo son
  los contornos duros. El usuario lo vio y lo rechazó, y esa es una decisión de
  aspecto, no un error.

  Aun así conviene tenerlo apuntado con su número, porque es la palanca más
  fuerte que existe: **a 0,6 el juego va a 60 fps clavados**. Y hay una versión
  menos borrosa sin probar — `scaling_3d_mode` con **FSR**, que reconstruye los
  bordes en vez de estirarlos. Si algún día hay que elegir entre 30 fps con
  tirones y una imagen un pelín más blanda, la prueba está a un parámetro.
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
