# Sailor Moon: El Cristal de los Sueños

Juego de acción 3D para Android hecho en Godot 4.7. **Proyecto personal, regalo
para una niña de 8 años. No comercial y no distribuido.**

> 📖 **Empieza por [`docs/ESTADO.md`](docs/ESTADO.md)** — es el punto de entrada:
> en qué fase estamos, qué funciona, mapa del código, rutas del entorno y una
> lista de trampas ya pisadas que ahorra horas de depuración.

---

## Qué es

Un **beat 'em up ligero en 3D** con arenas de combate, pensado para que una niña
de 8 años pueda jugarlo sola en el móvil.

- **Motor:** Godot 4.7.1 · GDScript · renderizador Mobile (Vulkan/Metal)
- **Estética:** cel shading anime con MToon
- **Plataforma:** Android (touch), con soporte de escritorio para desarrollo

### Pilares de diseño

1. **Imposible perder de forma frustrante.** No hay *game over*.
2. **Machacar un botón tiene que sentirse increíble.** Hit stop, sacudida y partículas.
3. **Nada muere, todo se purifica.** Los enemigos se vuelven amigos.
4. **Se juega con un pulgar.**

---

## Estado

| Fase | Estado |
|---|---|
| 0 — Cimientos | ✅ Cerrada. APK corriendo en móvil real |
| 1 — Combate | 🟡 Núcleo verificado. Falta pulir el *feel* |
| 2 — Vertical slice | 🟡 Modelos, rigueo, física de pelo y AnimationTree listos |

**Funciona hoy:** combo de 3 golpes con auto-orientación, ataque especial,
enemigos con sistema de fichas (nunca más de 3 atacando), purificación, arenas
con oleadas, HUD y controles táctiles. 60 fps con 9 enemigos.

---

## Documentación

| Documento | Contenido |
|---|---|
| [`ESTADO.md`](docs/ESTADO.md) | **Punto de entrada.** Estado, entorno y trampas |
| [`00-GDD.md`](docs/00-GDD.md) | Diseño, guion y mecánicas |
| [`01-ARQUITECTURA.md`](docs/01-ARQUITECTURA.md) | Estructura y presupuestos |
| [`03-ROADMAP.md`](docs/03-ROADMAP.md) | Fases y riesgos |
| [`05-COMBATE.md`](docs/05-COMBATE.md) | Guía de ajuste del combate |
| [`06-GUIA-ASSETS-3D.md`](docs/06-GUIA-ASSETS-3D.md) | Pipeline 3D con IA |
| [`07-ESCENARIOS.md`](docs/07-ESCENARIOS.md) | Cómo se montan los escenarios |
| [`08-ANIMACIONES-MIXAMO.md`](docs/08-ANIMACIONES-MIXAMO.md) | Animaciones y ajustes |
| [`09-FISICA-PELO.md`](docs/09-FISICA-PELO.md) | Coletas con inercia |
| [`10-ANIMATION-TREE.md`](docs/10-ANIMATION-TREE.md) | AnimationTree |

---

## Puesta en marcha

Requiere **Git LFS** (los modelos y el audio van por ahí):

```bash
brew install git-lfs && git lfs install
git clone <url> && cd sailor-moon
git lfs pull
```

Abrir con Godot 4.7.1. La escena principal es
`scenes/prototypes/test_combat.tscn`.

Para exportar el APK, las rutas del SDK están en
[`docs/ESTADO.md`](docs/ESTADO.md) §5.

---

## Aviso legal

Sailor Moon (美少女戦士セーラームーン) es propiedad de **Naoko Takeuchi,
Kodansha y Toei Animation**.

Este es un proyecto personal sin ánimo de lucro, **no distribuido públicamente y
no monetizado**, hecho como regalo familiar. El repositorio es privado y no debe
publicarse en ninguna tienda de aplicaciones.

Las atribuciones de recursos de terceros están en
[`docs/CREDITOS.md`](docs/CREDITOS.md).
