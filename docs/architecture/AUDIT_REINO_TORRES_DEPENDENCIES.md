# Auditoría de dependencias: Reino Torres

**Fecha:** 2026-11-19  
**Rama revisada:** `feat/npc-relational-memory-decay`  
**Commit revisado:** `bac3dffe0eeeeb965ac962d3ea217a9ba315b240`  
**Estado:** auditoría estática con primera extracción del constructor del vivero; la prueba de contrato quedó incorporada a CI, pendiente de ejecución.

## 1. Contrato de escena

- `scenes/kingdom/reino_torres.tscn` instancia `scripts/world/reino_torres.gd` en su nodo raíz `ReinoTorres`.
- La escena conserva una gran cantidad de nodos urbanos, marcadores `Entrada`, cuerpos de colisión y sprites editables.
- La posición de edificios y puertas también forma parte del contrato de navegación de NPC. La prueba `tests/world/test_npc_schedule_torres_navigation_bounds.gd` compara destinos de rutina con coordenadas concretas.
- La prueba `tests/world/test_torres_cesped_tilemap.gd` instancia la escena y valida capas, atlas, posiciones y distribución urbana.

**Regla:** no reconstruir ni trasladar el mapa, los edificios, marcadores o colisiones a una escena generada por código como parte de esta refactorización. La escena sigue siendo la fuente editable de esa composición.

## 2. Dependencias y contratos encontrados

### Integración con el mundo

- `ZoneManager` es la autoridad del ciclo de vida de zonas y carga `reino_torres.tscn` mediante `REINO_TORRES_ESCENA_PATH`.
- `main.gd` coordina la materialización y retirada de NPC de Torres, detecta la zona activa y realiza llamadas diferidas para materializarlos después de cargarla.
- `reino_torres.gd` emite `salida_solicitada` y `destino_viaje_solicitado(destino_id)`; el selector de viajes usa la segunda señal.
- Torres expone métodos utilizados fuera del archivo, entre ellos `obtener_posicion_exterior_para_viaje()`, `desactivar_colision_npc_exterior()`, `restaurar_colision_npc()`, `registrar_npc_materializado()`, `sincronizar_npcs_del_interior()`, `teletransportar_jugador_a_npc()` y `sacar_npc_del_interior()`.

### NPC y edificios

- Los NPC se localizan mediante el grupo `torres_game_npc`; la interacción exterior usa `interactable`.
- Los metadatos `rutina_en_edificio`, `rutina_edificio_id`, `rutina_ubicacion`, `rutina_en_transito` y `viajando` enlazan horarios, navegación e interiores.
- El sistema de horarios conoce entradas y coordenadas por separado. La prueba de navegación protege parte de esa duplicación de datos.
- La prueba `test_npc_building_entry_collision.gd` invoca directamente los métodos de colisión de Torres y verifica que las capas/máscaras originales se restauren.

### Interiores, guardado y servicios

- La entrada/salida de interiores coordina visibilidad exterior, colisiones, cámara, jugador y reparentado de NPC.
- `obtener_estado_guardado()` y `restaurar_estado_guardado()` son contratos de persistencia; no deben cambiarse sin revisar al repositorio de guardado y sus pruebas.
- Posada, archivo, laboratorio, comercio y estaciones de edificios crean objetivos de interacción con `Callable` hacia métodos de este nodo.
- Algunos servicios se instancian bajo `SceneTree.root`, fuera de la escena de Torres; su ciclo de vida se limpia en `_exit_tree()`.

### Recursos y presentación

- `torres_pixel_art.gd` ya concentra funciones de generación de texturas pixel-art; `torres_tilemap_layout.gd` concentra reglas geométricas de distribución; `building_interior_style.gd` concentra acabados interiores.
- `reino_torres.gd` todavía coordina la aplicación de esos recursos y conserva lógica de clima, luces, interiores y servicios.
- El código de generación de imágenes existente no debe ampliarse ni confundirse con los sprites de arte del proyecto. Esta auditoría no propone generar arte nuevo.

## 3. Riesgos de refactorización

| Área | Riesgo | Motivo |
|---|---|---|
| Entrada/salida de interiores | Alto | Estado compartido de jugador, NPC, colisiones, visibilidad y cámara |
| Guardado de interiores/posada | Alto | Contrato persistente y estado económico |
| Horarios y entradas | Alto | Coordenadas duplicadas entre Torres y navegación NPC |
| Servicios e interacciones | Medio-alto | Callables, grupos, señales y UI fuera del árbol de la escena |
| Clima, faroles y decoración | Medio | Actualización por frame y nodos creados dinámicamente |
| Terreno y composición urbana | Alto | Escena editable, TileMapDual y pruebas de regresión |
| Helpers de pixel-art | Bajo-medio | Ya existe un script dedicado; comprobar duplicación antes de mover más código |

## 4. Orden de trabajo recomendado

1. Construir un inventario de llamadas externas y contratos dinámicos para cada grupo de funciones.
2. Mantener intactos los contratos públicos y las rutas de escena.
3. Identificar duplicación real y límites de responsabilidad; no extraer bloques solo por su tamaño.
4. Elegir primero una unidad de baja dependencia que tenga una prueba o pueda recibir una prueba de contrato.
5. Ejecutar importación Godot y pruebas de regresión relacionadas después de cada extracción.
6. Repetir el inventario de referencias antes de borrar métodos, señales, variables o recursos.

## 5. Hallazgos que no deben confundirse con código muerto

- Un método que no aparezca en una llamada textual puede ser invocado mediante `Callable`, `call()`, `has_method()`, una señal, un grupo o una escena.
- Los métodos de sincronización NPC y colisiones se llaman desde pruebas y otros sistemas.
- Los métodos de estado guardado pueden ser consumidos por el sistema de persistencia.
- Los nodos de la escena son configuración editable, aunque el script los busque por nombre.
- Esta revisión no confirma funciones o recursos sin uso. Para declarar algo muerto hace falta una búsqueda completa y comprobar las rutas dinámicas.

## 6. Primera extracción: constructor del vivero

Se extrajeron de `reino_torres.gd` tres responsabilidades relacionadas:

- Creación del `TileMapDual` de tierra cultivable.
- Creación de la capa visual de tierra mojada.
- Creación de las parcelas e instancias de `watering_interactable.gd`.

Ahora viven en `scripts/world/torres_vivero_builder.gd` como funciones estáticas. `reino_torres.gd` conserva la composición de la habitación y decide dónde colocar cada bancal; el builder solo construye las capas y parcelas solicitadas.

La extracción conserva:
- Las texturas `Tierra.png` y `Tierra Mojada.png`.
- Las 16 coordenadas de atlas y las máscaras de terreno.
- Los nombres de las capas.
- Las claves persistentes de los cinco bancales centrales.
- El grupo `interactable` y el script de interacción de cada celda.

Se añadieron `tests/world/test_torres_vivero_builder.gd` y su escena, y el workflow principal ejecuta esa prueba en modo headless. El bloque extraído redujo `reino_torres.gd` de 2.900 a 2.780 líneas (120 líneas menos). Es una extracción de responsabilidad, no una eliminación de funcionalidad.

## 7. Validación pendiente

No se ejecutó Godot localmente en este entorno. La prueba nueva y la importación headless deben completarse en GitHub Actions antes de considerar validado el cambio. Si la prueba falla, corregir el contrato antes de continuar con otra extracción.
