# Auditoría arquitectónica de Garlia — 2026-10-04

## Alcance

Revisión estática del árbol de GitHub `Franilover/Game`, rama `main`, enfocada en estructura de archivos, ownership del estado, composición de dependencias, búsqueda implícita de nodos y responsabilidades demasiado grandes. No se ejecutó Godot ni se verificó compilación local.

## Hallazgos confirmados

### Corregidos durante esta pasada

1. **Estado persistido encapsulado en GameState**
   - Se añadieron APIs específicas para leer/escribir configuración de personaje, configuración administrativa, relaciones sociales, recuerdos sociales y proceso IUM equipado.
   - Player, AdminConsole, RelationshipSystem y Main dejaron de acceder directamente a `GameState.flags`.
   - `GameState` conserva `world_state.flags` como detalle interno de serialización; no se expone el diccionario mutable a los consumidores.

2. **SupabaseClient dejó de inspeccionar el árbol de escena**
   - Antes buscaba `World/WorldGenerator` bajo `get_tree().current_scene` cada vez que se disparaba la sincronización periódica.
   - Ahora mantiene un estado explícito `_mundo_activo_en_escena`, configurado por Main al entrar y salir de la escena de juego.
   - Esto elimina una dependencia de infraestructura hacia la estructura interna de una escena.

3. **AdminPlayerEditor tiene composición explícita**
   - Antes AdminConsole buscaba `UI` y `AdminPlayerEditor` en la escena actual y creaba el editor dinámicamente si no existía.
   - AdminPlayerEditor ahora está declarado en `scenes/world/main.tscn` y Main lo inyecta a AdminConsole.
   - AdminConsole ya no busca ni crea el editor mediante SceneTree.

4. **Tipos concretos en dependencias del mundo**
   - Main declara WorldContext como `WorldContext` y WorldAtmosphere como `WorldAtmosphere`, en lugar de referencias genéricas `Node`.

5. **Limpieza menor**
   - Se eliminaron constantes de claves sociales que quedaron obsoletas después de mover la persistencia a APIs de GameState.

## Estructura actual observada

### Puntos fuertes

- `Main` funciona como raíz de composición para Player, HUD, Inventory, Combat, Interaction, Dialogue, IUM y mundo.
- `WorldGenerator` se concentra principalmente en orquestar la generación y sus subsistemas.
- `WorldContext` es la API de consulta del mundo.
- `WorldEntityManager`, `WorldEntitySpawner`, `WorldEntityFactory` y `WorldSpawnRules` tienen responsabilidades separadas.
- Inventory separa UI, Controller, Runtime, State, Hotbar y Equipment.
- Combat separa ataque, targeting, daño, defensa, feedback y proyectiles.
- GameState usa PlayerState, WorldState y DiscoveryState para snapshots persistibles.

### Responsabilidades grandes que aún necesitan auditoría antes de dividirse

| Archivo | Tamaño observado antes de esta pasada | Siguiente acción |
|---|---:|---|
| `scripts/core/game_state.gd` | ~1.000 líneas | Separar responsabilidades de ciclo de guardado/aplicación sin duplicar estado |
| `scripts/characters/player.gd` | ~968 líneas | Identificar lógica que todavía pertenece a controladores existentes |
| `scripts/ui/hud.gd` | ~1.079 líneas | Separar presentación por responsabilidad solo donde exista comportamiento independiente |
| `scripts/dev/admin_console.gd` | ~1.250 líneas | Extraer comandos por dominio si reduce acoplamiento; no es prioridad de gameplay |
| `scripts/infrastructure/supabase_client.gd` | ~780 líneas | Distinguir transporte HTTP de cargas/operaciones de dominio |
| `scripts/gameplay/mission_manager.gd` | ~607 líneas | Revisar ownership del estado y persistencia antes de dividir |

Estos tamaños son indicadores para investigar, no una orden automática de dividir los archivos.

## Riesgos y deuda pendiente

### 1. GameState

Aunque los consumidores ya no modifican `GameState.flags` directamente en los archivos migrados, GameState sigue siendo un coordinador grande de:
- ciclo de vida de partidas;
- archivos locales;
- captura/aplicación de PlayerState;
- estado del mundo;
- inventario y misiones guardados;
- descubrimientos;
- configuración de personaje;
- compatibilidad de datos anteriores.

Próximo paso: separar el ciclo de guardado/carga en un coordinador dedicado solo después de mapear todas las llamadas y señales. No crear otra fachada de estado.

### 2. SupabaseClient y repositorios

SupabaseClient todavía concentra varias cargas de dominios diferentes además del transporte. Ya existe la ruta IUMManager → IUMRepository → SupabaseClient, y la ruta social usa SocialRepository. Antes de extraer más repositorios hay que inventariar cada método, sus consumidores y sus señales para evitar repositorios duplicados o una migración parcial.

### 3. Dependencias dinámicas

Main es la raíz de composición, pero varias conexiones todavía se hacen mediante `has_method()` y `call()` sobre referencias de tipo `Node`. Esto permite compatibilidad, pero reduce comprobación estática. Migrar gradualmente a tipos concretos e interfaces claras, sin reescribir todo de una vez.

### 4. Ciclo de vida de escena

GameState todavía consulta `current_scene` para comprobar si hay una escena activa y registrar cambios de escena. Es una comprobación de ciclo de vida, no una búsqueda de dependencias. No se debe eliminar sin reemplazar la señalización de ciclo de vida.

### 5. Autoloads

`project.godot` contiene 13 autoloads: GameplayInputRouter, Events, GameState, SceneManager, SupabaseClient, SocialRepository, WorldData, GarliaAuth, GarliaMultiplayer, GarliaWorldItems, GarliaSalas, MissionManager y RelationshipSystem.

No deben reducirse por número solamente. El siguiente paso es clasificar cada uno como servicio de aplicación global, infraestructura compartida o sistema de escena, y moverlo únicamente si sus consumidores lo permiten.

### 6. Archivos muertos y referencias legacy

No se eliminaron archivos basándose únicamente en su nombre. Una auditoría completa de archivos muertos requiere contrastar cada script, clase, escena, preload, UID y referencia desde escenas/recursos. Los scripts eliminados en pasadas anteriores no deben volver a crearse como duplicados.

## Orden de trabajo recomendado

1. Terminar un inventario de consumidores para los sistemas grandes: GameState, SupabaseClient, Player, HUD y AdminConsole.
2. Auditar señales y contratos entre Main, Player, HUD, DialogueSystem, MissionManager y RelationshipSystem.
3. Auditar autoloads y distinguir servicios globales de sistemas que deberían vivir en Main.
4. Identificar scripts, escenas y recursos sin referencias; eliminar solo con evidencia.
5. Refactorizar GameState en cambios pequeños y verificables, manteniendo un único propietario del estado.
6. Separar SupabaseClient por dominio solo cuando los métodos y consumidores estén mapeados.
7. Revisar nombres de dependencias, tipos concretos y APIs de compatibilidad restantes.
8. Ejecutar una prueba completa en Godot después de cada grupo de cambios: inicio, crear partida, cargar partida, inventario, interacción, combate y guardado.

## Verificación

- Los archivos centrales migrados en esta pasada ya no contienen accesos directos `GameState.flags`.
- SupabaseClient ya no busca WorldGenerator en `current_scene`.
- AdminConsole ya no busca ni crea AdminPlayerEditor dinámicamente.
- No se afirma que el proyecto compile: los cambios requieren validación en Godot local.
