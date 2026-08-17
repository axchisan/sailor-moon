# Calidad de imagen: por qué se veía pálido y de dónde salía el aura blanca

> Documento hermano de [`26-OPTIMIZACION.md`](26-OPTIMIZACION.md). Aquel va de
> que el juego **corra**; este de que se **vea**. Se separan porque casi todo lo
> que hay aquí sale gratis: son valores mal puestos, no efectos caros.

## El antes y el después

| Antes | Después |
|---|---|
| ![antes](img/render/01_antes.png) | ![después](img/render/09_despues.png) |

Mismo sitio, misma cámara, mismo contenido. No se ha añadido ni un triángulo ni
un efecto nuevo: lo único que cambia son seis números que estaban mal.

De cerca, con el cel shading ya legible:

![de cerca](img/render/10_cerca.png)

---

## 1. El aura blanca alrededor de los personajes

**Lo que se veía:** un halo claro pegado a la silueta de Serena, de Luna y de los
enemigos, como un delineado blanco por fuera del contorno negro. Se notaba más
contra el fondo oscuro y en los bordes del pelo y la falda.

**Lo que era:** la *luz de borde* (rim light) de MToon. Y la clave está en dónde
se suma. En [`mtoon_common.gdshaderinc`](../addons/Godot-MToon-Shader/mtoon_common.gdshaderinc),
línea 277:

```glsl
emission += mix(rim * (1.0 - _RimLightingMix), vec3(0), isOutline);
```

`EMISSION` en Godot es **luz propia**: no la apaga el sol, ni la sombra, ni la
noche, ni la niebla. Y `rim` vale:

```glsl
rim = pow(clamp(1.0 - dot(N, V) + _RimLift, 0, 1), _RimFresnelPower) * _RimColor
```

En la silueta la normal es perpendicular a la vista, o sea `dot(N,V) = 0`, o sea
`rim = _RimColor` entero. Con lo que había —`_RimColor` blanco `(1, 0.95, 1)` y
`_RimLightingMix = 0.12`— cada personaje llevaba **un +0,88 de blanco puro
sumado a todo su contorno, permanentemente**.

**El arreglo:** rim apagado por defecto (`ToonMaterial.RIM_APAGADO`). El borde de
un personaje ya lo define el contorno negro, que es el recurso de verdad del
anime; el rim aquí solo estaba tapándolo.

Si algún día se quiere un rim —para una transformación, para el jefe a
contraluz—, la forma correcta es poner color **y subir `rim_mix` a 1.0**. Con
`_RimLightingMix = 1` el rim deja de ir a la emisión y pasa por la iluminación:
brilla donde da la luz y se apaga donde no, que es lo que hace un reflejo de
verdad.

## 2. Los personajes salían planos

**Lo que se veía:** la figura sin volumen, como una calcomanía de colores lisos.
El escalón de luz y sombra —lo que define el cel shading— no aparecía por
ninguna parte.

**Lo que era:** `_IndirectLightIntensity` a **0,5**. Ese parámetro no controla
«cuánta luz indirecta hay», controla cuánto se dobla la normal hacia arriba antes
de iluminar (línea 280 del include):

```glsl
NORMAL = normalize(mix_normal(up_normal, viewNormal, _IndirectLightIntensity));
```

A 0,5, media normal de cada píxel apunta al cielo. El lado de sombra y el lado de
luz acaban recibiendo casi lo mismo, así que **no hay escalón que dibujar**. Da
igual lo bien afinados que estén `_ShadeColor` y `_ShadeToony`: no llegan a
usarse.

**El arreglo:** 0,1, que es el valor propio de MToon. Suaviza lo justo para que
la sombra no sea un corte a cuchillo, sin borrarla.

## 3. El contorno no se veía

Estaba en **6 milímetros**. En un personaje de 1,55 m eso es una línea que
desaparece en cuanto te alejas tres metros — y en la pantalla de un móvil,
antes. Sin contorno, el cel shading no se lee como cel shading.

**El arreglo:** 2 cm por defecto. Las escenas que lo sobreescriben (enemigos a
0,008, el guardián a 0,014) se quedan como estaban: son piezas más pequeñas y
ahí la proporción ya era correcta.

> El contorno se hace con *inverted hull*: la malla se dibuja **otra vez** del
> revés y ligeramente inflada. O sea que **cuesta el doble de geometría por
> personaje**. Está anotado en [`26-OPTIMIZACION.md`](26-OPTIMIZACION.md) como
> cosa a medir en el móvil, porque con el guardián a 25.000 triángulos son
> 50.000.

## 4. El fondo lavado: había dos velos puestos a la vez

**Lo que se veía:** de la mitad de la pantalla hacia arriba, un lavado morado
uniforme. Las colinas sin forma, la cordillera sin valor, el cielo y el suelo
fundiéndose en el mismo gris malva.

**Lo que era:** dos efectos distintos haciendo exactamente lo mismo, con el mismo
color, en el mismo tramo de distancia:

| | Dónde | Tramo | Color |
|---|---|---|---|
| Niebla del `Environment` | escena | 78 → 148 m | `(0.90, 0.86, 0.95)` |
| Perspectiva aérea del terreno | `terreno.gdshader` | 65 → 110 m, al **92 %** | `(0.63, 0.62, 0.80)` |

Cada una por separado es razonable. Las dos encima, no: a 110 m ya no quedaba
nada del color original.

**El arreglo**, tres cosas:

1. **La niebla del `Environment`, apagada** — en las dos plataformas. La
   perspectiva aérea del terreno hace el mismo trabajo y **sale gratis**, porque
   ya se está calculando dentro de un shader que se ejecuta igualmente.
2. **La perspectiva aérea, más suave y más lejos**: del 92 % al **72 %**,
   empezando a 78 m en vez de a 65 y acabando a 180 en vez de a 110. Lo que da
   sensación de distancia es el **gradiente**, no cuánto tinte hay al final.
3. **El color del aire, azul en vez de morado gris.** `(0.63, 0.62, 0.80)` es un
   color sin croma: al teñir con él, lo lejano no se aleja, se descolora. El aire
   real tiñe de azul, y un azul con algo de saturación deja que el verde de la
   ladera siga leyéndose por debajo.

### Y en el móvil era peor a propósito

`nivel.gd` tenía esto en el perfil de móvil:

```gdscript
const MOVIL_NIEBLA_DESDE := 0.55   # 0,55 × 86 m = 47 m
```

Al apagar la niebla en el móvil se acercaba la perspectiva aérea para
«compensar». El resultado era el contrario del buscado: en el móvil el fondo
empezaba a lavarse **treinta metros antes** que en el Mac. Buena parte de eso de
que «en el móvil la calidad parece reducida» era literalmente esto.

Ahora las dos plataformas van con los mismos números. Y eso no es solo cuestión
de justicia: **es lo único que permite juzgar el aspecto sin exportar un APK**.

## 5. El tonemap era el de una cámara de fotos

`tonemap_mode = 2` es **Filmic**, una curva pensada para imitar la respuesta de
una película fotográfica: comprime los claros y desatura al subir de valor. En
una escena realista eso es exactamente lo que se quiere.

En cel shading es lo contrario de lo que se quiere. El estilo va de colores
planos, elegidos a mano, con saltos claros entre ellos; una curva que los mezcla
y los desatura deshace justo el trabajo. El azul marino de la falda salía celeste
grisáceo y el rojo del lazo, rosa palo.

**El arreglo:** `tonemap_mode = 0`, **lineal**. Los colores salen como se
pintaron.

De propina, esto arregla otra cosa. En el móvil el ajuste de color va **horneado**
en los colores de origen (`PaletaTerreno.vivo()`) en vez de aplicado al fotograma
terminado. Hornearlo solo es exacto si lo que pasa entre medias es lineal — con
Filmic por en medio, el Mac y el móvil no podían coincidir por mucho que se
afinara. Ahora sí.

## 6. La luz ambiente tapaba las sombras

`ambient_light_energy = 0.6` con el cielo como fuente. El cielo de este juego es
claro, así que eso es una luz pálida entrando por todos lados a la vez y
rellenando cada sombra. Sin zonas oscuras no hay contraste, y sin contraste la
imagen se lee como plana aunque los colores sean correctos.

**El arreglo:** 0,35. Las sombras vuelven a tener cuerpo y el sol vuelve a
notarse. Bajarlo más empieza a ennegrecer las caras a contraluz, que en un juego
para una niña de ocho años es peor que un poco de lavado.

---

## Lo que queda pendiente de esto

**Los personajes no reciben el ajuste de color en el móvil.** Es el único trozo
del problema de tono que sigue abierto.

En el móvil el ajuste (contraste 1,08 · saturación 1,25) no se aplica al
fotograma —costaría un pase de pantalla completa, que en una GPU por tiles es
caro— sino que se hornea en los colores de origen. Eso funciona para el terreno y
para el cielo, que son colores. **No funciona para un personaje**, porque su color
viene de una TEXTURA y el `_Color` de MToon que sí se podría avivar es blanco:
multiplicar por blanco no hace nada.

O sea que en el móvil el parque sale avivado y Serena no, y la diferencia se lee
como que el personaje está descolorido respecto al fondo.

**La solución no es hornear mejor, es mover la cuenta al shader.** El MToon ya se
está ejecutando en cada píxel de cada personaje; meterle el contraste y la
saturación al final del `fragment()` son cuatro operaciones, que para una GPU no
es nada — lo caro nunca fue la cuenta, era tener que releer la pantalla entera
para hacerla. Con eso, móvil y Mac se ven idénticos y el pase de post sigue sin
existir.

Queda para la sesión siguiente porque toca un shader del addon (vendorizado en
`addons/`, así que se puede editar) y conviene medirlo en el móvil antes y
después.

---

## Dónde está cada cosa

| Qué | Archivo |
|---|---|
| Rim, contorno y sombreado de personajes | [`src/core/toon_material.gd`](../src/core/toon_material.gd) |
| Los mismos, por nodo | [`src/core/toon_root.gd`](../src/core/toon_root.gd) |
| Perspectiva aérea | [`src/level/terreno_nivel.gd`](../src/level/terreno_nivel.gd) → `LEJANIA_*` |
| Tonemap, ambiente y niebla | `scenes/levels/nivel_1_parque.tscn` → `Env_1` |
| Recortes de móvil | [`src/level/nivel.gd`](../src/level/nivel.gd) → `_ajustar_para_el_movil()` |
| El shader MToon por dentro | `addons/Godot-MToon-Shader/mtoon_common.gdshaderinc` |
