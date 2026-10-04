# Garlia — Frontera Supabase ↔ Godot

## Principio

Supabase es la fuente canónica de los datos de mundo y catálogo.

Godot no debe reconstruir reglas canónicas a partir de valores hardcodeados cuando existe una fuente estructurada en Supabase.

## Capas

```
Supabase PostgreSQL
      ↓
SupabaseClient / repositories
      ↓
runtime adapters
      ↓
WorldData / domain state
      ↓
Gameplay
      ↓
Presentation
```

## Datos de mundo

| Canon | Tabla principal | Runtime |
|---|---|---|
| Bioma | `biomas` | WorldData |
| Ecosistema | `ecosistemas` | WorldData |
| Habitat | `habitats` | WorldData |
| Criatura | `criaturas` + relaciones ecológicas | Creature data / spawn |
| Item | `items` + `items_game` | Item runtime |
| Misión | `misiones_game` + objetivos/recompensas | MissionManager |
| Personaje | `personajes_game` | NPC/Creature |
| Inventario persistente | `inventario_usuario` | Inventory persistence |

## Reglas

### Lectura

Godot puede:

- cargar
- indexar
- cachear
- transformar DTOs en runtime state

Godot no puede:

- inventar una categoría que debería venir del catálogo
- sustituir relaciones canónicas con arrays locales
- decidir que un item es arma por una heurística si `items_game.tipo` ya define la categoría.

### Escritura

Toda escritura persistente debe pasar por un adaptador explícito.

No:

`HUD → REST`

No:

`CombatSystem → HTTPRequest`

No:

`IUMManager → URL Supabase`

Sí:

`Gameplay → Repository/Service → SupabaseClient`

## Snapshot del mundo

`WorldData` actualmente recibe un snapshot remoto y construye índices.

Eso es útil para rendimiento, pero debe considerarse un **runtime cache**, no una segunda fuente de verdad.

La arquitectura futura separará:

- `WorldRepository`: obtiene el dato.
- `WorldCache`: persistencia local del snapshot.
- `WorldRuntime`: estado de la partida.
- `WorldData`: fachada de transición mientras se migra.

## Realtime

Supabase Realtime puede transportar cambios de PostgreSQL al cliente. La arquitectura debe decidir por cada dominio si:

1. el cambio se aplica inmediatamente al runtime;
2. se guarda para la siguiente sesión;
3. se bloquea mientras la partida está activa.

No todos los datos canónicos deben mutar una partida en curso.

## Backend deuda detectada

Los advisors actuales reportan múltiples políticas permisivas duplicadas y 3 índices duplicados:

- `item_estructuras_fisicas`
- `iums_configuraciones_funcionales`
- `proceso_demanda_eterium_fisica_v1`

La limpieza de estos objetos es una tarea separada del runtime y no debe introducirse accidentalmente en el refactor de Godot.

## Criterio

Si una corrección requiere tocar Supabase y Godot, primero se modifica el contrato canónico y después el adaptador/runtime.

Nunca se parchea el cliente para ocultar una inconsistencia del modelo canónico.
