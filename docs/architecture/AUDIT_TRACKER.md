# Garlia — Registro persistente de auditoría

**Última actualización:** 2026-11-20  
**Repositorio:** `Franilover/Game`  
**Rama auditada en esta continuación:** `work/design-and-architecture`  
**Commit validado por CI:** `1ceaad725f31e47cbd6446e502463c9eb422fc2b`  
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

- El CI Godot 4.7 del commit `1ceaad7` terminó en **success** (run `43924866198`, 40 pasos completados).
- `INV-01`, `ITEM-03`, `SAVE-01`, `WORLD-01`, `MISS-01`, `DIA-01`, `MOBILE-01` y `NPC-01` tienen contratos automatizados aprobados en la rama actual. `SPECIES-01` tiene prueba de reintento aprobada y queda pendiente validar el endpoint en ejecución real. `AUTH-02` ya vuelve a solicitar catálogos al restaurar/iniciar sesión; el contrato de disparadores pasó CI.
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
| AUTH-02 | Alta | Restauración de sesión | Las cargas que requieren sesión podían salir antes de que terminara el refresh token y no repetirse después; iniciar sesión manualmente tampoco reactivaba todos los catálogos. `GarliaSupabaseClient` ahora escucha `session_restored` y `login_succeeded`, y vuelve a solicitar Eterium runtime, reglas de especie, reglas sociales, regalos, relaciones ecológicas y reinos; evita duplicar solicitudes HTTP en curso. | Corregido pendiente de prueba | `AuthenticatedCatalogReload: PASS` en CI Godot 4.7 run `43924866198`; falta comprobar refresh real con sesión persistida y endpoints en ejecución integrada. |
| SAVE-01 | Alta | Persistencia | `SaveFileRepository` escribe en temporal, valida JSON, conserva respaldo durante el reemplazo y recupera el último save válido. `GameStateRoundtrip` verifica ida/vuelta de salud, Eterium, stamina, posición/tile/orientación, inventario, interior/zona, proceso IUM, tiempo ambiental y estado/progreso/reclamación de misiones. | Resuelto verificado | `SaveFileRepositoryContract: PASS` y `GameStateRoundtrip: PASS` en CI Godot 4.7 run `43924866198`. Sigue pendiente una prueba visual de partida completa con cierre y reanudación. |
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
| INV-02 | Media | Identidad del objeto al equipar | La búsqueda usa coincidencia estricta por ID cuando el objeto solicitado incluye ID; solo permite fallback por nombre si ambos carecen de ID. El contrato UI prueba nombres repetidos, IDs distintos y un ID inexistente. | Corregido pendiente de ejecución | Ejecutar `test_inventory_overflow_ui.tscn` y verificar el equipamiento visual en runtime. |
| INV-03 | Media | Capacidad visible del inventario | La UI usa `InventoryScroll` y grupos `RESERVA N` para mostrar todas las ranuras conservadas en el snapshot, sin truncar objetos adicionales. | Corregido pendiente de ejecución | Ejecutar `test_inventory_overflow_ui.tscn` y verificar desplazamiento/selección en ventana real. |
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

- CI completo Godot 4.7: `success`, run `43924866198`, commit `1ceaad725f31e47cbd6446e502463c9eb422fc2b`; 40 pasos, sin fallos.
- `INV-01`, `ITEM-03`, `SAVE-01`, `WORLD-01` y `MISS-01`: **Resuelto verificado**.
- Las recompensas de misiones resuelven UUIDs desde el catálogo canónico; rollback y reintentos no generan ciclos recursivos.
- Auth/RLS por endpoint, refresh real de sesión, offline end-to-end, continuidad de guardado de una partida completa, solicitud REST real del catálogo de especies y pruebas visuales Android/PC siguen en el backlog.
- PR #12 sigue en borrador. `main` no se modificó; Supabase se consultó solo en lectura y no recibió cambios.


## Actualización de diálogo — 2026-11-16

- `DialogueSystem` aplica un ritmo de revelado más lento cuando la actividad capturada del NPC indica desplazamiento; los diálogos explícitos de tránsito conservan la última línea 2,5 s antes del cierre automático.
- Las despedidas y la frase del jugador se adaptan a caminar frente a trabajo, evitando tratar un paseo como una obligación laboral.
- `DialogueSocialMenu` comprueba ritmo pausado y despedidas de tránsito/trabajo. CI Godot 4.7: run `43929922701` (#1654), 40 pasos completados sin fallos.
- Pendiente: prueba visual en partida real y revisión de las frases que llegan desde datos externos; CI headless no demuestra legibilidad física en Android.



## Actualización de diálogo — 2026-11-16 (contexto interior y voces)

- Los NPC que caminan dentro de un edificio ya no anuncian el destino exterior de su siguiente tramo. Los saludos y despedidas describen el movimiento local y usan el contexto `dentro_edificio`.
- Las despedidas distinguen también si el personaje está caminando, trabajando o simplemente conversando; caminar no se presenta como una tarea que impide hablar.
- `NPCVoiceProfile` deja de aplicar normalizaciones generales que empujaban a todos los habitantes al mismo registro. Conserva ajustes puntuales por personaje.
- El fallback social incorpora respuestas diferenciadas para Mara, Ivo y Nima en planes, aficiones, preocupaciones, consejos, estado de ánimo y reacciones de rutina.
- Se reescribieron conversaciones ambientales de Mara/Ivo, Nima/Ivo y Saira/Ivo para que la confianza, el humor, los límites y el interés se expresen mediante sus intercambios, sin convertir cada línea en una explicación de trasfondo.
- Los planes cotidianos ya no concatenan claves internas de horario como texto visible.
- `DialogueSocialMenu` comprueba perfiles de voz y reacciones diferenciadas; CI Godot 4.7: run `43932011916`, **40 pasos completados sin fallos**.
- La validación es headless. Falta revisar la lectura y naturalidad en una partida real, especialmente en Android.
- No se modificaron filas de `dialogos_game`, tablas, RPC ni políticas de Supabase; los cambios de contenido se limitaron a diálogos locales/fallback y conversaciones ambientales del código.



## NPC Mind — núcleo de estado interno y aprendizaje (2026-11-16)

- Se incorporó `NPCMindService` como autoload `NPCMind`, separado de diálogo, navegación y animación.
- Estado individual versionado por habitante: necesidades (descanso, socialización, diversión, seguridad, curiosidad y autonomía), rasgos normalizados, estado emocional inicial, preferencias aprendidas, objetivos y contador de decisiones.
- Las necesidades evolucionan por horas de mundo mediante una función explícita; satisfacción reduce presión sin exceder el rango 0–100.
- Evaluación de actividades combina presión de necesidades, afinidad de rasgos, preferencias aprendidas, prioridad, coste y riesgo. El servicio puntúa y selecciona; todavía no ejecuta acciones ni sustituye el horario.
- Aprendizaje incremental de resultados de actividad usa media acumulada y confianza progresiva para que una sola experiencia no se convierta en preferencia absoluta.
- Los objetivos individuales se pueden establecer, completar y abandonar, con límite de cinco objetivos activos/registrados por personaje.
- `GameStateService` persiste el bloque `npc_mentes` dentro del guardado local de la partida. No se creó almacenamiento remoto ni se modificó Supabase.
- Los perfiles sociales existentes en escala 0–100 se normalizan a 0–1 al incorporarlos al núcleo.
- Prueba `tests/persistence/test_npc_mind_core.tscn`: necesidades, satisfacción, elección, aprendizaje positivo/negativo, objetivos, normalización y roundtrip desde GameState.
- CI Godot 4.7: **41 pasos completados, 0 fallos**, run [#1677](https://github.com/Franilover/Game/actions/runs/43934161188).
- Alcance deliberado: aún no se conecta la elección de actividades al movimiento/rutinas ni se simula tiempo fuera de pantalla. Esa integración se hará después de validar el núcleo.



## NPC Mind — primera conexión con comportamiento en mundo (2026-11-16)

- `NPCScheduleSystem` consulta el servicio `NPCMind` durante la actualización de habitantes vivos en Torres.
- El núcleo procesa intervalos de tiempo del calendario del mundo (en lotes de al menos cinco minutos de juego), aumenta necesidades y aplica alivio según la actividad que el NPC realiza.
- El estado emocional (ánimo, estrés y energía) se recalcula desde las necesidades; no se usa para generar texto.
- En los días libres y franjas de ocio de plaza, los habitantes con perfil definido evalúan tres alternativas propias. La utilidad considera necesidades, rasgos sociales, preferencias aprendidas, coste y prioridad.
- La decisión queda fijada durante el tramo para evitar cambios de actividad cada tick.
- Las decisiones pueden dirigir al NPC a lugares concretos (por ejemplo, Elian a la panadería, Bruna a la forja, Narel al archivo, Ivo a su vivienda y los miembros de la casa real al castillo); se reutiliza el sistema existente de navegación/entrada a edificios.
- Al finalizar el tramo, el resultado observado en la necesidad principal se registra como experiencia positiva/negativa y modifica gradualmente las preferencias futuras.
- La prueba de núcleo cubre procesamiento temporal, satisfacción, actualización emocional y que Ivo/Mara tengan conjuntos de actividades distintos.
- CI Godot 4.7: **41/41 pasos correctos, 0 fallos**, run [#1685](https://github.com/Franilover/Game/actions/runs/43935581554).
- Alcance actual: la autonomía se aplica a alternativas de ocio de día libre, no reemplaza trabajo, guardias, investigaciones ni compromisos. La simulación offline y la iniciativa social basada en objetivos quedan para siguientes etapas.



## Objetivos sociales autónomos de NPC (2026-11-16)

- `NPCScheduleSystem` genera objetivos sociales a partir de la necesidad de socialización y los vínculos registrados: `buscar_compania` o `visitar_amigo`.
- La elección de pareja considera amistad, afecto, confianza, colaboración, tensión y distancia; descarta habitantes muertos, ocupados, en tránsito, dentro de edificios o en conversaciones.
- El objetivo queda registrado en `NPCMind` y persiste en el estado mental. La referencia de ejecución (NPC destino, espera y temporizador) vive en metadatos de la instancia y se reconstruye si la partida vuelve a cargar.
- El NPC traza una ruta hacia un punto cercano a la otra persona, espera el encuentro y completa la interacción tras permanecer juntos. La interacción alivia socialización/diversión, actualiza aprendizaje y registra un recuerdo de relación.
- Los objetivos sociales sólo interrumpen ocio de días libres, entre 09:00–20:00. No desplazan trabajo, guardias, horarios de edificios ni compromisos. Un objetivo se cancela si el compañero desaparece, entra en un edificio o inicia otra interacción; los compañeros en tránsito tienen una espera máxima.
- Los objetivos completados/abandonados se reciclan para que el historial limitado no impida crear objetivos futuros.
- Prueba NPC Mind: valida ciclo de objetivos repetidos y reciclaje del límite. CI Godot 4.7: **41/41 pasos correctos, 0 fallos**, run [#1694](https://github.com/Franilover/Game/actions/runs/43936746181).
- La conversación visible sigue utilizando líneas escritas y condiciones del sistema narrativo existente; no se genera texto automáticamente. El encuentro social puede servir de contexto para escenas ambientales ya definidas.



## Memoria social y asuntos entre NPC (2026-11-16)

- `RelationshipSystemService` ahora conserva asuntos pendientes y promesas entre habitantes dentro de `conversaciones_npc`, junto con el resto de relaciones y conocimientos. Los estados cerrados se mantienen en el historial y no vuelven a generarse desde el mismo recuerdo.
- Una promesa se registra con emisor, destinatario y clave; puede incluir una clave de conocimiento que debe compartirse al cumplirla. Los recuerdos que contienen `promesa_para` y `clave_promesa` pueden materializar esa promesa una sola vez.
- Los conocimientos marcados explícitamente con `requiere_ayuda` y `personaje_relacionado` generan asuntos que el NPC puede tratar con esa persona.
- Los conocimientos con `compartible=true` o tipo `noticia`, `evento_publico` o `conocimiento_compartible` pueden transmitirse si el destinatario aún no los conoce. Se conserva la procedencia y cadena de transmisión.
- Los encuentros sociales priorizan compromisos pendientes, asuntos de ayuda, noticias no compartidas y, después, desacuerdos con tensión >= 18. Resolver un desacuerdo reduce tensión; ayudar y compartir información fortalecen vínculos y dejan recuerdos individuales para ambos participantes.
- El historial de promesas, asuntos, relaciones y conocimientos se guarda localmente en el estado de la partida. No se generan textos con IA. Estos encuentros aún no muestran una conversación visual NPC-NPC: registran motivos, consecuencias y recuerdos; la integración con líneas ambientales escritas queda para una etapa posterior.
- Pruebas NPC Mind cubren registro, transmisión, resolución, selección de motivo y recuperación de promesas/asuntos desde recuerdos. CI Godot 4.7: **41/41 pasos correctos, 0 fallos**, run [#1708](https://github.com/Franilover/Game/actions/runs/43938773401).

## Conversaciones ambientales desde objetivos sociales autónomos (2026-11-16)

- Los encuentros que completa `NPCScheduleSystem` ahora pueden iniciar una conversación ambiental mediante el grupo `npc_conversation_system`.
- Se añadieron líneas escritas para cumplir promesas, tratar asuntos pendientes, compartir noticias, resolver desacuerdos y encuentros cotidianos. Las líneas pasan por el perfil de voz de cada participante.
- Las conversaciones sociales autónomas usan las burbujas ambientales existentes y sólo se muestran cuando el jugador está cerca. Su temporizador continúa aunque el jugador se aleje o tenga abierto otro diálogo.
- Mientras dura el intercambio, el horario no vuelve a mover a los participantes. Al terminar, se liberan los metadatos de conversación y recuperan sus rutinas.
- Se evita aplicar dos veces los cambios de relación: las consecuencias y recuerdos se registran al completar el objetivo social; la capa de conversación sólo presenta el intercambio.
- No se añadió generación de texto por IA ni se modificó Supabase.
- CI Godot 4.7: **41/41 pasos correctos, 0 fallos**, run [#1717](https://github.com/Franilover/Game/actions/runs/43940597598). El primer intento detectó un error de alcance de la variable `motivo`; se corrigió antes de esta ejecución exitosa.
- Sigue pendiente revisar la presentación en una partida real, especialmente Android.

## Variedad de conversaciones sociales (2026-11-16)

- `NPCVoiceProfile` ahora construye tres variantes por motivo social: promesas, ayuda, noticias, desacuerdos, visitas y compañía.
- La selección rota según el historial de interacciones de la pareja y cambia según confianza, amistad y tensión.
- Los diálogos usan expresiones propias de Elian, Bruna, Darven, Saira, Narel, Mara, Ivo y Nima sin imponer modismos uniformes.
- Las conversaciones pueden retomar antecedentes reales del historial de la pareja y el título de una noticia conocida; no se inventan hechos adicionales.
- Se añadieron pruebas de voces diferenciadas, rotación de variantes, continuidad histórica e inclusión de información compartida.
- CI Godot 4.7: **41/41 pasos correctos, 0 fallos**, run [#1719](https://github.com/Franilover/Game/actions/runs/43941877535).


## Limpieza y optimización del ciclo NPC (2026-11-19)

- Se reparó la escena de prueba ausente para la regresión de movimiento NPC; la suite pudo volver a ejecutar esa prueba.
- La regla del tramo nocturno (21:00–06:00) vive ahora en `NPCScheduleRules.es_horario_nocturno()`, con pruebas de límites e invalidación de minutos fuera del día.
- `NPCScheduleSystem.actualizar()` comparte una sola instantánea del grupo de NPC, la referencia del jugador y el calendario del mundo durante el tick. Los métodos sociales, de rutina, ocio y eventos reutilizan ese contexto; fuera del tick conservan el acceso de respaldo a sus fuentes.
- La consulta del grupo `torres_game_npc` se centralizó en `_obtener_npcs_torres()`; la fecha de la reunión del castillo se calcula una vez por grupo.
- La memoria diaria que usan las conversaciones de reunión se separó de `_aplicar_rutina()` en `_actualizar_resumen_diario_reunion()`, manteniendo las claves de metadatos existentes.
- Nueva prueba de integración `tests/world/test_npc_schedule_context.tscn`: snapshot temporal y de NPC, fallback fuera del tick, conservación de actividad significativa y reinicio de memoria al cambiar de fecha. Añadida al workflow.
- Se detectó y corrigió una colisión de nombre entre el acumulador de intervalo y la instantánea temporal (`_tiempo_actualizacion` / `_tiempo_mundo_actualizacion`). Las ejecuciones anteriores a esa corrección fallaron al cargar NPCScheduleSystem; no se cuentan como validación.
- CI Godot 4.7: **46/46 pasos correctos, 0 fallos**, run [#44622633288](https://github.com/Franilover/Game/actions/runs/44622633288). GDScript Quality: **success**, run [#44622597880](https://github.com/Franilover/Game/actions/runs/44622597880).
- Auditoría detallada: secciones 44–51 de `AUDIT_NPC_SCHEDULE_INITIAL.md`.


## Optimización de movimiento NPC (2026-11-19)

- `CreatureMovement._direccion_evitar_superposicion_npcs()`: filtro de distancia con `length_squared()`, raíz sólo para vecinos cercanos, dirección normalizada e ID actual reutilizados por consulta.
- Se mantienen radios, prioridades, filtros de grupo/padre, exclusión de destinos compartidos y repulsión original.
- Regresión ampliada: NPC lejano no altera rumbo; distancia exacta de 34 px no activa separación.
- Primera optimización validada: Godot 4.7 46/46 y GDScript Quality success. Segunda optimización validada: Godot 4.7 **46/46 pasos correctos, 0 fallos** ([run #44623523513](https://github.com/Franilover/Game/actions/runs/44623523513)); GDScript Quality success ([run #44623523563](https://github.com/Franilover/Game/actions/runs/44623523563)).


## Optimización de movimiento NPC (2026-11-19)

- La separación direccional descarta candidatos lejanos con distancia al cuadrado; la prueba cubre vecino lejano y límite de 34 px. Validado: [Godot 4.7 46/46](https://github.com/Franilover/Game/actions/runs/44623203556), [GDScript Quality](https://github.com/Franilover/Game/actions/runs/44623203373) success.
- La corrección final de solapamientos usa ahora el mismo filtro por distancia al cuadrado antes de calcular la raíz. Se añadió un caso de regresión que comprueba la distancia mínima de 28 px. CI de esta segunda modificación pendiente.


## Refactor NPCScheduleSystem — selección de rutina (2026-11-19)

- Extraído `_resolver_rutina_base_y_eventos()` desde `_aplicar_rutina()`: selección calendario/día libre, ocio, invitaciones, evento comunitario y encuentro del trío.
- El helper devuelve un contexto con calendario, rutina y evento; la fase de turnos, prioridad nocturna, clima y movimiento permanece en `_aplicar_rutina()`.
- Añadida regresión para la extensión local de Elian y la no mutación del calendario original.
- CI: [Godot 4.7 46/46](https://github.com/Franilover/Game/actions/runs/44624623124); [GDScript Quality](https://github.com/Franilover/Game/actions/runs/44624623318), ambos success.


## Extracción NPCNavigationSystem — navegación de Torres (2026-11-19)

- La malla AStar, su construcción e invalidación, la detección de cambios de colisión, los costes de terreno y el cálculo de rutas ahora pertenecen a `NPCNavigationSystem`, como nodo de `Main/Systems`.
- `NPCScheduleSystem` conserva rutinas, actividades, interiores y estado de movimiento; recibe navegación por inyección y delega las rutas.
- La señal `malla_reconstruida` permite invalidar rutas de rutina desde el propietario de las decisiones NPC, sin transferir esa responsabilidad al servicio geométrico.
- Se adaptaron las regresiones de límites del mapa y búsqueda de celda transitable. Se añadieron escenas ejecutables para los límites de Torres y la construcción/cálculo/invalidez de la malla real; ambas se incorporaron al workflow. No se cambian puertas, escenas de edificios, datos guardados ni Supabase.
- CI Godot 4.7: **48/48 pasos completados, 0 fallos** ([run #44626438272](https://github.com/Franilover/Game/actions/runs/44626438272)); GDScript Quality: **success** ([run #44626236415](https://github.com/Franilover/Game/actions/runs/44626236415)).


## Transición NPC entre edificios (2026-11-19)

- Extraído `_salir_de_edificio_para_cambiar_rutina()` de `_aplicar_rutina()`; conserva cancelación de animaciones/paseos, reparentado, colisiones, metadatos y ocultación durante interiores activos.
- `ReinoTorres.sacar_npc_del_interior()` queda como fuente única de la posición del umbral; se elimina el recálculo duplicado del planificador.
- `test_npc_building_entry_collision` ejercita el helper real y comprueba umbral, reparentado, metadatos, visibilidad, interacción y colisiones.
- CI Godot 4.7: **48/48 pasos, 0 fallos** ([run #44628441771](https://github.com/Franilover/Game/actions/runs/44628441771)); GDScript Quality: **success** ([run #44628441413](https://github.com/Franilover/Game/actions/runs/44628441413)).


## Resolución del destino de rutina (2026-11-19)

- Extraído `_resolver_destino_rutina_local()` como cálculo de coordenadas sin efectos secundarios; recibe la variación de posición ya tipada.
- Se conservan hogar personalizado, umbral de edificio, posición absoluta de plaza, anclas por habitante, variaciones individuales y perímetro de 118 px para NPC adicionales.
- `test_npc_schedule_context` cubre los cinco casos de selección de destino.
- CI Godot 4.7: **48/48 pasos, 0 fallos** ([run #44628969650](https://github.com/Franilover/Game/actions/runs/44628969650)); GDScript Quality: **success** ([run #44628969766](https://github.com/Franilover/Game/actions/runs/44628969766)).


## Búsqueda compartida de mobiliario interior (2026-11-19)

- Se unificó la búsqueda de sprites por tokens para selección de puestos y animaciones de postura.
- La selección conserva todos los muebles compatibles y el orden de escena; la animación sigue usando el primero.
- Se añadieron casos de cama/litera, silla/asiento, orden y búsqueda vacía a `test_npc_schedule_context`.
- CI Godot 4.7: **48/48 pasos, 0 fallos** ([run #44629354647](https://github.com/Franilover/Game/actions/runs/44629354647)); GDScript Quality: **success** ([run #44629354490](https://github.com/Franilover/Game/actions/runs/44629354490)).


## Interrupción de actividades interiores por cinemáticas (2026-11-19)

- Una cinemática cancela el paseo interior activo y libera el control de locomoción del NPC.
- Se conserva el siguiente horario del paseo para que la actividad pueda reanudarse sin reiniciar su cadencia.
- Las conversaciones ambientales mantienen su contrato de pausa temporal y conservación de ruta.
- `test_npc_schedule_context` comprueba la cancelación de una ruta real y la conservación del siguiente horario.
- CI Godot 4.7 y GDScript Quality pendientes.


### Ampliación: regresión de reanudación

- La prueba de cinemática verifica ahora también que el paseo pendiente se reanude al terminar la interrupción.
- Se valida el contrato con `CreatureMovement` real, el contenedor `Habitacion_panaderia` y la misma hora programada.
- Se comprueba que el horario pendiente no cambie al reanudar.
- CI Godot 4.7 y GDScript Quality pendientes.


## Replanificación de paseos interiores por cambio de actividad (2026-11-19)

- Se registra la actividad que originó cada paseo interior.
- Un cambio de actividad dentro del mismo edificio cancela el destino anterior y vuelve a seleccionar un puesto según la nueva tarea.
- Se limpia la metadata de actividad al detener o completar el paseo.
- La regresión cubre interrupción cinematográfica, reanudación y cambio de tarea en el mismo interior.
- CI Godot 4.7 y GDScript Quality pendientes.


## Regresión integrada de cambio de edificio durante interior activo (2026-11-19)

- La prueba ejecuta la transición del planificador `_salir_de_edificio_para_cambiar_rutina()` directamente.
- Comprueba que el NPC se retire de la habitación, limpie la identidad del edificio anterior y permanezca oculto/no interactuable/sin colisiones mientras el jugador sigue dentro.
- Comprueba que al salir el jugador se restauren visibilidad, interacción y colisiones originales.
- Sin cambios de comportamiento productivo; CI Godot 4.7 y GDScript Quality pendientes.


## Contrato de autoridad de movimiento NPC (2026-11-19)

- Se verificó que `CreatureMovement` es el ejecutor único; agenda, conversaciones, acercamientos e historias sólo coordinan estados y rutas.
- Prioridad documentada: pausa temporal, ruta de rutina, restricción de criatura inmóvil, dirección externa y movimiento autónomo.
- Se aclaró la diferencia crítica entre `detener_por_rutina()` (mantiene el bloqueo de control con ruta vacía) y `detener()` (libera el modo de rutina).
- El acercamiento a iniciativa restaura la rutina al finalizar/cancelar; las actividades y objetivos sociales se procesan con prioridad excluyente en el tick.
- No se detectó una colisión de órdenes que justifique añadir un controlador o modificar producción. La siguiente cobertura útil es probar precedencia de órdenes y ciclo completo de iniciativa.
- CI de los cambios de regresión previos continúa en ejecución; no se declara validación hasta su resultado.


### Cobertura del contrato de movimiento NPC

- Nueva regresión `test_creature_movement_authority`: precedencia ruta/dirección externa, pausa y reanudación, diferencia entre detener por rutina y liberar el control, limpieza de dirección externa.
- Usa la escena real `Creature` y el componente `CreatureMovement`; añadida al workflow headless.
- CI pendiente.


### Recuperación segura tras cancelar iniciativa NPC

- Corregida la salida temprana de `finalizar_acercamiento_social()`: siempre detiene la ruta temporal y limpia tránsito/firma antes de comprobar disponibilidad del mundo, zona, navegación o calendario.
- Evita que el NPC continúe caminando hacia la antigua posición del jugador cuando el diálogo termina durante una transición o con calendario no disponible.
- `test_npc_schedule_context` recorre la cancelación real de `NPCConversationSystem`, simula pausa/reanudación del diálogo y comprueba que agenda y movimiento liberen el acercamiento sin contexto mundial.
- CI pendiente.


## Continuación P0 — 2026-11-20

La rama de trabajo recibió correcciones adicionales de persistencia que todavía no deben marcarse como verificadas hasta ejecutar Godot/CI:

| ID | Prioridad | Área | Hallazgo y corrección | Estado | Verificación pendiente |
|---|---|---|---|---|---|
| SAVE-02 | Alta | Validación del payload | GameState valida ahora la estructura anidada de `inventario_estado`: items deben ser diccionarios, hotbar debe ser un arreglo numérico, equipo debe contener diccionarios y los selectores deben ser numéricos. Valida el campo canónico `hotbar_indices` sin asumir una migración de formatos históricos no demostrada. | Corregido pendiente de prueba | Ejecutar `GameStateSavePayloadContract` en Godot 4.7/CI y probar un save corrupto real con respaldo válido. |
| INV-04 | Alta | Restauración de equipo | La carga de equipamiento ahora reemplaza todas las ranuras y solo acepta armaduras compatibles en cabeza/torso/pies. El controlador notifica el estado completo y la UI ya no añade equipo sobre el anterior. | Corregido pendiente de prueba | Ejecutar `InventoryEquipmentTransaction`; probar dos cargas consecutivas en la misma instancia de inventario y comprobar que no sobreviva equipo del primer save. |

Esta continuación no cambia Supabase ni el formato/versionado de los saves. Las nuevas pruebas están integradas en pasos ya existentes del workflow; no hay confirmación de ejecución en esta sesión.

| SAVE-03 | Alta | Integridad del payload | La validación comprueba ahora que la versión sea entera, metadata `mundo/semilla/generador` tenga tipos válidos, `elapsed_time/scene` sean compatibles y los campos numéricos/vectoriales de Player no contengan tipos arbitrarios. | Corregido pendiente de prueba | Ejecutar `GameStateSavePayloadContract` y probar listado/carga de un JSON con metadata corrupta. |


| ZONE-01 | Alta | Transiciones de zona | El destino se carga e instancia antes de descargar la zona actual; fallos de ruta/instanciación cancelan la transición sin dejar el manager bloqueado. | Corregido pendiente de ejecución | Ejecutar `test_zone_manager_torres_fallback.tscn` y probar navegación real entre Torres, Hogar y Mundo Abierto. |

| ZONE-02 | Crítica | Persistencia del mundo compartido | Antes se advertía de un fallo al guardar el mundo global pero se descargaba igualmente la zona. Ahora ZoneManager aborta la transición, libera la escena destino preparada y conserva la zona actual si GlobalWorldStore no confirma el snapshot. | Corregido pendiente de prueba de fallo de escritura | Simular una ruta global no escribible en un entorno aislado y confirmar que la zona actual permanece activa. |

| SAVE-04 | Alta | Descubrimiento de partidas recuperables | `listar_ids_partidas()` ahora incluye respaldos `.json.bak` válidos cuando falta el archivo principal. No lista temporales `.tmp` ni respaldos corruptos; `obtener_partidas()` valida el contenido y `leer_partida()` intenta restaurarlo. | Corregido pendiente de CI | Ejecutar `SaveFileRepositoryContract` y comprobar en el menú de partidas una recuperación con sólo `.bak`. |
