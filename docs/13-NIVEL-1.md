# Nivel 1 — Parque Juuban, completo

> Plan de implementación para dejar el primer nivel **terminado de verdad**
> antes de tocar el segundo. Estado y avance al final del documento.

## Por qué se replantea

El blockout funciona y se recorre entero, pero es exactamente lo que su nombre
dice: pasillo → arena → pasillo → arena. Se acaba en diez minutos y **no hay
nada que decidir ni nada que descubrir**. Un beat 'em up para una niña de 8
años puede ser sencillo, pero no puede ser un pasillo.

Lo que se añade, en orden de cuánto cambia la sensación por cuánto cuesta:

| # | Qué | Qué aporta |
|---|---|---|
| 1 | **Estrellas de Sueño y secretos** | Motivo para mirar fuera del camino. Rejugabilidad |
| 2 | **Encuentro con una Sailor** | Convierte el nivel en historia. Empieza el reparto |
| 3 | **Un objetivo que no sea pelear** | Rompe el ritmo de arena-arena |
| 4 | **Un cruce con dos caminos** | Hay algo que decidir |
| 5 | **Decoración** | Lo último, cuando lo de arriba ya funciona |

La decoración va al final **a propósito**: un nivel que no se entiende en gris
tampoco se entiende con árboles.

---

## 1. Estrellas de Sueño

El coleccionable del juego. `GameManager.collect_star()` y el contador del HUD
ya existían desde la Fase 0, sin usarse.

**Siete por nivel**, repartidas así:

| Dónde | Cuántas | Idea |
|---|---|---|
| En el camino | 3 | Enseñan qué son. Imposible no cogerlas |
| Fuera del camino, a la vista | 2 | Se ven desde el camino pero hay que desviarse |
| Tras un salto o en una zona secreta | 2 | Para quien explore |

**Reglas de diseño:**

- **Con imán.** A los 8 años, calcular un salto para tocar exactamente un objeto
  es frustrante. Si te acercas lo suficiente, la estrella viene sola.
- **Nunca en un sitio donde puedas caerte.** Un coleccionable que castiga por
  intentar cogerlo enseña a no explorar.
- **Se ven de lejos.** Giran, flotan y brillan.

Al conseguir las siete: recompensa visible y se guarda en el progreso del nivel.

## 2. Encuentro con Sailor Mercury

Cada escenario presenta a un personaje del reparto. En el Nivel 1 es **Mercury**,
la primera del guion.

- Aparece **después de la Arena 2**, atrapada tras unos enemigos.
- Al acercarse: panel de diálogo breve, dos o tres frases.
- Se une al reparto (`EventBus.sailor_unlocked`), que quedará usable cuando esté
  el selector de personaje.

El sistema es **reutilizable**: un nodo `Encuentro` con su ficha de personaje y
sus frases. Los diez encuentros restantes son configurar, no programar.

## 3. Encender los faroles

En el tramo C, antes del guardián, hay **tres faroles de piedra apagados**. Hasta
que no se enciendan los tres, la puerta al guardián no se abre.

No hay que pelear: hay que **buscar**. Uno está a la vista, otro detrás de unos
arbustos y el tercero en la zona alta. Da un respiro entre la Arena 2 y el jefe,
y de paso justifica la caja de luz del `tōrō`, que ya lleva material propio.

## 4. El cruce

A mitad del tramo B, el camino se parte en dos y se vuelve a juntar:

- **Camino corto:** directo, sin nada.
- **Camino largo:** una plataforma más, dos Estrellas y una vista del torii.

Ninguno castiga. El que explora se lleva algo; el que va directo, llega antes.

## 5. Decoración

Con todo lo anterior funcionando:

- Props sembrados por el recorrido, `MultiMeshInstance3D` donde se repitan
- Anillo de fondo lejano: montañas, pagoda, torii y cerezos gigantes
- Medir draw calls contra el presupuesto de
  [`01-ARQUITECTURA.md`](01-ARQUITECTURA.md) §8

---

## Duración objetivo

De 8-10 minutos a **18-25 minutos** la primera vez, contando exploración y
diálogo. Rejugándolo para completar las estrellas, menos.

No se alarga metiendo más oleadas: se alarga dando **cosas distintas que hacer**.

---

## Avance

| Parte | Estado |
|---|---|
| 1. Estrellas de Sueño | ✅ hecho |
| 2. Encuentro con Mercury | ⬜ |
| 3. Faroles | ⬜ |
| 4. Cruce | ⬜ |
| 5. Decoración | ⬜ |
