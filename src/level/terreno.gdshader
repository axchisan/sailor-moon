shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_back;

// Superficies del escenario con aspecto dibujado: hierba, tierra, piedra,
// madera, agua. Un solo shader para todas.
//
// POR QUÉ UNO SOLO
//
// Hacer una textura por objeto no escala. Vienen plazas de piedra, interiores y
// un templo, y no puede haber un `.png` por cada superficie del juego. Aquí el
// material se define con **dos colores y tres números**, así que una losa gris
// de ciudad y una de arena de templo son el mismo material con otros
// parámetros. Un escenario nuevo no pide texturas nuevas: pide otra
// combinación.
//
// POR QUÉ SE VE DIBUJADO
//
// No es cuestión de detalle, es de **cuántos tonos hay**. Una foto tiene
// millones; un fondo de anime tiene tres o cuatro por superficie, con saltos
// claros entre ellos. Eso es lo que hace `tonos`: parte el ruido en escalones
// en vez de dejarlo continuo. Con manchas grandes y bordes marcados, el ojo lo
// lee como pintado a mano aunque la geometría sea de cajas.
//
// PROYECCIÓN SIN UV
//
// Las coordenadas salen de la POSICIÓN EN EL MUNDO, no de las UV. El blockout
// son cajas escaladas y multimallas sin desplegar, y desplegarlas a mano sería
// trabajo por cada pieza. Además así la escala es la misma en todo el mapa: un
// metro de hierba mide igual en el suelo del pasillo que en el disco de hierba,
// aunque las mallas tengan tamaños completamente distintos.
//
// Se elige el eje dominante de la normal en vez de mezclar tres muestras
// (triplanar de verdad). Cuesta un tercio y en geometría de cajas —que es toda
// la del blockout— no se nota la diferencia: solo asomaría en superficies
// curvas y muy inclinadas.

uniform vec3 color_base : source_color = vec3(0.42, 0.55, 0.38);
uniform vec3 color_mancha : source_color = vec3(0.34, 0.47, 0.31);
uniform vec3 color_luz : source_color = vec3(0.52, 0.64, 0.44);
// Metros que ocupa una repetición del patrón. Más grande = manchas más grandes.
uniform float escala : hint_range(0.2, 20.0) = 3.0;
// Cuántos escalones de color. 2 es cartel, 5 ya parece degradado.
uniform int tonos : hint_range(2, 6) = 3;
// Cuánto pesa el patrón sobre el color base.
uniform float fuerza : hint_range(0.0, 1.0) = 0.55;
// Segundo patrón, mucho más fino: rompe las manchas grandes para que no se lea
// la repetición. Sin él, a partir de cierta distancia se ve el mosaico.
uniform float grano : hint_range(0.0, 1.0) = 0.18;
// Rayado en una dirección, para vetas de madera o surcos de tierra.
uniform float vetas : hint_range(0.0, 1.0) = 0.0;
uniform float aspereza : hint_range(0.0, 1.0) = 0.95;

// Perspectiva aérea: lo lejano se destiñe hacia el color del aire y tira a azul.
//
// Es la razón por la que las montañas de verdad se ven moradas, y hace más por
// la sensación de distancia que cualquier cantidad de geometría. Aquí sustituye
// a los conos morados que hacían de montañas al fondo: en vez de poner objetos
// lejanos, se tiñe el propio terreno según lo lejos que esté.
//
// Con `lejania` a 0 no hace nada, así que las superficies del parque —que están
// todas cerca— pueden usar el mismo shader sin enterarse.
uniform vec3 centro_mundo = vec3(0.0, 0.0, 0.0);
uniform vec3 color_lejania : source_color = vec3(0.62, 0.60, 0.78);
uniform float lejania : hint_range(0.0, 1.0) = 0.0;
uniform float desde : hint_range(10.0, 400.0) = 70.0;
uniform float hasta : hint_range(20.0, 600.0) = 190.0;

// Ruido de valor clásico. Va en el shader y no en una textura para no gastar
// memoria ni un archivo por variante: a esta escala se calcula más barato de
// lo que costaría muestrear.
float picotazo(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float ruido(vec2 p) {
	vec2 celda = floor(p);
	vec2 dentro = fract(p);
	// Suavizado cúbico: con interpolación lineal se ven los rombos de la
	// rejilla, que es el aspecto de «ruido de videojuego de 1998».
	vec2 t = dentro * dentro * (3.0 - 2.0 * dentro);
	float a = picotazo(celda);
	float b = picotazo(celda + vec2(1.0, 0.0));
	float c = picotazo(celda + vec2(0.0, 1.0));
	float d = picotazo(celda + vec2(1.0, 1.0));
	return mix(mix(a, b, t.x), mix(c, d, t.x), t.y);
}

// Dos octavas bastan. Con más, el patrón se vuelve fotográfico y se pierde
// justo lo que se busca.
float manchas(vec2 p) {
	return ruido(p) * 0.65 + ruido(p * 2.7) * 0.35;
}

void fragment() {
	// En `fragment()`, VERTEX y NORMAL vienen en espacio de VISTA, no de mundo.
	// Hay que pasarlos con `INV_VIEW_MATRIX`: la posición como punto (w = 1) y
	// la normal como dirección (w = 0), para que no le afecte la traslación.
	//
	// No existe ningún `NORMAL_WORLD` en Godot 4 — usarlo compila en silencio
	// hasta que se ejecuta, y entonces el material se queda en blanco liso sin
	// más pista que una línea en la consola.
	vec3 mundo = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 n = abs(normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz));

	// Proyección triplanar con MEZCLA, no eligiendo un eje con un `if`.
	//
	// Elegir el eje dominante es más barato, pero produce parpadeos: en cuanto
	// dos componentes de la normal se parecen —una superficie a 45°, o
	// simplemente el error de precisión al girar la cámara— la condición salta
	// de rama y el patrón cambia de golpe. Se veía como un centelleo en los
	// muros al mover la vista.
	//
	// Mezclando los tres planos con pesos, la transición es continua y el
	// problema desaparece por completo. Cuesta tres muestras de ruido en vez de
	// una, pero el ruido aquí es aritmética pura, no lectura de textura.
	vec3 peso = pow(n, vec3(4.0));
	peso /= max(peso.x + peso.y + peso.z, 0.0001);

	float inv = 1.0 / max(escala, 0.01);
	vec2 uv_y = mundo.xz * inv;
	vec2 uv_x = mundo.zy * inv;
	vec2 uv_z = mundo.xy * inv;

	float patron = manchas(uv_y) * peso.y
		+ manchas(uv_x) * peso.x
		+ manchas(uv_z) * peso.z;
	// Para el grano y las vetas basta el plano dominante: son detalle fino y
	// una costura ahí no se ve.
	vec2 uv = peso.y >= peso.x && peso.y >= peso.z ? uv_y
		: (peso.x >= peso.z ? uv_x : uv_z);
	if (vetas > 0.001) {
		// Las vetas van a lo largo de un eje y muy estiradas en el otro.
		patron = mix(patron, ruido(vec2(uv.x * 9.0, uv.y * 0.6)), vetas);
	}

	// El escalonado: aquí es donde deja de parecer una foto.
	float pasos = float(tonos);
	float escalonado = floor(patron * pasos) / max(pasos - 1.0, 1.0);
	escalonado = clamp(escalonado, 0.0, 1.0);

	// Tres colores en vez de dos: el tercero solo asoma en la banda más alta y
	// hace de luz, que es como se pinta la hierba en un fondo de anime.
	vec3 color = mix(color_mancha, color_base, smoothstep(0.0, 0.6, escalonado));
	color = mix(color, color_luz, smoothstep(0.72, 1.0, escalonado));
	color = mix(color_base, color, fuerza);

	if (grano > 0.001) {
		float fino = ruido(uv * 13.0) - 0.5;
		color += fino * grano * 0.14;
	}

	if (lejania > 0.001) {
		// La distancia se mide en el PLANO: lo que aleja una montaña es lo
		// lejos que está, no lo alta que sea.
		float d = length(mundo.xz - centro_mundo.xz);
		float mezcla = smoothstep(desde, hasta, d) * lejania;
		color = mix(color, color_lejania, mezcla);
	}

	ALBEDO = color;
	ROUGHNESS = aspereza;
	METALLIC = 0.0;
}
