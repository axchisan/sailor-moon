#!/usr/bin/env bash
# Reaplica las rutas de Android en los ajustes del editor de Godot.
#
# POR QUÉ EXISTE: al cerrar el editor, Godot reescribe
# editor_settings-4.7.tres y borra estas rutas, dejando la exportación rota con
# "Ruta del SDK de Android inválida". Este script las devuelve a su sitio.
#
# Uso:  ./tools/configurar_android.sh

set -euo pipefail

AJUSTES="$HOME/Library/Application Support/Godot/editor_settings-4.7.tres"
JDK="/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home"
SDK="/opt/homebrew/share/android-commandlinetools"
KEYSTORE="$HOME/.android/debug.keystore"

[ -f "$AJUSTES" ] || { echo "No existe $AJUSTES"; exit 1; }
[ -d "$JDK" ]     || { echo "Falta el JDK en $JDK"; exit 1; }
[ -d "$SDK" ]     || { echo "Falta el SDK en $SDK"; exit 1; }
[ -f "$KEYSTORE" ]|| { echo "Falta el keystore en $KEYSTORE"; exit 1; }

if pgrep -f "Godot.*--editor" >/dev/null 2>&1; then
  echo "AVISO: el editor de Godot está abierto. Al cerrarlo puede volver a"
  echo "       borrar estas rutas. Ciérralo y vuelve a ejecutar el script."
fi

python3 - "$AJUSTES" "$JDK" "$SDK" "$KEYSTORE" <<'PY'
import sys, re
ruta, jdk, sdk, keystore = sys.argv[1:5]
s = open(ruta, encoding="utf-8").read()
valores = {
    "export/android/java_sdk_path": jdk,
    "export/android/android_sdk_path": sdk,
    "export/android/debug_keystore": keystore,
    "export/android/debug_keystore_user": "androiddebugkey",
    "export/android/debug_keystore_pass": "android",
}
for clave, valor in valores.items():
    patron = re.compile(r'^' + re.escape(clave) + r'\s*=\s*".*?"$', re.M)
    linea = f'{clave} = "{valor}"'
    if patron.search(s):
        s = patron.sub(linea, s)
    else:
        s = s.replace("export/android/scrcpy/screen_size", linea + "\nexport/android/scrcpy/screen_size", 1)
open(ruta, "w", encoding="utf-8").write(s)
print("Rutas de Android reaplicadas:")
for clave, valor in valores.items():
    print("  %-38s %s" % (clave.split("/")[-1], valor))
PY
