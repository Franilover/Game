# Garlia — Registro persistente de auditoría

**Última actualización:** 2026-11-16  
**Repositorio:** `Franilover/Game`  
**Rama auditada:** `fix/p0-godot47-crafting-token-type`  
**Commit validado por CI:** `2aae9f75b3f33c6933b5c6f93c800219c34750f3`  
**Pull request de correcciones:** [#12](https://github.com/Franilover/Game/pull/12)  
**Método:** inspección estática del código actual y CI completo Godot 4.7. No equivale a una prueba visual ni a una validación manual de gameplay.

## Para continuar en otra sesión

1. Leer este archivo antes de repetir el diagnóstico.
2. Verificar si la rama auditada avanzó y registrar el nuevo SHA antes de reutilizar hallazgos.
3. Mantener separado lo **confirmado por código** de lo **pendiente de reproducir**.
4. No cambiar Supabase ni el código de gameplay como parte de la auditoría sin una decisión explícita.
5. Al resolver un hallazgo, añadir evidencia de la corrección y una prueba reproducible; no marcarlo resuelto solo porque se hizo un cambio.
6. La fuente canónica del mundo sigue siendo Supabase; esta documentación solo registra el estado de la auditoría técnica.

## Resumen ejecutivo

- El CI Godot 4.7 del commit `cb383ef` terminó en **success** (run `43923629275`, 39 pasos completados).
- `INV-01`, `ITEM-03`, `SAVE-01`, `WORLD-01`, `MISS-01`, `DIA-01`, `MOBILE-01` y `NPC-01` tienen contratos automatizados aprobados en la rama actual. `SPECIES-01` tiene prueba de reintento aprobada y queda pendiente validar el endpoint en ejecución real.
- La entrega de recompensas ahora resuelve `item_id` mediante el catálogo canónico `GarliaWorldItems`, aplica rollback atómico y evita reintentos recursivos por `inventory_changed`.
- El catálogo real de Supabase se consultó solo en lectura: la misión activa «Conocer a Abel» recompensa una Espada de Madera mediante UUID; no se modificaron tablas, funciones, políticas ni datos.
- La corrección de compilación Godot 4.7, encabezados de Auth, Garudex, locomoción, continuidad del menú social, diálogos móviles y entradas NPC también pasan la batería actual.
- Las pruebas son headless/contractuales; todavía falta validar una partida visual en Android/PC y el flujo offline completo.
- No se modificó Supabase ni se integró la rama en `main`. 

## Registro de hallazgos

Estados permitidos: **Abierto**, **En verificación**, **Corregido pendiente de prueba**, **Resuelto verificado**, **No reproducido**.

| ID | Prioridad | Área | Hallazgo y evidencia estática | Estado | Verificación pendiente |
|---|---|---|---|---|---|
| INV-01 | Alta | Inventario/recogida | `InventoryRuntime.agregar_objeto()` ahora revierte una recogida que no cabe íntegramente. El contrato prueba pila 9/10 + solicitud 3 con inventario lleno (rechazo sin mutación), y el caso válido con slot libre (pila 10 + remanente 2). | Resuelto verificado | `InventoryPickupContract: PASS` en CI Godot 4.7 run `42213469008`. |
| ITEM-01 | Alta | Drops | La auditoría anterior describía pérdida de solicitudes; el código actual `_reintentar_drop_actual()` reencola la solicitud tras fallos y la conserva al agotar los reintentos. No se encontró un contrato que cubra timeout, HTTP no-2xx, JSON inválido o duplicación tras reintento. | En verificación | Añadir pruebas de fallo al iniciar request, desconexión/timeout, HTTP no-2xx y JSON inválido; verificar reintentos limitados, recuperación y ausencia de drops duplicados. |
| ITEM-03 | Alta | Soltar objetos desde inventario | `InventoryController.soltar_objeto_al_mundo()` obtiene el objeto actual desde runtime y solo lo descuenta después de que `GarliaWorldItems` confirma el registro. La UI entrega índice/posición, no una copia antigua del arrastre. | Resuelto verificado | `InventoryDropContract: PASS` en CI Godot 4.7 run `42213469008`; prueba de infraestructura ausente conserva ID y cantidad. |
| ITEM-02 | Media | Catálogo de objetos | La generación inicial depende de `catalogo`; no se encontró un fallback local equivalente. Algunos fallos HTTP terminan en `carga_fallida` sin reintento. | Abierto | Arranque offline y reconexión; definir catálogo local versionado/snapshot sin duplicar la autoridad canónica. |
| SPECIES-01 | Alta | Catálogo de especies | Supabase contiene tres especies activas (`Feerin`, `Humano`, `Necromancer`) y la tabla tiene SELECT para `anon`/`authenticated` con política pública limitada a `activo = true`. El cliente cachea y reemite el catálogo; antes detenía la recuperación tras tres respuestas vacías, sin comprobar de nuevo hasta que otra escena llamara la carga. Ahora emite el estado vacío y programa reintentos de recuperación cada 30 s tras los intentos rápidos. | Corregido pendiente de prueba | `SpeciesCatalogRetry: PASS` en CI Godot 4.7 run `43923629275`; falta confirmar la solicitud REST real y el selector dentro del flujo de creación en Android/PC. |\n| AUTH-01 | Alta | Supabase Auth | Login y renovación en `GarliaAuth` ya envían la clave publicable solo en `apikey`; Crafteo agrega `Authorization` únicamente si existe un JWT real. Otras rutas de `SupabaseClient` siguen usando clave publicable sin Bearer y requieren cotejo individual con RLS. | En verificación | Probar restauración/refresh y revisar permisos de cada endpoint protegido antes de introducir JWT genérico. |
| AUTH-02 | Alta | Restauración de sesión | Las cargas iniciales diferidas de catálogos pueden terminar si todavía no hay sesión restaurada. No se encontró una conexión clara que repita todas esas cargas al finalizar la restauración. | En verificación | Trazar `session_restore_finished`, cargas iniciales y reintentos por dominio. Probar inicio en frío con sesión persistida. |
| SAVE-01 | Alta | Persistencia | `SaveFileRepository` escribe en temporal, valida JSON, conserva respaldo durante el reemplazo y recupera el último save válido. `GameStateRoundtrip` verifica ida/vuelta de salud, Eterium, stamina, posición/tile/orientación, inventario, interior/zona, proceso IUM, tiempo ambiental y estado/progreso/reclamación de misiones. | Resuelto verificado | `SaveFileRepositoryContract: PASS` y `GameStateRoundtrip: PASS` en CI Godot 4.7 run `43923629275`. Sigue pendiente una prueba visual de partida completa con cierre y reanudación. |
| DIA-01 | Alta | Continuidad de diálogo | Tras cerrar el selector social o responder un tema cotidiano, el menú principal podía no reconstruir sus botones. `DialogueSystem` vuelve a establecer `Preguntar`, `Hablar`, `Dar cumplido` y `Despedirse`; el contrato ejecuta cierre de selector y respuesta casual. | Resuelto verificado | `DialogueSocialMenu: PASS` en CI Godot 4.7 run `43921504449`. |
| MOBILE-01 | Alta | Entrada táctil | El joystick podía capturar toques sobre el diálogo en zonas superpuestas. Ahora ignora y libera movimiento mientras hay diálogo abierto; el layout del panel y selectores se adapta al viewport. | Resuelto verificado | `MobileControlsDialogueTouch` y `DialogueMobileLayout: PASS` en CI Godot 4.7 run `43921504449`. |
| NPC-01 | Alta | Entradas a edificios | Los NPC marcados como dentro del edificio se ocultan en el exterior, pero el cuerpo físico podía conservar `collision_layer` y `collision_mask`; el nodo invisible bloqueaba el umbral y otros NPC no podían entrar. Se añade captura/restauración de capas y máscaras, y recuperación de las formas de colisión al reparentar al interior. | Resuelto verificado | `NPCBuildingEntryCollision: PASS` en CI Godot 4.7 run `43920496439`; cubre colisión exterior desactivada, restauración de capas/máscaras y reactivación de formas originales. |
| WORLD-01 | Alta | Snapshot offline | `WorldDataService` y `GarliaSupabaseClient` delegan la validación del snapshot a `WorldSnapshotValidator`; el contrato verifica estructura jerárquica, campos obligatorios, tipos incorrectos y el JSON incluido en el proyecto. | Resuelto verificado | `WorldSnapshotValidatorContract: PASS` en CI Godot 4.7 run `43916861872`. La recuperación offline end-to-end sigue cubierta por `START-01`. |
| START-01 | Alta | Inicio de partida | La ruta de inicio a Reino Torres reintenta mientras `reinos_game` esté vacío; no se observó un fallback local equivalente en esa espera. | En verificación | Inicio de jugador nuevo completamente offline y reconexión posterior. |
| WORLD-02 | Media | Mutabilidad del estado | Algunos getters de `WorldData` parecen devolver referencias internas en vez de copias profundas. | En verificación | Buscar todos los consumidores y comprobar si alguno muta los diccionarios/arreglos recibidos. |
| STREAM-01 | Media | LOD de entidades | `DATA_RADIUS=3` supera `VISIBLE_RADIUS=2`; el precálculo de entidades consulta contexto de terreno basado en chunks cargados. Los chunks de solo datos pueden no tener contexto y producir listas vacías antes del fallback runtime. | En verificación | Registrar un chunk exterior a radio visible: contexto disponible, resultado de precálculo y resultado al entrar en radio visible. |
| STREAM-02 | Baja/Media | Cache de entidades | `WorldEntityManager.tiene_datos_chunk` usa arrays vacíos como si no hubiera datos calculados; una lista vacía puede significar también “calculado y sin entidades”. | En verificación | Confirmar llamadas, colas y coste de recálculo en chunks válidos sin entidades. |
| TERR-01 | Alta | Renderizado del terreno | La composición por `z_index` se deriva del identificador numérico de zona, no de una regla explícita de prioridad de bordes. Es una causa posible de solapamiento, no una causa raíz demostrada. | En verificación | Capturas reproducibles con combinaciones Pradera/Tierra, inspección de orden de dibujo y comparación de imagen esperada. |
| TERR-02 | Alta por verificar | Atlas/renderizado | En `world_terrain_visual.gd`, `_crear_base_tile()` asigna `atlas.texture_region_size = Vector2i(tile_size, tile_size)` y crea tiles de atlas por coordenadas `TILE_SEQUENCE`; el comentario dice que la máscara alfa se normaliza antes de registrar el atlas, pero en la función no aparece ninguna operación de normalización/recorte alfa. El atlas sí segmenta la textura en regiones de tamaño `tile_size`. Esto es una pista concreta si el arte de borde debe sobresalir de la celda, pero todavía no demuestra que sea la causa visible: hay que contrastar el PNG original, la región de atlas y el resultado renderizado. Además, las capas se ordenan con `z_index = -4095 + zone`, por lo que una zona con ID mayor se dibuja encima de una menor cuando sus píxeles son opacos. | En verificación | Comparar PNG original y regiones 32×32 del atlas; probar un borde con píxeles fuera del límite de celda; registrar coordenadas/capa/z-index y captura. No cambiar código hasta que una prueba mínima discrimine recorte de atlas frente a oclusión por orden de capas. |
| PERF-01 | Media | Presupuesto de frames | El presupuesto adaptativo observa parte del trabajo de datos, pero el coste agregado de preparación, pintura y TileMapDual puede superar el objetivo por frame. | En verificación | Perfilar por fase en resolución fija y hardware objetivo; no optimizar sin medir. |
| TEST-01 | Media | CI | CI cubre inventario, persistencia, misiones/recompensas, locomoción, combate, IA, Garumis, clima, snapshot, terreno, toque de diálogo, continuidad del menú social, multitáctil, layout móvil y colisión de entrada NPC. Auth, modo offline end-to-end, cierre/reanudación de partida real y validación física de pantalla siguen sin cobertura integral. | En verificación | Añadir pruebas de sesión/restauración y una partida completa sin servicios remotos; complementar con pruebas manuales visuales en Android/PC. |
| TEST-02 | Baja | CI | El workflow `.github/workflows/procedural-world-tests.yml` no parece incluir `scripts/world/world_generator.gd` en sus filtros de rutas, aunque puede afectar inicialización del renderizador. | Abierto | Revisar `paths`/ `paths-ignore` y confirmar con cambios aislados de ese archivo. |
| DOC-01 | Baja | Documentación | Hay comentarios en `world_terrain_visual.gd` que parecen describir una capa compartida o un orden que no coincide con la implementación por capas/z-index actual. | Abierto | Contrastar cada comentario con el código y corregirlos cuando se autorice la fase de cambios. |
| INV-03 | Baja/Media | Carga de inventario | `cargar_estado_partida()` acepta el arreglo guardado completo y `_normalizar_capacidades_runtime()` solo amplía `items` si es menor que `slot_count`; no recorta si el guardado trae más slots que la UI actual. Como `_crear_slots()` crea exactamente `slot_count` controles, los objetos en índices superiores pueden quedar invisibles en la cuadrícula aunque sigan en el estado y puedan referenciarse desde una hotbar persistida. | En verificación | Cargar un save con más elementos que `slot_count`; decidir si se migra, se preserva con UI ampliada o se valida explícitamente sin perder objetos. |\n| INV-02 | Media | Identidad del objeto al equipar | El código actual busca por ID cuando el objeto solicitado tiene ID; solo permite fallback por nombre si tanto el objeto solicitado como el slot carecen de ID. El hallazgo antiguo no coincide con la implementación actual. | No reproducido | Añadir un contrato con nombres iguales e IDs distintos para conservar evidencia automatizada. |
| MISS-01 | Alta | Recompensas/ciclo de misiones | `Main` consume `recompensa_disponible`; `MissionManager` guarda `recompensas_reclamadas`, aplica recompensas de forma idempotente y revierte entregas parciales. Se añadió bloqueo durante la transacción para que el `inventory_changed` emitido por rollback no genere un bucle de reintentos. Las recompensas canónicas que solo contienen `item_id` se resuelven contra `GarliaWorldItems`; al cargar el catálogo se reintentan las recompensas pendientes. La lectura de Supabase confirmó que «Conocer a Abel» entrega una Espada de Madera por UUID con `datos` vacío. | Resuelto verificado | `MissionRewardDelivery: PASS` y `MissionManagerContract: PASS` en CI Godot 4.7 run `43916861872`; cubre rollback con inventario lleno, reintento, resolución por UUID e idempotencia. La prueba de continuidad de una partida guardada tras entrega queda en la siguiente fase. |
| SOCIAL-01 | Media | Relaciones sociales | `RelationshipSystem` carga reglas y regalos desde `SocialRepository`; no se encontró fallback local. Si las reglas no cargan, `obtener_relacion()` puede devolver `{}` y `registrar_dialogo()` no modifica la relación. `SocialRepository` emite error y descarta la respuesta fallida sin reintento visible. | Abierto | Probar reglas/regalos con red ausente y restauración de conexión; definir caché local si se requiere gameplay social offline. |
| CONFIG-01 | Baja | Configuración/perfilado | `project.godot` usa viewport base 960×540 y overrides de ventana 1920×1080; métricas anteriores tomadas con otra resolución no son comparables directamente. | Abierto | Fijar perfil de prueba, renderer, resolución y equipo antes de comparar rendimiento. |

## Protocolo mínimo de pruebas de inventario y drops

Estas pruebas son casos de verificación, no resultados ejecutados. Hacerlas con datos de prueba aislados y registrar inventario/objetos antes y después; no usar partidas importantes.

### INV-01 — recogida parcial

1. Preparar un inventario con una pila compatible de 9/10 y sin slots libres.
2. Crear en el mundo una pila de 3 del mismo ID, con `max_stack=10`.
3. Intentar recoger una vez; registrar retorno, cantidad del inventario y cantidad del objeto del mundo.
4. Repetir una vez y comparar el total combinado.
5. Criterio de aceptación: ninguna unidad se duplica ni desaparece; la cantidad transferida y el remanente del mundo concuerdan.

### ITEM-03 — soltar objeto con infraestructura no disponible

1. Tener un objeto en un slot y registrar su ID/cantidad.
2. Probar con `_entities_root` ausente; repetir con `_entity_manager` ausente y con fallo controlado de `registrar_global()`.
3. Soltar el objeto y comprobar si aparece un `WorldItem` registrado.
4. Criterio de aceptación: el inventario solo descuenta el objeto si la creación/registro del objeto en mundo devuelve éxito; ante fallo, se conserva íntegro en inventario.

### ITEM-01 — solicitud de drop fallida

1. Encolar un drop de una criatura y provocar, por separado, fallo inmediato de `HTTPRequest.request()`, timeout/desconexión, respuesta HTTP no-2xx y JSON no-array.
2. Registrar tamaño de cola, criatura solicitada, número de peticiones y número de objetos creados.
3. Confirmar que la solicitud fallida se reintenta con límite/backoff o queda en una cola de fallos recuperable; las solicitudes posteriores deben continuar.
4. Criterio de aceptación: no perder silenciosamente una solicitud y no crear duplicados cuando una respuesta exitosa se procese una sola vez.

### Estado de ejecución

La inspección disponible es estática. No se afirma que estos casos hayan sido ejecutados en Godot. El siguiente paso de ejecución requiere abrir la rama auditada en un entorno Godot y correr escenarios controlados con registro de cantidades y nodos creados.

## Estado del terreno

La auditoría anterior observó que:

- La arquitectura activa separa `WorldStreamer → WorldTerrain → WorldTerrainVisual → TileMapDual/DisplayLayer`.
- Las pruebas existentes verifican varias invariantes estructurales, pero no una imagen final de referencia.
- El CI correcto es evidencia de compilación/importación y de las pruebas que se ejecutaron; no es evidencia suficiente de ausencia de seams, oclusión incorrecta o pérdida visual de bordes.
- Los datos históricos de tiempos de generación/frame mencionados en conversaciones anteriores no deben presentarse como mediciones actuales sin repetirlos bajo una configuración controlada.

**Pista nueva (TERR-02, todavía no confirmada):** el atlas se segmenta en regiones `tile_size × tile_size`, mientras el comentario afirma que la máscara alfa se normaliza sin que `_crear_base_tile()` realice esa operación. Si los bordes ilustrados deben sobresalir de la celda, hay que verificar primero si el propio atlas los recorta; el orden `z_index = -4095 + zone` también puede hacer que una zona de ID mayor oculte píxeles opacos de una menor. Ninguna de estas dos hipótesis se declara raíz confirmada sin comparar el PNG, el atlas y una captura del caso mínimo.

**Próximo paso de terreno:** capturar un caso mínimo y reproducible, registrar coordenadas/tiles/orden de dibujo, y comparar contra una imagen esperada antes de proponer cambios.

## Orden recomendado para la próxima pasada

1. Completar la revisión de `GameState`, carga/guardado y aplicación de estado al cambiar de zona.
2. Auditar equipamiento, hotbar y consumo de objetos, especialmente transferencias parciales y persistencia.
3. Seguir misiones y relaciones sociales desde el evento de gameplay hasta el estado guardado.
4. Mapear inicio de escena, spawn del jugador y carga del snapshot offline.
5. Verificar los contratos de Auth/REST/RLS sin modificar tablas ni políticas.
6. Volver al terreno con una reproducción visual y perfilado de fases.
7. Actualizar esta tabla con nuevos hallazgos y pruebas; evitar duplicar IDs para el mismo defecto.

## Límites de esta revisión

- Es una auditoría estática sobre el SHA indicado; los archivos pueden cambiar después.
- No se ejecutó el juego localmente ni se realizó una prueba visual automatizada de píxeles.
- La ausencia de una referencia encontrada no demuestra que no exista en todo el proyecto; se debe ampliar la búsqueda antes de declarar una función ausente.
- Las afirmaciones sobre RLS dependen de las políticas y grants reales de Supabase, que no se modificaron en esta fase.


## Actualización de rama — 2026-11-16

Esta sección sustituye los estados históricos para los hallazgos revalidados en `fix/p0-godot47-crafting-token-type`.

- CI completo Godot 4.7: `success`, run `43923629275`, commit `cb383ef5d5cc7174492dad546c7a2714a577ed3e`; 39 pasos, sin fallos.
- `INV-01`, `ITEM-03`, `SAVE-01`, `WORLD-01` y `MISS-01`: **Resuelto verificado**.
- Las recompensas de misiones resuelven UUIDs desde el catálogo canónico; rollback y reintentos no generan ciclos recursivos.
- Auth/RLS por endpoint, offline end-to-end, continuidad de guardado de una partida completa, solicitud REST real del catálogo de especies y pruebas visuales Android/PC siguen en el backlog.
- PR #12 sigue en borrador. `main` no se modificó; Supabase se consultó solo en lectura y no recibió cambios.

