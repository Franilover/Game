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

Ruta jugador:
GameplayInputRouter → CombatSystem → CombatController → CombatSystem → CombatItemResolver → CombatAttackExecutor → CombatAttackArea / CombatProjectile → CombatTargeting / CombatDamage → Entity.

Ruta criatura:
CreatureAI (objetivo, perfil, estado y momento del ataque) → CombatSystem → CombatDamage → Entity / Creature → señales de criatura → CreatureAI.
- Ataques genéricos de IA: CreatureAI → CombatSystem.solicitar_danio_desde_entidad() → CombatDamage → CombatAttackResult. La API booleana aplicar_danio_desde_entidad() permanece como wrapper y sólo devuelve true si la salud disminuyó.
- Cambiaformas con arma: CreatureAI → CombatSystem.solicitar_ataque_con_arma() → CombatWeaponAttackValidator → aplicación de daño/contacto → CombatAttackResult devuelto a CreatureAI.
En la ruta de Cambiaformas, solicitud aceptada, contacto registrado y daño aplicado son estados independientes.

Responsabilidades:
- `CombatController`: valida el bloqueo de entrada y emite el snapshot de dirección, objeto y modo.
- `CombatItemResolver`: interpreta la clasificación y propiedades del objeto; no crea ataques ni aplica daño.
- `CombatAttackExecutor`: construye y conecta los nodos melee/proyectil; no decide cuándo se ataca ni resuelve impactos.
- `CombatWeaponAttackValidator`: valida atacante, objetivo vivo y clasificación de arma; no ejecuta acciones ni modifica estado.
- `CombatAttackResult`: comunica por separado aceptación de solicitud, contacto registrado, daño aplicado y motivo de rechazo tanto en armas como en daño genérico de entidades.
- `CombatSystem`: ejecuta solicitudes validadas, aplica cooldown y coordina daño, contacto/eventos públicos y robo de vida. `solicitar_danio_desde_entidad()` y `solicitar_ataque_con_arma()` devuelven resultados tipados; la aceptación no equivale a daño aplicado.
- `CreatureAI`: decide a quién atacar, según qué perfil y cuándo; administra su máquina de estados y solicita la ejecución a `CombatSystem`. No modifica salud.
- `Entity`: conserva `VitalState`, salud y ciclo vital. Es el dueño del estado de vida. La señal `died` se emite una sola vez por transición a muerto; restaurar una partida muerta no reproduce el evento histórico.
- `Creature`: extiende `Entity` con datos y comportamiento de especie. Publica `configuracion_actualizada` y `danio_recibido`; no llama directamente a `CreatureAI` para entregar esos dos eventos.
- `CreatureAI` escucha las señales de su `Creature`: actualiza su configuración cuando ésta cambia y decide su reacción cuando recibe daño. La IA no es dueña de la salud.
- `CombatImpactEffects`: procesa una sola vez los efectos de cada daño confirmado: agresión ecológica del jugador, registro de derrota, absorción de Eterium del jugador derrotador, reacción de IA ante armas y feedback visual. No aplica daño.
- `CombatProjectile`: aplica daño mediante `CombatDamage`; publica contacto aunque no haya daño y emite el evento de impacto únicamente cuando la salud disminuye.
- `CombatDamage`: único punto que reduce salud; no registra derrotas, no absorbe Eterium ni produce feedback.
- `CombatTargeting`: valida objetivos.

Archivos principales:
- scripts/gameplay/combat_system.gd
- scripts/gameplay/combat/combat_controller.gd
- scripts/gameplay/combat/combat_item_resolver.gd
- scripts/gameplay/combat/combat_attack_executor.gd
- scripts/gameplay/combat/combat_weapon_attack_validator.gd
- scripts/gameplay/combat/combat_attack_result.gd
- scripts/gameplay/combat/combat_impact_effects.gd
- scripts/gameplay/combat/combat_attack_area.gd
- scripts/gameplay/combat/combat_projectile.gd
- InventoryController / InventoryEquipment para el objeto y el equipamiento
- entidades objetivo para recibir daño.

La dirección enviada por `CombatController` forma parte del snapshot de la acción: `CombatSystem` debe propagarla hasta el hitbox o proyectil, sin volver a leer el facing después de aceptar la solicitud. Sólo se usa el facing actual como fallback para una dirección cero.

Si la IA elige un objetivo, alcance o perfil equivocado, revisar `CreatureAI`. Si una solicitud se rechaza, revisar `CombatWeaponAttackValidator`; si se acepta pero contacto o daño no coinciden, inspeccionar `CombatAttackResult` y `CombatSystem`. Para la ejecución revisar `CombatItemResolver` y `CombatAttackExecutor`. Si salud o muerte no cambian bien, revisar `Entity` / `CombatDamage`. Si no llega una reacción de criatura, revisar las señales `configuracion_actualizada` y `danio_recibido` y la suscripción de `CreatureAI`. Si los efectos posteriores están equivocados, revisar `CombatImpactEffects`.

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


### Reentrada durante contacto de IA/melee

Si el contacto se registra pero el daño no debe continuar, inspeccionar los listeners de `contacto_efectivo` y el contrato de revalidación posterior en `CombatSystem.solicitar_danio_desde_entidad()` y `CombatSystem._aplicar_danio()`. No mover esta regla a `CreatureAI`: cubre también melee y Cambiaformas. Para Rancrodeen adherido, comprobar `CombatTargeting.es_objetivo_valido()` antes de cada pulso.


### Reentrada al recibir daño de criaturas

Si `danio_recibido` informa un atacante incorrecto durante varios impactos en el mismo frame, revisar `Creature._aplicar_danio_recibido()`. El atacante debe permanecer local a cada invocación; no reintroducir un campo temporal compartido. La regresión está en `tests/combat/test_combat_creature_damage_reentrancy.gd`.


### Recuperación y curación de Eterium

Si el jugador no recupera Eterium, revisar `Player._aplicar_movimiento_normal()`, `PlayerEteriumCoordinator` y `PlayerEteriumRuntime.actualizar_recuperacion()`. La recuperación pasiva y la curación automática se procesan sólo durante quietud en `IDLE`. Si una entidad muerta altera sus reservas, revisar las guardas de `is_alive` en `PlayerEteriumRuntime`. La curación automática debe rechazarse cuando `vida_eterium_compartidos()` sea true; no convertirla en gasto de la misma reserva que representa la vida.

Si el primer movimiento tras reaparecer consume Eterium acumulado de la vida anterior, revisar `Player.reaparecer()`, `Player.reaparecer_en_red()` y `PlayerEteriumRuntime.reiniciar_temporizadores()`. El coordinador de sprint debe rechazar jugadores muertos y limpiar cualquier coste pendiente inválido.


## Guardado y restauración de vida/Eterium

Ruta: GameStateService.capturar_estado_desde_juego() → PlayerState → JSON local → PlayerState.normalizar_reservas_vitales() → Entity.restaurar_estado_vital().

- Si salud/Eterium aparecen fuera de rango, revisar la normalización de PlayerState; las capacidades máximas vienen del Player/runtime actual, no del save.
- Si una especie usa reserva compartida, ambas reservas deben terminar iguales. Ante un snapshot inconsistente se conserva el menor valor para no crear recursos.
- Si un snapshot llega con salud cero, debe restaurarse como muerto. No cambiar el argumento vivo a true sin comprobar la salud efectiva.
- Los guardados normales e Historia no persisten al jugador muerto; el último snapshot vivo se conserva hasta el respawn y el siguiente guardado válido.
- Contrato: tests/state/test_player_state_vital_persistence_contract.gd. Aún pendiente de ejecución local/CI.


### Contrato del archivo de partida

Antes de depurar una partida que no aparece o no carga, separar dos capas: SaveFileRepository comprueba que el archivo sea JSON Dictionary recuperable; GameStateService._datos_partida_cargables valida ID, versión compatible y estructura estado/player/flags. Versiones legacy sin version se interpretan como versión 1; versiones futuras o snapshots con tipos incorrectos se rechazan sin aplicar estado parcial. Contrato: tests/persistence/test_game_state_save_payload_contract.gd.


### Save carga vida/Eterium con máximos equivocados

Comprobar el orden `Main._inicializar_runtime_de_zona()` → `Player.configurar_dependencias()` → configuración de personaje/especie → runtime Eterium → `GameStateService._revisar_escena_actual()`. Si la respuesta de especie llega antes que la respuesta general de Eterium, comprobar que Player reaplique la capacidad específica después del runtime general. Sólo la restauración vital espera `Player.esta_listo_para_restaurar_estado()`; mientras tanto, los guardados deben quedar bloqueados si ya se aplicó el resto del snapshot para no reemplazar el archivo original con reservas temporales; posición, inventario y misiones deben seguir aplicándose aunque Eterium esté pendiente; si no se emite `configuracion_eterium_lista`, revisar la carga de `eterium_runtime_cargado` y `especie_eterium_game_cargado` en SupabaseClient. No mover la normalización de reservas antes de resolver capacidades y fisiología.


### Inventario/equipo incorrecto tras cargar una partida

Revisar `GameStateService._datos_partida_cargables()` y `_inventario_guardado_valido()` antes de inspeccionar el runtime. La carga usa `GarliaInventory.cargar_estado_partida()` → `InventoryController.establecer_equipamiento()` → `InventoryRuntime.establecer_equipamiento()`; esta última operación reemplaza las ranuras y solo acepta armaduras compatibles. Si persiste una pieza vieja, comprobar que el flujo de carga invoca el setter y que la señal de actualización de equipamiento se procesa. Si hay objetos que no aparecen, revisar `InventoryScroll/Grid` y los grupos `RESERVA N`; la UI debe crear tantos controles como ranuras contiene el snapshot.

Si una partida falla al aparecer en el selector, revisar primero `GameStateService._datos_partida_cargables()`: además de JSON, comprueba tipos de `mundo`, semilla, versión, tiempo, escena, reservas y vectores del jugador. No relajar la validación sin añadir un caso legacy concreto al contrato.


### Objetos guardados que no aparecen en inventario

La cuadrícula visible se reconstruye en `GarliaInventory.cargar_estado_partida()` después de normalizar la capacidad. Comprueba `max(slot_count, items.size())`, el nodo `InventoryScroll/Grid` y los grupos `RESERVA N`. Los índices de cada botón se guardan en el metadata `inventory_index`; no recortar `items` al tamaño base de 18. El contrato `InventoryOverflowUI` cubre una carga de 30 ranuras.


### Una transición deja el mundo sin zona activa

Revisar `ZoneManager._cambiar_zona()`: debe cargar e instanciar el destino antes de ejecutar `queue_free()` sobre la zona actual. Si la ruta o instancia falla, `_transicionando` debe volver a `false` y `zona_actual` debe seguir apuntando a la zona previa. El contrato de regresión está en `tests/world/test_zone_manager_torres_fallback.gd`.

En servidor dedicado, si aparece el aviso de transición cancelada por fallo de snapshot, revisar primero `GlobalWorldStore.guardar_desde_runtime()`, permisos/ruta `--world-data`, escritura temporal y respaldo. ZoneManager conserva la zona activa deliberadamente hasta que el guardado global confirme.
