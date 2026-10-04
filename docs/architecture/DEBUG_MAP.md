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
GameplayInputRouter → CombatSystem → CombatController → CombatTargeting / CombatDamage → target.

Archivos principales:
- scripts/gameplay/combat_system.gd
- controladores Combat existentes
- InventoryEquipment para estado del arma
- entidades objetivo para recibir daño.

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
