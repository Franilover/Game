# Garlia — Auditoría del estado actual

Fecha: 2026-11-05

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
- CombatSystem recibe explícitamente InventoryController, WorldContext, root de proyectiles y GameState.
- InteractionSystem recibe InventoryController y GarliaWorldItems; no depende de la UI de inventario.
- InventoryController centraliza uso/consumo de objetos de mano y durabilidad; GarliaInventory sólo refleja esos cambios mediante señales.
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


## Trigésima barrida — InteractionSystem e Input Router refuerzan contratos de gameplay

`InteractionSystem` ahora expone `class_name` y recibe `Player`, `GarliaInventory`, `GarliaWorldItems` y `WorldEntityManager` con contratos concretos. La colocación y consumo de objetos ya no pasan por `has_method()/call()` cuando las APIs son propias y conocidas. `GameplayInputRouter` también expone `class_name` y tipa InteractionSystem, CombatSystem, GarliaInventory, DialogueSystem y HUD. Las interfaces todavía dinámicas externas (por ejemplo objetivos interactuables o AdminConsole) se mantienen hasta confirmar un contrato común real.


## Trigésima primera barrida — Hotbar y slots de equipamiento pasan a contratos concretos

`InventoryHotbar` ahora tiene `class_name` y consume `GarliaInventory` directamente. Los slots `InventorySlot` e `InventoryEquipmentSlot` también exponen contratos concretos; `Inventory` dejó de usar reflexión para crear, consultar, configurar y limpiar slots de equipamiento. La separación inventario/equipamiento/hotbar se conserva: la selección de hotbar no determina el arma equipada.


## Trigésima segunda barrida — GameState deja de tratar el runtime como Node genérico

`GameState` ahora mantiene contratos concretos para `GarliaInventory`, `Player`, `WorldContext`, `WorldAtmosphere` y `MissionManager`. También consulta directamente `WorldContext.get_tile_at()` y `WorldAtmosphere.obtener_tiempo()`. Se mantiene `GameState` sin `class_name` por ahora para no alterar el contrato de autoload existente; el estado sigue siendo coordinador de guardado y no dueño de reglas canónicas.


## Trigésima tercera barrida — Main, HUD, Inventory y Player consolidan contratos concretos

Se eliminó reflexión innecesaria en `GameplayInputRouter` y `Main`. `HUD` ahora recibe contratos concretos para Player, MissionManager, WorldEntityManager, Supabase y Inventory; su Hotbar también es concreta. `Inventory` y `AdminInventory` pasaron a contratos concretos para Player, WorldEntitySpawner, GarliaWorldItems y las pestañas de mapa/crafteo/relaciones. `Player` ahora usa contratos concretos para WorldContext, Inventory, IUMManager y WorldEntityManager. Se añadieron contratos nominales para IUMLab, PauseMenu, DeathMenu, CraftingUI, RelationshipsUI, WorldMapUI, IUMManager y RelationshipSystem.

`GameState` también eliminó reflexión de serialización/carga para Inventory, MissionManager, Player IUM y WorldAtmosphere. `Main` dejó de descubrir configuraciones mediante `has_method()/call()` en los sistemas que ya tienen contratos explícitos.


## Trigésima cuarta barrida — Main y gameplay reducen reflexión residual

`Main` quedó sin `has_method()/call()` para sus sistemas configurables; la única reflexión restante allí corresponde al contrato polimórfico de objetivos de interacción (`Creature`, `WorldItem`, `WorldProp`). `DialogueSystem` usa contratos concretos para Player, HUD, MissionManager y RelationshipSystem y llama directamente a las APIs sociales. `InteractionSystem` usa `GameplayInputGate` directamente. `GameState` quedó sin reflexión en guardado/carga de Inventory, MissionManager, Player IUM y WorldAtmosphere; permanece una frontera genérica para identificar criaturas derrotadas, porque `GameState` todavía acepta entidades polimórficas y no debe inventar un contrato único para todos los `damageable`.


## Trigésima quinta barrida — AdminConsole y WorldData consolidan contratos

`AdminConsole` ahora recibe contratos concretos para WorldContext, WorldEntitySpawner, WorldAtmosphere, Player, Inventory, EntityManager, AdminPlayerEditor y WorldItems. Sus comandos `/summon`, `/give`, `/time`, `/tp` y edición de jugador dejaron de usar reflexión runtime. `WorldData` ahora tiene `class_name` y sus consultas de criaturas/personajes son contratos concretos. `InventoryController` también dejó de configurarse mediante reflexión desde Inventory. Se mantiene reflexión únicamente en fronteras polimórficas aún no formalizadas, principalmente fuentes de diálogo y compatibilidad del GameState autoload.


## Trigésima sexta barrida — Fronteras de interacción y diálogo formalizadas

`DialogueSystem` ya no usa reflexión para su fuente: la fuente de diálogo canónica del gameplay es `Creature`, con acceso directo a datos, identidad, nombre, control de movimiento y seguimiento. `InteractionSystem` usa el contrato concreto de `Creature` para texto contextual. `Player` y `GameState` también dejaron de reflejar APIs de `Creature` para Eterium y registro de derrotas. La reflexión restante de Player hacia GameState se conserva deliberadamente mientras `GameState` siga siendo el autoload global sin `class_name`, evitando introducir una migración global innecesaria.


## Trigésima séptima barrida — Contratos HUD/Combate endurecidos

HUD tipa directamente `WorldData` y consume su snapshot mediante `world_data.mundo`, eliminando el acceso genérico `Node.get()`. `CombatSystem` tipa directamente `Player` y conecta `GameplayInputGate` mediante `player.input_gate`, eliminando la reflexión para descubrir esa dependencia. Se mantiene `GameState` como frontera global deliberada y no se amplían contratos polimórficos sin verificar sus implementaciones reales.

## Trigésima octava barrida — Contratos de entrada y daño endurecidos

`CombatController` ahora depende explícitamente de `GameplayInputGate` y llama su API concreta, eliminando la reflexión para consultar el bloqueo de entrada. `CombatDamage` ahora recibe `Entity` y usa directamente `is_alive`, `health` y `take_damage()`. La resolución de daño deja así de depender de descubrimiento dinámico dentro de la frontera de entidades.

## Trigésima novena barrida — Estado vital de combate tipado

`CombatSystem` consolida `Entity` como contrato de objetivo para la aplicación de ataques y deja de consultar dinámicamente `take_damage`, `is_alive` y su estado vital. La resolución continúa centralizada en `CombatDamage`; las fronteras que siguen siendo polimórficas (atacantes genéricos, GameState y absorción de Eterium) no se fuerzan sin verificar todos sus consumidores.

## Cuadragésima barrida — Targeting de combate tipado

La cadena de combate ahora mantiene el contrato `Entity` desde la detección hasta la resolución: `CombatTargeting` valida entidades vivas, y `CombatAttackArea`/`CombatProjectile` convierten explícitamente sus candidatos a `Entity` antes de continuar. Esto evita que nodos arbitrarios alcancen `CombatDamage`.

## Cuadragésima primera barrida — Texto de interacción centralizado

`Main` ya no inspecciona dinámicamente el objetivo contextual para construir el texto del HUD. `InteractionSystem` expone `obtener_texto_interaccion()` y mantiene la responsabilidad de presentar el contrato contextual hacia la capa de UI.

## Cuadragésima segunda barrida — Router de input tipado

`GameplayInputRouter` dejó de descubrir dinámicamente `InteractionSystem` y `CombatSystem`. Ambos contratos son concretos y ahora el router invoca directamente `procesar_accion_primaria()` y `procesar_accion_secundaria()`, manteniendo el router como única autoridad de entrada.

## Cuadragésima tercera barrida — GameState tipado en Player

`GameState` ahora tiene contrato explícito (`class_name GameState`) y `Player` dejó de depender de llamadas dinámicas para terreno, descubrimientos, configuración de personaje y guardado. La dependencia de estado de partida queda tipada desde la composición hasta el uso.

## Cuadragésima cuarta barrida — InteractionSystem y CombatSystem cierran la frontera de manos

Se eliminó la dependencia de presentación que todavía quedaba en la ruta contextual:

- `InteractionSystem` recibe `InventoryController` directamente desde `Main`.
- La UI `GarliaInventory` ya no es necesaria para que el gameplay consulte, use o consuma un objeto de mano.
- Las reglas de uso de consumibles (vida, stamina y Eterium), la validación de efectos y el consumo de cantidad ahora pertenecen a `InventoryController`.
- `InventoryController` emite `mano_objeto_cambiado` tras el uso, consumo o desgaste de una mano; `GarliaInventory` escucha el evento y actualiza slots, selección y presentación.
- El bloqueo de acciones sigue siendo responsabilidad de `GameplayInputRouter`/`GameplayInputGate`; la UI conserva su papel de bloqueo visual/modal.
- `CombatSystem` identifica explícitamente la mano usada: acción primaria = izquierda; acción secundaria = derecha. El consumo de durabilidad sigue esa misma mano, sin invertirla.

La regresión `CombatTemporalContract` ahora comprueba ambos casos de durabilidad. GitHub Actions ejecutó Godot 4.7, compilación de recursos y la suite headless de regresión para esta rama.

La separación de manos no cambia las reglas de combate ni el comportamiento de uso de consumibles; sólo mueve la operación a su dueño y corrige el destino de la durabilidad.

## Cuadragésima quinta barrida — Resolución de objetos y dirección de ataque

Se separó la interpretación de datos de objetos de la ejecución del combate:

- Se creó `CombatItemResolver` como componente puro para clasificar armas/herramientas, interpretar el modo de ataque y leer daño, alcance, ancho y otras propiedades numéricas.
- `CombatSystem` conserva la orquestación: valida la acción, crea el hitbox o proyectil y coordina el daño. Mantiene wrappers internos para no romper sus consumidores actuales.
- `CombatController` ya entrega dirección, objeto y modo en la solicitud. `CombatSystem` ahora conserva esa dirección durante la ejecución melee y a distancia; sólo consulta el facing actual cuando el vector recibido es inválido/cero.
- Se añadieron pruebas para clasificación directa y legacy, categorías anidadas, modo proyectil, valores por defecto y dirección recibida.
- GitHub Actions ejecutó la suite completa con Godot 4.7, incluida la prueba nueva de `CombatItemResolver` y el contrato temporal de combate.

No se alteraron fórmulas de daño, balance, alcance, categorías admitidas ni reglas de ataque; esta pasada separa lectura de datos y respeta el snapshot de dirección de la solicitud.

## Cuadragésima sexta barrida — Construcción de ataques separada de la orquestación

Se extrajo la creación y conexión de nodos de ataque a `CombatAttackExecutor`:

- `crear_ataque_melee()` construye/configura `CombatAttackArea`, aplica el override de daño directo, conecta el callback de objetivo y agrega el hitbox al atacante.
- `disparar_proyectil()` construye `CombatAttack` y `CombatProjectile`, establece la posición inicial, configura movimiento/vida/colisión y conecta las señales de contacto e impacto.
- `CombatSystem` conserva las decisiones de combate, selección de objeto, cooldown, feedback, daño, agresión ecológica, absorción de Eterium y registro de derrotas. Sólo delega la construcción/instanciación.
- Se añadió `test_combat_attack_executor.tscn`, que verifica la creación melee y a distancia, dirección, propiedades, override de daño, root de proyectiles y conexiones de señales.
- GitHub Actions validó la importación de Godot 4.7 y la suite completa, incluida la nueva prueba del executor.

La extracción mantiene el orden de configuración y adición de nodos que ya utilizaba `CombatSystem`. No altera daño, cooldown, velocidad, alcance, duración, posición inicial ni reacciones posteriores al impacto.


## Cuadragésima séptima barrida — Efectos posteriores al impacto separados

Se extrajeron los efectos que ocurren después de confirmar una reducción real de salud a `CombatImpactEffects`:

- Reacciones de `CreatureAI` ante armas.
- Registro de derrotas mediante `GameStateService`.
- Marcadores de agresión ecológica del bosque.
- Feedback visual del objetivo.
- `CombatSystem` sigue siendo dueño de las rutas de daño, contacto, cooldown, eventos públicos, absorción de Eterium y robo de vida.
- `CombatDamage` permanece como única capa que reduce salud. `CombatProjectile` conserva su contrato: publica el contacto por separado y emite el impacto consumible únicamente si la salud disminuyó.
- Se añadió una regresión para agresión ecológica, registro en enciclopedia y dependencias nulas, integrada en GitHub Actions.

La extracción no agrega otra aplicación de daño ni unifica artificialmente los caminos melee, proyectil y ataque de criatura. Se preservan los momentos y condiciones actuales de cada efecto.

## Cuadragésima octava barrida — Resultado de impacto unificado y atribución

Se consolidó en `CombatImpactEffects.procesar_impacto_confirmado()` la parte compartida de los tres caminos de daño confirmado:

- Melee y armas de entidades llaman al mismo procesador después de que `CombatDamage` confirma una reducción real de salud.
- Los proyectiles llaman al mismo procesador desde `objetivo_impactado`; el proyectil sigue siendo quien aplica el daño, así que no existe una segunda aplicación.
- Las derrotas de criaturas se registran desde las tres rutas. La agresión ecológica se atribuye al jugador atacante sin depender de que la víctima tenga un AIController.
- El jugador recibe absorción de Eterium cuando él es el atacante que derrota a la criatura, también mediante proyectil. Las derrotas causadas por criaturas/NPC no se atribuyen por defecto al jugador.
- Las reacciones de IA se notifican para impactos con arma contra criaturas que sobreviven; el feedback visual se procesa una sola vez.
- La curación por robo de vida del vampiro y los eventos públicos de combate permanecen en `CombatSystem`.
- La prueba cubre la absorción por derrota de jugador, la agresión de Feerin, el registro de derrota, las reacciones de IA y la no atribución al jugador de derrotas causadas por NPC.

El procesador solo recibe impactos ya confirmados. No modifica vida, fórmulas, defensa, cooldown, ni el contrato de contacto independiente del daño.

## Cuadragésima novena barrida — Señales entre Creature y CreatureAI

Se eliminó la llamada directa de `Creature` a `CreatureAI` para notificar cambios de configuración y daño recibido:

- `Creature` emite `configuracion_actualizada` al terminar de aplicar nuevos datos de especie.
- `Creature` emite `danio_recibido(cantidad, atacante)` después de que `Entity` confirma una reducción real de salud. La emisión también sucede para impactos letales y conserva el atacante durante el evento.
- `CreatureAI` se suscribe a ambas señales al iniciar: actualiza perfil/configuración y ejecuta sus reacciones defensivas/especializadas.
- `Entity` conserva el estado vital; `Creature` lo extiende con datos de especie; `CreatureAI` conserva percepción, selección de objetivo, máquina de estados y decisiones de ataque.
- `CombatSystem` continúa siendo el ejecutor de ataques solicitados por IA y el punto de coordinación del daño. No se movieron fórmulas, cooldowns, perfiles ni reglas de criaturas.
- Se añadió una regresión con la escena real de criatura: comprueba actualización de perfil, reducción de salud, cantidad/atacante emitidos y reacción de Espíritu Estelar al recibir daño.

La comunicación de configuración/daño es ahora un contrato de señales; se mantienen las otras dependencias explícitas de composición y control de simulación que todavía necesita `Creature`.


## Quincuagésima barrida — Validación de solicitudes y resultado de ataque explícito

Se separó la validación de ataques con arma de su ejecución y se dejó de representar todo el resultado con un booleano:

- CombatWeaponAttackValidator valida atacante, objetivo vivo y clasificación del arma. No emite eventos ni aplica daño.
- CombatSystem.solicitar_ataque_con_arma() ejecuta únicamente solicitudes válidas y devuelve CombatAttackResult.
- CombatAttackResult separa cuatro datos: solicitud aceptada, contacto registrado, daño aplicado y motivo de rechazo.
- CombatSystem._aplicar_danio() ahora devuelve si CombatDamage confirmó una reducción real de salud; sus consumidores que no necesitan el valor conservan el mismo comportamiento.
- CreatureAI consulta solicitud_aceptada para mantener la reacción de Cambiaformas. La copia de apariencia conserva su condición previa: se realiza al aceptar la solicitud, no depende de que el daño sea mayor que cero.
- Se mantiene atacar_objetivo_con_arma() como wrapper booleano de compatibilidad; su true significa solicitud aceptada, no daño aplicado.
- La regresión verifica validación de entradas, rechazo de objetivos derrotados, contacto aceptado con daño cero y daño real aplicado exactamente una vez.

No se modificaron daño, alcance, cooldown, clasificación de armas ni reglas de Cambiaformas. La separación aclara el contrato sin cambiar las condiciones de gameplay.


## Quincuagésima primera barrida — Resultado tipado para ataques genéricos de entidades

Se aplicó el mismo contrato explícito a las solicitudes de ataque genérico que usa CreatureAI:

- CombatSystem.solicitar_danio_desde_entidad() devuelve CombatAttackResult: distingue solicitud aceptada, contacto registrado, daño aplicado y motivo de rechazo.
- La API registra el contacto de una solicitud válida aunque la cantidad sea cero; sólo declara daño aplicado cuando CombatDamage confirma una reducción real de salud.
- aplicar_danio_desde_entidad() permanece como wrapper booleano para consumidores existentes. Conserva su significado histórico: true únicamente cuando se redujo salud.
- CreatureAI._aplicar_danio_objetivo() ahora devuelve el resultado tipado y distingue objetivo inválido de CombatSystem no disponible.
- Lignianos aplica el slow sólo cuando el resultado confirma el contacto. El efecto no depende de que el daño sea mayor que cero.
- Los efectos posteriores al impacto y el robo de vida del Vampiro siguen ejecutándose únicamente después de daño real confirmado.
- Se añadió una regresión para daño cero, daño real, wrapper booleano, atacante nulo y objetivo derrotado.

No se cambió la fórmula de daño, la defensa, el cooldown ni la cantidad de daño configurada por especie. Se unificó el contrato de resultados y se conserva la API anterior.


## Quincuagésima segunda barrida — Ciclo de vida de muerte en Entity

Se corrigió una transición inconsistente entre VitalState y Entity:

- VitalState.recibir_danio() marca is_alive = false al llegar a cero.
- Entity.take_damage() sincroniza ese estado antes de llamar a _die().
- Antes de la corrección, _die() interpretaba el estado ya sincronizado como una muerte procesada y retornaba sin emitir died.
- Entity ahora usa un guard independiente (_death_emitted) para emitir la señal exactamente una vez por transición de vida a muerte.
- Restaurar una partida muerta no reproduce died; restaurar una entidad viva rearma el evento para su siguiente muerte.
- Se añadió EntityLifecycleContract para comprobar muerte letal, daño posterior, idempotencia, restauración viva y restauración muerta.

La corrección no cambia el cálculo de daño ni las reglas de combate. El alcance de la señal se limita al ciclo de vida de Entity; las subclases que implementan su propio _die() conservan su lógica.


## Quincuagésima tercera barrida — Estado vital coherente en Creature

Se cerró una inconsistencia entre la configuración de criaturas y el estado vital heredado:

- \`Creature.configurar()\` antes actualizaba \`health\`, \`mana\` e \`is_alive\` directamente, pero podía dejar \`VitalState.max_health/max_mana\` con los valores anteriores cuando la configuración llegaba después de \`_ready()\`.
- La configuración ahora usa \`_configurar_estado_vital()\`, que restablece el snapshot vital completo y rearma el guard de muerte de \`Entity\`.
- \`Creature._die()\` conserva sus efectos específicos de criatura (misión, drops, movimiento y desaparición), pero delega la emisión de \`died\` a \`Entity._die()\` para reutilizar el guard idempotente común.
- Se amplió \`CreatureAISignalContract\` para configurar una criatura con 140 HP, verificar que \`Creature\` y \`VitalState\` coincidan, y comprobar una única señal \`died\` ante muerte letal y llamada repetida.
- El workflow ya ejecuta esa prueba; no se afirma CI validado hasta disponer de un resultado publicado para el commit actual.

No se cambian estadísticas canónicas, daño, recompensas ni comportamiento de IA. La restauración viva completa de una criatura (visibilidad, movimiento y estado de IA) sigue fuera de esta corrección y requiere un contrato propio si se incorpora al flujo de juego.


## Quincuagésima cuarta barrida — Validación estructural compartida de snapshots

Se reemplazó la validación mínima que solo comprobaba la existencia de \`biomas\` por un contrato compartido:

- Se creó \`WorldSnapshotValidator\`, usado tanto por \`WorldDataService\` como por \`GarliaSupabaseClient\`.
- Exige que el snapshot contenga biomas y que la jerarquía bioma → ecosistemas → habitats → criaturas mantenga arreglos y registros con IDs; las criaturas deben incluir nombre.
- Valida el tipo de los catálogos opcionales cuando están presentes (\`personajes_game\`, \`dialogos_game\`, \`misiones_game\`, \`reinos_game\`, \`props_game\`, \`lugares_game\`, \`garumis_game\`).
- No exige que cada nodo tenga descendientes: un ecosistema o hábitat sin hijos sigue siendo una estructura válida.
- Se añadió \`WorldSnapshotValidatorContract\` con casos válidos e inválidos y lectura del snapshot incluido \`data/world_initial.json\`.
- La prueba quedó incorporada al workflow Godot 4.7. No se declara validación CI hasta disponer de un resultado publicado.

La validación solo rechaza estructuras incompletas o mal tipadas; no transforma, corrige ni escribe datos en Supabase. La autoridad de los datos permanece en la fuente canónica.


## Quincuagésima quinta barrida — Restauración coherente de Player y Eterium

Se corrigieron rutas que modificaban las propiedades públicas de \`Player\` sin actualizar el \`VitalState\` que usa el combate:

- \`Entity.restaurar_estado_vital()\` ahora puede restaurar salud y maná en una sola operación, aplica límites y rearma el guard de muerte según el estado restaurado.
- \`GameStateService\` restaura salud/maná mediante ese método; ya no escribe directamente \`health\`, \`mana\` e \`is_alive\` ni duplica sus señales.
- \`Player.restaurar_eterium()\` delega en \`PlayerEteriumCoordinator\`; el daño de fisiología compartida también modifica Eterium mediante el coordinador.
- Las reapariciones local y de red usan el dueño de estado \`Entity\`, evitando que el siguiente daño lea reservas antiguas y rearmando la siguiente transición de muerte.
- Los máximos administrativos actualizan \`VitalState\` y el controlador de stamina; en fisiología compartida vida y Eterium conservan una misma capacidad.
- La absorción de Eterium ahora recupera también la vida cuando la fisiología es compartida y no permite recuperar recursos en una entidad muerta.
- Se ampliaron \`EntityLifecycleContract\` y se añadió \`PlayerVitalStateContract\` para restauración, daño normal/compartido, muerte, reaparición, absorción y límites administrativos.

No se cambian fórmulas canónicas ni datos de Supabase. Las pruebas están integradas al workflow, pero todavía no se declara CI validado para esta revisión.
