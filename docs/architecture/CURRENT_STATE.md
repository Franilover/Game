# Garlia — Auditoría del estado actual

Fecha: 2026-10-04

## Evidencia revisada

### GitHub
El repositorio ya tuvo una primera migración de arquitectura en el merge `d179006df86b26ff7982e0fd80ceae99e955d4af`, que introdujo límites para Player, Eterium, Combat, Inventory e Input.

El problema actual no es ausencia total de arquitectura: es que varias fronteras quedaron a medio cerrar.

Se detectaron especialmente:

- `GameplayInputRouter` ya existe como autoridad global de acciones primaria/secundaria.
- `InventoryRuntime`, `InventoryController`, `InventoryEquipment` y `InventoryHotbar` ya separan estados.
- `CombatController`, `CombatTargeting` y `CombatDamage` ya existen.
- `PlayerLocomotionController`, `PlayerActionController`, `PlayerStaminaController` y coordinadores de Eterium ya existen.
- `WorldData` ya mantiene un snapshot/indexado del mundo.
- `WorldGenerator` todavía funciona como fachada demasiado grande para Terrain + Streaming + Spawner + Atmosphere + consultas de mundo.
- `WorldEntitySpawner` dependía directamente de `get_tree().current_scene/Entities`; esto ya fue eliminado mediante inyección del root de entidades desde Main.
- `Main` creaba DialogueSystem e IUMManager dinámicamente; esto ya fue eliminado: ambos son nodos explícitos de la escena.
- `InteractionSystem` ya no conoce HUD; emite `objetivo_cambiado` y Main conecta la presentación.
- WorldTerrain, WorldTerrainVisual, WorldStreamer, WorldEntitySpawner y WorldAtmosphere ahora son nodos explícitos de `main.tscn`; WorldGenerator ya no los crea dinámicamente.
- WorldAtmosphere ya no busca `current_scene`; recibe su `CanvasModulate` como dependencia de escena.
- GameplayInputRouter recibe explícitamente InteractionSystem y CombatSystem.
- CombatSystem recibe explícitamente Inventory, WorldGenerator y root de proyectiles.
- InteractionSystem recibe explícitamente Inventory y GarliaWorldItems.
- `DialogueSystem` accede directamente a MissionManager y RelationshipSystem.
- `CombatSystem` y `InteractionSystem` todavía encuentran algunos servicios mediante grupos.
- `IUMManager` realiza HTTP directo contra Supabase en vez de pasar por la infraestructura común.
- `GameState` sigue concentrando guardado, estado de jugador, descubrimientos y lógica de menú.

### Supabase

El proyecto está activo y saludable, PostgreSQL 17.6.1.

Datos relevantes actuales:

- 9 biomas
- 14 ecosistemas
- 38 habitats
- 29 criaturas
- 16 items_game
- 2 misiones game
- 3 personajes_game
- 0 filas en inventario_usuario

La estructura canónica del juego ya refleja relaciones fuertes:

`bioma → ecosistema → habitat`

`ecosistema → criaturas`

`item → items_game`

`mision → objetivos/recompensas`

`personaje_game → criatura`

Esto refuerza que Godot debe adaptar estos datos, no recrear otra base de reglas.

Los advisors de Supabase también detectan múltiples políticas permisivas duplicadas y 3 índices duplicados. Son deuda del backend, pero no deben mezclarse con la refactorización del runtime de Godot.

## Cambios realizados en esta fase

1. Se creó `docs/architecture/GARLIA_ARCHITECTURE.md`.
2. `Main` dejó de crear DialogueSystem dinámicamente.
3. `Main` dejó de crear IUMManager dinámicamente.
4. DialogueSystem e IUMManager ahora son nodos explícitos de `scenes/world/main.tscn`.
5. IUMLab ahora también está declarado explícitamente en la escena.
6. `WorldEntitySpawner` dejó de buscar `current_scene/Entities`.
7. `WorldGenerator` ahora recibe explícitamente el root de entidades desde Main.
8. Main actúa cada vez más como Composition Root: conecta dependencias en vez de descubrirlas durante la ejecución.

## Próximas fronteras

### Prioridad 1
Eliminar búsquedas de SceneTree para dependencias estructurales:

- Inventory → runtime/equipment explícitos
- Combat → equipment explícito
- Interaction → presentation por señales
- Dialogue → Mission/Relationship por servicios/eventos
- Spawner → EntityManager

### Prioridad 2
Partir WorldGenerator:

```
WorldRuntime
├── ChunkGeneration
├── WorldStreaming
├── TerrainRuntime
├── TerrainRenderer
├── EntityManager
└── Atmosphere
```

### Prioridad 3
Mover IUMManager a Infrastructure/adapter:

```
IUMGameplay
↓
IUMRepository
↓
SupabaseClient
```

Nunca HTTP directo desde gameplay.

### Prioridad 4
Reducir GameState:

```
GameState (fachada temporal)
├── SaveState
├── PlayerState
├── WorldState
└── DiscoveryState
```

### Prioridad 5
Revisar autoloads y dejar sólo estado realmente global.

## Regla de trabajo

No volver a corregir un síntoma de render, input, misión o generación modificando un sistema ajeno.

Primero localizar el dueño del estado y seguir el grafo de dependencias definido en `GARLIA_ARCHITECTURE.md`.


## Segunda etapa completada — Entity lifecycle e infraestructura IUM

### Entidades

La generación ya no es dueña del ciclo de vida de nodos.

WorldEntitySpawner → decide QUÉ aparece
WorldEntityFactory → crea QUÉ escena
WorldEntityManager → decide DÓNDE vive y CUÁNDO se elimina

El streamer continúa orquestando el momento de activar/desactivar chunks, pero la propiedad del registro y despawn está centralizada en WorldEntityManager.

Se eliminó el estado duplicado de criaturas/props por chunk que mantenía WorldEntitySpawner.

Las entidades invocadas manualmente se registran como globales y no dependen del streaming de chunks.

### IUM / Supabase

La ruta ahora es:

IUMManager → IUMRepository → SupabaseClient → Supabase REST/RPC

IUMManager ya no contiene URLs, API keys, HTTPRequest ni RPCs.
IUMRepository traduce operaciones del dominio IUM a operaciones de Supabase.
SupabaseClient es infraestructura genérica de transporte.

### Regla nueva

Un sistema de gameplay no debe importar ni construir HTTPRequest para hablar con Supabase.
Un sistema de generación no debe administrar el ciclo de vida de nodos.
Un factory no decide reglas de spawn.
Un manager de entidades no decide qué criatura corresponde a un habitat.
Cada frontera tiene un dueño.


## Tercera etapa — estado, diálogo y relaciones

Se eliminó otra capa de descubrimiento implícito:

- GameState recibe Player, Inventory y WorldGenerator desde Main.
- DialogueSystem recibe MissionManager y RelationshipSystem.
- RelationshipSystem recibe SocialRepository.
- SocialRepository usa SupabaseClient para transportar datos sociales.

Ruta social:

Main → RelationshipSystem → SocialRepository → SupabaseClient → Supabase

Ruta de diálogo:

Main → DialogueSystem → MissionManager / RelationshipSystem

DialogueSystem ya no busca estos sistemas mediante /root/... .

GameState ya no busca Player/Inventory/WorldGenerator mediante grupos o la escena actual durante guardado/aplicación del estado.

El objetivo es que los sistemas de gameplay dependan de contratos suministrados por el Composition Root y no de la estructura global del SceneTree.


## Tercera etapa — Inventory state boundary

La frontera de inventario ya no es solamente estructural; las mutaciones principales pasan por el mismo flujo:

Inventory UI → InventoryController → InventoryRuntime → InventoryState / InventoryHotbar / InventoryEquipment

Las operaciones de añadir, quitar, intercambiar/apilar, durabilidad, hotbar y transferencias de equipamiento están centralizadas en Controller/Runtime.

La UI conserva responsabilidades de presentación y coordinación visual: actualizar slots, mostrar información, gestionar drag & drop y reflejar señales.

La hotbar continúa siendo selección independiente del equipamiento. Equipar un objeto requiere una operación explícita de equipamiento; seleccionar una posición de hotbar no cambia el equipo.

El Player también es una dependencia inyectada en la UI de inventario para usos de objetos y pestañas administrativas; ya no se descubre mediante grupos.


## Cuarta etapa — Combat ↔ Equipment

CombatSystem ya consume el arma desde InventoryController.obtener_objeto_equipado().
La selección de hotbar ya no define el arma utilizada por el ataque primario.
La durabilidad de las herramientas usadas por combate se descuenta desde el equipamiento.
El slot actual de combate es mano_secundaria, coincidiendo con el slot de equipamiento existente en la UI.
