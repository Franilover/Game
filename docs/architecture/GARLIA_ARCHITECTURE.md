# Garlia — Arquitectura y mapa de responsabilidades

> Documento operativo. Si una funcionalidad falla, este archivo indica dónde buscar antes de tocar otro sistema.

## 1. Regla principal

**SUPABASE MANDA.**

La cadena canónica es:

`Supabase → acceso/adaptación → estado runtime → reglas de gameplay → presentación`

La presentación nunca es fuente de verdad. Un sistema no puede crear una segunda versión de un dato que ya es canónico.

## 2. Capas

### Core
Código transversal y contratos.

- eventos
- input global
- estados/contratos comunes
- ciclo de vida

Core no conoce criaturas, armas concretas, HUD ni tablas.

### Infrastructure
Comunicación externa.

- Supabase
- Auth
- Realtime
- persistencia local
- multiplayer

Infrastructure obtiene/guarda datos; no decide reglas de gameplay.

### Domain
Estado y modelo de Garlia.

- Entity/VitalState
- Player state
- Creature data
- Item data
- Inventory state
- Equipment state
- World data

Domain no conoce UI.

### Gameplay
Reglas.

- Input routing
- locomotion
- interaction
- combat
- inventory
- equipment
- dialogue
- missions
- relationships
- Eterium

Gameplay opera sobre estado del dominio y emite eventos.

### World
Mundo físico/lógico.

- WorldState
- generation
- chunks/streaming
- terrain data
- terrain rendering
- spawning
- atmosphere

World no decide inventario, UI ni daño.

### Presentation
Sólo representación.

- HUD
- inventory UI
- dialogue UI
- menus
- combat feedback
- world/entity visuals

Puede enviar comandos de usuario explícitos, pero no modificar estado interno de otros sistemas.

### Dev
Administración, debug y profiling.

---

## 3. Árbol objetivo

```
Main
├── World
│   ├── WorldGenerator / WorldRuntime
│   ├── Terrain
│   ├── Streaming
│   ├── EntityManager
│   └── Atmosphere
├── Entities
│   └── Player / Creatures / NPCs / Props
├── Gameplay
│   ├── InputRouter
│   ├── Movement
│   ├── Interaction
│   ├── Combat
│   ├── Inventory
│   ├── Equipment
│   ├── Dialogue
│   ├── Missions
│   ├── Relationships
│   └── Eterium
├── Presentation
│   ├── HUD
│   ├── InventoryUI
│   ├── DialogueUI
│   └── Menus
└── Dev
```

El SceneTree debe reflejar relaciones reales. Si un sistema es independiente, debe ser hermano y no hijo de un objeto que sólo coincide espacialmente.

## 4. Contratos

Cada sistema debe poder responder:

1. ¿Qué estado posee?
2. ¿Quién puede modificarlo?
3. ¿Qué recibe?
4. ¿Qué produce?
5. ¿Qué eventos emite?
6. ¿De qué sistemas depende?
7. ¿Qué sistemas NO puede conocer?

Si hay dos dueños para el mismo estado, hay duplicación.

---

## 5. Input

**Autoridad:** `GameplayInputRouter`.

Flujo:

`InputEvent → GameplayInputRouter → sistema que corresponde`

Prioridad actual de `primary_action`:

1. UI/modal bloquea gameplay.
2. InteractionSystem.
3. colocación.
4. CombatSystem.

`secondary_action` → CombatSystem.

Movimiento debe migrar progresivamente a la misma autoridad, evitando que Player y sistemas de gameplay lean acciones físicas para la misma intención.

### Para arreglar un click

Buscar en este orden:

`project.godot [input]`
→ `GameplayInputRouter`
→ sistema receptor
→ UI que pueda consumir el evento
→ sistema de estado correspondiente.

No comenzar por HUD.

---

## 6. Interaction

**Dueño:** InteractionSystem.

Responsabilidades:

- detectar objetivo contextual
- seleccionar objetivo
- determinar acción contextual
- solicitar la interacción

No crea misiones ni controla directamente el contenido de la misión.

Flujo:

`InputRouter → InteractionSystem → target → evento/acción → Mission/Dialogue/etc.`

El prompt visual pertenece a Presentation.

---

## 7. Dialogue

**Dueño:** DialogueSystem.

Debe:

- recibir datos de diálogo
- resolver líneas/variantes
- controlar el estado de diálogo
- emitir apertura/cierre

No debe convertirse en el dueño de misiones ni relaciones.

Una conversación puede provocar una acción de MissionManager o RelationshipSystem, pero mediante una frontera explícita.

---

## 8. Missions

**Dueño:** MissionManager.

Supabase/WorldData define la misión canónica.

MissionManager posee:

- estado de misión durante la partida
- progreso
- aceptación
- finalización
- recompensas pendientes

La UI sólo solicita:

`aceptar misión`

No escribe directamente el estado de misión.

---

## 9. Combat

Ruta única:

`Input → CombatController → CombatAttack → CombatTargeting → CombatDamage → Entity.take_damage()`

CombatDamage es el único camino de resolución de daño.

CombatFeedback sólo muestra el resultado.

CreatureAI no puede tener otro DamageSystem.

---

## 10. Inventory / Equipment / Hotbar

Tres estados distintos:

### InventoryRuntime
Qué objetos existen y cantidades.

### Equipment
Qué está equipado.

### Hotbar
Qué índices están asignados y cuál está seleccionado.

**Regla canónica:**

`hotbar_selected != equipped_item`

InventoryController coordina el runtime.

Inventory UI representa.

Combat consulta Equipment cuando necesita saber qué arma está equipada.

---

## 11. Entity

Entity posee estado físico común:

- vida
- mana
- vivo/muerto
- daño
- curación
- muerte
- profundidad visual de entidad

Entity no conoce:

- HUD
- misiones
- inventario
- Supabase
- implementación de ataques.

La profundidad de entidades pertenece al dominio/representación de entidades, no al renderer de terreno.

---

## 12. World

La generación debe separar:

`WorldData → Generation → WorldState/ChunkData → Rendering/Spawning`

### Generation
Calcula:

- bioma
- ecosistema
- habitat
- zona/terreno
- datos de chunk

### TerrainRenderer
Sólo dibuja.

TileMapDual es una implementación del renderer, no dueño del mundo.

### EntitySpawner / EntityManager
Crea y elimina entidades según datos del mundo.

### Atmosphere
Clima/estación/factores ambientales.

No mezclar estos roles.

---

## 13. Regla crítica de render

Orden conceptual:

```
TerrainRenderer
↓
World decorations
↓
Entity rendering / Y-depth
↓
Effects
↓
CanvasLayer UI
```

Cambiar TileMapDual no debe requerir modificar Player, Creature o WorldProp.

Si sucede, la frontera renderer/entity está mal definida.

---

## 14. WorldData

WorldData es el adaptador runtime del snapshot canónico del mundo.

Supabase puede actualizar:

- biomas
- ecosistemas
- habitats
- criaturas
- personajes
- diálogos
- misiones
- props
- demás datos canónicos exportados.

WorldData construye índices rápidos.

No debe decidir reglas de combate, movimiento o UI.

---

## 15. GameState

El GameState actual todavía concentra demasiadas responsabilidades.

Objetivo:

```
GameState (fachada temporal)
├── SaveState
├── PlayerState
├── WorldState
└── DiscoveryState
```

Migración gradual. No eliminar GameState hasta que todas sus dependencias hayan sido trasladadas.

---

## 16. Autoloads

Los autoloads actuales deben clasificarse:

### Apropiados como globales
- Events
- SupabaseClient
- WorldData
- Auth
- Multiplayer, si realmente es global
- SceneManager

### Revisar
- GameState
- MissionManager
- RelationshipSystem
- GarliaWorldItems
- sistemas que realmente pertenecen sólo a una partida/escena.

Un autoload no debe convertirse en un cajón de utilidades global.

Godot recomienda autoload sólo cuando el estado necesita persistir globalmente y puede existir de forma aislada; para sistemas que modifican otros sistemas se prefieren nodos/sistemas explícitos. 

---

## 17. Violaciones detectadas actualmente

### Main demasiado acoplado
`scripts/world/main.gd` actualmente configura HUD, Interaction, Combat, Inventory, Dialogue, IUM y cámara directamente.

Debe convertirse en **Composition Root**: crear/conectar/injectar dependencias, no ejecutar lógica de dominio.

### WorldGenerator demasiado grande
Actualmente coordina:

- terrain
- streamer
- entity spawner
- atmosphere
- seed
- queries de mundo
- contexto ambiental
- summon de criaturas

Debe convertirse en orquestador del mundo y delegar cada operación.

### WorldEntitySpawner conoce Main/Entities
Debe recibir un `EntityManager` explícito en lugar de buscar `current_scene/Entities`.

### InteractionSystem conoce HUD
Debe emitir estado/eventos y dejar que Presentation escuche.

### CombatSystem conoce Inventory mediante group lookup
Debe recibir una dependencia de Equipment/Inventory runtime.

### DialogueSystem consulta directamente MissionManager y RelationshipSystem
Debe recibir servicios/runtime explícitos.

### IUMManager hace HTTP directo a Supabase
Esto rompe la frontera Infrastructure → Runtime. Debe migrarse a un adaptador/repositorio Supabase común.

### WorldData mezcla snapshot local, cache y sincronización
Es útil como runtime actual, pero su responsabilidad debe separarse posteriormente en:
- WorldRepository
- WorldCache
- WorldRuntime.

### GameState mezcla save, estado de jugador, descubrimientos, UI/menu y bloqueo
Es el principal candidato a división progresiva.

---

## 18. Regla de dependencias

Permitido:

```
Core ← todos

Infrastructure → Core

Domain → Core

Gameplay → Domain + Core

World → Domain + Core + Infrastructure adapters

Presentation → Domain state + Gameplay events
```

No permitido:

```
Domain → UI
Domain → Supabase HTTP
TerrainRenderer → Entity internals
Entity → HUD
Entity → MissionManager
HUD → Supabase
HUD → modificar runtime arbitrario
Hotbar → Equipment
Combat → implementar inventario
CreatureAI → implementar daño paralelo
WorldGenerator → resolver misiones
```

---

## 19. Matriz de diagnóstico

| Problema | Dueño principal | Segundo lugar |
|---|---|---|
| Tecla/click no llega | GameplayInputRouter | project.godot / UI |
| Movimiento | Player + Locomotion | InputRouter |
| Interacción no detecta | InteractionSystem | Entity/groups |
| Prompt incorrecto | Presentation/HUD | InteractionSystem |
| Ataque no sale | CombatController | InputRouter |
| Ataque no golpea | CombatAttack/Targeting | Collision |
| Daño incorrecto | CombatDamage | Entity/VitalState |
| Arma equivocada | Equipment | InventoryController |
| Hotbar incorrecta | InventoryHotbar | Inventory UI |
| Item no aparece | InventoryRuntime | Inventory UI |
| Misión no aparece | MissionManager | Dialogue/Interaction |
| Diálogo no abre | DialogueSystem | InteractionSystem/UI |
| Criatura no aparece | EntityManager/Spawner | World/Streaming |
| Criatura incorrecta | Spawn rules | WorldData |
| Terreno no genera | Generation/Chunk | WorldData |
| Bioma incorrecto | Generation | WorldData/Supabase |
| Tile se ve mal | TerrainRenderer | TileMapDual |
| Entidad detrás del terreno | Entity depth/render layer | TerrainRenderer |
| HUD no aparece | Presentation | Main composition |
| Dato canónico incorrecto | Supabase/Data adapter | WorldData |
| Mundo desactualizado | WorldRepository/WorldData | Supabase Realtime |
| Guardado roto | SaveState/SaveRepository | GameState fachada |

---

## 20. Plan de migración

### Fase A — contratos
Crear documentación y fronteras.

### Fase B — Composition Root
Main sólo compone.

### Fase C — World
Separar WorldGenerator en:
- WorldRuntime
- ChunkGeneration
- TerrainRenderer
- WorldStreaming
- EntityManager
- Atmosphere.

### Fase D — Gameplay
Separar:
- Input
- Movement
- Interaction
- Combat
- Inventory
- Equipment
- Dialogue
- Missions.

### Fase E — Data
Separar:
- Supabase repositories
- World snapshot/cache
- runtime adapters.

### Fase F — Presentation
Eliminar lógica de gameplay de HUD/UI.

### Fase G — limpieza
Eliminar:
- lookups globales innecesarios
- duplicaciones
- sistemas legacy
- rutas paralelas.

### Fase H — validación
Cada sistema debe poder probarse/diagnosticarse de forma independiente.

---

## 21. Criterio de terminado

No consideramos una migración terminada porque "el juego abre".

Debe ser posible contestar:

- quién posee cada estado
- quién lo puede modificar
- qué dato es canónico
- qué evento comunica el cambio
- qué sistema ejecuta la regla
- qué sistema lo presenta
- qué archivos revisar ante un fallo

Si una respuesta requiere revisar varios sistemas sin una frontera clara, la arquitectura todavía no está terminada.
