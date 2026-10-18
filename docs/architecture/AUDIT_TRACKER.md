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
| INV-01 | Alta | Inventario/recogida | `InventoryRuntime.agregar_objeto()` puede insertar parcialmente una pila y devolver `false` cuando queda cantidad restante. `WorldItem` y `GarliaWorldItems` eliminan el objeto del mundo solo si el resultado es `true`. La porción ya insertada puede duplicarse al volver a recoger la pila original. | Abierto | Caso de prueba: inventario con espacio para parte de la pila; comprobar cantidades tras dos intentos. Definir contrato de transferencia parcial/atómica. |
| ITEM-01 | Alta | Drops | `GarliaWorldItems` extrae la solicitud de la cola antes de completar la consulta de `criatura_drops`; los fallos no reponen esa solicitud ni tienen reintento equivalente visible. | Abierto | Simular desconexión y HTTP no exitoso; comprobar que la solicitud se conserva o se recupera. |
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
| PERF-01 | Media | Presupuesto de frames | El presupuesto adaptativo observa parte del trabajo de datos, pero el coste agregado de preparación, pintura y TileMapDual puede superar el objetivo por frame. | En verificación | Perfilar por fase en resolución fija y hardware objetivo; no optimizar sin medir. |
| TEST-01 | Media | CI | Las pruebas cubren invariantes de terreno/TileMapDual, pero no se encontró una suite equivalente para inventario, persistencia, Auth y offline end-to-end. | Abierto | Añadir pruebas deterministas para los contratos descritos, sin depender de servicios remotos reales. |
| TEST-02 | Baja | CI | El workflow `.github/workflows/procedural-world-tests.yml` no parece incluir `scripts/world/world_generator.gd` en sus filtros de rutas, aunque puede afectar inicialización del renderizador. | Abierto | Revisar `paths`/ `paths-ignore` y confirmar con cambios aislados de ese archivo. |
| DOC-01 | Baja | Documentación | Hay comentarios en `world_terrain_visual.gd` que parecen describir una capa compartida o un orden que no coincide con la implementación por capas/z-index actual. | Abierto | Contrastar cada comentario con el código y corregirlos cuando se autorice la fase de cambios. |
| INV-03 | Baja/Media | Carga de inventario | `cargar_estado_partida()` acepta el arreglo guardado completo y `_normalizar_capacidades_runtime()` solo amplía `items` si es menor que `slot_count`; no recorta si el guardado trae más slots que la UI actual. Como `_crear_slots()` crea exactamente `slot_count` controles, los objetos en índices superiores pueden quedar invisibles en la cuadrícula aunque sigan en el estado y puedan referenciarse desde una hotbar persistida. | En verificación | Cargar un save con más elementos que `slot_count`; decidir si se migra, se preserva con UI ampliada o se valida explícitamente sin perder objetos. |\n| INV-02 | Media | Identidad del objeto al equipar | `Inventory._buscar_indice_objeto()` intenta primero por ID, pero si no encuentra coincidencia cae al nombre incluso cuando el objeto solicitado sí tiene ID. Si existen dos objetos con el mismo nombre y distinto ID, puede seleccionar otra entrada; `equipar_desde_inventario()` reemplaza esa entrada por el equipo anterior mientras equipa la copia recibida. Riesgo de pérdida/duplicación o de equipar el objeto equivocado. | Abierto | Probar dos items con igual nombre y distinto ID, incluyendo un ID no presente en inventario; comparar inventario y equipo antes/después. Preferir coincidencia estricta por ID cuando exista. |
| MISS-01 | Alta | Recompensas de misiones | `MissionManager._completar_mision()` cambia el estado a `completada`, construye el arreglo de recompensas y emite `recompensa_disponible`. En la rama inspeccionada, la búsqueda de referencias encontró la señal solo en su declaración/emisión; `HUD` escucha `mision_completada` únicamente para refrescar el panel. No se encontró método de reclamación ni ruta que aplique `recompensas_resultado` al inventario; `reclamada` solo aparece como estado bloqueante en `aceptar_mision()`. Evidencia estática fuerte de que las recompensas no se aplican por el flujo visible, pendiente de una prueba funcional y de descartar consumidores dinámicos/reflexivos. | En verificación | Seguir todas las referencias en el SHA de la rama y comprobar si hay un flujo de recompensa alternativo; prueba de misión con recompensa material y comparación de inventario antes/después. |
| SOCIAL-01 | Media | Relaciones sociales | `RelationshipSystem` carga reglas y regalos desde `SocialRepository`; no se encontró fallback local. Si las reglas no cargan, `obtener_relacion()` puede devolver `{}` y `registrar_dialogo()` no modifica la relación. `SocialRepository` emite error y descarta la respuesta fallida sin reintento visible. | Abierto | Probar reglas/regalos con red ausente y restauración de conexión; definir caché local si se requiere gameplay social offline. |
| CONFIG-01 | Baja | Configuración/perfilado | `project.godot` usa viewport base 960×540 y overrides de ventana 1920×1080; métricas anteriores tomadas con otra resolución no son comparables directamente. | Abierto | Fijar perfil de prueba, renderer, resolución y equipo antes de comparar rendimiento. |

## Estado del terreno

La auditoría anterior observó que:

- La arquitectura activa separa `WorldStreamer → WorldTerrain → WorldTerrainVisual → TileMapDual/DisplayLayer`.
- Las pruebas existentes verifican varias invariantes estructurales, pero no una imagen final de referencia.
- El CI correcto es evidencia de compilación/importación y de las pruebas que se ejecutaron; no es evidencia suficiente de ausencia de seams, oclusión incorrecta o pérdida visual de bordes.
- Los datos históricos de tiempos de generación/frame mencionados en conversaciones anteriores no deben presentarse como mediciones actuales sin repetirlos bajo una configuración controlada.

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
