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

**Resolución única de daño:** `CombatDamage.aplicar()` es el único resolver autorizado que entrega daño a `Entity.take_damage()`. No deben existir fórmulas paralelas ni escrituras directas de salud desde gameplay.

Los caminos de entrada dependen del tipo de acción:

- Melee: `Input → CombatController → CombatSystem → CombatAttackArea/Targeting → CombatDamage`.
- Proyectiles: `CombatSystem → CombatAttackExecutor → CombatProjectile → CombatDamage`. El proyectil ejecuta el impacto y notifica el resultado; no implementa otra fórmula de daño.
- IA e IUM: solicitan daño a `CombatSystem.solicitar_danio_desde_entidad()`, que valida la solicitud y delega en `CombatDamage`.

La API de daño de entidad exige que el objetivo pertenezca al grupo `damageable`; una entidad fuera de ese contrato se rechaza antes de emitir contacto o efectos. Garumis no pertenecen a ese grupo. `CreatureAI` los excluye de selección de objetivos, persecución y relaciones ecológicas, incluso con políticas generales como `objetivos="todo"`; tampoco pueden convertirse en objetivo hostil por referencias especiales de liberación o por búsquedas de amenazas. No basta con que un nodo herede de `Entity` o `Creature`, ni que conserve `is_alive=true`, para convertirlo en combatiente.

`CombatDamage.aplicar()` repite la validación de `damageable` como última frontera antes de modificar el estado vital. Así, una llamada directa desde un sistema nuevo no puede saltarse accidentalmente la política de objetivos que aplican `CombatTargeting` y `CombatSystem`.

CombatSystem coordina solicitudes y efectos de gameplay; CombatDamage resuelve el daño; Entity conserva su estado vital. Ningún sistema de IA, IUM, proyectiles o feedback puede crear un DamageSystem alternativo.

`Player.take_damage()` es la especialización del receptor: aplica la defensa de armadura y luego entrega el daño efectivo a vida o Eterium compartido. Durante `Player.State.DASH` rechaza el impacto por completo; fuera de ese estado no existe invulnerabilidad temporal adicional. La defensa no se vuelve a aplicar en `CombatDamage`, para evitar doble mitigación. Los ataques que necesiten saltarse defensa o invulnerabilidad requieren una regla explícita y no deben llamar directamente a `VitalState`.

---

## 10. Inventory / Equipment / Hotbar

Tres estados distintos, con una sola autoridad runtime:

### InventoryRuntime
Qué objetos existen, sus cantidades y durabilidad.

### Equipment
Qué objetos están equipados en ranuras de equipo. Equipar/desequipar desde el inventario es una transacción: el objeto equipado sale del inventario y el anterior vuelve al slot de origen; desequipar requiere espacio libre.

### Hotbar
Qué índices de inventario están asignados y cuál está seleccionado. Sus seis posiciones sólo pueden apuntar a la mochila (índices 6–11), nunca a las manos ni a espacios adicionales.

**Reglas canónicas:**

- `hotbar_selected != equipped_item`.
- La hotbar referencia objetos del inventario; no mantiene copias de objetos.
- InventoryRuntime posee la selección. La hotbar visual sólo refleja el índice activo.
- La UI conserva únicamente selección de inspección/arrastre y datos visuales temporales; nunca replica items, hotbar o equipo.

InventoryController coordina operaciones y permisos de interacción; InventoryRuntime aplica transacciones; InventoryState, InventoryHotbarState y EquipmentState poseen cada estado.

La definición estática de uso de objetos se valida en InventoryController. La UI sólo solicita esa validación con datos enriquecidos; la aplicabilidad concreta sigue dependiendo de los recursos actuales del actor y sólo el controlador aplica efectos.

Las armas y herramientas se leen desde las manos del inventario (izquierda 0–5 y derecha 12–17). Equipment sólo admite armadura en cabeza, torso y pies; la compatibilidad se valida en EquipmentState y InventoryRuntime, no sólo en la UI. CombatDefense suma defensa exclusivamente desde esas tres ranuras y admite datos en `estadisticas.defensa`, `propiedades_game.defensa` o `defensa` raíz, con precedencia para evitar dobles sumas.

La durabilidad se consume mediante operaciones explícitas del objeto equipado o de la mano. No se desgasta armadura automáticamente al recibir daño: esa regla no está definida y no debe inventarse durante una refactorización.

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

### IUMManager y su repositorio IUM
`IUMManager` ya delega las consultas a `IUMRepository`. El manager conserva reglas y estado runtime; el repositorio conserva transporte y adaptación de respuestas. Los efectos de daño se solicitan a `CombatSystem`, no se aplican desde el manager.

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


### Reaparición y animación de muerte

- `Player` conserva la referencia del tween de muerte para poder cancelarlo al reaparecer.
- Las rutas local y de red cancelan cualquier animación de muerte anterior antes de restaurar vida, movimiento y presentación. Un tween de una vida anterior no puede seguir escribiendo sobre el jugador ya reaparecido.
- `test_combat_temporal_contract` verifica reaparición inmediata, restauración de procesamiento/estado/cooldowns y estabilidad visual después de superar la duración de la animación anterior.
