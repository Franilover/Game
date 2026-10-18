# Garlia — Registro persistente de auditoría

**Última actualización:** 2026-10-18  
**Repositorio:** `Franilover/Game`  
**Rama auditada:** `fix/terrain-root-cause-v1`  
**Commit auditado:** `d8a2331dfadce482f89a646197a3e9fb6300f4fa`  
**Pull request de terreno:** [#3](https://github.com/Franilover/Game/pull/3)  
**Método:** inspección estática de archivos y metadatos de GitHub. No equivale a una prueba visual ni a una ejecución integral de Godot.

## Para continuar en otra sesión

1. Leer este archivo antes de repetir el diagnóstico.
2. Verificar si la rama auditada avanzó y registrar el nuevo SHA antes de reutilizar hallazgos.
3. Mantener separado lo **confirmado por código** de lo **pendiente de reproducir**.
4. No cambiar Supabase ni el código de gameplay como parte de la auditoría sin una decisión explícita.
5. Al resolver un hallazgo, añadir evidencia de la corrección y una prueba reproducible; no marcarlo resuelto solo porque se hizo un cambio.
6. La fuente canónica del mundo sigue siendo Supabase; esta documentación solo registra el estado de la auditoría técnica.

## Resumen ejecutivo

- El CI observado para el commit auditado terminó correctamente en importación/compilación headless y pruebas automatizadas de mundo/TileMapDual.
- Ese CI no demuestra que la composición visual del terreno sea correcta píxel a píxel ni cubre de forma suficiente el ciclo integral de partida, autenticación, inventario, persistencia y funcionamiento offline.
- Hay defectos estáticos plausibles en el contrato de recogida parcial de objetos, el descarte de consultas de drops fallidas, la escritura directa de saves y la validación débil de snapshots.
- Se identificaron riesgos de integración con JWT/RLS, restauración de sesión, arranque offline y precálculo de entidades por chunk. Deben confirmarse contra las rutas completas y, cuando corresponda, contra la configuración real de Supabase.
- No se han aplicado correcciones en esta auditoría.

## Registro de hallazgos

Estados permitidos: **Abierto**, **En verificación**, **Corregido pendiente de prueba**, **Resuelto verificado**, **No reproducido**.

| ID | Prioridad | Área | Hallazgo y evidencia estática | Estado | Verificación pendiente |
|---|---|---|---|---|---|
| INV-01 | Alta | Inventario/recogida | Confirmado por lectura directa de `InventoryRuntime.agregar_objeto()`: primero modifica pilas compatibles y ocupa slots vacíos, y solo después calcula `exito = restante <= 0`; si queda remanente devuelve `false` sin revertir las modificaciones ya hechas. `WorldItem.interact()` y `GarliaWorldItems.intentar_recoger()` conservan el objeto del mundo cuando reciben `false`. Ejemplo reproducible por código: una pila de 9/10 y una recogida de 3 unidades dejan el inventario en 10, devuelven `false` con 2 pendientes y conservan el objeto del mundo con las 3 originales; al reintentar se pueden duplicar unidades. | En verificación | Ejecutar el caso mínimo en Godot y comprobar conteos; decidir contrato: operación atómica con rollback, o transferencia parcial que actualice la cantidad restante del objeto del mundo. |
| ITEM-01 | Alta | Drops | Confirmado por lectura directa de `generar_drops_criatura()` y `_procesar_siguiente_drop()`: la solicitud se añade a `_cola_drops`, pero se extrae con `pop_front()` antes de iniciar la consulta REST. Si `request()` falla al iniciar, el resultado HTTP falla, el status no es 2xx o el JSON no es un arreglo, se procesa la siguiente solicitud sin reponer la que falló ni reintentarla. En esa ruta no se generan los drops de esa criatura; el fallo puede perder el drop del combate. | En verificación | Probar fallo al iniciar request, desconexión/timeout, HTTP no-2xx y JSON inválido; verificar que el fallo se registra y la solicitud se reintenta o queda recuperable, sin duplicar drops exitosos. |
| ITEM-03 | Alta | Soltar objetos desde inventario | `Inventory._soltar_objeto_al_mundo()` llama a `GarliaWorldItems.soltar_objeto_al_mundo()` y luego ejecuta `quitar_objeto(indice)` sin comprobar si se creó el `WorldItem`. La función de infraestructura retorna `void`; `_generar_world_item()` puede salir sin crear nada si falta `Entities` o `WorldEntityManager`/falla `registrar_global()`. En ese caso el objeto desaparece del inventario sin aparecer en el mundo. | Abierto | Prueba con `WorldEntityManager` ausente o `registrar_global()` fallido; definir resultado de creación y retirar el objeto solo tras éxito. |
| ITEM-02 | Media | Catálogo de objetos | La generación inicial depende de `catalogo`; no se encontró un fallback local equivalente. Algunos fallos HTTP terminan en `carga_fallida` sin reintento. | Abierto | Arranque offline y reconexión; definir catálogo local versionado/snapshot sin duplicar la autoridad canónica. |
| AUTH-01 | Alta | Supabase Auth | `GarliaSupabaseClient._crear_headers()` no incorpora el JWT de usuario como `Authorization: Bearer <user JWT>`; `GarliaAuth` usa la clave publicable como Bearer en el flujo inspeccionado. | En verificación | Revisar encabezados en todas las rutas, sesiones reales y políticas RLS. No asumir que todas las tablas fallan sin inspeccionar sus permisos. |
| AUTH-02 | Alta | Restauración de sesión | Las cargas iniciales diferidas de catálogos pueden terminar si todavía no hay sesión restaurada. No se encontró una conexión clara que repita todas esas cargas al finalizar la restauración. | En verificación | Trazar `session_restore_finished`, cargas iniciales y reintentos por dominio. Probar inicio en frío con sesión persistida. |
| SAVE-01 | Alta | Persistencia | `SaveFileRepository.escribir_partida()` y `WorldData` escriben sobre el archivo final directamente; no se observó estrategia temporal + reemplazo atómico. | Abierto | Interrumpir una escritura en una prueba controlada y verificar recuperación del último save válido. |
| WORLD-01 | Alta | Snapshot offline | `WorldDataService._mundo_valido()` acepta un diccionario solo por contener `biomas` como arreglo. Un snapshot incompleto puede desplazar uno válido. | Abierto | Probar JSON mínimo, tipos incorrectos, campos obligatorios ausentes y compatibilidad de versiones. |
| START-01 | Alta | Inicio de partida | La ruta de inicio a Reino Torres reintenta mientras `reinos_game` esté vacío; no se observó un fallback local equivalente en esa espera. | En verificación | Inicio de jugador nuevo completamente offline y reconexión posterior. |
| WORLD-02 | Media | Mutabilidad del estado | Algunos getters de `WorldData` parecen devolver referencias internas en vez de copias profundas. | En verificación | Buscar todos los consumidores y comprobar si alguno muta los diccionarios/arreglos recibidos. |
| STREAM-01 | Media | LOD de entidades | `DATA_RADIUS=3` supera `VISIBLE_RADIUS=2`; el precálculo de entidades consulta contexto de terreno basado en chunks cargados. Los chunks de solo datos pueden no tener contexto y producir listas vacías antes del fallback runtime. | En verificación | Registrar un chunk exterior a radio visible: contexto disponible, resultado de precálculo y resultado al entrar en radio visible. |
| STREAM-02 | Baja/Media | Cache de entidades | `WorldEntityManager.tiene_datos_chunk` usa arrays vacíos como si no hubiera datos calculados; una lista vacía puede significar también “calculado y sin entidades”. | En verificación | Confirmar llamadas, colas y coste de recálculo en chunks válidos sin entidades. |
| TERR-01 | Alta | Renderizado del terreno | La composición por `z_index` se deriva del identificador numérico de zona, no de una regla explícita de prioridad de bordes. Es una causa posible de solapamiento, no una causa raíz demostrada. | En verificación | Capturas reproducibles con combinaciones Pradera/Tierra, inspección de orden de dibujo y comparación de imagen esperada. |
| TERR-02 | Alta por verificar | Atlas/renderizado | En `world_terrain_visual.gd`, `_crear_base_tile()` asigna `atlas.texture_region_size = Vector2i(tile_size, tile_size)` y crea tiles de atlas por coordenadas `TILE_SEQUENCE`; el comentario dice que la máscara alfa se normaliza antes de registrar el atlas, pero en la función no aparece ninguna operación de normalización/recorte alfa. El atlas sí segmenta la textura en regiones de tamaño `tile_size`. Esto es una pista concreta si el arte de borde debe sobresalir de la celda, pero todavía no demuestra que sea la causa visible: hay que contrastar el PNG original, la región de atlas y el resultado renderizado. Además, las capas se ordenan con `z_index = -4095 + zone`, por lo que una zona con ID mayor se dibuja encima de una menor cuando sus píxeles son opacos. | En verificación | Comparar PNG original y regiones 32×32 del atlas; probar un borde con píxeles fuera del límite de celda; registrar coordenadas/capa/z-index y captura. No cambiar código hasta que una prueba mínima discrimine recorte de atlas frente a oclusión por orden de capas. |
| PERF-01 | Media | Presupuesto de frames | El presupuesto adaptativo observa parte del trabajo de datos, pero el coste agregado de preparación, pintura y TileMapDual puede superar el objetivo por frame. | En verificación | Perfilar por fase en resolución fija y hardware objetivo; no optimizar sin medir. |
| TEST-01 | Media | CI | Las pruebas cubren invariantes de terreno/TileMapDual, pero no se encontró una suite equivalente para inventario, persistencia, Auth y offline end-to-end. | Abierto | Añadir pruebas deterministas para los contratos descritos, sin depender de servicios remotos reales. |
| TEST-02 | Baja | CI | El workflow `.github/workflows/procedural-world-tests.yml` no parece incluir `scripts/world/world_generator.gd` en sus filtros de rutas, aunque puede afectar inicialización del renderizador. | Abierto | Revisar `paths`/ `paths-ignore` y confirmar con cambios aislados de ese archivo. |
| DOC-01 | Baja | Documentación | Hay comentarios en `world_terrain_visual.gd` que parecen describir una capa compartida o un orden que no coincide con la implementación por capas/z-index actual. | Abierto | Contrastar cada comentario con el código y corregirlos cuando se autorice la fase de cambios. |
| INV-03 | Baja/Media | Carga de inventario | `cargar_estado_partida()` acepta el arreglo guardado completo y `_normalizar_capacidades_runtime()` solo amplía `items` si es menor que `slot_count`; no recorta si el guardado trae más slots que la UI actual. Como `_crear_slots()` crea exactamente `slot_count` controles, los objetos en índices superiores pueden quedar invisibles en la cuadrícula aunque sigan en el estado y puedan referenciarse desde una hotbar persistida. | En verificación | Cargar un save con más elementos que `slot_count`; decidir si se migra, se preserva con UI ampliada o se valida explícitamente sin perder objetos. |\n| INV-02 | Media | Identidad del objeto al equipar | `Inventory._buscar_indice_objeto()` intenta primero por ID, pero si no encuentra coincidencia cae al nombre incluso cuando el objeto solicitado sí tiene ID. Si existen dos objetos con el mismo nombre y distinto ID, puede seleccionar otra entrada; `equipar_desde_inventario()` reemplaza esa entrada por el equipo anterior mientras equipa la copia recibida. Riesgo de pérdida/duplicación o de equipar el objeto equivocado. | Abierto | Probar dos items con igual nombre y distinto ID, incluyendo un ID no presente en inventario; comparar inventario y equipo antes/después. Preferir coincidencia estricta por ID cuando exista. |
| MISS-01 | Alta | Recompensas/ciclo de misiones | `WorldDataService` carga `misiones_game` y entrega copias profundas; `MissionManagerService` las usa para aceptar misiones y acumular progreso. Al completar, cambia directamente el estado a `completada`, copia `mision.recompensas` y emite `recompensa_disponible`. En la rama auditada, no aparece ningún consumidor de esa señal ni una función de reclamar/aplicar recompensas; la búsqueda de `recompensas` en código encuentra la declaración/emisión y la extracción de datos en `MissionManager`. `HUD` conecta `mision_completada` solo para refrescar la lista y no presenta recompensas ni acción de reclamación. `GameState` serializa/restaura solo `estado` y `progreso`; no existe estado separado de recompensa pendiente/reclamada en el contrato inspeccionado. La finalización sí dispara guardado rápido mediante `mision_completada`, por lo que el estado `completada` puede persistir aunque la recompensa no se aplique. Evidencia estática fuerte de un flujo de recompensa incompleto; no es aún confirmación de runtime. | En verificación | Prueba funcional con misión que otorgue un objeto: registrar inventario antes/después de completar, cerrar/recargar y comprobar estado y duplicación/pérdida. Antes de corregir, revisar definiciones reales de `recompensas` en datos locales/remotos y descartar consumidores indirectos fuera de las referencias localizadas. |
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
