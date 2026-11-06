# Garlia — Mapa de diagnóstico por sistema

Usar este mapa antes de modificar código. La regla es corregir en el dueño del estado, no en el sistema que simplemente muestra el síntoma.

## Input / clicks

Ruta:
InputEvent → GameplayInputRouter → InteractionSystem / CombatSystem → dominio → Presentation.

Si falla el click:
1. scripts/core/gameplay_input_router.gd
2. scripts/world/main.gd — composición de dependencias
3. scripts/gameplay/interaction_system.gd si es interacción
4. scripts/gameplay/combat_system.gd si es ataque
5. UI sólo si el input está siendo bloqueado por un panel.

No empezar modificando HUD para arreglar gameplay input.

## Inventario / hotbar / equipamiento

Responsabilidades:
- InventoryRuntime: estado de inventario.
- InventoryController: operaciones.
- InventoryEquipment: equipado real.
- InventoryHotbar: representación/selección.
- HUD/Inventory: presentación.

Regla:
Hotbar seleccionada no equivale automáticamente a arma equipada.

Si un arma aparece pero no se equipa:
revisar InventoryEquipment antes que HUD.

## Combate

Ruta:
GameplayInputRouter → CombatSystem → CombatController → CombatSystem → CombatItemResolver → CombatAttackExecutor → CombatAttackArea / CombatProjectile → CombatTargeting / CombatDamage → Entity.

Responsabilidades:
- `CombatController`: valida el bloqueo de entrada y emite el snapshot de dirección, objeto y modo.
- `CombatItemResolver`: interpreta la clasificación y propiedades del objeto; no crea ataques ni aplica daño.
- `CombatAttackExecutor`: construye y conecta los nodos melee/proyectil; no decide cuándo se ataca ni resuelve impactos.
- `CombatSystem`: orquesta la acción, cooldown y aplicación de daño; conserva la absorción de Eterium, los contratos de contacto/ataque y el robo de vida.
- `CombatImpactEffects`: ejecuta reacciones de `CreatureAI`, registro de derrotas, agresión ecológica y feedback visual después de que el daño ya fue confirmado; no modifica salud.
- `CombatTargeting`: valida objetivos.
- `CombatDamage`: aplica daño.

Archivos principales:
- scripts/gameplay/combat_system.gd
- scripts/gameplay/combat/combat_controller.gd
- scripts/gameplay/combat/combat_item_resolver.gd
- scripts/gameplay/combat/combat_attack_executor.gd
- scripts/gameplay/combat/combat_impact_effects.gd
- scripts/gameplay/combat/combat_attack_area.gd
- scripts/gameplay/combat/combat_projectile.gd
- InventoryController / InventoryEquipment para el objeto y el equipamiento
- entidades objetivo para recibir daño.

La dirección enviada por `CombatController` forma parte del snapshot de la acción: `CombatSystem` debe propagarla hasta el hitbox o proyectil, sin volver a leer el facing después de aceptar la solicitud. Sólo se usa el facing actual como fallback para una dirección cero.

Si el ataque usa el modo o las dimensiones equivocados, revisar `CombatItemResolver`. Si el hitbox/proyectil no se crea o no conserva propiedades/conexiones, revisar `CombatAttackExecutor`. Si el impacto y sus efectos posteriores están equivocados, revisar el handler correspondiente de `CombatSystem`.

No poner lógica de inventario dentro del HUD.

## Interacción

Ruta:
InteractionSystem → objetivo_cambiado → Main → HUD.

InteractionSystem no dibuja el prompt.

Si aparece el prompt pero no ejecuta:
revisar InteractionSystem.

Si ejecuta pero no aparece:
revisar conexión objetivo_cambiado en Main y el HUD.

## Mundo / generación

Ruta:
WorldGenerator
→ WorldTerrain
→ WorldStreamer
→ WorldEntitySpawner
→ EntityManager / Factory / SpawnRules.

### WorldGenerator
Orquesta. No debe crear sistemas dinámicamente ni administrar entidades.

### WorldTerrain
Estado y simulación del terreno.

### WorldTerrainVisual
Sólo representación del terreno.

### WorldStreamer
Decide cuándo cargar/descargar chunks.

### WorldSpawnRules
Decide qué entidades son válidas en una ubicación.

### WorldEntityFactory
Sabe qué escena corresponde a una entidad.

### WorldEntityManager
Es dueño del ciclo de vida y registro de nodos.

Si un chunk genera mal:
- datos/terrain → WorldTerrain / WorldData
- cuándo se genera → WorldStreamer
- qué aparece → WorldSpawnRules
- qué escena aparece → WorldEntityFactory
- entidad que no desaparece/aparece duplicada → WorldEntityManager

No corregir problemas de generación modificando el renderer.

## Renderizado de entidades

Ruta:
WorldEntityManager → Entities → entidad → Sprite2D/AnimatedSprite2D.

El terreno no debe gestionar el z de criaturas, props o Player.

Si una entidad existe/interactúa pero no se ve:
1. entidad concreta
2. su CanvasItem/z/depth
3. Entities
4. renderer del terreno
5. sólo después investigar TileMapDual.

No añadir z_index aleatorios a sistemas completos.

## Supabase / IUM

Ruta:
IUMManager → IUMRepository → SupabaseClient → RPC/REST.

IUMManager no conoce URLs, API keys ni HTTPRequest.

Si IUM falla:
- reglas/runtime → IUMManager
- contrato de datos/RPC → IUMRepository
- transporte/autenticación → SupabaseClient
- función canónica → Supabase.

## Misiones / diálogo

DialogueSystem coordina la conversación, pero no debe convertirse en dueño de MissionManager ni RelationshipSystem.

Futura ruta:
Dialogue → eventos/servicios de dominio → Mission / Relationship.

## Regla de dependencias

Permitido:

Presentation → Gameplay → Domain → Infrastructure.

También:

World orchestration → World subsystems.

No permitido:

Infrastructure → HUD
Gameplay → HTTP
Terrain → Combat
HUD → generación
SpawnRules → Factory
Factory → SpawnRules
Renderer → reglas de spawn

## Checklist antes de tocar código

1. ¿Quién es dueño del estado?
2. ¿Quién sólo presenta ese estado?
3. ¿Quién decide la regla?
4. ¿Quién crea el objeto?
5. ¿Quién administra su vida?
6. ¿La dependencia ya está disponible para inyectarse?
7. ¿Estoy arreglando la causa o sólo el síntoma?


## Estado y misiones

GameState conserva el guardado local, pero recibe Player, Inventory y WorldGenerator desde Main.
MissionManager conserva progreso de la partida y recibe Player y WorldEntityManager.
DialogueSystem coordina presentación y acciones de diálogo, pero recibe MissionManager y RelationshipSystem por inyección.
RelationshipSystem conserva el estado social y recibe SocialRepository para los datos canónicos de Supabase.


## Inventario — frontera actual

`GarliaInventory` es Presentation/UI; crea y contiene `InventoryController`, y recibe `Player` e `InputGate` desde `Main`.
`InventoryController` coordina `InventoryRuntime` y expone operaciones de dominio para consultar manos, usar/consumir objetos y consumir durabilidad.
`InventoryRuntime` conserva el estado canónico separado en items, hotbar y equipment.

`InteractionSystem` recibe `InventoryController`, nunca el nodo visual `GarliaInventory`.
Cuando una operación de gameplay cambia una mano, `mano_objeto_cambiado` notifica a la UI para refrescar slots, información y señales de presentación.

La hotbar y el equipamiento son estados distintos. Seleccionar un índice de hotbar no equipa automáticamente el objeto de ese índice.

Si falla la apertura/bloqueo del inventario: `Main → GarliaInventory → InventoryController → GameplayInputRouter`.
Si falla qué objeto está equipado: revisar `InventoryRuntime/Equipment`, no la hotbar ni el HUD.


## Combate y equipamiento — frontera

CombatSystem recibe `InventoryController` desde `Main`; no depende de `GarliaInventory`.
La acción primaria consulta el objeto activo de la mano izquierda y la secundaria consulta el objeto activo de la mano derecha. La durabilidad de una herramienta se consume en la misma mano que ejecutó la acción.

Flujo de objetos: GameplayInputRouter → InteractionSystem / CombatSystem → InventoryController → InventoryRuntime.
Flujo de resolución: CombatController (snapshot dirección/objeto/modo) → CombatSystem → CombatItemResolver → hitbox/proyectil.

El equipamiento real (`InventoryEquipment`) y las manos activas son estados distintos. La hotbar tampoco determina qué objeto de mano ejecuta una acción.

Si un click usa el objeto equivocado: revisar `CombatSystem.procesar_accion_primaria/secundaria()`, `InventoryController.obtener_objeto_mano_activa()` y la selección de mano; no empezar por la UI.
Si el daño recibido ignora armadura: revisar la ruta de equipamiento defensivo del Player y `CombatDefense`.
