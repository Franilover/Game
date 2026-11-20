# Garlia — Auditoría del estado actual

Fecha: 2026-11-16

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

Datos relevantes del último recuento documentado (2026-11-05):

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

## Cuarta etapa — Combat ↔ Inventory hands

La implementación actual lee el objeto de la mano izquierda (slots 0–5) para la acción primaria y de la mano derecha (slots 12–17) para la secundaria. La hotbar (slots 6–11) no decide qué arma se usa.

La durabilidad de herramientas se descuenta del slot de mano que ejecutó la acción. Las armaduras sólo pueden equiparse en cabeza, torso y pies; InventoryRuntime valida tipo y ranura antes de intercambiar objetos, por lo que la regla no depende de la UI.

CombatDefense sólo suma defensa de esas tres ranuras y reconoce `estadisticas.defensa`, `propiedades_game.defensa` y `defensa` raíz sin sumar dos veces el mismo valor. Las entradas antiguas de manos/equipo no otorgan defensa.

Se eliminó de CombatSystem la búsqueda obsoleta de armas dentro de Equipment y su modo heredado `mano_secundaria`: las armas activas provienen exclusivamente de las manos del inventario.

La durabilidad de armadura puede consumirse explícitamente, pero no se desgasta al recibir daño. No se implementó desgaste automático porque todavía no existe una regla de diseño confirmada.


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


## Quincuagésima sexta barrida — Agotamiento de Eterium compartido

Se cerraron rutas adicionales del runtime de Eterium:

- La configuración de una especie con vida/Eterium compartidos aplica primero la capacidad vital y después establece la barra llena, evitando emitir una muerte transitoria durante la configuración.
- Cuando una operación del runtime agota la barra compartida, el adaptador de \`Player\` sincroniza el estado y procesa la muerte mediante \`Entity._die()\`.
- La animación de muerte de Player tiene guard propio para no iniciar varios tweens por una misma transición; ambas rutas de reaparición la rearman.
- La recuperación pasiva y la absorción ya no emiten señales duplicadas desde Player cuando el runtime ya notificó el cambio.
- \`PlayerVitalStateContract\` comprueba que gastar toda la reserva compartida mata al jugador, que la absorción no revive una entidad muerta y que la reaparición de red restaura las reservas.

No se modifican costes, tasas, capacidades canónicas ni datos remotos. La validación automatizada sigue pendiente de un resultado CI visible.


## Quincuagésima séptima barrida — Protección del respaldo ante recuperación bloqueada

Se cerró un caso límite del repositorio de guardados:

- Si el archivo final está dañado o ausente y existe un \`.bak\` válido, \`leer_partida()\` devuelve ese estado e intenta restaurarlo.
- Si el filesystem impide completar el reemplazo (por ejemplo, el destino está bloqueado), \`escribir_partida()\` ahora detecta que el respaldo válido sigue siendo la única copia recuperable y cancela la nueva escritura.
- Se amplió \`SaveFileRepositoryContract\` para simular un destino que es un directorio, comprobar que el respaldo se puede leer y verificar que una escritura posterior fallida no lo elimina.

La prueba cubre recuperación y preservación del respaldo; no sustituye pruebas de apagado abrupto ni de fallos físicos de disco. Pendiente ejecución CI.


## Quincuagésima octava barrida — Restauración segura del progreso de misiones

- `MissionManagerService.cargar_estado_partida()` valida los estados guardados contra los estados reconocidos por el runtime y normaliza estados desconocidos a `disponible`.
- El progreso se reconstruye usando los objetivos del catálogo actual: cantidades negativas pasan a cero, valores superiores se limitan al requisito y los objetivos que ya no existen se descartan.
- Los datos de progreso con tipos incorrectos se rechazan sin romper la carga de la partida.
- Se añadió `MissionManagerContract` para verificar normalización, serialización, finalización idempotente y emisión única de `recompensa_disponible`.
- El workflow Godot 4.7 ejecutó el nuevo contrato correctamente en el run `42213469008`.
- En esa barrida, la aplicación efectiva de recompensas seguía pendiente; quedó resuelta en la sexagésima primera barrida, usando el catálogo canónico de items y sin modificar Supabase.



## Quincuagésima novena barrida — Transacción segura al soltar objetos

- `GarliaInventory` separa ahora la posición del puntero de la operación de transferencia mediante `_soltar_objeto_en_posicion()`; la entrada de UI solo proporciona la posición.
- La operación devuelve un resultado y solo retira el objeto del inventario cuando `GarliaWorldItems` confirma que el `WorldItem` fue registrado por `WorldEntityManager`.
- Se añadió `InventoryDropContract` para simular infraestructura ausente y verificar que el inventario conserva ID y cantidad cuando el drop falla.
- El contrato pasó en el run CI Godot 4.7 `42213469008`.
- Esta corrección no modifica el formato de los objetos ni los datos canónicos.



## Sexagésima barrida — Persistencia, inventario y progresión validados

- `SaveFileRepository` ya valida el tamaño UTF-8 realmente escrito en el temporal; no usa `get_error()` como indicador de éxito después de escribir, porque el cursor al final puede representar `ERR_FILE_EOF`.
- El lector usa `JSON.parse()` con instancia para tratar archivos corruptos como una condición recuperable sin contaminar la consola con un error global.
- `InventoryController.soltar_objeto_al_mundo()` es dueño de la transacción: toma el objeto actual desde `InventoryRuntime`, crea/registra el `WorldItem` y solo después descuenta el slot.
- La UI ya no entrega una copia potencialmente obsoleta del objeto arrastrado; solo entrega índice y posición.
- `MissionManagerService.cargar_estado_partida()` valida estados y progreso contra los objetivos vigentes, limita cantidades y descarta referencias de objetivos inexistentes.
- Contratos ejecutados: `SaveFileRepositoryContract`, `InventoryPickupContract`, `InventoryDropContract` y `MissionManagerContract`.
- CI completo Godot 4.7: **success**, run `42213469008`, commit de código `820d1b3c854f60ee110509586ceb2ec8e9c3bc01`. También pasaron locomoción, combate, IA, ciclo de vida, snapshot y terreno.
- Pendiente funcional en esa barrida: aplicar/reclamar recompensas con el esquema canónico correcto. La siguiente barrida documenta la resolución; esta barrida histórica no modificó Supabase.



## Sexagésima primera barrida — Compilación Godot 4.7 y recompensas canónicas

- Se corrigió la inferencia de tipo del token en Crafteo para Godot 4.7.
- `GarliaAuth` ahora usa la clave publicable solo en `apikey` para login/refresh; Crafteo agrega `Authorization: Bearer` únicamente si existe un JWT real.
- `CombatItemResolver` reconoce categorías de arma descriptivas como `arma especial`.
- El test climático se ejecuta como escena del proyecto para disponer de autoloads; el test de locomoción se ejecuta en escena y compara recursos importados con ResourceLoader.
- `GarumiHub` incluye subpestañas Vínculos y Garudex; la tecla G abre Vínculos y el catálogo queda accesible desde la misma sección.
- El catálogo de pruebas usa sprites que existen en el repositorio (`Desell`, `Velki` y `Plava`), sin crear arte sustituto.
- Se protegió `MissionManagerService.entregar_recompensas()` con un bloqueo transaccional. El rollback de una entrega parcial ya no programa reintentos recursivos a través de `inventory_changed`.
- Las recompensas canónicas que contienen solo `item_id` se resuelven mediante `GarliaWorldItems.buscar_item_por_id()`. Si el catálogo aún está cargando, la recompensa permanece pendiente y se reintenta al recibir `catalogo_cargado`.
- La consulta de solo lectura a Supabase confirmó que la misión activa «Conocer a Abel» recompensa una Espada de Madera mediante UUID y que `datos` está vacío; `items` + `items_game` aportan nombre, tipo, max_stack y propiedades.
- Se añadieron `MissionRewardDelivery` y pruebas para rollback, ausencia de reintentos recursivos, resolución por UUID e idempotencia.
- CI Godot 4.7: **PASS**, run `43916861872`, 33 pasos completados sin fallos.
- Rama de trabajo: `fix/p0-godot47-crafting-token-type`. PR #12 sigue en borrador. Sin cambios en `main` ni mutaciones de Supabase.
- Pendiente: validar continuidad de una partida real tras entregar recompensa, offline end-to-end, pruebas visuales Android/PC y flujos NPC/móvil con dispositivo real.


## Sexagésima segunda barrida — Interacción móvil de diálogos

- `GarliaMobileControls` consulta el grupo `dialogue_system` antes de capturar toques del joystick. Mientras hay un diálogo abierto, el joystick no roba toques destinados a botones o respuestas.
- Si el diálogo se abre mientras el joystick mantiene una dirección, el control libera el dedo y emite las acciones de movimiento en estado neutral.
- `DialogueSystem` adapta el panel al viewport: ancho/alto, márgenes, retrato, tamaños de botones sociales, acciones principales y columnas de selectores.
- En pantallas estrechas se oculta el retrato para conservar espacio de texto y se pasa el selector de objetos a una columna; en paisaje compacto recupera el retrato reducido y dos columnas.
- Se añadieron `MobileControlsDialogueTouch` y `DialogueMobileLayout` para verificar bloqueo del joystick durante diálogo, liberación de movimiento, multitáctil y medidas en 360×640, 640×360 y 960×540.
- CI Godot 4.7: **PASS**, run `43918828793`, 35 pasos completados sin fallos.
- La validación headless no sustituye la prueba en dispositivo Android: falta revisar safe areas, orientación real, tamaño físico de botones y legibilidad en varios DPI.


## Sexagésima tercera barrida — Colisiones de NPC en entradas

- `NPCScheduleSystem._marcar_npc_dentro_edificio()` oculta al NPC que llega al umbral y ahora desactiva también sus `collision_layer` y `collision_mask` del exterior. Así, el cuerpo invisible no bloquea la puerta para otros NPC.
- `ReinoTorres` conserva los valores originales de capa/máscara y los restaura al salir del edificio; al trasladar NPC al interior recupera las capas y formas de colisión que correspondían.
- Los NPC que abandonan su rutina mientras el jugador permanece dentro siguen sin colisionar en el exterior oculto; al salir el jugador se restaura su estado según si continúan dentro o ya salieron.
- Los NPC materializados mientras un interior está abierto también quedan sin colisión exterior hasta restaurar el mundo.
- Se añadió `NPCBuildingEntryCollision` para verificar la desactivación de colisión exterior, la restauración de capas/máscaras y la recuperación de formas al entrar.
- CI Godot 4.7: **PASS**, run `43920496439`, 36 pasos completados sin fallos.
- Falta una prueba visual en Reino Torres con varios NPC dirigiéndose simultáneamente a la misma puerta; el contrato confirma el ciclo de colisiones, no la navegación física completa.


## Sexagésima cuarta barrida — Continuidad del menú social

- `DialogueSystem._cerrar_selector_conversacion()` reconstruye las cuatro acciones principales cuando se cierra el selector social.
- Después de responder a un tema cotidiano, al terminar de mostrarse la respuesta vuelven a aparecer `Preguntar`, `Hablar`, `Dar cumplido` y `Despedirse`.
- El test `DialogueSocialMenu` ya se ejecuta como escena del proyecto y verifica tanto el cierre del selector como la recuperación del menú después de una respuesta casual.
- Se amplió el filtro de CI para incluir `tests/dialogue/**`; los contratos de diálogo no volverán a quedar fuera de la batería por un filtro de rutas.
- CI Godot 4.7: **PASS**, run `43921504449`, 37 pasos completados sin fallos.
- La prueba sigue siendo headless; queda validar la experiencia con Ivo, Mara y Nira dentro de una partida real, incluyendo interrupciones, regalos y preguntas.


## Sexagésima quinta barrida — Recuperación del catálogo de especies

- La consulta de solo lectura a Supabase confirma tres filas activas en `especies_jugables`: Feerin, Humano y Necromancer. La tabla concede SELECT a `anon` y `authenticated`, y la política pública filtra `activo = true`; no se modificó la base de datos.
- El cliente ya cacheaba y reemitía el catálogo, pero si la respuesta REST era válida y vacía agotaba los tres intentos iniciales y dejaba de comprobar automáticamente. Si el fallo ocurría mientras la pantalla de creación seguía abierta, podía permanecer sin especies hasta que otra escena volviera a solicitar el catálogo.
- Ahora una respuesta vacía se comunica a la UI y mantiene una recuperación automática: tres intentos rápidos y, agotados estos, una nueva comprobación cada 30 segundos. Las respuestas válidas no vacías se guardan en caché y reinician el contador.
- Se añadió `SpeciesCatalogRetry` para verificar caché, emisión de catálogo y programación de recuperación después de una respuesta vacía.
- CI Godot 4.7: **PASS**, run `43923629275`, 39 pasos completados sin fallos.
- Esta prueba cubre el manejo local de respuestas, no la llamada REST en red ni la visualización en un dispositivo. Sigue pendiente validar el selector dentro del flujo real de creación de personaje en Android/PC.


## Sexagésima sexta barrida — Cargas después de restaurar sesión

- `GarliaAuth` restaura la sesión de forma asíncrona. Los primeros intentos de `GarliaSupabaseClient` para catálogos protegidos podían ocurrir antes de que el refresh terminara; al iniciar sesión manualmente tampoco se repetían automáticamente todas esas cargas.
- `GarliaSupabaseClient.configurar_dependencias()` ahora escucha `session_restored` y `login_succeeded`. Si la sesión ya está autenticada al inyectar la dependencia, también programa la carga.
- Al quedar disponible la autenticación se solicitan Eterium runtime, reglas Eterium por especie, reglas sociales, preferencias de regalos, relaciones ecológicas y reinos. Cada HTTPRequest comprueba que no haya otra petición en curso antes de iniciar una nueva.
- Se añadió `AuthenticatedCatalogReload`, que verifica el caso de sesión ya autenticada, la señal de restauración y el login normal, comprobando que cada catálogo se solicite una sola vez por evento.
- CI Godot 4.7: **PASS**, run `43924866198`, 40 pasos completados sin fallos.
- La prueba valida la coordinación de señales con un fixture, no el refresh real ni las respuestas de red. Falta comprobar una sesión persistida real y la disponibilidad efectiva de cada endpoint.


## Sexagésima séptima barrida — Ritmo y coherencia de diálogo en tránsito

- El texto de diálogo de NPCs cuya rutina indica caminar, pasear o desplazarse ahora se revela a 0,028 s por carácter (aprox. 36 caracteres por segundo), frente al intervalo general de 0,006 s.
- Los diálogos marcados explícitamente como tránsito dejan la última línea visible 2,5 s después de terminar de revelarse, en vez de cerrarse inmediatamente.
- La despedida distingue el desplazamiento del trabajo: el NPC que camina continúa hacia su destino y el jugador responde con una despedida acorde; quien trabaja vuelve a su tarea sin frases de paseo.
- `DialogueSocialMenu` cubre el ritmo lento y las despedidas coherentes de caminar/tránsito/trabajo.
- CI Godot 4.7: **PASS**, run `43929922701` (#1654), 40 pasos completados sin fallos.
- La prueba es headless. Falta revisar la legibilidad en una partida real, en especial Android, y rastrear cualquier frase contradictoria que provenga de datos externos.



## Sexagésima octava barrida — Voces y contenido cotidiano de los NPC

- Se revisaron las respuestas de rutina y el fallback del menú social para que Mara, Ivo y Nima tengan reacciones propias incluso cuando no hay temas narrativos cargados desde datos.
- Mara responde con calma y reserva; Ivo habla con franqueza y humor sobre su propio ritmo; Nima mantiene la curiosidad, pero recuerda que conversa con una persona y no sólo con un tema de estudio.
- Las conversaciones ambientales de Mara/Ivo, Nima/Ivo y Saira/Ivo ahora avanzan mediante bromas, preguntas, límites y propuestas concretas, con menos frases explicativas.
- Los perfiles de voz ya no convierten expresiones de todos los NPC al mismo registro; cada adaptación queda asociada al personaje.
- Se corrigieron respuestas de movimiento dentro de edificios para que hablen del lugar en el que están y no de un destino exterior. También se eliminó la concatenación de nombres internos de actividad en los planes cotidianos.
- Se añadieron aserciones para las voces y respuestas de rutina de Mara, Ivo y Nima a `DialogueSocialMenu`.
- CI Godot 4.7: **PASS**, run `43932011916`, 40 pasos completados sin fallos.
- Falta revisar los textos en una partida real y confirmar su legibilidad/naturalidad en Android. La prueba headless verifica contratos y frases, no sustituye una lectura jugada.
- No se cambiaron los datos canónicos de diálogos en Supabase.



## Núcleo NPC Mind — primera etapa

- Añadido `NPCMindService` (`NPCMind` autoload) para representar el estado interno persistente de cada habitante.
- Incluye necesidades, rasgos, estado emocional inicial, preferencias de actividad aprendidas, objetivos y evaluación de utilidad.
- La selección de actividad es una evaluación pura: devuelve la mejor opción disponible y no controla directamente movimiento ni animaciones.
- El aprendizaje usa resultados acotados de -1 a 1, media acumulada y confianza progresiva.
- GameState guarda y restaura `npc_mentes` dentro de `world_state.flags`; el guardado sigue siendo local por partida.
- Se añadió una regresión headless específica y CI Godot 4.7 pasó **41/41 pasos** en run #1677.
- No se modificó Supabase. No se reemplazaron horarios existentes ni se habilitó aún la autonomía en tiempo real.



## NPC Mind — primera acción autónoma en Torres

- `NPCScheduleSystem` ya consume el estado mental persistente para elegir entre alternativas de ocio en los días libres.
- La selección depende de necesidades, rasgos, aprendizaje previo, coste y prioridad; cada NPC conserva un repertorio de acciones distinto.
- Las acciones reutilizan navegación y ubicaciones existentes, por lo que pueden llevar al habitante a la plaza, panadería, forja, archivo, vivienda o castillo.
- El tiempo del mundo modifica necesidades por intervalos; las actividades alivian necesidades asociadas y actualizan ánimo, estrés y energía.
- Al terminar cada tramo se registra el resultado para aprendizaje incremental. La elección queda estable durante ese tramo.
- CI Godot 4.7: **41/41 pasos correctos, 0 fallos**, run #1685.
- Las rutinas laborales y los compromisos existentes siguen teniendo prioridad. La autonomía todavía está limitada a ocio de días libres; no hay simulación offline ni planes sociales autónomos complejos.



## Objetivos sociales autónomos

- En horas libres de días de descanso, la necesidad de socialización puede generar `buscar_compania` o `visitar_amigo`.
- Los compañeros se seleccionan según vínculos, tensión y distancia; el NPC navega hasta ellos y registra el encuentro como una interacción social persistente.
- El resultado reduce necesidades sociales, modifica gradualmente preferencias y actualiza el historial del vínculo.
- Se respetan horarios, edificios, conversaciones y disponibilidad del compañero. Los objetivos se cancelan o esperan con límites claros.
- El ciclo de objetivos repetidos y el reciclaje del historial se cubren con la prueba NPC Mind.
- CI Godot 4.7: **41/41 pasos correctos, 0 fallos**, run #1694.
- No hay generación de diálogo: se conservan textos escritos y escenas ambientales existentes.



## Memoria social y asuntos entre habitantes

- Las promesas y asuntos pendientes se guardan entre partidas. Los NPC pueden buscar a la persona implicada para cumplir una promesa o pedir/recibir ayuda.
- Los habitantes comparten conocimientos marcados como públicos/compartibles cuando el otro aún no los conoce, conservando procedencia y cadena de transmisión.
- Si un mismo conocimiento llega por varias personas, se conservan hasta 12 rutas de transmisión distintas; la cadena más reciente sigue disponible para consumidores antiguos. La repetición de una misma ruta no crea otra copia.
- La procedencia distingue el origen inicial de cada ruta y cada enlace posterior; el receptor mantiene sus propias evidencias y no hereda como observación propia lo que sólo presenció el emisor.
- La tensión entre dos habitantes puede provocar un encuentro para intentar resolver el desacuerdo; la resolución modifica tensión, confianza/amistad y recuerdos.
- Los cambios dejan recuerdos individuales en ambos NPC y afectan sus vínculos futuros.
- Los compromisos originados en recuerdos usan identificadores estables para no reaparecer tras resolverse.
- Estos encuentros aún no presentan diálogo visual NPC-NPC; no hay generación de texto. La narración visible se mantiene escrita y queda pendiente conectar estos motivos a conversaciones ambientales.
- CI Godot 4.7: **41/41 pasos correctos, 0 fallos**, run #1708.

## Conversaciones visibles para encuentros sociales autónomos

- Cuando un NPC termina de reunirse con otro por una promesa, un asunto pendiente, una noticia, un desacuerdo o una necesidad de compañía, `NPCScheduleSystem` solicita una conversación ambiental.
- `NPCConversationSystem` presenta cuatro intervenciones escritas con las burbujas existentes y el perfil de voz de cada personaje.
- La conversación avanza sin depender de la posición del jugador ni de que tenga cerrado el diálogo modal. Si el jugador se acerca, puede observar las intervenciones que aún estén en curso.
- Los participantes quedan temporalmente fuera de la actualización de sus rutinas para evitar que se alejen durante la charla; al finalizar, recuperan el horario normal.
- La presentación no vuelve a aplicar amistad, confianza, promesas, asuntos ni transmisión de conocimientos: esos efectos ya pertenecen al cierre del objetivo social.
- CI Godot 4.7: **41/41 pasos correctos, 0 fallos**, run [#1717](https://github.com/Franilover/Game/actions/runs/43940597598). La importación/compilación y la suite de regresión pasaron.
- Alcance actual: líneas breves escritas por tipo de motivo, sin generación de texto. Sigue pendiente revisar la presentación en una partida real, especialmente Android.

## Variedad contextual de conversaciones sociales

- Los diálogos ambientales autónomos disponen de tres variantes por motivo social y alternan con el historial de interacciones de cada pareja.
- El nivel de confianza/amistad y la tensión orientan el tono: cercano, cordial o tenso.
- Cada personaje aplica ajustes de voz propios, conservando el registro ya definido para Elian, Bruna, Darven, Saira, Narel, Mara, Ivo y Nima.
- Las conversaciones de compañía pueden retomar una ayuda, una promesa cumplida, una noticia o una conversación previa de la pareja.
- Las noticias incorporan el título que el NPC realmente conoce; se conserva la cautela cuando no está confirmado.
- CI Godot 4.7: **41/41 pasos correctos, 0 fallos**, run [#1719](https://github.com/Franilover/Game/actions/runs/43941877535).


## NPC Mind — objetivos y estado emocional en las decisiones

- La evaluación de actividades ya considera objetivos personales activos cuando la actividad coincide con su identificador, una lista de actividades aceptadas o etiquetas compartidas.
- La prioridad del objetivo modula su influencia; sólo se toma la mejor coincidencia para evitar que acumular objetivos multiplique artificialmente la puntuación.
- Las actividades pueden declarar `afinidad_emocional` para que ánimo, estrés y energía influyan en su utilidad. Las afinidades usan escala 0–1.
- Se amplió `test_npc_mind_core.gd` para comprobar que objetivos y estado emocional participan en la evaluación.
- Cambios en la rama `fix/p0-godot47-crafting-token-type`; no se modificó `main` ni Supabase.
- Pendiente: CI Godot 4.7 y revisión de los resultados dentro de una partida. La evaluación sigue siendo determinista y no genera texto.

## Memoria episódica social y elección de compañía

- Al finalizar una interacción autónoma entre NPC, ambos participantes reciben un recuerdo `experiencia_npc` con contraparte, tipo de encuentro, resultado, importancia y fecha de mundo.
- La selección futura de compañía consulta hasta seis experiencias recientes relevantes con cada candidato. Las positivas aumentan su puntuación; las negativas la reducen.
- Los recuerdos más recientes pesan más y la influencia total se limita a [-15, 15], por lo que no sustituye los valores persistentes de amistad, confianza, afecto o tensión.
- Se añadieron pruebas para experiencias positivas, negativas y recuerdos de terceras personas.
- La memoria utiliza el almacenamiento local de recuerdos sociales existente. No modifica Supabase ni genera texto.
- Pendiente: ejecutar CI Godot 4.7 y validar en partida que los encuentros reflejen las experiencias sin crear preferencias rígidas.


### Memoria contextual de lugares (2026-11-16)
- `NPCMind` conserva por personaje resultados acumulados por `ubicacion_clave`.
- La preferencia por lugar se calcula con media incremental y confianza progresiva; una experiencia aislada no crea una aversión o preferencia absoluta.
- Las decisiones de ocio consultan esta memoria al puntuar actividades. El resultado del tramo anterior alimenta tanto el aprendizaje de la actividad como el del lugar visitado.
- La memoria se guarda en `npc_mentes` dentro del guardado local y no requiere cambios de Supabase.


## Memoria de corto plazo y variedad de conducta (2026-11-16)
- `NPCMind` conserva las últimas cuatro actividades elegidas por habitante dentro del guardado local.
- La evaluación aplica una penalización decreciente a las actividades más recientes (7, 4, 2 y 0,75 puntos); no las bloquea.
- La penalización se integra como componente visible de la puntuación, de modo que una necesidad urgente o un objetivo de mayor peso puede justificar repetir una actividad.
- Se añadieron pruebas para alternancia entre opciones equivalentes, penalización de repetición, límite/orden del historial y prioridad de necesidades urgentes.
- Se inicializa y normaliza el historial para conservar compatibilidad con partidas anteriores que todavía no tengan este campo.
- El historial es local por partida; no requiere cambios en Supabase ni generación de texto.


## Hábitos individuales a largo plazo (2026-11-16)
- `NPCMind` registra hábitos por actividad y contexto temporal, separados de las preferencias aprendidas.
- Un hábito gana fuerza al practicarse en días distintos; varias ejecuciones el mismo día no inflan su consolidación.
- La puntuación combina días practicados, resultado medio de la experiencia y días transcurridos sin repetirlo. El desuso reduce gradualmente su influencia.
- Los hábitos aportan hasta 6 puntos a la elección de actividad y no bloquean alternativas ni desplazan necesidades urgentes.
- La rutina de ocio aporta un contexto por tramo horario para que una costumbre matinal no se transfiera automáticamente a la noche.
- El perfil conserva hasta 32 hábitos y se guarda en el estado local de cada NPC.
- Se añadieron pruebas de consolidación, separación temporal, no duplicación diaria y persistencia.
- Compatible con partidas anteriores: el campo se inicializa al normalizar estados antiguos.


## Personalidad social como límite de autonomía (2026-11-16)
- La sociabilidad de cada NPC se consulta desde el perfil social definido en Supabase (personaje_social_v1); no se aprende ni se incrementa por repetir conversaciones.
- La sociabilidad regula el umbral de necesidad para iniciar encuentros: perfiles más reservados requieren una necesidad social mayor.
- Los perfiles con sociabilidad baja solo buscan o aceptan encuentros casuales cuando existe un vínculo suficiente. Promesas, asuntos pendientes o noticias relevantes permiten encuentros justificados aunque el NPC sea reservado.
- La selección considera la disposición de ambas personas, no solo la iniciativa de quien se acerca. Así, un NPC sociable no fuerza encuentros casuales con alguien reservado.
- Se añadieron pruebas para perfiles reservados/sociables, vínculos cercanos y excepciones por motivos concretos.
- Se utilizan los campos actuales de Supabase; no se modificó el esquema ni se escribieron datos en Supabase.
- Pendiente: ejecutar las pruebas con Godot 4.7 y validar en partida la frecuencia y selección de encuentros.


## Memoria social bilateral y decaimiento temporal (2026-11-17)
- La selección de encuentros casuales evalúa recuerdos desde la perspectiva de ambos participantes; una buena relación no se presupone simétrica si solo uno conserva experiencias positivas.
- Los recuerdos sociales recientes tienen más influencia que los antiguos. La vigencia cae gradualmente con una semivida aproximada de 14 días de mundo; los recuerdos sin fecha válida conservan el peso basado en orden como mecanismo de compatibilidad.
- Experiencias negativas repetidas pueden frenar encuentros casuales con una persona concreta, incluso para NPC sociables. Una promesa, una solicitud de ayuda o una noticia relevante permite una excepción para resolver el asunto.
- Experiencias positivas repetidas pueden elevar la familiaridad efectiva antes de que amistad o confianza general hayan cambiado mucho.
- La influencia está acotada y no cambia los rasgos base de personalidad ni reescribe los valores canónicos de Supabase.
- Se añadieron pruebas para cautela por experiencias negativas, excepción por motivo concreto y decaimiento temporal.
- Pendiente: ejecutar CI Godot 4.7 y validar el ritmo de decaimiento en días de mundo dentro de una partida.


## Sincronización de identidad canónica (2026-11-17)
- Cuando `RelationshipSystem` confirma que terminó la carga y existe una fila social propia del NPC, `NPCScheduleSystem` entrega sus rasgos a `NPCMind`.
- `NPCMind` actualiza los rasgos base con los valores recibidos de Supabase incluso si ya había valores anteriores en la partida.
- La sincronización no sustituye necesidades, preferencias aprendidas, hábitos, objetivos ni recuerdos.
- Mientras las reglas cargan, o si el NPC no tiene una fila propia, no se aplica el perfil neutral de respaldo sobre el estado guardado.
- Se añadió una prueba de regresión que cambia los rasgos canónicos y comprueba que el aprendizaje y los hábitos permanecen.
- No se modificó el esquema ni se escribieron datos en Supabase.


## Memoria conversacional y privacidad de conocimiento (2026-11-17)
- Las conversaciones sociales autónomas registran el tema compartido en la memoria de cada participante, asociado al ID del otro NPC. En un siguiente encuentro pueden recuperar una referencia al último tema compartido; no se generaliza a otros interlocutores.
- El registro se crea sólo al completar la conversación, no si se interrumpe.
- La retransmisión de conocimiento respeta `compartible` y `privacidad`: los datos públicos conservan compatibilidad; los confidenciales no se retransmiten automáticamente; los personales/reservados requieren `permiso_transmision=true` y confianza >= 30 entre origen y destino.
- La procedencia y cadena de transmisión continúan registrándose en el conocimiento del destinatario.
- Se añadieron pruebas de aislamiento de temas por interlocutor y de las reglas de privacidad/consentimiento.
- No se añaden columnas ni se modifica Supabase; la información sigue en el guardado local de conversaciones NPC.
- Pendiente: ejecutar CI Godot 4.7 y comprobar el flujo en una partida real.


## Cobertura general de memoria conversacional y creencias (2026-11-17)
- La memoria de temas ya no depende de `_social_autonoma`: se registra al completar cualquier conversación entre dos o tres NPC que estén presentes en el registro del mundo y tengan `personaje_game_id`.
- Incluye encuentros autónomos, conversaciones guionizadas y conversaciones grupales. Se puede excluir un caso excepcional con `_sin_memoria_conversacional=true`.
- El tema se toma de `tema_memoria`, `_tema_social`, `tema` o `motivo`; en conversaciones antiguas sin esos campos se conserva la clave de la escena como referencia.
- Cada pareja recibe recuerdos bilaterales, no un recuerdo global compartido.
- Nueva evaluación epistemológica local por NPC: rumores y testimonios no verificados empiezan como sospechas; observaciones y pruebas pueden aumentar la confianza; evidencias contradictorias la reducen.
- La misma fuente no gana peso por repetir la misma versión. La evaluación distingue sospecha, creencia firme, conocimiento sostenido y creencia refutada; no cambia la verdad global del mundo.
- Las APIs nuevas son `registrar_evidencia_conocimiento_npc`, `evaluar_creencia_conocimiento_npc` y `obtener_evaluacion_creencia_npc`.
- No se modificó Supabase ni se usa IA generativa. CI sigue pendiente de validación completa; hay fallos existentes de `NPCMindCore` que requieren aislarse antes de afirmar que la suite pasa.


## Aprendizaje por observación de eventos comunitarios (2026-11-17)
- Cuando un NPC llega realmente al punto de reunión de un acontecimiento comunitario de Torres, registra una observación directa individual. La asignación de la rutina o el trayecto no cuentan como presencia.
- La clave de conocimiento incluye evento, año y día; la evidencia usa ese identificador estable para impedir que cada actualización de rutina cuente como un nuevo testigo.
- El registro conserva título, detalle, procedencia y momento. No se atribuye la observación a NPC sin identidad canónica ni a habitantes que no entraron en la rutina del evento.
- La observación queda como conocimiento público compartible, sin afirmar nada sobre sucesos que el NPC no presenció.
- Se añadió una regresión para confirmar la primera observación, la deduplicación y su estado epistemológico.
- La integración cubre por ahora los eventos comunitarios del calendario de Torres; todavía falta conectar observaciones de incidentes, trabajo, acciones del jugador y pruebas materiales.


## Correcciones de aprendizaje y privacidad en decisiones sociales (2026-11-17)
- Las experiencias recientes ahora tienen más peso que las antiguas al ajustar la afinidad por un lugar; un historial previo favorable puede cambiar cuando se acumulan experiencias negativas.
- Un objetivo cuyo identificador coincide con una actividad influye en su utilidad aunque el registro no repita el campo `actividad`.
- La selección de noticias y la puntuación de encuentros usan la misma lista de conocimientos realmente compartibles con el destinatario, evitando ofrecer información confidencial o reservada como tema casual.
- El conocimiento sin metadatos explícitos sólo se considera público automáticamente para tipos reconocidos de noticia/evento público; una nota personal no se retransmite por defecto.
- Se corrigió la expectativa de persistencia del test para contar las dos actividades aprendidas que efectivamente se registran.


## Procedencia epistemológica en transmisiones entre NPC (2026-11-17)
- Un NPC que recibe una noticia no hereda como propia la observación directa de quien se la contó: se registra como testimonio atribuido al emisor.
- Los testimonios no verificados parten de una confianza menor y permanecen como sospechas hasta recibir evidencia independiente.
- La evidencia de observación directa identifica al NPC testigo y al evento, para que compartir el recuerdo no lo convierta en una observación propia del receptor.
- La transmisión conserva la cadena de procedencia y las evidencias que el receptor ya había reunido; no reemplaza sus recuerdos anteriores.


## NPC: selección de ocio consciente de destinos

- El catálogo de actividades de ocio se valida antes de que NPCMind puntúe las opciones: cada alternativa debe tener identificador y una ubicación existente en Torres.
- Cuando la malla de navegación está lista, las alternativas cuyo destino no puede alcanzarse desde la posición actual se excluyen antes de elegir.
- Si no queda ninguna alternativa válida, el NPC conserva su rutina base en lugar de recibir una ubicación sustituta.
- Se añade una regresión para destinos desconocidos, identificadores vacíos y preservación de ubicaciones válidas.
- Alcance: esta mejora cubre la selección de ocio en días libres; no cambia horarios laborales, datos canónicos ni Supabase.


## NPC: autonomía durante huecos del calendario

La selección de actividades ya no depende exclusivamente de los días libres. Cuando el selector de horarios no encuentra una rutina activa, el sistema comprueba que el NPC sí tenga un calendario definido y calcula cuánto falta para el siguiente compromiso dentro del ciclo semanal de cinco días. Si dispone de al menos una hora, puede elegir una actividad cotidiana compatible con sus necesidades, preferencias aprendidas y destinos alcanzables.

Los turnos, guardias, citas y demás rutinas activas conservan prioridad. El hueco se vuelve a evaluar por hora y la rutina programada vuelve a tomar el control al comenzar. Los NPC sin calendario no reciben actividades improvisadas por este mecanismo.


## NPC: actividades interiores vinculadas al mobiliario

Al ejecutar una actividad dentro de un edificio abierto, el NPC busca primero un puesto junto al mueble compatible con su intención: camas/literas para descansar, mesas para leer o estudiar, hornos y bancos para cocinar, reparar o trabajar, y mesas/mostradores para atender o conversar. Si el edificio no contiene un mueble adecuado, conserva los puntos generales de movimiento interior. La animación de actividad existente se mantiene y se inicia cuando el NPC ya está en el edificio; no se altera el horario ni se fuerza la entrada a interiores cerrados.


## Diálogos: continuidad entre conversación y actividad

- Las respuestas a «¿Cómo va tu día?» incorporan la actividad actual de los NPC con oficio y evitan presentar caminar o pasear como trabajo.
- Las referencias temporales de esas respuestas se ajustan para no hablar de «la mañana» cuando ya pasó ese periodo.
- Nima describe sus estudios según lo que está haciendo realmente; ya no afirma estar observando fenómenos Oris mientras camina o descansa.
- Las descripciones de tareas laborales usan frases legibles en vez de exponer identificadores internos de rutina.
- Se ampliaron las regresiones de `DialogueSocialMenu` para cubrir actividades reales y evitar contradicciones entre rutina y conversación.
- No se modificaron datos narrativos de Supabase ni se introdujo generación de diálogo.


## Progresión encadenada de historias locales

- La historia de Mara e Ivo debe completar sus tres etapas antes de desbloquear la investigación de Nima.
- La investigación de Nima e Ivo debe completar sus tres etapas antes de desbloquear el contacto de Saira.
- Los requisitos usan el progreso guardado de cada cadena (etapa 3), por lo que abandonar una escena o completar sólo su primera etapa no habilita la siguiente.
- La comprobación se realiza antes de iniciar la escena; las cadenas ya iniciadas conservan su etapa guardada.
- Se añadieron regresiones para impedir que estas historias se desbloqueen prematuramente.

## Separación de historia y contenido opcional

- Las cadenas con etapas y efectos se clasifican como historia; cada etapa conserva el progreso guardado y no vuelve a reproducirse al completarse.
- Las conversaciones locales con progresión también son parte de la historia.
- Los acontecimientos diarios, reuniones y rutinas compartidas siguen siendo contenido ambiental opcional y repetible.
- Al comenzar una conversación de historia, se solicita el encuadre automático de cámara y se mantiene el seguimiento durante la duración calculada de sus líneas, para que el jugador pueda verla completa.
- Las cadenas narrativas pueden activarse cuando los participantes están en el mismo interior que el jugador, además de los encuentros exteriores. Cada etapa puede declarar `activacion_historia` con `anio`, `dia`, `hora_desde` y `hora_hasta`; también admite requisitos de progreso por clave y etapa.
- Las solicitudes de cámara narrativas no caducan ni se descartan para hacer espacio a eventos opcionales; siguen la posición actual de los participantes.
- No se alteran datos de Supabase; la clasificación y el progreso usan los datos locales existentes.


## Estado de mantenimiento NPC — 2026-11-19

La auditoría actual continúa priorizando rendimiento y unificación del sistema existente:

- El planificador comparte por tick la lista de NPC, jugador y calendario del mundo para evitar consultas repetidas al SceneTree y WorldAtmosphere.
- La condición de horario nocturno se centralizó en NPCScheduleRules y se cubren sus límites.
- La memoria diaria de las reuniones se separó en una operación privada con entradas explícitas y metadatos existentes.
- La prueba de integración NPCScheduleContext protege el contexto compartido y la memoria diaria; está conectada al workflow headless.
- Validación confirmada: Godot 4.7 **46/46 pasos correctos, 0 fallos**, run [#44622633288](https://github.com/Franilover/Game/actions/runs/44622633288); GDScript Quality **success**, run [#44622597880](https://github.com/Franilover/Game/actions/runs/44622597880).
- La geometría y el cálculo de rutas de Torres ya están separados en `NPCNavigationSystem`; `NPCScheduleSystem` conserva la coordinación de rutinas, actividades sociales e interiores. La extracción está protegida por pruebas de construcción de malla, cálculo de ruta, invalidación, límites del mapa y seguridad de movimiento.
- La salida de un edificio al cambiar de rutina se concentra en `_salir_de_edificio_para_cambiar_rutina()`. `ReinoTorres` determina la posición real de la puerta; la agenda ya no vuelve a calcularla desde un catálogo duplicado. La regresión de entrada/salida cubre la transición completa.
- CI Godot 4.7: **48/48 pasos, 0 fallos** ([run #44628441771](https://github.com/Franilover/Game/actions/runs/44628441771)); GDScript Quality: **success** ([run #44628441413](https://github.com/Franilover/Game/actions/runs/44628441413)).
- El cálculo de destinos locales también quedó aislado y probado: hogar, puerta, plaza y posiciones de NPC adicionales. La búsqueda de mobiliario interior se unificó para puestos y animaciones, conservando el orden de escena y las prioridades actuales. Validación: [Godot 4.7 48/48](https://github.com/Franilover/Game/actions/runs/44629354647) y [GDScript Quality](https://github.com/Franilover/Game/actions/runs/44629354490), ambos success. La siguiente auditoría debe revisar las responsabilidades restantes antes de extraer más módulos.


## Movimiento NPC — optimización en curso (2026-11-19)

Se optimizó el descarte de NPC lejanos en la separación física: primero se compara distancia al cuadrado y sólo se calcula la raíz para candidatos dentro del radio de 34 px. Se reutilizan la dirección normalizada y el ID del NPC actual. Las pruebas ahora protegen el caso de un vecino lejano y el límite exacto del radio. Primera optimización validada: Godot 4.7 46/46 y GDScript Quality success. Segunda optimización validada: Godot 4.7 46/46 pasos correctos, 0 fallos; GDScript Quality success.


## Movimiento NPC — segunda optimización (2026-11-19)

La comprobación de solapamiento final ahora descarta parejas separadas usando distancia al cuadrado y sólo calcula la raíz para las que realmente necesitan corrección. Se conserva la distancia mínima de 28 px y el ajuste determinista cuando dos NPC ocupan la misma posición. Se amplió la prueba de seguridad de movimiento; CI de esta segunda modificación pendiente.


## NPCScheduleSystem — primera extracción de _aplicar_rutina (2026-11-19)

La selección de calendario y las prioridades de ocio, invitaciones, eventos comunitarios y encuentro del trío se movieron a `_resolver_rutina_base_y_eventos()`. La ejecución de destino, navegación, interior, clima y metadatos de movimiento sigue en `_aplicar_rutina()`. Se conserva el calendario original de Elian y se prueba que el ajuste local de cierre no lo muta.

Validación CI: Godot 4.7 46/46 pasos correctos, 0 fallos; GDScript Quality success.


## Interrupción de actividades interiores — 2026-11-19

Las cinemáticas ahora detienen los paseos interiores activos, liberan el estado de tránsito y conservan el siguiente horario programado. Las conversaciones ambientales siguen utilizando la pausa temporal que conserva la ruta. La regresión correspondiente está añadida a `test_npc_schedule_context`; validación CI pendiente.


La prueba de interrupción por cinemática también cubre la reanudación del paseo interior con `CreatureMovement` real y conserva el minuto programado. Esta ampliación está pendiente de validación CI.


Los paseos interiores registran la actividad que generó su destino. Cuando cambia la tarea programada dentro del mismo edificio, la ruta se replantea para la nueva actividad. La prueba cubre también la interrupción cinematográfica y la reanudación. Validación CI pendiente.


La regresión de cambio de edificio ahora ejecuta el helper real del planificador mientras el jugador permanece dentro de otro interior y verifica la restauración completa al salir. No requiere cambios en la lógica productiva; validación CI pendiente.


## Contrato de movimiento NPC — 2026-11-19

`CreatureMovement` conserva la autoridad única sobre el desplazamiento físico. Las rutinas y actividades sociales de Torres le entregan rutas; los acercamientos a iniciativa reutilizan ese mismo mecanismo y reponen la rutina al cerrar o cancelar el diálogo. Las conversaciones ambientales sólo se inician con participantes detenidos y bloquean nuevas asignaciones durante la escena. Las cinemáticas requieren NPC libres y detenidos; no incorporan un motor alternativo.

La precedencia de órdenes es pausa temporal, ruta de rutina, restricción de criatura inmóvil, dirección externa y movimiento autónomo. `detener_por_rutina()` conserva el bloqueo de rutina aunque no haya ruta, mientras que `detener()` libera ese modo. No se encontró evidencia suficiente para añadir otro controlador ni para cambiar producción; la siguiente prueba específica debe cubrir precedencia de órdenes y restauración de rutina tras una iniciativa.


La prueba `test_creature_movement_authority.tscn` protege la prioridad entre ruta de rutina, dirección externa y pausa temporal, y diferencia detener una rutina de liberar el control. Se ejecuta con la escena real de criatura en CI; validación pendiente.


La cancelación de una iniciativa NPC detiene ahora siempre la ruta temporal y limpia tránsito/firma antes de intentar restaurar la rutina. Si el mundo, la zona, la navegación o el calendario aún no están disponibles, el NPC queda quieto en lugar de continuar hacia la posición anterior del jugador. La regresión `test_npc_schedule_context` recorre `NPCConversationSystem._cancelar_acercamiento()`, simula pausa/reanudación del diálogo y verifica la limpieza de la ruta. CI pendiente.


## Contrato del inventario — 2026-11-19

- Una recogida es atómica: se calcula sobre una propuesta aislada y solo se confirma si cabe la cantidad completa. El rechazo no puede dejar pilas parcialmente incrementadas.
- Dos objetos solo se apilan por identidad cuando sus identificadores coinciden. Se resuelve primero `id` y, si está vacío, `item_id`; el nombre es compatibilidad únicamente cuando ambos objetos carecen de identificador. Los ejemplares con identidad propia nunca se fusionan.
- Equipar toma el objeto canónico del slot del runtime; una copia antigua conservada por la UI no puede sustituirlo. El intercambio conserva el objeto que estaba equipado.
- La durabilidad de mochila y equipo usa la misma regla de desgaste y elimina el objeto al llegar a cero.
- La creación del objeto en el mundo precede a retirar la cantidad del inventario; si el mundo rechaza el drop, el inventario conserva el objeto.

Las regresiones `test_inventory_pickup_contract`, `test_inventory_equipment_transaction` y `test_inventory_drop_contract` protegen estos límites. La validación completa de Godot 4.7 está en curso para esta revisión.


## Contrato de fabricación — 2026-11-19

- La fabricación se ejecuta en InventoryRuntime.fabricar: trabaja sobre una copia aislada del inventario y confirma el estado sólo cuando se han consumido todos los ingredientes y cabe el resultado.
- Los ingredientes pueden estar repartidos entre varias pilas o repetirse en la receta; se descuentan por identidad (item_id, con fallback a id).
- El resultado se inserta después de consumir materiales, por lo que puede ocupar los slots liberados.
- Si faltan materiales, la receta está mal formada o el resultado no cabe completo, no cambia ningún slot.
- InventoryController.fabricar aplica el input gate y emite una sola actualización de inventario tras confirmar.
- Regresión: tests/inventory/test_inventory_crafting_transaction.tscn.

## Contrato de uso de objetos — 2026-11-19

- El controlador valida el índice real del inventario incluso cuando la interfaz entrega datos enriquecidos del objeto.
- Los consumibles no alimenticios sólo se usan si al menos un efecto tiene margen aplicable; se retira el objeto antes de mutar recursos.
- Los alimentos se consumen aunque vida, Eterium y stamina estén al máximo, manteniendo el comportamiento de juego.
- Regresión: tests/inventory/test_inventory_use_transaction.tscn.

## Contrato de guardado del mundo compartido — 2026-11-19

- El guardado global escribe y valida un temporal antes de tocar el archivo principal.
- Si existe un mundo anterior, se mueve a `.bak` antes de publicar el temporal; un fallo al proteger el archivo cancela la escritura sin eliminar el mundo válido.
- Si falla la publicación o la validación final, intenta restaurar el respaldo. La carga también recupera un `.bak` válido si el archivo principal está corrupto.
- El servidor sólo pausa el mundo cuando el guardado se confirmó correctamente; ante un fallo permanece activo, deja el guardado pendiente y lo reintenta periódicamente mientras no haya jugadores. Si alguien vuelve antes del reintento, se cancela la pausa pendiente y continúa el mundo.
- Regresión: `tests/persistence/test_global_world_store_contract.tscn`.

## Restauración de estado del jugador — 2026-11-19

- `PlayerState.from_dictionary()` conserva la stamina fraccionaria dentro de su escala actual `0..3`; ya no redondea a enteros durante la carga.
- Los saves antiguos en escala `0..100` se convierten proporcionalmente a `0..3`, conservando también sus fracciones.
- `test_game_state_roundtrip` cubre un roundtrip con stamina `1.5` y la migración de un valor antiguo `50.0`.

## Registro de réplicas de entidades — 2026-11-19

Al salir una criatura o un prop del árbol, WorldEntityManager elimina también las referencias que mantenía en los registros de réplicas de red. Antes, esos diccionarios podían conservar nodos liberados hasta que volviera a registrarse la misma clave; en sesiones con muchas entidades transitorias, el registro podía crecer aunque las entidades ya no existieran. La limpieza compara la referencia exacta y conserva las demás réplicas. Regresión: tests/entities/test_world_entity_replica_registry.tscn.


## Reinicio completo del administrador de entidades — 2026-11-19

`WorldEntityManager.limpiar_todo()` vacía ahora también los registros de réplicas de red y los estados runtime de criaturas y props, además de las entidades, índices activos y datos preparados por chunk. Esto evita reutilizar referencias o estados de una sesión anterior tras un reinicio completo. Regresión: tests/entities/test_world_entity_manager_reset.tscn.


## Reanudación de posición por zona — 2026-11-19

La posición global del jugador sólo se reutiliza al cargar la misma zona persistida. Si la zona de destino difiere, se conserva su punto de aparición normal; los retornos explícitos de expedición y viaje exterior siguen aplicándose después del spawn. La regla se comparte entre mundo procedural, reinos de escena fija e Historia, evitando que una partida reanude siempre en el spawn inicial o que una transición herede coordenadas de otra zona. Regresión: tests/world/test_zone_spawn_resume_contract.tscn.


## Captura antes de descargar una zona global — 2026-11-19

En servidor dedicado, ZoneManager solicita a GlobalWorldStore capturar el runtime mientras la zona anterior y su WorldEntityManager todavía existen, después de validar la escena destino y antes de queue_free. Esto conserva el estado de criaturas y props también en transiciones iniciadas por salidas físicas u otros flujos, no sólo por el RPC del menú de viaje. La captura duplicada del RPC de viaje se retiró para mantener un único punto de persistencia. Si el guardado falla, se advierte y la transición continúa, igual que el comportamiento previo del flujo RPC.


## Clave runtime de criaturas sin metadatos — 2026-11-19

Cuando una criatura se registra sin `runtime_instance_key`, el administrador usa su ID natural como clave de instancia y añade las coordenadas del chunk una sola vez. Antes se añadían las coordenadas al fallback y nuevamente al construir la clave final, por lo que la recuperación por ID natural no encontraba el estado. La regresión `tests/entities/test_world_entity_runtime_key.tscn` verifica clave, posición, vida, velocidad y registro DATA.


## Persistencia de props recolectados — 2026-11-19

- La salida de un `WorldProp` por recolección registra un tombstone `is_present=false` bajo su clave runtime y actualiza los datos del chunk.
- Los materializadores DATA y FULL consultan ese estado antes de crear el prop; una recolección confirmada no vuelve a aparecer al regenerar el chunk.
- La descarga normal del chunk marca la entidad como retirada por el administrador y conserva `is_present=true`, diferenciando una descarga de una recolección.
- El tombstone sólo actualiza una entrada DATA existente; si todavía no hay datos preparados, permanece en el estado runtime sin crear una lista parcial que impida generar los demás props del chunk.
- Si la recolección ya había solicitado `queue_free` cuando comienza la descarga, el administrador guarda el tombstone en vez de registrar el objeto como intacto. La misma protección se aplica si el guardado global captura el mundo antes de que se procese `tree_exiting`.
- Regresión: `tests/entities/test_world_prop_persistence.tscn`.


## Persistencia de vida de Garumis — 2026-11-19

- Los registros de amistad y de vínculo incluyen `health` además de experiencia, nivel y Eterium.
- La configuración reconstruye la vida actual después de calcular las estadísticas de nivel; no reemplaza la vida guardada por la máxima.
- Los registros antiguos sin `health` mantienen compatibilidad y comienzan con vida máxima.
- Este contrato de salud fue retirado al eliminar la vida y el combate de Garumis.
- Su reemplazo es `GarumiNonCombatContract`: comprueba ausencia de APIs de combate, inmunidad al daño y exclusión de salud/nivel/experiencia de los registros sociales.


## Dogma de diseño Garumi — 2026-11-19

Los Garumis son seres autónomos de exploración, misterio y relación. No son criaturas capturables ni unidades de combate. El jugador puede conocerlos, conversar, investigar, negociar y construir vínculos; sus habilidades se habilitan como capacidades del jugador, nunca como ataques ejecutados por un compañero invocado. No tienen vida, daño, defensa, nivel ni experiencia de combate. Los encuentros Garumi no abren arenas ni usan barras de salud. El combate físico del juego pertenece al jugador y a las criaturas/enemigos normales, mediante el sistema general de armas y daño.

La implementación conserva la base técnica `Creature` para movimiento y representación, pero los Garumis están fuera de `damageable`, anulan el daño y no exponen vitalidad como mecánica. El desacoplamiento físico completo de la clase base sigue pendiente; no debe confundirse con una vida o combate disponibles en gameplay.


## Retirada de combate y seguimiento Garumi — 2026-11-19

- Main ya no compone la arena Garumi, el HUD de grupo de batalla ni el seguimiento de cámara asociado.
- Se retiraron de Garumi las APIs de combate como aliado vinculado y el vínculo ya no activa seguimiento físico: es una relación, no una invocación.
- Los Garumis vinculados siguen siendo dialogables y el texto de interacción refleja conversación.
- La progresión de combate heredada y la salud compartida con Creature siguen pendientes de desacoplar en una pasada separada.


## Contrato no combatiente Garumi — 2026-11-19

La regresión de salud de Garumi se reemplazó por un contrato de no combate: verifica que el modelo no exponga APIs de arena, daño, derrota, curación o progresión de combate; que no pertenezca al grupo `damageable`; y que los registros sociales y de vínculo no persistan salud, nivel ni experiencia de combate. La energía Eterium se conserva como recurso separado para futuras habilidades prestadas.


## Interacción Garumi conversacional — 2026-11-19

La interacción principal de Garumi ahora deriva al diálogo heredado de Creature mediante `abrir_dialogo()`. Se retiró el menú contextual de acciones de vínculo/amistad que sustituía la conversación. El vínculo persistente queda como relación para habilitar habilidades, no como invocación física; los Garumis vinculados continúan como entidades del mundo.

## Recepción de daño del jugador y defensa — 2026-11-20

- El daño entrante del jugador atraviesa `Player.take_damage()`; allí se calcula la defensa del equipamiento antes de aplicar el impacto a la vida o a la reserva de Eterium compartida.
- `CombatDefense` es el único cálculo de mitigación: resta defensa plana, limita el resultado a cero y redondea hacia arriba cuando queda daño fraccionario.
- La ruta de Eterium compartido sincroniza vida y estado de supervivencia desde `PlayerEteriumRuntime`; el evento de cambio actualiza la presentación y activa la muerte una sola vez.
- La durabilidad de armadura no se consume al recibir daño. El desgaste de equipo sigue siendo una operación explícita de inventario, no un efecto implícito del golpe.
- `test_inventory_equipment_transaction` cubre daño reducido, bloqueo completo, impacto nulo, defensa negativa, redondeo fraccionario y fallback ante estadísticas mal formadas.
- `test_combat_temporal_contract` instancia las escenas reales de Player e Inventory y verifica mitigación con vida normal y Eterium compartido, sincronización de vida/reserva, emisión única de muerte, invulnerabilidad durante el estado DASH y ausencia de desgaste implícito.
- `Player.take_damage()` ignora impactos mientras `state == DASH`; fuera del dash, la defensa se aplica antes de la vida o la reserva compartida.
- La prueba de integración no consume durabilidad de armadura: confirma que la recepción de daño no introduce desgaste implícito.

## Frontera de objetivos de combate — 2026-11-20

- `CombatSystem.solicitar_danio_desde_entidad()` rechaza objetivos fuera del grupo `damageable` antes de registrar contacto; heredar de `Entity` o conservar `is_alive=true` no concede permiso de combate.
- `CombatDamage.aplicar()` vuelve a comprobar `damageable` como última frontera, incluso si un llamador omite `CombatTargeting`.
- `CreatureAI` excluye a los Garumis de selección de objetivos, persecución y relaciones ecológicas, incluso con `objetivos="todo"`; también los excluye del análisis de depredadores/amenazas y descarta referencias de liberación hostiles que apunten a un Garumi.
- `test_creature_ai_target_policy` cubre selección hostil, seguimiento ecológico y objetivo de liberación con un Garumi real.
- `test_combat_entity_attack_contract` verifica el rechazo explícito de un Garumi tanto desde `CombatSystem` como mediante una llamada directa a `CombatDamage`, sin contacto ni alteración vital.
- La IA de criaturas continúa usando el mismo resolver central; los ataques especializados no aplican daño directamente.


## Interrupción de muerte al reaparecer — 2026-11-20

Se corrigió una carrera temporal: la animación de muerte podía seguir activa después de una reaparición rápida y volver a modificar la transparencia o escala del jugador. `Player` ahora conserva y cancela el tween anterior tanto en reaparición local como en reaparición de red. La regresión de `test_combat_temporal_contract` comprueba vida, procesamiento físico, estado IDLE, acción/cooldown reiniciados y presentación estable tras 0,4 s.


## Cancelación de ataques tras la muerte del atacante — 2026-11-20

La ejecución melee y a distancia ahora depende de `CombatTargeting.es_atacante_valido()`: atacante de tipo Entity, válido, dentro del árbol y vivo. Hitboxes y proyectiles se cancelan al detectar que el atacante murió, y vuelven a validar antes de procesar un objetivo. CombatSystem protege también los callbacks de contacto/impacto, evitando efectos posteriores de un ataque interrumpido. `test_combat_temporal_contract` comprueba cancelación melee/proyectil, ausencia de señales y ausencia de daño.


## Validación compartida de impactos simultáneos — 2026-11-20

`CombatTargeting.es_objetivo_valido()` ahora aplica la misma política en melee, proyectiles y ataques de entidad: el atacante debe ser una Entity viva dentro del árbol y el objetivo debe seguir vivo y pertenecer a `damageable`. `CombatWeaponAttackValidator` y `CombatSystem.solicitar_danio_desde_entidad()` comparten esta frontera; la IA ya no puede registrar contacto ni aplicar daño con un atacante derrotado o fuera del árbol.

La fase posterior al impacto conserva una distinción importante: un objetivo muerto es inválido para recibir otro ataque, pero sigue siendo válido como resultado de un impacto letal ya confirmado. Por eso el callback de efectos comprueba que el nodo exista y que el atacante siga válido, sin exigir que el objetivo continúe vivo. La resolución central impide que impactos posteriores reduzcan de nuevo la salud. La regresión temporal prueba dos proyectiles sobre un objetivo con 5 puntos de vida, un único contacto/resultado confirmado y el rechazo de un atacante derrotado o fuera del árbol.


## Ciclo de vida de proyectiles — 2026-11-20

`CombatProjectile._finalizar()` centraliza el cierre por impacto, muerte del atacante y expiración. La operación marca el proyectil como consumido, desactiva la detección de colisiones y solicita su liberación, evitando que una expiración deje una ventana para impactos tardíos. Después de emitir contacto, el proyectil vuelve a validar atacante y objetivo antes de aplicar daño: si un listener derrota al atacante en esa misma emisión, el daño pendiente se cancela. `test_combat_temporal_contract` cubre esa interrupción y la expiración sin impacto.


## Auditoría de ejecución de ataques de criaturas — 2026-11-20

Se revisó la ruta completa de `CreatureAI`: perfiles de contacto (genérico, Dramarias, Flaxis y Lignianos), Cambiaformas con arma y Rancrodeen adherido. La IA sólo decide y solicita; las rutas de daño llegan a `CombatSystem` y `CombatDamage`. No se encontró una escritura directa de salud en `CreatureAI`.

Se cerró una ventana de reentrada: `contacto_efectivo` ejecuta listeners síncronos, por lo que un listener podía derrotar al atacante o al objetivo y la solicitud continuaba aplicando daño. `solicitar_danio_desde_entidad()` ahora vuelve a validar ambos participantes después de la señal. El resolver melee `_aplicar_danio()` también valida antes de reducir salud, protegiendo tanto al jugador como a las armas de entidades/Cambiaformas. Una solicitud interrumpida conserva el contacto ya emitido, pero no informa daño ni publica `ataque_realizado`.

Además, Lignianos no aplica ralentización si alguno de los participantes ya murió durante el contacto, y Rancrodeen se desprende al perder un objetivo válido. Se ampliaron `test_combat_entity_attack_contract` y `test_combat_weapon_attack_contract` para cubrir interrupciones síncronas. La ejecución de Godot sigue pendiente de confirmación local/CI.


## Reentrada al recibir daño de criaturas — 2026-11-20

Se eliminó el atacante temporal compartido de `Creature`. Ahora `take_damage_desde()` y `take_damage()` convergen en una operación común que conserva el atacante como dato local. Esto evita que un listener síncrono de `health_changed` provoque un segundo golpe y sobrescriba la atribución del primero. Se mantiene la protección de sparring y la señal `danio_recibido` sólo se emite cuando la salud realmente disminuye. Se añadió `test_combat_creature_damage_reentrancy` para comprobar dos golpes anidados, sus cantidades y sus atacantes. La prueba está añadida, pero aún no se ha ejecutado en Godot.


## Recuperación y curación de Eterium — 2026-11-20

Se cerraron las rutas de recuperación después de la muerte: `gastar()`, `establecer_mana()`, recuperación pasiva y curación automática respetan el estado vital. El acumulador pasivo se descarta al detectar muerte; el setter ya no puede reanimar al jugador por accidente. La curación automática estaba implementada en el runtime, pero no conectada al ciclo de juego: ahora se procesa cuando el jugador permanece quieto en `IDLE`, junto con la recuperación pasiva.

La curación automática se limita a fisiologías con vida y Eterium separados. En fisiología compartida, sumar vida y luego pagar el coste desde la misma reserva sustituía la curación por un gasto neto; el runtime ahora rechaza esa ruta. La reserva compartida sigue recuperándose por restauración y absorción válidas. Se amplió `test_player_vital_state_contract` para comprobar la ruta de curación no compartida, sincronización y límites post-muerte/compartidos. El test no simula el paso físico del jugador. Ejecución de Godot pendiente de confirmación local/CI.

Además, se cerró el ciclo de temporizadores: el sprint no acumula coste con el jugador muerto, el coordinador no procesa sprint en ese estado y cualquier fallo al confirmar el gasto descarta el coste pendiente. Las reapariciones local y de red reinician los acumuladores de recuperación, sprint y curación. La curación rechaza configuraciones sin coste/curación positivos y costes negativos.


## Persistencia del estado vital del jugador — 2026-11-20

Se auditó la ruta GameStateService → PlayerState → Player.restaurar_estado_vital() desde captura hasta aplicación en escena.

- El save conserva salud y Eterium actuales; las capacidades máximas siguen derivándose del runtime/especie y no se duplican en el JSON.
- PlayerState.normalizar_reservas_vitales() limita ambas reservas a sus máximos runtime. En fisiología compartida, normaliza ambas al menor valor guardado para impedir que un save inconsistente otorgue salud/Eterium adicionales.
- La aplicación de un snapshot con salud cero restaura al jugador como muerto; no fuerza vivo=true por el mero hecho de cargar una partida.
- Los saves antiguos conservan sus campos y conversión de stamina 0..100; no se introdujo una nueva versión de formato.
- test_player_state_vital_persistence_contract cubre migración legacy, límites, reservas compartidas inconsistentes, salud cero y serialización de ida y vuelta. La prueba está añadida, pero aún no se ha ejecutado en Godot.

Límite de esta pasada: no se ha validado todavía el orden de carga completo con datos reales de especie/Supabase, ni la recuperación ante interrupciones reales del proceso. La muerte sigue sin ser un snapshot guardable: guardar_partida() y el guardado de Historia rechazan al jugador muerto.


### Validación estructural de partidas

Se añadió validación del contrato de save en GameState, separada de la validación JSON de SaveFileRepository. Al listar o iniciar una partida se rechazan IDs internos que no coinciden, estructuras de estado no Dictionary, snapshots anidados con tipos incorrectos y versiones futuras. Los saves legacy sin campo version se interpretan como versión 1. Se añadió test_game_state_save_payload_contract; pendiente de ejecución.


## Orden de carga de especie y restauración vital — 2026-11-20

Se corrigió una dependencia de inicialización detectada en la auditoría: `Player.configurar_dependencias()` se ejecuta después de `Player._ready()`, por lo que la configuración persistida del personaje podía no haberse aplicado cuando se iniciaba la carga de Eterium. Ahora se aplica al inyectar GameState/Supabase, antes de resolver las reglas de especie.

La restauración de reservas espera a que estén resueltos tanto el runtime general de Eterium como las reglas de especie (incluido el resultado de catálogo sin regla aplicable). Player publica `configuracion_eterium_lista`; GameStateService se suscribe una sola vez y reintenta la aplicación del snapshot al recibirla. Esto evita normalizar vida/Eterium usando máximos por defecto y que una respuesta asíncrona posterior sobrescriba los valores guardados.

Se añadió `test_player_eterium_restore_readiness` y su ejecución al workflow. El test está integrado, pero no se ha ejecutado localmente en esta sesión ni hay confirmación de CI.
