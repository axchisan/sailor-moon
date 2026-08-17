#!/usr/bin/env python3
"""Manda órdenes al juego, esté donde esté: en el Mac o en el móvil.

POR QUÉ EXISTE

El MCP de Godot sabe hablar con el juego, pero solo si LO HA LANZADO ÉL. Contra
el juego corriendo en el teléfono contesta «No active Godot process», y ahí se
acaba la conversación — justo en el único aparato donde las mediciones valen
algo.

El servidor que el juego lleva dentro (`scripts/mcp_interaction_server.gd`) no
tiene esa limitación: escucha en el 9090 y acepta JSON por línea. Con el
`adb forward` que abre `probar_en_movil.sh`, el 9090 de esta máquina ES el del
móvil. O sea que solo faltaba un cliente que hable ese protocolo sin preguntar
quién arrancó el juego.

USO

    ./tools/hablar_con_el_juego.py eval 'return Engine.get_frames_per_second()'
    ./tools/hablar_con_el_juego.py eval --archivo prueba.gd
    ./tools/hablar_con_el_juego.py captura pantalla.png
    ./tools/hablar_con_el_juego.py arbol

OJO CON EL CÓDIGO QUE SE MANDA (trampa 15 de ESTADO.md)

Un error de sintaxis dentro de `eval` deja el juego atrapado en el depurador y
bloquea el puerto. Nada de lambdas sueltas, y `round()` solo acepta un
argumento. Si se queda mudo, hay que reiniciar el juego.
"""
import argparse
import base64
import json
import socket
import sys

PUERTO = 9090
# Generoso a propósito: un banco de medición tarda medio minuto largo, y en el
# móvil más. El que se corta por lo sano es el `eval` de un juego colgado.
ESPERA = 180.0


def mandar(orden: str, parametros: dict) -> dict:
    con = socket.create_connection(("127.0.0.1", PUERTO), timeout=10.0)
    con.settimeout(ESPERA)
    peticion = json.dumps({"id": 1, "command": orden, "params": parametros})
    con.sendall((peticion + "\n").encode("utf-8"))

    # La respuesta viene en una línea, pero puede ser muy larga (una captura son
    # cientos de kilobytes en base64), así que se lee hasta el salto de línea.
    trozos = []
    while True:
        trozo = con.recv(65536)
        if not trozo:
            break
        trozos.append(trozo)
        if b"\n" in trozo:
            break
    con.close()
    crudo = b"".join(trozos).split(b"\n")[0]
    if not crudo:
        raise SystemExit("El juego no ha contestado. ¿Sigue abierto? "
                         "¿Está el puente puesto (adb forward tcp:9090 tcp:9090)?")
    return json.loads(crudo.decode("utf-8"))


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="orden", required=True)

    ev = sub.add_parser("eval", help="ejecuta GDScript dentro del juego")
    ev.add_argument("codigo", nargs="?", default=None)
    ev.add_argument("--archivo", help="lee el código de un archivo")

    ba = sub.add_parser("banco", help="inyecta y ejecuta un banco de medición")
    ba.add_argument("archivo", help="el .gd del banco, desde esta máquina")
    ba.add_argument("--nodo", default=None,
                    help="nombre del nodo, para saber cuándo ha terminado")
    ba.add_argument("--espera", type=float, default=240.0)

    cap = sub.add_parser("captura", help="guarda una captura de pantalla")
    cap.add_argument("salida")

    sub.add_parser("arbol", help="vuelca el árbol de escena")

    args = p.parse_args()

    if args.orden == "eval":
        codigo = args.codigo
        if args.archivo:
            codigo = open(args.archivo, encoding="utf-8").read()
        if not codigo:
            raise SystemExit("Hace falta código, o --archivo")
        r = mandar("eval", {"code": codigo})
        if "error" in r and r["error"]:
            print("ERROR:", r["error"], file=sys.stderr)
            return 1
        print(json.dumps(r.get("result"), indent=2, ensure_ascii=False))

    elif args.orden == "banco":
        # POR QUÉ SE INYECTA EL CÓDIGO EN VEZ DE CARGARLO DEL PCK
        #
        # `load("res://tools/…")` lee lo que había cuando se compiló el APK, así
        # que cada retoque del banco costaría reexportar e instalar: dos minutos
        # largos por iteración, y afinar un banco son muchas iteraciones. Aquí el
        # fuente viaja en la propia orden y se compila en el móvil.
        #
        # Va en base64 para no pelearse con el escapado: el código lleva
        # comillas, saltos de línea y tabuladores, y meterlo dentro de un
        # literal de GDScript dentro de un JSON es pedir un error tonto.
        fuente = open(args.archivo, encoding="utf-8").read()
        # `class_name` sobra al compilar en caliente: el nombre ya está
        # registrado por el que vino en el APK y volver a declararlo es un error.
        fuente = "\n".join(l for l in fuente.splitlines()
                           if not l.startswith("class_name "))
        b64 = base64.b64encode(fuente.encode("utf-8")).decode("ascii")
        arranque = f'''
var guion := GDScript.new()
guion.source_code = Marshalls.base64_to_utf8("{b64}")
var err := guion.reload()
if err != OK:
	return {{"error": "el banco no compila, código %d" % err}}
var nodo: Node = guion.new()
get_tree().current_scene.add_child(nodo)
return {{"lanzado": nodo.name}}
'''
        r = mandar("eval", {"code": arranque})
        if "error" in r and r["error"]:
            print("ERROR:", r["error"], file=sys.stderr)
            return 1
        resultado = r.get("result") or {}
        if "error" in resultado:
            print("ERROR:", resultado["error"], file=sys.stderr)
            return 1
        nombre = args.nodo or resultado.get("lanzado")
        print("Banco en marcha:", nombre)

        espera = f'''
var n := 0
while get_tree().current_scene.get_node_or_null("{nombre}") != null and n < {int(args.espera * 2)}:
	await get_tree().create_timer(0.5).timeout
	n += 1
return "terminado tras %.0f s" % (n * 0.5)
'''
        print(json.dumps(mandar("eval", {"code": espera}).get("result"),
                         ensure_ascii=False))

    elif args.orden == "captura":
        r = mandar("screenshot", {})
        # La captura llega en `data` al nivel de arriba, no dentro de `result`.
        # Se prueban las tres formas para no depender de esa elección.
        datos = r.get("result") if isinstance(r.get("result"), dict) else {}
        b64 = r.get("data") or datos.get("image") or datos.get("data") or r.get("image")
        if not b64:
            print("Respuesta inesperada:", json.dumps(r)[:400], file=sys.stderr)
            return 1
        open(args.salida, "wb").write(base64.b64decode(b64))
        print("Guardada en", args.salida)

    elif args.orden == "arbol":
        print(json.dumps(mandar("get_scene_tree", {}), indent=2, ensure_ascii=False))

    return 0


if __name__ == "__main__":
    sys.exit(main())
