#!/bin/bash
# Compila, instala y ARRANCA el juego en el móvil, dejando abierto el puente
# para poder medirlo desde el Mac.
#
# POR QUÉ ESTE SCRIPT
#
# Hasta ahora medir en el móvil era: exportar, instalar, jugar, mirar el panel
# de F1, apuntar a mano, y volver a empezar por cada corazonada. Eso hace que se
# mida poco, tarde, y solo lo que uno ya sospechaba.
#
# El juego lleva dentro un servidor (`McpInteractionServer`) que escucha en el
# 9090 y acepta órdenes. En el Mac eso es lo que permite ejecutar código dentro
# del juego y sacar capturas. En el móvil escucha igual — solo que en el 9090
# DEL TELÉFONO, al que desde aquí no se llega.
#
# `adb forward` lo arregla: hace que el 9090 de esta máquina sea el 9090 del
# teléfono. A partir de ahí, todo lo que ya se sabe hacer contra el juego del
# Mac vale igual contra el del móvil — incluidos los dos bancos de medición de
# `tools/`. Se mide en el aparato que tiene el problema, no en el que no lo
# tiene.
#
# DOS COMPILACIONES, Y LA DIFERENCIA IMPORTA
#
#   debug    lleva el depurador, las comprobaciones de GDScript y el servidor.
#            Es la que se puede medir e inspeccionar, y es MÁS LENTA.
#   final    es la de release. Es la que se le instala a la niña.
#
# Medir en debug y sacar conclusiones sobre lo que se va a jugar es un error:
# la diferencia entre las dos no es pequeña en un juego con mucho GDScript.
# Por eso hay `--final`: para comprobar cuánto de lo que se ve es del juego y
# cuánto era el andamio.
#
# USO
#   ./tools/probar_en_movil.sh              compila debug, instala, arranca y
#                                           deja el puente abierto
#   ./tools/probar_en_movil.sh --final      lo mismo con la compilación final
#   ./tools/probar_en_movil.sh --sin-compilar   solo instala lo que ya hay
#   ./tools/probar_en_movil.sh --registro   además, engancha el logcat
#   ./tools/probar_en_movil.sh --temperatura  solo dice cómo está de caliente
#
# EL CALOR NO ES UN DETALLE, ES PARTE DE LA MEDIDA
#
# Este teléfono, tras una hora de pruebas seguidas, entra en estrangulamiento
# térmico ligero: las CPU a 55-61 grados y `Thermal Status: 1`. Y ahí el MISMO
# sitio del mapa que daba 57,7 fps en frío da 45. O sea que una medición sin
# saber cómo estaba el aparato no se puede comparar con ninguna otra.
#
# Regla: mirar la temperatura ANTES de una tanda que vaya a servir de referencia,
# y si está estrangulado, dejarlo descansar. Es también la explicación de por qué
# «hay zonas con tirones» aparece a los minutos y no al entrar.
set -euo pipefail

GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
ADB="/opt/homebrew/share/android-commandlinetools/platform-tools/adb"
PROYECTO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PAQUETE="com.familia.sailormoon"
PUERTO=9090

PRESET="Android (depuracion)"
APK="export/sailor_moon_debug.apk"
MODO="--export-debug"
COMPILAR=1
REGISTRO=0
TEMPERATURA=0

for arg in "$@"; do
	case "$arg" in
		--final)
			PRESET="Android (final)"
			APK="export/sailor_moon.apk"
			MODO="--export-release"
			;;
		--sin-compilar) COMPILAR=0 ;;
		--registro) REGISTRO=1 ;;
		--temperatura) TEMPERATURA=1 ;;
		*) echo "Opción desconocida: $arg"; exit 1 ;;
	esac
done

cd "$PROYECTO"

# Cómo está de caliente. Un aparato estrangulado da números que no valen.
temperatura() {
	local estado
	estado="$("$ADB" shell dumpsys thermalservice 2>/dev/null | grep -m1 'Thermal Status:' | tr -d '\r')"
	echo "${estado:-Thermal Status: (no disponible)}"
	# El rango, no la lista: `dumpsys` saca las temperaturas dos veces —las de
	# ahora y las cacheadas— y con ocho núcleos son dieciséis líneas que no dicen
	# nada más que el mínimo y el máximo.
	"$ADB" shell dumpsys thermalservice 2>/dev/null \
		| grep -oE 'mValue=[0-9.]+, mType=0, mName=CPU' \
		| sed -E 's/mValue=([0-9.]+).*/\1/' | sort -n | tr -d '\r' \
		| awk 'NR==1{min=$1} {max=$1} END{if(NR)printf "CPU: %.1f – %.1f °C\n", min, max}'
	case "$estado" in
		*"Status: 0"*) echo "→ frío. Los números de ahora sirven de referencia." ;;
		*"Status: 1"*) echo "→ estrangulado LIGERO. Los fps van a salir por debajo de lo que da en frío." ;;
		*"Status: "[2-9]*) echo "→ estrangulado FUERTE. Dejarlo descansar antes de medir nada." ;;
	esac
}

# 1. ¿Hay teléfono? Sin esto los errores de más abajo no dicen nada útil.
if ! "$ADB" get-state >/dev/null 2>&1; then
	cat <<'AYUDA'
No hay ningún teléfono conectado.

  1. Cable USB (de datos, no de solo carga)
  2. En el móvil: Ajustes → Información → tocar 7 veces «Número de compilación»
  3. Ajustes → Opciones de desarrollador → activar «Depuración por USB»
  4. Al conectar, el móvil pregunta si se fía de este ordenador: decir que sí

Comprobar con:  adb devices -l
AYUDA
	exit 1
fi
echo "Teléfono: $("$ADB" shell getprop ro.product.model | tr -d '\r') · Android $("$ADB" shell getprop ro.build.version.release | tr -d '\r')"
temperatura

if [ "$TEMPERATURA" -eq 1 ]; then
	exit 0
fi

# 2. Compilar. El editor de Godot borra las rutas de Android al cerrarse
#    (trampa 20 de ESTADO.md), así que se reponen antes de cada exportación.
if [ "$COMPILAR" -eq 1 ]; then
	./tools/configurar_android.sh >/dev/null 2>&1 || true
	# Las llaves NO son adorno: pegado a una comilla angular, bash se come los
	# bytes del carácter multibyte como parte del nombre de la variable y falla
	# con «PRESET»: unbound variable».
	echo "Exportando «${PRESET}» → ${APK}"
	"$GODOT" --headless --path . "$MODO" "$PRESET" "$APK"
	ls -lh "$APK" | awk '{print "APK: " $5}'
fi

# 3. Instalar y arrancar.
echo "Instalando…"
"$ADB" install -r "$APK" >/dev/null
"$ADB" shell am force-stop "$PAQUETE" || true

# 4. El puente. Esto es lo que convierte el móvil en algo medible: a partir de
#    aquí, localhost:9090 de este Mac ES el juego corriendo en el teléfono.
"$ADB" forward --remove-all >/dev/null 2>&1 || true
"$ADB" forward "tcp:$PUERTO" "tcp:$PUERTO" >/dev/null
echo "Puente abierto: localhost:$PUERTO → móvil:$PUERTO"

"$ADB" shell monkey -p "$PAQUETE" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
echo "Juego arrancado."
echo
echo "Para medir desde aquí, con el juego ya dentro de un nivel:"
echo "  · el banco de render:  tools/medir_rendimiento.gd"
echo "  · el banco de CPU:     tools/medir_cpu.gd"
echo "Los dos se cargan con game_eval y escupen su tabla por consola."
echo

if [ "$REGISTRO" -eq 1 ]; then
	echo "Registro del juego (Ctrl-C para salir):"
	"$ADB" logcat -c
	"$ADB" logcat godot:V GodotEngine:V "*:S"
fi
