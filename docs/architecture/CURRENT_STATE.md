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
- `WorldEntitySpawner` dejó de depender de `get_tree().current_scene/Entities` mediante inyección del root de entidades desde Main.
- `Main` dejó de crear DialogueSystem e IUMManager dinámicamente; ambos son nodos explícitos de la escena.
- `InteractionSystem` ya no conoce HUD; emite `objetivo_cambiado` y Main conecta la presentación.
- WorldTerrain, WorldTerrainVisual, WorldStreamer, WorldEntitySpawner y WorldAtmosphere ahora son nodos explícitos de `main.tscn`.
- WorldAtmosphere recibe su CanvasModulate como dependencia de escena.
- GameplayInputRouter recibe explícitamente InteractionSystem y CombatSystem.
- CombatSystem recibe explícitamente Inventory, WorldGenerator y root de proyectiles.
- InteractionSystem recibe explícitamente Inventory y GarliaWorldItems.
- `DialogueSystem` accede directamente a MissionManager y RelationshipSystem.
- `IUMManager` ya usa `IUMRepository → SupabaseClient` para acceso remoto.
- `GameState` coordina guardado/carga local; `PlayerState`, `WorldState` y `DiscoveryState` contienen los snapshots persistibles correspondientes.

### Supabase

El proyecto está activo y saludable.

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

Los advisors de Supabase también detectan deuda independiente de backend. Esa limpieza no se mezcla con esta refactorización del runtime.

## Cambios realizados en esta fase

1. Se creó `docs/architecture/GARLIA_ARCHITECTURE.md`.
2. Main dejó de crear DialogueSystem dinámicamente.
3. Main dejó de crear IUMManager dinámicamente.
4. DialogueSystem e IUMManager ahora son nodos explícitos de `scenes/world/main.tscn`.
5. IUMLab ahora también está declarado explícitamente en la escena.
6. WorldEntitySpawner dejó de buscar `current_scene/Entities`.
7. WorldGenerator recibe explícitamente el root de entidades desde Main.
8. Main actúa como Composition Root: conecta dependencias en vez de descubrirlas durante la ejecución.
9. Inventory separó InventoryRuntime, InventoryState, InventoryHotbar e InventoryEquipment como una única frontera de estado.
10. Combat usa la ruta canónica de ataque/proyectil y un root explícito de proyectiles.
11. Interaction recibe WorldEntityManager en vez de descubrir interactuables mediante SceneTree.
12. Se eliminó la capa no utilizada `GameStateFacade` y sus wrappers `PlayerRuntime`, `WorldRuntime` y `SaveState`. No eran consumidores del juego activo.

## Próximas fronteras

### Prioridad 1
Eliminar búsquedas de SceneTree para dependencias estructurales que todavía queden:

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
Mantener GameState como coordinador de persistencia y ciclo de vida local.

Ya no se busca crear otra fachada paralela. `GameState` ahora compone `PlayerState`, `WorldState` y `DiscoveryState`; estos objetos son los dueños de sus snapshots persistibles. GameState conserva únicamente la coordinación que realmente le pertenece:

- ciclo de vida de la partida local
- lectura/escritura del save
- coordinación de carga inicial
- metadatos de la partida
- eventos de guardado/descubrimiento cuando no exista un dueño mejor

Los estados de dominio nuevos sólo deben introducirse cuando exista un consumidor real y una autoridad clara.

### Prioridad 4
Revisar autoloads y dejar sólo estado realmente global.

### Prioridad 5
Mantener la documentación sincronizada con el código real y continuar la eliminación de descubrimiento implícito.

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

La ruta es:

IUMManager → IUMRepository → SupabaseClient → Supabase REST/RPC

IUMManager no debe contener URLs, API keys, HTTPRequest ni RPCs.
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

DialogueSystem ya no busca estos sistemas mediante `/root/...`.

GameState ya no busca Player/Inventory/WorldGenerator mediante grupos o la escena actual durante guardado/aplicación del estado.

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


### Limpieza estructural

Auditoría del árbol Git actual: 470 archivos, 65 directorios derivados y **0 directorios vacíos**. No hay carpetas que borrar; Git no conserva directorios vacíos por sí mismos.


## Quinta etapa — auditoría de dependencias y estado

Auditoría de seguimiento documentada en [ARCHITECTURE_AUDIT_2026-10-04.md](ARCHITECTURE_AUDIT_2026-10-04.md).

Cambios de esta pasada:

- Player, AdminConsole, RelationshipSystem y Main dejaron de acceder directamente a `GameState.flags`; GameState expone APIs de dominio para personaje, rol administrativo, relaciones, recuerdos y proceso IUM.
- SupabaseClient ya no inspecciona `current_scene/World/WorldGenerator` durante la sincronización periódica. Main declara explícitamente cuándo el mundo está activo.
- AdminPlayerEditor ahora es un nodo declarado en `scenes/world/main.tscn` y se inyecta a AdminConsole desde Main; ya no se busca ni crea dinámicamente.
- Main utiliza tipos concretos `WorldContext` y `WorldAtmosphere` para esas dependencias.

Pendientes estructurales principales: reducir responsabilidades de GameState, Player, HUD, AdminConsole y SupabaseClient después de inventariar sus consumidores; revisar los 13 autoloads por ownership; y completar la auditoría de scripts/escenas legacy. No se declara compilación validada hasta probar el proyecto en Godot.


La segunda barrida también migró las dependencias de UI anidadas: Inventory compone sus pestañas de mapa, relaciones, crafteo y administración; HUD inyecta Inventory en Hotbar; Main inyecta Inventory en PauseMenu y DeathMenu; y Main inyecta AdminConsole en IUMLab. Encyclopedia usa la API de GameState y Relationships usa una API pública de RelationshipSystem en lugar de leer su diccionario privado.

La deuda de descubrimiento global restante se concentra ahora principalmente en CreatureAI/Creature y en el flujo de WorldProp/WorldItem/GarliaWorldItems/WorldDecoration. Está enumerada en ARCHITECTURE_AUDIT_2026-10-04.md; no se debe interpretar esta pasada como una eliminación total de búsquedas por grupos.


La fase posterior a la auditoría de UI migró CreatureAI, Creature, WorldProp, WorldItem y GarliaWorldItems a dependencias explícitas. Main compone WorldGenerator/WorldEntityFactory con Player, Inventory, CombatSystem, DialogueSystem, MissionManager, WorldContext y el root Entities antes de iniciar la generación diferida. Las criaturas y props reciben datos antes de ser agregados al árbol, evitando inicialización incompleta y reconfiguración redundante después de `_ready()`. Detalles y validación pendiente en ARCHITECTURE_AUDIT_2026-10-04.md.


## Undécima barrida — cierre de fronteras encontradas en composición

Fecha: 2026-10-04

Se corrigieron dos inconsistencias que sobrevivían en el código real aunque la arquitectura documentada ya las daba por resueltas:

- `GarliaSalas.buscar_sala()` tenía la guarda de autenticación invertida. Ahora rechaza la operación cuando no existe `GarliaAuth` inyectado o no hay sesión válida.
- `GarliaSalas.cerrar_sala()` ahora también exige una sesión válida antes de realizar el PATCH.
- `Main._configurar_combate()` recibía sólo `WorldContext` pero utilizaba `world_gen` sin recibirlo como dependencia. Ahora la composición pasa explícitamente `WorldGenerator`.

Esto refuerza la regla de esta fase: si una dependencia es necesaria para ejecutar una operación, debe aparecer en el contrato de composición; no debe existir como variable implícita ni recuperarse de otra parte.

### Siguiente frontera

La siguiente pasada continúa con infraestructura y gameplay, pero primero se auditarán contratos de composición concretos antes de dividir monolitos. El orden será:

1. SupabaseClient: clasificar operaciones por dominio y distinguir transporte de operaciones de aplicación.
2. CombatSystem: comprobar qué parte de su orquestación ya pertenece a CombatController/Attack/Targeting/Damage.
3. Player: retirar sólo lógica que ya tenga dueño real.
4. HUD: separar presentación únicamente donde exista una frontera funcional clara.
5. Autoloads restantes: clasificar ámbito global vs. partida activa antes de mover cualquiera.

No se considera esta fase terminada hasta que el código y la documentación coincidan.


## Duodécima barrida — cierre de contrato de credenciales Supabase

Se corrigió una inconsistencia de composición detectada al validar `SupabaseClient`: tras mover la autoridad de credenciales a `GarliaAuth`, quedaban referencias a las antiguas constantes `SUPABASE_KEY` y `SUPABASE_URL`.

Ahora el contrato es coherente: `Main → SupabaseClient → GarliaAuth (credenciales) → Supabase`. `SupabaseClient` no declara ni mantiene una segunda copia de la URL/clave.

La división por dominio sigue deliberadamente pendiente hasta mapear consumidores; no se crearán repositorios paralelos sólo para reducir el tamaño del archivo.


## Decimotercera barrida — Player y CombatSystem sin estado global implícito

Se cerraron dos fugas de composición encontradas durante la revisión de Player/CombatSystem:

- Player ya no consulta GameState directamente en las operaciones administrativas; usa la referencia GameState inyectada en configurar_dependencias.
- CombatSystem recibe GameState desde Main y centraliza mediante una pequeña frontera interna el registro de criaturas derrotadas.
- Main queda como responsable de componer explícitamente esa dependencia.

No se movió la lógica de daño fuera de CombatDamage, ni se confundió la hotbar con el equipamiento. El objetivo de esta barrida es cerrar dependencias implícitas, no cambiar las reglas de combate.

Siguiente frente: revisar HUD y CombatSystem por responsabilidades de presentación/feedback que todavía estén mezcladas, y después continuar con los autoloads restantes.


## Decimocuarta barrida — HUD sin acceso global a GameState

HUD ya no consume directamente el autoload GameState para escuchar descubrimientos. Main inyecta GameState al HUD y HUD administra la conexión/desconexión de esa señal.

Esto mantiene al HUD como capa de presentación: recibe estado y eventos explícitamente, sin descubrir dependencias globales. No se trasladó lógica de descubrimiento al HUD.


## Decimoquinta barrida — HUD sobre contrato concreto de WorldContext

Se corrigió además una regresión de ciclo de vida introducida en la barrida anterior: cuando Main inyecta GameState después de `_ready()`, HUD conecta inmediatamente la señal `descubrimiento_mundo`. Así la presentación de descubrimientos no depende del orden accidental de inicialización.

HUD también dejó de tratar WorldContext como un objeto genérico con `has_method()/call()` para su API conocida. Ahora declara `WorldContext` explícitamente y utiliza sus métodos tipados para posición, chunk, seed, reinos, chunks cargados, tiempo y contexto ambiental.

Esto elimina una capa de descubrimiento innecesaria y hace visible el contrato real: `Main → HUD → WorldContext`. La compatibilidad dinámica queda reservada para fronteras donde todavía no existe un contrato tipado claro.

No se declara compilación validada hasta probar el proyecto en Godot.


## Decimosexta barrida — CombatSystem sobre contrato concreto de WorldContext

CombatSystem también dejó de tratar WorldContext como un Node genérico. La dependencia ahora está tipada como WorldContext y la pala utiliza directamente get_tile_at(), get_zona_at() y cambiar_zona_at().

Esto mantiene la regla de que las fronteras conocidas deben ser explícitas. No se movió todavía la lógica de inventario, ataque o daño: esas piezas se mantienen en sus dueños actuales para evitar una división artificial del sistema.

Siguiente objetivo: continuar reduciendo descubrimiento dinámico en CombatSystem y revisar sus responsabilidades de presentación/IA antes de tocar la resolución de daño.


## Decimoséptima barrida — SupabaseClient reduce duplicación de transporte

Se centralizó la creación de los HTTPRequest internos de SupabaseClient en una única función de infraestructura. Cada operación conserva su propio request y callback, pero la configuración común de timeout y pertenencia al nodo deja de repetirse siete veces.

No se creó todavía una capa de repositorios artificial: el siguiente paso es separar responsabilidades por dominio sólo cuando el código real y sus consumidores justifiquen esa frontera.


## Decimoctava barrida — SupabaseClient corrige frontera de credenciales REST

Se detectó y corrigió una referencia residual incorrecta al acceso de credenciales (`_auth._auth.SUPABASE_URL`) dentro del transporte REST compartido. SupabaseClient vuelve a depender únicamente de la API pública de `GarliaAuth` (`SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY`). También se centralizó la construcción de headers REST autenticados.

La corrección mantiene a GarliaAuth como dueño de credenciales y evita que SupabaseClient conozca la implementación interna de autenticación.


## Decimonovena barrida — CombatSystem entrega feedback a su frontera de presentación

Se confirmó que `CombatFeedback` ya existía como componente `RefCounted`; no se creó un sistema paralelo ni se añadió otro nodo a Main. Su implementación ahora contiene el flash visual de impacto que antes vivía dentro de `CombatSystem`.

`CombatSystem` conserva la resolución del ataque y el daño, pero delega la presentación del impacto a `CombatFeedback`. La composición principal no necesita conocer este detalle y no se introduce una nueva dependencia global.


## Vigésima barrida — CombatSystem deja de consultar EntityManager para IA

Se auditó la única ruta que usaba `WorldEntityManager` desde `CombatSystem`. El manager no expone actualmente una API de IA; la supuesta integración era sólo una búsqueda dinámica (`has_method/call`) con fallback al nodo `AIController` de la criatura. Se eliminó esa dependencia falsa y `CombatSystem` ahora consulta directamente el contrato estructural existente del objetivo.

Esto refuerza la frontera: `WorldEntityManager` administra ciclo de vida/ubicación de entidades; `CombatSystem` no le pide información que no pertenece a ese dueño.


## Vigésima primera barrida — CombatSystem usa contrato concreto de CreatureAI

Se confirmó que la IA real del proyecto es `CreatureAI` (`scripts/creatures/creature_ai.gd`), no un `AIController` tipado como clase independiente. `CombatSystem` ahora resuelve el nodo `AIController` una sola vez y lo convierte al contrato `CreatureAI`, eliminando `has_method()/call()` para `al_recibir_ataque_con_arma`.

La notificación de reacción al recibir un ataque sigue perteneciendo a la IA de la criatura, especialmente porque Zlish usa la información del arma para su comportamiento canónico.


## Vigésima segunda barrida — CreatureAI sin acceso directo a Supabase

Se eliminó la dependencia directa de CreatureAI sobre SupabaseClient para relaciones ecológicas. Main obtiene el snapshot disponible desde el cliente de infraestructura y lo entrega a WorldGenerator → WorldEntityFactory → Creature → CreatureAI durante la composición.

CreatureAI conserva únicamente la lectura y evaluación de esas relaciones durante el runtime. Ya no decide cómo obtenerlas ni conoce el transporte REST.

Además, WorldEntityManager quedó tipado directamente en CreatureAI y su consulta de entidades activas ya no usa has_method()/call().


## Vigésima tercera barrida — Relaciones ecológicas como dependencia inyectada y actualizable

CreatureAI ya no consulta SupabaseClient. Las relaciones ecológicas se cargan en la infraestructura y se propagan por la composición: Main → WorldGenerator → WorldEntityFactory → Creature → CreatureAI.

La carga es además reactiva: SupabaseClient emite `relaciones_ecologicas_cargadas` y WorldGenerator actualiza las criaturas activas mediante su factory. Así se evita que la IA conozca transporte, autenticación o cachés de infraestructura.

Durante esta barrida también se corrigió una regresión en `_crear_headers()` de SupabaseClient que había quedado recursiva, y las cabeceras REST vuelven a construirse directamente desde `GarliaAuth`.


## Vigésima cuarta barrida — WorldItems deja de ser dependencia global de criaturas

Se eliminó la dependencia implícita de `GarliaWorldItems` dentro de `Creature` y `CreatureAI`.

La composición queda:
`Main → WorldGenerator → WorldEntityFactory → Creature → CreatureAI`.

`WorldItems` se inyecta junto con el resto de dependencias del mundo. Esto evita que una criatura creada por el generador dependa de un autoload o nombre global para buscar objetos o generar drops.

Además, `WorldEntityFactory` y `Creature` ahora mantienen el contrato concreto de `WorldEntityManager`, y `Creature` usa directamente el contrato tipado de `CreatureAI` para configuración y reacción al daño.

La lógica canónica de objetos continúa fuera de la criatura: la criatura solicita al servicio inyectado la búsqueda/generación correspondiente y no conoce su ubicación global.


## Vigésima quinta barrida — Main refuerza contratos concretos de composición

Main dejó de tratar como Nodes genéricos tres dependencias cuyo contrato ya está confirmado: GarliaInventory, CombatSystem y DialogueSystem. También configura GarliaWorldItems directamente mediante su API concreta. Esto reduce reflexión innecesaria en el Composition Root sin convertir todavía en tipos artificiales los sistemas que aún no exponen un contrato de clase estable.

La regla se mantiene: sólo se elimina has_method()/call() cuando el contrato real fue verificado en el código.

## Vigésima sexta barrida — SupabaseClient endurece su frontera de credenciales

SupabaseClient ahora valida de forma centralizada que GarliaAuth esté inyectado y que las credenciales públicas necesarias existan antes de iniciar solicitudes REST/RPC compartidas o la sincronización del mundo. _crear_headers() también tolera una infraestructura todavía no configurada.

Esto evita accesos a _auth nulo durante arranques tempranos y mantiene a GarliaAuth como único dueño de las credenciales. No se trasladó ninguna regla de dominio a SupabaseClient.


## Vigésima séptima barrida — Player y HUD pasan a contratos concretos

Player y HUD ahora exponen clases explícitas para que Main pueda depender de sus contratos reales. Main dejó de usar reflexión para configurar al jugador, HUD e inventario en las rutas ya verificadas, y las llamadas directas a Player (`set_spawn_from_world`, `configurar_dependencias`, `get_jugador_id`, `equipar_proceso_ium`) sustituyen comprobaciones dinámicas.

No se extendió esta conversión a sistemas cuyo contrato todavía es Node/global sin clase estable. La reflexión restante queda como deuda localizada, no como objetivo de eliminarla mecánicamente.


## Vigésima octava barrida — CombatSystem reduce reflexión en inventario y ataques

CombatSystem ahora depende explícitamente de `GarliaInventory`, `CombatAttackArea` y `CombatProjectile` para las rutas de equipamiento, durabilidad, creación de hitboxes y proyectiles. Se retiraron `has_method()/call()` de esas fronteras ya tipadas. GameState conserva su llamada dinámica porque todavía no expone un `class_name` seguro y no se introduce una abstracción artificial solo para eliminar una línea dinámica.


## Vigésima novena barrida — Creature y proyectiles eliminan instanciación dinámica conocida

`Creature.crear_rastro_teleport()` ahora instancia `CreatureTeleportTrail` directamente y configura su contrato concreto. `CombatSystem` hace lo mismo con `CombatProjectile`; se elimina `set_script()` para una clase que ya estaba declarada con `class_name`. Esto reduce reflexión y mantiene los recursos como dependencias tipadas cuando el contrato ya existe.
