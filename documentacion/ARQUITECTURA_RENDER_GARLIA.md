# Arquitectura de Renderizado y Optimización de Garlia

## Estado
Fase actual: **Fase 5 — estado lógico y representación de props en progreso**.

Las fases 1–3 están implementadas. TileMapDual se conserva como backend visual y no se aumenta la carga de assets.

Este documento define la arquitectura que sustituye progresivamente los parches aislados de streaming y renderizado.

## Principio rector
1. Supabase / World Data: define qué existe canónicamente.
2. World Simulation: mantiene el estado lógico.
3. World Streamer: decide qué zona necesita trabajo cercano.
4. Render Manager: decide qué representación visual merece existir y cuándo puede construirse sin romper el frame.
5. Godot: backend de representación y ejecución.

```text
SUPABASE → WORLD DATA → WORLD SIMULATION → SPATIAL CHUNKS → WORLD STREAMER → RENDER MANAGER → GODOT
                                                     ├─ Terrain Renderer
                                                     ├─ Prop Renderer
                                                     └─ Entity Renderer
```

## Diagnóstico que origina el cambio
El profiler mostró que el coste principal no está dominado por las criaturas visibles. Durante la carga del terreno, render_objects crece de decenas a miles y aparecen picos de process_ms de aproximadamente 400–600 ms, con caídas temporales a 1–15 FPS.

El número de criaturas puede permanecer estable mientras el coste de renderizado aumenta. Esto apunta al trabajo de construcción/actualización del terreno, especialmente al trabajo derivado de TileMapDual.

Reducir cells_per_frame es un control de emergencia, no una arquitectura.

## Referencias técnicas

### Unreal Engine — World Partition / HLOD
World Partition divide el mundo en celdas espaciales y carga las necesarias alrededor de los streaming sources. HLOD permite representar regiones lejanas mediante una representación agregada y más barata.
Referencias:
- https://dev.epicgames.com/documentation/en-us/unreal-engine/world-partition-in-unreal-engine
- https://dev.epicgames.com/documentation/en-us/unreal-engine/world-partition---hierarchical-level-of-detail-in-unreal-engine
Aplicación a Garlia: chunks espaciales, prioridades de representación y futura representación simplificada.

### Unity — DOTS / ECS
ECS separa datos de entidades de su representación como objetos y favorece recorridos de datos contiguos y sistemas especializados.
Referencias:
- https://unity.com/dots
- https://learn.unity.com/article/c-and-dots-specific-performance-tips
Aplicación a Garlia: CreatureData puede existir sin un Creature Node. Los Nodes son proxies visuales/físicos temporales.

### Godot — TileMapLayer
Godot optimiza TileMap/TileMapLayer para grandes cantidades de tiles. La estrategia no es sustituirlo por miles de Sprite2D, sino alimentarlo con cambios agrupados.
Referencia: https://docs.godotengine.org/en/latest/tutorials/2d/using_tilemaps.html

### Godot — MultiMesh
MultiMesh permite representar grandes cantidades de instancias con bajo coste de draw calls, pero no tiene culling individual por instancia.
Referencia: https://docs.godotengine.org/en/latest/tutorials/performance/using_multimesh.html
Aplicación: candidato para decoración estática masiva, no para criaturas interactivas.

### Godot — Servers
Los Servers permiten bajar de SceneTree a una capa de ejecución más directa cuando la sobrecarga de Nodes se vuelve dominante.
Referencia: https://docs.godotengine.org/en/latest/tutorials/performance/using_servers.html
Aplicación: opción futura, no primer paso.

### Geometry Clipmaps
Los geometry clipmaps muestran cómo mantener una representación estable alrededor del observador y actualizar sólo las regiones necesarias.
Referencia: https://developer.nvidia.com/gpugems/gpugems2/part-i-geometric-complexity/chapter-2-terrain-rendering-using-gpu-based-geometry
Aplicación: adoptar el principio de no reconstruir datos que no cambiaron.

## Arquitectura objetivo
```text
WORLD DATA → WORLD SIMULATION → SPATIAL CHUNKS → WORLD STREAMER → RENDER MANAGER
                                                           ├─ TERRAIN
                                                           ├─ PROPS
                                                           └─ CREATURES
```

### Estados de un chunk
UNLOADED → DATA_READY → RENDER_BUILDING → VISIBLE → DIRTY → REBUILDING → VISIBLE

El chunk no debe entrar y salir repetidamente de estados por cada celda.

## Render Proxy
Los datos lógicos y su representación visual se separan.
```text
CreatureData
 ├─ id
 ├─ criatura_id
 ├─ position
 ├─ chunk
 ├─ health
 └─ state
      ↓ sólo si está activa
CreatureRenderProxy
 ├─ CharacterBody2D
 ├─ Sprite2D
 ├─ Collision
 ├─ Animation
 └─ AI
```
Al salir del chunk se captura el estado y se desactiva/reutiliza el proxy. Al volver, se restaura el estado. La simulación no depende de Nodes visibles.

## Terrain Renderer
Arquitectura actual: WorldTerrain → WorldTerrainVisual → múltiples TileMapDual → DisplayLayer → actualizaciones derivadas por celda.

Arquitectura objetivo: WorldTerrainData → ChunkTerrainCache → Dirty Regions → Terrain Renderer → TileMapLayer.

El renderer debe preparar la visualización de un chunk antes de tocar el backend gráfico y agrupar cambios.

## Dirty Regions
No interpretar cada celda modificada como una tarea independiente. Las celdas cercanas deben combinarse en regiones y reconstruirse juntas.

## Presupuesto temporal
El presupuesto no debe medirse únicamente en cantidad de celdas, porque una celda puede producir distinto trabajo dependiendo de vecinos, transiciones y capas.

Objetivo inicial para 60 FPS: reservar aproximadamente 2–4 ms para trabajo de render diferible, sin convertirlo en un límite rígido. Si el renderer agota su presupuesto, detiene trabajo diferible y continúa en el siguiente frame.

## Prioridades
0 — chunk actual.
1 — chunk que está entrando en pantalla.
2 — prefetch inmediato.
3 — trabajo de fondo.
El trabajo de prioridad 0 nunca debe quedar bloqueado detrás de un chunk lejano.

## Pooling
Los Nodes de alta rotación deben reutilizarse cuando tenga sentido: criaturas, proyectiles, efectos y props dinámicos.

Preferir pool → activate(data) → deactivate() frente a instantiate → free repetidamente.

## LOD
```text
cerca → representación completa
medio → representación simplificada
lejos → representación agregada / sólo datos / nada
```
Implementarlo sólo si el profiling demuestra beneficio.

## Qué no hacer
No seguir acumulando como solución definitiva cambios arbitrarios de cells_per_frame, radios, flushes, erase_cell o más Nodes. Estos parámetros pueden existir como controles de seguridad, pero no son el diseño.

## Plan de implementación
### Fase 1 — Render Manager e instrumentación — COMPLETADA
- GarliaRenderManager creado.
- Presupuesto temporal por frame.
- Registro acumulado y por frame del trabajo visual.
- Separación de métricas de streaming/renderer.

### Fase 2 — Desacoplamiento — COMPLETADA
- WorldStreamer decide qué chunks necesitan trabajo.
- RenderManager decide cuánto trabajo puede entrar en el frame.
- WorldTerrain recibe el presupuesto sin convertirse en dueño del streaming.
- La carga inicial sigue usando el mismo backend visual.

### Fase 3 — Terrain Render Queue — COMPLETADA
- Trabajo de terreno dividido en preparación, pintura y flush.
- Presupuesto adaptativo según tiempo restante del frame.
- Dirty cells deduplicadas mediante lookup.
- Consumo espacial por regiones contiguas antes de completar el lote.
- Flush de TileMapDual limitado por presupuesto.
- Métricas `terrain_flush` registradas en RenderManager.
- Sin reemplazar TileMapDual ni aumentar la cantidad de assets necesarios.

### Fase 2 — Desacoplamiento
- WorldStreamer decide qué chunks necesitan trabajo.
- GarliaRenderManager decide qué trabajo visual se ejecuta.
- WorldTerrain deja de conocer detalles del presupuesto gráfico.

### Fase 4 — Entity Renderer — MAYORMENTE COMPLETADA
- Estado lógico de criaturas separado del ciclo de vida del Node.
- Render Proxy reutilizable para criaturas.
- Pool de proxies en WorldEntityFactory.
- Al descargar un chunk se conserva el estado lógico y el proxy se desactiva/reutiliza en lugar de destruirlo.
- Al recargar se restaura posición, velocidad, vida y estado.
- Claves estables natural:<slot>:<criatura_id> y personaje:<personaje_game_id> evitan colisiones entre instancias.
- Las criaturas fuera del chunk activo no mantienen proxies en el SceneTree.
- La muerte persistente sigue evitando respawns automáticos.

Pendiente menor de Fase 4:
- Integrar un presupuesto/cola temporal explícita para spawn/despawn cuando una transición de chunk requiera muchas entidades simultáneamente. El pool reduce el coste de creación, pero no se considera cerrado hasta que esa cola sea independiente del spawn síncrono.

### Fase 5 — Props
- Separar props lógicos de representación.
- Pooling para props dinámicos.
- Evaluar MultiMesh para decoración estática masiva.

### Fase 6 — Optimización avanzada
Si los datos lo justifican: representación simplificada, instancing, Servers o técnicas de caché espacial/clipmaps.

## Métricas mínimas
Render: frame_budget_ms, frame_used_ms, terrain_build_ms, terrain_update_ms, terrain_dirty_cells, terrain_dirty_regions, terrain_chunks_visible, terrain_chunks_building, props_visible, creatures_visible, render_proxy_create_ms, render_proxy_destroy_ms, deferred_work_remaining.

Además: FPS, frame_ms, draw_calls, render_objects, render_primitives, physics_ms y process_ms.

## Criterio de éxito
1. El chunk actual aparece primero.
2. Cruzar un límite de chunk no provoca picos de cientos de ms.
3. El trabajo diferible respeta un presupuesto temporal.
4. Las criaturas fuera del chunk no requieren Nodes activos.
5. render_objects deja de crecer sin relación con lo visible.
6. Volver a un chunk no reconstruye innecesariamente datos válidos.
7. Supabase mantiene la autoridad canónica.

## Regla de ingeniería
MEDIR → IDENTIFICAR CUELLO DE BOTELLA → CAMBIAR ARQUITECTURA → MEDIR DE NUEVO → CONSERVAR SÓLO SI MEJORA.

Garlia no debe convertirse en una colección de microparches de rendimiento.

## Siguiente fase

### Fase 4 — Entity Render Manager — PARCIALMENTE COMPLETADA
1. Estado runtime de criaturas separado del ciclo de vida del Node.
2. WorldEntityManager conserva posición, velocidad, vida y estado al descargar un chunk.
3. Al recargar, WorldEntitySpawner restaura ese estado en lugar de tratar la criatura como nueva.
4. Las criaturas fuera del chunk activo siguen sin Nodes activos.
5. La muerte de una criatura se conserva y evita su reaparición automática.

Pendiente dentro de esta fase:
- pooling de proxies.
- presupuesto explícito para spawn/despawn de entidades.
- soporte de más de una instancia natural de la misma criatura por chunk mediante una clave estable de instancia.

### Fase 5 — Props — PARCIALMENTE COMPLETADA
1. WorldProp conserva datos canónicos de props_game y sigue siendo sólo la representación activa.
2. WorldEntityManager guarda estado runtime de props fuera del ciclo de vida del Node.
3. WorldEntityFactory reutiliza WorldProp mediante pool.
4. Las claves prop:<slot>:<prop_id> permiten distinguir instancias dentro del chunk.
5. props_game.item_id continúa siendo el vínculo canónico con items.
6. El pool no sustituye la lógica de interacción/recolección: los props interactivos siguen siendo WorldProp normales cuando están activos.

Pendiente:
- cola temporal explícita para spawn/despawn de props.
- separar definitivamente PropData de la representación Node si el profiling demuestra que el diccionario actual no es suficiente.
- evaluación de MultiMesh sólo para decoración estática masiva.
