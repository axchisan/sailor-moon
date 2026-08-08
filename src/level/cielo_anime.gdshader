shader_type sky;
render_mode use_debanding;

// Cielo de fondo pintado, estilo anime de los 90.
//
// POR QUÉ ES PROCEDURAL Y NO UNA FOTO
//
// Los HDRI de Poly Haven son fotografías: preciosas y completamente fuera de
// tono con un juego cel shaded. Y los generadores de skybox por IA que
// prometen "gratis" acaban pidiendo créditos para descargar.
//
// Un cielo de anime no necesita ninguna de las dos cosas: es un degradado, unas
// nubes de borde duro y un sol. Eso se pinta con matemáticas, sale gratis, pesa
// cero, y —lo que de verdad importa— se cambia entero moviendo cuatro colores.
// El mismo shader da el parque al atardecer, el santuario de noche o el nivel
// submarino.
//
// COSTE EN MÓVIL: el cielo se calcula una vez y se guarda en la radiancia
// mientras no cambie. Con `velocidad_nubes` a 0 es prácticamente gratis; con
// nubes en movimiento conviene dejar el Sky en modo de proceso INCREMENTAL.

group_uniforms Cielo;
uniform vec3 color_cenit : source_color = vec3(0.30, 0.52, 0.88);
uniform vec3 color_medio : source_color = vec3(0.72, 0.78, 0.95);
uniform vec3 color_horizonte : source_color = vec3(0.99, 0.80, 0.68);
// Dónde se funden el cenit y el horizonte. Subirlo baja la línea del cielo.
uniform float altura_mezcla : hint_range(0.02, 1.0) = 0.32;

group_uniforms Nubes;
uniform vec3 color_nube : source_color = vec3(1.0, 0.97, 0.96);
uniform vec3 color_nube_sombra : source_color = vec3(0.86, 0.76, 0.84);
// Cuánto cielo tapan. 0 = despejado.
uniform float cobertura : hint_range(0.0, 1.0) = 0.46;
// Lo que hace que parezcan de anime: cerca de 1 el borde es un recorte limpio,
// bajándolo se deshilachan como nubes de verdad.
uniform float dureza_borde : hint_range(0.0, 1.0) = 0.86;
uniform float escala_nubes : hint_range(0.5, 8.0) = 2.4;
uniform float velocidad_nubes : hint_range(0.0, 0.05) = 0.004;

group_uniforms Sol;
uniform vec3 color_sol : source_color = vec3(1.0, 0.96, 0.86);
uniform float tamano_sol : hint_range(0.0, 0.2) = 0.035;
uniform float halo : hint_range(0.0, 40.0) = 14.0;

group_uniforms Extras;
// Un puñado de estrellas para los niveles nocturnos. A 0 no se ven.
uniform float estrellas : hint_range(0.0, 1.0) = 0.0;


float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float ruido(vec2 p) {
	vec2 celda = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(celda);
	float b = hash(celda + vec2(1.0, 0.0));
	float c = hash(celda + vec2(0.0, 1.0));
	float d = hash(celda + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Cuatro octavas bastan: son nubes de dibujo animado, no un simulador.
float fbm(vec2 p) {
	float suma = 0.0;
	float amplitud = 0.5;
	for (int i = 0; i < 4; i++) {
		suma += ruido(p) * amplitud;
		p *= 2.03;
		amplitud *= 0.5;
	}
	return suma;
}

void sky() {
	float altura = clamp(EYEDIR.y, -1.0, 1.0);

	// Degradado en dos tramos: del horizonte al medio y del medio al cenit.
	// Un solo `mix` da un cielo plano de motor; el escalón intermedio es lo
	// que da esa franja cálida del atardecer.
	float t = clamp(altura / altura_mezcla, 0.0, 1.0);
	vec3 color = mix(color_horizonte, color_medio, smoothstep(0.0, 1.0, t));
	float t_alto = clamp((altura - altura_mezcla) / max(1.0 - altura_mezcla, 0.001), 0.0, 1.0);
	color = mix(color, color_cenit, smoothstep(0.0, 1.0, t_alto));

	// Sol y su halo, en la dirección de la luz direccional de la escena.
	if (LIGHT0_ENABLED) {
		float cercania = dot(EYEDIR, LIGHT0_DIRECTION);
		color += color_sol * pow(max(cercania, 0.0), halo) * 0.35;
		color = mix(color, color_sol,
			smoothstep(1.0 - tamano_sol, 1.0 - tamano_sol * 0.35, cercania));
	}

	if (estrellas > 0.001 && altura > 0.0) {
		vec2 rejilla = floor(EYEDIR.xz / max(altura, 0.05) * 120.0);
		float brillo = step(0.995, hash(rejilla));
		color += vec3(brillo) * estrellas * smoothstep(0.0, 0.35, altura);
	}

	// Nubes. Se proyectan sobre un plano por encima de la cámara, así se
	// aplastan hacia el horizonte igual que las de verdad. Por debajo del
	// horizonte no se dibuja ninguna.
	if (altura > 0.01 && cobertura > 0.001) {
		vec2 plano = EYEDIR.xz / (altura + 0.18) * escala_nubes;
		plano += vec2(TIME * velocidad_nubes, TIME * velocidad_nubes * 0.6);

		float densidad = fbm(plano);
		float umbral = 1.0 - cobertura;
		// El borde duro es la firma del estilo: se recorta con `smoothstep`
		// en una ventana estrecha en vez de dejar un degradado suave.
		float margen = mix(0.28, 0.012, dureza_borde);
		float masa = smoothstep(umbral - margen, umbral + margen, densidad);

		// Segunda capa desplazada: hace de sombra propia y da volumen sin
		// necesidad de iluminar nada.
		float sombra = smoothstep(umbral - margen, umbral + margen,
			fbm(plano + vec2(0.35, 0.22)));
		vec3 tono = mix(color_nube_sombra, color_nube, clamp(sombra, 0.0, 1.0));

		// Se desvanecen al acercarse al horizonte, si no forman una costura.
		masa *= smoothstep(0.01, 0.16, altura);
		color = mix(color, tono, clamp(masa, 0.0, 1.0));
	}

	COLOR = color;
}
