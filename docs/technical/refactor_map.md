# Garlia — Mapa de refactorización y dependencias

Fecha: 2026-10-04

## Objetivo

Reducir la fragmentación del proyecto sin mezclar responsabilidades.

La estructura actual queda deliberadamente pequeña:

```
scripts/
├── characters/       Player, Entity y representación del personaje
├── creatures/        Creature y comportamiento de criaturas
├── core/             infraestructura transversal del juego
├── dev/              herramientas, debug y editor
├── gameplay/         reglas y sistemas jugables
├── infrastructure/   Supabase, autenticación, multiplayer y persistencia
├── state/            estados/runtime persistibles
├── ui/               interfaz
└── world/            generación, terreno, streaming y entidades del mundo
```

No se crean carpetas por una sola clase. Las subcarpetas dentro de gameplay/world se mantienen solo cuando agrupan un sistema real.

## Qué se eliminó de la organización anterior

### globals

Se eliminó como categoría general.

- Entity → `scripts/characters/entity.gd`
- Events → `scripts/core/events.gd`
- GameState → `scripts/core/game_state.gd`
- SceneManager → `scripts/core/scene_manager.gd`
- Auth / Multiplayer / Salas / WorldItems → `scripts/infrastructure/`

### domain

Se eliminó como carpeta intermedia.

Los estados puros viven en `scripts/state/`:

- VitalState
- PlayerState
- PlayerRuntime
- PlayerIdentity
- InventoryState
- InventoryEquipment
- InventoryHotbar
- EquipmentState
- WorldState
- WorldRuntime
- DiscoveryState

Esto conserva la separación conceptual sin obligar a navegar por domain/entities/items/player/world.

### systems

Se eliminó como carpeta genérica.

- Supabase → infrastructure
- Mission / Relationship / Dialogue / Interaction → gameplay
- IUM → gameplay
- CombatSystem → gameplay
- El proyectil antiguo queda explícitamente marcado como legacy mientras se termina la migración al nuevo sistema de combate.

### presentation

Se eliminó como capa física separada para el único script que contenía.

- PlayerVisualController → `scripts/characters/`

La UI ya tiene su propia categoría física: `scripts/ui/`.

### debug / editor

Se consolidaron en:

`scripts/dev/`

## Gameplay

La organización actual es:

```
scripts/gameplay/
├── combat/
├── inventory/
├── player/
├── eterium/
└── sistemas jugables compartidos
```

Hay una excepción importante: el runtime nuevo de Eterium del jugador está en `gameplay/player/`.

El runtime antiguo duplicado fue eliminado.

## World

```
scripts/world/
├── main.gd
├── world_data.gd
├── world_generator.gd
├── world_streamer.gd
├── world_terrain.gd
├── world_terrain_areas.gd
├── world_terrain_visual.gd
├── world_entity_spawner.gd
├── world_decoration.gd
├── world_prop.gd
├── world_item.gd
└── world_atmosphere.gd
```

No se separa cada archivo en una carpeta propia: todos pertenecen claramente al subsistema World.

## Scenes

La estructura queda:

```
scenes/
├── SceneManager.tscn
├── characters/
├── creatures/
├── dev/
├── ui/
└── world/
```

Se corrigió el typo histórico `scenes/wold/` → `scenes/world/`.

También se actualizaron las referencias conocidas a esa ruta en GameState, WorldItems y StartMenu.

## Flujo de dependencias

```
Supabase
   ↓
infrastructure
   ↓
state / world data
   ↓
gameplay + world
   ↓
characters / creatures
   ↓
events
   ↓
ui
```

Reglas:

- Supabase sigue siendo la fuente canónica.
- State no conoce UI.
- Entity no conoce Supabase.
- Gameplay no debe modificar internals de UI.
- UI representa estado y emite comandos.
- World no contiene reglas de inventario o combate.
- CreatureAI decide intención; CombatDamage resuelve daño.
- Hotbar y Equipment permanecen separados.
- Input pasa por GameplayInputGate.
- No crear otro sistema si ya existe uno con la misma responsabilidad.

## Compatibilidad

Durante la migración se conservan los UID de los scripts movidos cuando existían archivos `.uid`.

Los movimientos se hicieron a nivel de Git para conservar el historial y evitar copias paralelas.

## Pendientes detectados

1. Revisar y migrar completamente las referencias al antiguo CombatSystem hacia CombatController.
2. Eliminar `combat_projectile_legacy.gd` cuando ninguna escena/sistema dependa de él.
3. Revisar GameStateFacade y GameState para decidir cuándo puede desaparecer la fachada.
4. Revisar los dos shaders de prueba y los recursos de TileMapDual de desarrollo antes de eliminarlos.
5. Auditar referencias residuales a rutas antiguas mediante una pasada completa del proyecto local/Godot.
6. Actualizar `architecture_v2.md` para que describa esta estructura simplificada y no la estructura anterior demasiado fragmentada.

## Criterio

Una carpeta debe existir porque ayuda a responder inmediatamente:

"¿Qué tipo de cosa vive aquí?"

Si la respuesta es solamente "porque en arquitectura sonaba bien", la carpeta debe desaparecer.
