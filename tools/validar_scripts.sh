#!/bin/bash
# Compila todos los .gd del proyecto y falla si alguno tiene errores REALES.
#
# Hace falta porque `--import` NO compila los scripts: un error de parseo pasa
# la importación sin una queja y solo aparece al arrancar el juego, que además
# se queda atrapado en el depurador y bloquea el MCP.
#
# Se filtran dos ruidos inevitables: `--check-only` no carga los autoloads, así
# que TODO script que use EventBus o GameManager se queja de que no existen, y
# de rebote sus dependientes fallan también. Eso no son errores del código.
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
AUTOLOADS="EventBus|GameManager|AudioManager|SaveManager|SceneLoader|Settings|CombatFeel|CombatDirector"
fallos=0
for f in $(find src tools -name '*.gd' | sort); do
  salida=$("$GODOT" --headless --path . --check-only --script "$f" 2>&1 \
           | grep -E "SCRIPT ERROR|Parse Error" \
           | grep -vE "Identifier not found: ($AUTOLOADS)" \
           | grep -v "Failed to compile depended scripts" || true)
  if [ -n "$salida" ]; then
    echo "✗ $f"
    echo "$salida" | sed 's/^/    /'
    fallos=$((fallos+1))
  fi
done
if [ "$fallos" -eq 0 ]; then
  echo "✓ todos los scripts compilan"
else
  echo "$fallos script(s) con errores"
  exit 1
fi
