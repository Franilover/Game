# Garlia — Hoja de ruta técnica activa

**Rama de trabajo:** `work/design-and-architecture`  
**Alcance:** estabilidad y expansión del juego individual.  
**Regla de validación:** solo marcar como completado lo que tenga evidencia en código y pruebas; CI correcto no sustituye una prueba visual o de gameplay que no exista.

## Criterios de estado

- [x] Completado y verificado en el alcance indicado.
- [~] En progreso; existe implementación parcial o una corrección pendiente de validación.
- [ ] Pendiente.
- [!] Hallazgo detectado que requiere corrección o prueba específica.

---

## Fase 1 — Integridad del motor y persistencia (P0)

### 1.1 Estado y ciclo de vida de entidades
- [x] Separar el estado vital de la entidad de la lógica de combate.
- [x] Emitir `died` exactamente una vez por transición de vivo a muerto en `Entity`.
- [x] No reproducir el evento histórico al restaurar una entidad muerta.
- [x] Rearmar el evento al restaurar una entidad viva.
- [~] Revisar overrides de `_die()`: `Creature` ya delega la señal a `Entity` y sincroniza `VitalState` al configurarse; falta validar restauración viva de subclases.
- [~] Unificar restauración de salud/maná, Eterium compartido, reaparición y máximos administrativos mediante `VitalState`; falta auditar todos los efectos secundarios.
- [~] Añadir contratos de daño/restauración, absorción y agotamiento para fisiología compartida; falta auditar curación, regeneración y límites de todos los caminos.
- [ ] Detectar escrituras directas que omitan al dueño del estado.
- [~] Impedir operaciones sobre entidades eliminadas o inválidas: las rutas de combate rechazan nodos pendientes de `queue_free()`; falta auditar operaciones ajenas al combate.

### 1.2 Guardado y restauración
- [x] Mantener snapshots separados: `PlayerState`, `WorldState` y `DiscoveryState`.
- [x] Mantener `GameStateService` como coordinador, sin duplicar una fachada.
- [x] Implementar escritura temporal, validación JSON, respaldo y recuperación del último save válido en `SaveFileRepository`; el respaldo se conserva cuando el destino bloquea la recuperación.
- [x] Contrato automatizado de sobrescritura, recuperación, eliminación y rechazo de IDs/payloads inválidos; CI Godot 4.7 aprobado.
- [ ] Validar la recuperación ante interrupción real del proceso y errores de filesystem fuera del entorno de contrato.
- [ ] Validar versión y migraciones de saves antiguos.
- [x] Rechazar estructuras corruptas o incompletas sin destruir el último save válido dentro del contrato del repositorio; la validación de la estructura anidada de inventario también pasa en CI Godot 4.7. Migraciones de saves antiguos siguen pendientes.
- [~] El contrato `GameStateRoundtrip` verifica salud, Eterium, stamina, posición/tile/orientación, inventario, interior/zona, proceso IUM, tiempo ambiental y estado/progreso/reclamación de misiones. Falta validar la aplicación del snapshot y la reanudación integral en una escena real.
- [ ] Comprobar guardado rápido, autosave, cierre de ventana y guardados simultáneos.
- [ ] Verificar que una muerte o transición de escena no guarde un snapshot parcial.

### 1.3 Contratos del runtime
- [x] Extraer locomoción, inventario, resolución/ejecución de ataques y efectos posteriores al impacto.
- [x] Separar validación y resultado tipado de solicitudes de ataque.
- [x] Separar señales de configuración/daño entre `Creature` y `CreatureAI`.
- [ ] Auditar dependencias circulares y referencias directas restantes.
- [ ] Reducir responsabilidades de `Main`, `Player`, `HUD` y `GameStateService` solo cuando exista un dueño real.
- [ ] Revisar autoloads y distinguir servicios globales de estado de partida.
- [ ] Normalizar contratos de error, retorno y señales.
- [ ] Retirar código duplicado, muerto u obsoleto con evidencia de no uso.

---

## Fase 2 — Sistemas de gameplay (P1)

### 2.1 Combate
- [x] Separar interpretación de objetos, construcción de ataques y efectos posteriores al impacto.
- [x] Mantener `CombatDamage` como dueño de la reducción de salud en las rutas auditadas.
- [x] Cada impacto devuelve daño efectivo aislado de señales reentrantes; CombatSystem, proyectiles, feedback y robo de vida consumen el resultado real. Regresiones aprobadas en CI.
- [x] Distinguir solicitud aceptada, contacto y daño real mediante `CombatAttackResult`.
- [~] Defensa plana: Player aplica armadura equipada y Creature aplica `stats_dnd.defensa`; los contratos de ambos pasan en Godot 4.7. Resistencias/inmunidades por tipo siguen pendientes porque el contrato de ataque todavía no define tipos de daño.
- [x] Ruta de daño IUM verificada mediante `CombatSystem.solicitar_danio_desde_entidad()` y `CombatEntityAttackContract` en Godot 4.7; no se alteraron fórmulas IUM.
- [x] Proyectiles de impacto único, objetivos derrotados, impactos simultáneos, melee contra varios objetivos y colisiones físicas reales de hitbox/hurtbox pasan contratos en Godot 4.7; proyectiles rápidos usan barrido continuo para evitar tunneling.
- [~] Cooldown, cancelación por atacante inválido (incluido jugador derrotado), interrupciones síncronas y atribución de daño pasan sus contratos en Godot 4.7; falta validación integrada y balance en partida.
- [x] `PlayerVitalStateContract` cubre fisiología normal y compartida, absorción, daño, muerte al agotar Eterium y reaparición; el contrato se ejecuta en CI.
- [ ] Mantener el balance separado de la infraestructura.

### 2.2 IA de criaturas
- [x] Separar la salud y el estado vital de las decisiones de IA.
- [x] Comunicar configuración y daño mediante señales.
- [~] Separar percepción, selección de objetivo, decisión y ejecución: `CreaturePerception`, `CreatureTargetSelector` y `CreatureStateDecision` están extraídos; `CreatureAI` conserva ejecución, movimientos especializados y ataques con validación de alcance. Percepción, selección, memoria, Utility AI, personalidad, escalado por agresión y familiaridad tienen contratos aprobados en CI. Falta extraer navegación/conductas adicionales y validar transiciones visuales en partida.
- [~] Navegación local recupera bloqueos y mantiene el desvío; la pérdida de objetivo conserva y visita la última posición conocida. La memoria individual, familiaridad, confianza explícita, Utility AI y personalidad están implementadas y cubiertas por pruebas. Falta navegación global para rutas complejas y validación visual de reacciones/transiciones.
- [ ] Verificar IA fuera de rango y transiciones de simulación.
- [ ] Revisar perfiles y `ia_config` de las especies existentes.
- [ ] Comprobar sincronización de configuración desde los datos canónicos.
- [ ] Medir coste por frame y evitar trabajo repetido.

### 2.3 Interacciones y progresión
- [x] Validar estado y progreso de misiones al restaurar partidas; contrato CI cubre normalización, finalización idempotente y emisión única de la señal de recompensa.
- [~] El flujo de progreso/finalización, persistencia del estado de misión, reclamación idempotente, resolución de recompensas por UUID y rollback de entregas tiene contratos aprobados. Falta validar en una partida real la continuidad después de guardar y recargar.
- [~] La aplicación idempotente y el rollback ante inventario lleno están cubiertos por `MissionRewardDelivery` y `MissionManagerContract`; falta probar una recompensa ya entregada después de cerrar y reanudar una partida real.
- [ ] Revisar diálogos interrumpidos, ramas y condiciones.
- [ ] Auditar relaciones, regalos, memoria social y persistencia.
- [ ] Verificar interacciones con NPC, objetos, estaciones y zonas.
- [ ] Separar eventos de dominio de la presentación.

---

## Fase 3 — Mundo, inventario y datos de partida (P1/P2)

### 3.1 Mundo y generación
- [ ] Reducir responsabilidades de `WorldGenerator` mediante fronteras reales.
- [~] Hay contratos para ciclo de vida/reset del `WorldEntityManager`, persistencia de props/keys, registro de réplicas, spawn/resume de zona, terreno y kernel procedural. Falta una auditoría integral de streaming/factory/spawn en sesiones largas.
- [ ] Garantizar generación determinista para una misma semilla y versión.
- [~] Los contratos de identidad runtime, registro de réplicas y reanudación de spawn cubren duplicación en sus rutas probadas; falta una prueba de estrés de ciclos repetidos de carga/descarga de chunks.
- [~] La persistencia de props del mundo y el roundtrip de zona/interior tienen contratos; falta comprobar cambios de interiores y reanudación completa en una sesión real.
- [~] Los contratos de viaje/retorno, progresión de rutas y mapa estático de bosque cubren rutas y restauración en sus escenarios; faltan límites entre todos los reinos e interiores en runtime.
- [~] Hay contratos de ciclo de vida, reset, persistencia e identidad de entidades y registro de réplicas; falta verificar el comportamiento global/streaming bajo carga y cambios de zona prolongados.
- [ ] Probar mundos largos y sesiones con muchas criaturas.

### 3.2 Inventario y objetos
- [x] Separar la obtención de posición del puntero de la transacción de soltar objetos; el inventario solo descuenta tras confirmar el registro del WorldItem.
- [x] Separar estado/controlador de la presentación del inventario.
- [x] Separar hotbar de equipamiento.
- [x] `InventoryRuntime` revierte recogidas parciales que no caben; el contrato verifica rechazo atómico y transferencia íntegra cuando existe capacidad.
- [x] Verificar el contrato de soltar objetos: retirar del inventario solo tras crear y registrar el objeto del mundo; la ruta de fallo conserva el objeto y usa el dato actual del runtime, no una copia de arrastre obsoleta.
- [ ] Auditar identidad por ID, apilamiento, límites y capacidad.
- [~] Los contratos de uso de objetos, crafting y equipamiento pasan en CI; durabilidad y transferencia entre manos todavía necesitan cobertura específica y prueba visual.
- [~] Los contratos de transacción, desbordamiento UI, equipamiento y roundtrip de inventario pasan en CI; la carga de equipo valida ranuras y los slots extra se muestran mediante grupos de reserva. Falta compatibilidad con saves antiguos y comprobar scroll/selección en ventana real.
- [ ] Unificar validaciones para recoger, soltar, intercambiar, usar y equipar.

### 3.3 Datos y modo sin conexión
- [x] Introducir `WorldSnapshotValidator` compartido por `WorldData` y `SupabaseClient`; el contrato de jerarquía/snapshot incluido pasa CI.
- [x] Rechazar snapshots con jerarquía obligatoria incompleta o tipos incorrectos; el fallback/cache completo sigue pendiente de pruebas de integración.
- [ ] Revisar caché local versionada para catálogos cuando corresponda, sin duplicar la autoridad de Supabase.
- [ ] Comprobar inicio de una partida nueva sin conexión y recuperación posterior.
- [ ] Auditar reintentos y errores de red por dominio.
- [ ] Mantener Supabase como fuente canónica; no cambiar tablas, RPC, políticas ni datos sin aprobación explícita.

---

## Fase 4 — Rendimiento, pruebas y calidad (P2)

### 4.1 Rendimiento
- [ ] Perfilar CPU, GPU, memoria y tiempos de frame con renderer/resolución fijos.
- [ ] Medir en hardware modesto antes de optimizar.
- [ ] Revisar física, colisiones, señales por frame y búsquedas repetidas de nodos.
- [ ] Revisar creación/liberación de nodos, carga de recursos y streaming.
- [ ] Evitar trabajo duplicado entre chunks, entidades y presentación.
- [ ] Probar carga alta y sesiones prolongadas.

### 4.2 Pruebas y CI
- [x] Mantener importación/compilación headless en CI.
- [x] Ejecutar contratos de locomoción, combate, IA y ciclo de vida cubiertos por el workflow actual.
- [x] Contrato de recuperación de `SaveFileRepository` ejecutado en CI.
- [x] Contratos de recogida, uso, crafting, equipamiento, overflow, hotbar, drops, roundtrip de partida, restauración/finalización de misiones y entrega/rollback de recompensas ejecutados en CI; persistencia integral tras una sesión real sigue pendiente.
- [~] El contrato de `WorldSnapshotValidator` y `GameStateRoundtrip` ya cubre estructura de snapshot y serialización/restauración de datos; falta integración end-to-end offline y aplicación completa del snapshot en escena.
- [ ] Añadir pruebas de integración de inicio/cierre de partida.
- [ ] Verificar referencias rotas de escenas, recursos, autoloads y scripts.
- [ ] Añadir pruebas de regresión para fallos encontrados, no solo pruebas felices.
- [ ] Diferenciar evidencia automatizada, pruebas manuales y pruebas visuales.

### 4.3 UI y accesibilidad funcional
- [ ] Revisar HUD, inventario, combate, mapa, Garudex y menús.
- [ ] Mantener gameplay fuera de la capa de presentación.
- [ ] Verificar navegación por teclado, controles configurables y foco.
- [ ] Verificar volumen general, música y efectos por separado.
- [ ] Revisar escala, legibilidad, estados de carga y mensajes de error.
- [ ] Mantener el lenguaje visual de interfaz café/marrón y evitar cambios visuales no solicitados.

---

## Fase 5 — Preparación de contenido y herramientas (P3)

### 5.1 Criaturas y Garumis
- [ ] Estandarizar plantillas de criaturas, perfiles de IA, estadísticas, habilidades y ataques.
- [ ] Verificar condiciones de aparición y evolución.
- [ ] Auditar pactos, vínculos, límites y persistencia de Garumis.
- [ ] Completar enciclopedia, descubrimientos y siluetas.
- [ ] Mantener separados Originals, descendientes y criaturas que no son Garumis.

### 5.2 Ecología y biodiversidad
- [ ] Auditar biomas, ecosistemas y hábitats frente a los datos canónicos.
- [ ] Desarrollar categorías de biodiversidad adicionales sin mezclar organismos minerales con flora, fauna o fungi.
- [ ] Revisar cadenas ecológicas, agresión, depredación y distribución.
- [ ] Verificar ciclos ambientales y condiciones de aparición.
- [ ] No introducir supuestos de oxígeno ni cambiar reglas del canon sin aprobación.

### 5.3 Objetos y progresión
- [ ] Estandarizar datos de objetos, recetas, habilidades y recompensas.
- [ ] Auditar progresión de jugador y Garumis.
- [ ] Verificar desbloqueos, economía, comercio y recursos.
- [ ] Crear herramientas de validación de contenido antes de ampliar el catálogo.

---

## Fase 6 — Expansión posterior (P4)

- [ ] Nuevos reinos y regiones.
- [ ] Interiores, asentamientos y viviendas.
- [ ] Eventos ambientales y descubrimientos.
- [ ] Nuevas criaturas, evoluciones y Garumis.
- [ ] Nuevas conjuraciones IUM y habilidades.
- [ ] Misiones ramificadas y contenido social.
- [ ] Construcción, economía y actividades secundarias.
- [ ] Ecosistemas dinámicos y herramientas de investigación.

---

## Fuera del alcance actual

El trabajo multijugador queda aplazado. No forma parte de las fases activas ni se eliminará el código existente por esta decisión. No se realizarán refactors, pruebas ni cambios de backend orientados a multijugador hasta que se retome expresamente.

## Orden de ejecución inmediato

1. Terminar y validar el contrato de escritura/recuperación de saves.
2. Auditar la aplicación del snapshot de jugador y sus subclases de `Entity`.
3. Corregir los contratos de inventario de recogida y soltar objetos.
4. Seguir misiones desde la finalización hasta la recompensa persistida.
5. Auditar la validación de snapshots offline de mundo.
6. Continuar IA de criaturas (Utility AI contextual, memoria de interacción y aprendizaje acotado) y división de `WorldGenerator`.
7. Perfilar y ampliar pruebas de integración.

**Límites:** esta hoja de ruta no autoriza cambios en Supabase ni cambios de canon de Garlia. Los cambios de código permanecen aislados en la rama indicada; no se hace merge a `main` sin autorización explícita.

7. Validar memoria temporal de interacción con más perfiles. Incorporar recuerdos positivos sólo cuando exista un evento real de ayuda, alimentación o vínculo; reutilizar `RelationshipSystem` en criaturas con `personaje_game_id` en vez de duplicar amistad. No persistir memoria efímera por defecto.


### IA de criaturas — relaciones individuales (2026-11-20)

- [x] Memoria individual acotada para agresión y familiaridad.
- [x] Clasificación derivada de relación y confianza temporal por interacción positiva explícita.
- [x] Integración opt-in de confianza con Utility AI, limitada a investigar.
- [x] Reutilización de candidatos de percepción para evitar escaneos redundantes en el mismo tick.
- [ ] Conectar un evento positivo real cuando exista una acción de gameplay con semántica inequívoca.
- [ ] Añadir cooperación/evitación entre individuos sólo con eventos y reglas ecológicas existentes.
- [ ] Validar conducta visual y perfilar carga con muchas criaturas.


- [x] Escalado opcional de respuesta por agresiones repetidas, con umbral y memoria temporal acotada.


- [x] Preferencias de personalidad individuales opcionales ponderan necesidades y curiosidad en Utility AI, con límites y pruebas.
- [ ] Definir si el juego necesita persistencia de cambios de personalidad aprendidos; por ahora sólo se leen rasgos existentes en los datos individuales.


### IA de criaturas — familiaridad con conducta opcional

- [~] Diferenciar encuentros cercanos de avistamientos visuales; no asumir línea de visión sin un sistema validado de oclusión.
- [~] Permitir que especies configuradas investiguen individuos conocidos mediante un umbral ponderado por curiosidad.
- [~] Mantener prioridad de agresión recordada y relaciones ecológicas; familiaridad nunca autoriza combate.
- [ ] Validar visualmente aproximación/investigación y evitar oscilaciones entre estados.
- [ ] Añadir pruebas de integración con dos criaturas reales y reglas ecológicas simultáneas.


## Cierre de avances verificados — 2026-11-20

- CI completo Godot 4.7: **success**, run [44699447898](https://github.com/Franilover/Game/actions/runs/44699447898), commit `49a25d51`; importación/compilación y todos los contratos del workflow terminaron correctamente.
- P0 cerrados en el alcance automatizado: recuperación transaccional de `SaveFileRepository`, validación de estructura anidada de inventario, normalización/restauración de estado vital, roundtrip de snapshots y contratos de ciclo de vida. No se cierra la fase P0 completa: faltan carga integral en escena, saves antiguos, interrupciones reales y autosave/cierre.
- P1 combate: contratos de daño efectivo/reentrada, temporalidad, melee físico, proyectiles, ataques de entidades, defensas y fisiología pasan CI. Balance y validación visual siguen abiertos.
- P1 criaturas: percepción/selección, memoria individual, Utility AI, personalidad, escalado de agresión, familiaridad, navegación local y exclusión no-combatiente de Garumis pasan CI. Navegación global, transiciones visuales, simulación fuera de rango y perfilado siguen abiertos.
- P1 misiones: persistencia de progreso, finalización, entrega idempotente, resolución de recompensas y rollback pasan CI. Falta guardar/recargar una partida real después de reclamar.
- P1/P2 mundo e inventario: contratos de ciclo de vida/reset, persistencia de props/keys, registro de réplicas, spawn/resume, viaje/retorno, terreno, kernel procedural, transacciones de inventario y roundtrip pasan CI. Streaming de larga duración, reinos/interiores completos y pruebas visuales siguen abiertos.
- Estos cierres son por alcance probado; no significan que todas las fases P0, P1 o P1/P2 estén terminadas.


### Verificación adicional de persistencia y modo offline — 2026-11-20

- [x] `GameStateRoundtrip` ahora escribe el snapshot en un archivo real mediante `SaveFileRepository`, lo reabre desde disco y restaura el estado de misión, progreso y reclamación de recompensa desde ese archivo. Contrato ejecutado en CI Godot 4.7.
- [x] El contrato de snapshot del mundo ahora verifica lectura offline del caché con envoltorio actual (`{mundo: ...}`), compatibilidad con el formato directo legado y rechazo de caché con jerarquía inválida. Contrato ejecutado en CI Godot 4.7.
- [x] Los contratos de recuperación de saves, recogida atómica, drop, transacciones de inventario, misión y rollback de recompensa continúan pasando en la misma regresión.
- [~] La prueba de archivo real cierra el tramo de serialización/lectura del snapshot y de persistencia de reclamaciones; no reemplaza todavía la prueba end-to-end que instancia una escena de juego, aplica el snapshot a un `Player` real y continúa jugando.
- [ ] Sigue pendiente la validación manual de interrupciones reales del proceso/filesystem, migraciones de saves antiguos y reanudación visual completa de escena/zona/interior.
- [ ] El modo offline ya valida y lee los formatos de caché conocidos; queda probar inicio de partida sin conexión y recuperación de sincronización con Supabase en una sesión integrada.
- CI de código y contratos: [44700468681](https://github.com/Franilover/Game/actions/runs/44700468681) — **success** (commit `320c07251f`); calidad GDScript: [44700468617](https://github.com/Franilover/Game/actions/runs/44700468617) — **success**.


### Aplicación del snapshot sobre Player real — 2026-11-20

- [x] Nuevo contrato `GameStateSceneRestore`: instancia la escena real `Player`, la añade al árbol de escenas y ejecuta `GameStateService._aplicar_estado_al_juego()`.
- [x] Verifica restauración de salud, Eterium, stamina, posición y orientación, además de las banderas de aplicación/restauración vital.
- [x] Integrado al workflow de regresión Godot 4.7; ejecución [44701475641](https://github.com/Franilover/Game/actions/runs/44701475641), job de regresión **success**.
- [~] Esto verifica aplicación sobre una instancia real de Player en una escena de prueba; todavía no es una reanudación completa de `main.tscn` con ZoneManager, interior, inventario y continuidad de gameplay.
- [ ] Mantener pendiente la prueba end-to-end de guardar, cerrar, volver a abrir la escena principal y continuar la partida, incluyendo cambio de zona/interior.


### Reanudación integrada de zona, Player e inventario — 2026-11-20

- [x] Se añadió `tests/persistence/test_main_session_resume.gd` con una escena de prueba que monta un árbol de runtime con `ZoneManager`, `Player` e inventario reales.
- [x] La prueba reanuda Torres a partir de `zona_actual_tipo`, carga la escena real de Torres y aplica el snapshot de Player e inventario.
- [x] Verifica posición, orientación, salud, Eterium, stamina, objetos y selección de hotbar después de la aplicación.
- [x] El paso específico `Run saved zone, Player and inventory session resume integration` terminó **success** en CI Godot 4.7, run [44747758966](https://github.com/Franilover/Game/actions/runs/44747758966), commit `4422b9bd`.
- [~] El alcance confirma restauración integrada de zona/Player/inventario en un árbol de prueba, pero no instancia `main.tscn` ni ejecuta el ciclo real de cerrar y volver a abrir el juego.
- [ ] Siguen pendientes el reinicio real del proceso, continuidad de gameplay, interiores completos, migraciones antiguas y arranque/reconexión offline end-to-end.


### Reanudación desde main.tscn y propiedad del input gate — 2026-11-20

- [x] Se añadió `tests/persistence/test_main_scene_resume.gd`: instancia `scenes/world/main.tscn`, deja que Main inicie Torres desde el tipo de zona guardado y verifica la aplicación automática de GameState.
- [x] Comprueba Player real (posición, orientación, salud, Eterium y stamina), inventario real (objetos/hotbar) y que `InventoryController` sea dueño del nodo `GameplayInputGate`.
- [x] La prueba aísla el catálogo de NPC y resuelve Eterium localmente; no requiere credenciales ni modifica saves reales. No cubre materialización de NPC, interiores ni reinicio real del proceso.
- [x] El contrato encontró y corrigió un nodo `GameplayInputGate` huérfano: `InventoryController.configurar_gate()` ahora adopta el nodo como hijo y libera el gate anterior al reemplazarlo.
- [x] Suite completa Godot 4.7: **success**, run [44750243790](https://github.com/Franilover/Game/actions/runs/44750243790), commit `49d52ae3`. GDScript Quality (Advisory): **success**, run [44750243789](https://github.com/Franilover/Game/actions/runs/44750243789).
- [~] La aplicación automática de snapshot a `main.tscn` ya tiene cobertura headless integrada. Sigue pendiente guardar/cerrar/reabrir el proceso real y continuar gameplay con interiores/NPC en ejecución.


### Integración de reanudación en main.tscn — 2026-11-20

- [x] Nuevo contrato `test_main_scene_resume` instancia la escena real `scenes/world/main.tscn`, deja que su `Main` configure servicios, inicia Torres mediante el `ZoneManager` real y espera la restauración automática.
- [x] Verifica posición y orientación, salud, Eterium, stamina, inventario, hotbar, propiedad del `GameplayInputGate` y finalización de restauración vital.
- [x] La primera ejecución encontró que el test llegaba a `MainSceneResume: PASS` pero fallaba durante la limpieza por nodos dinámicos de entrada sin liberar. Se corrigió la limpieza explícita de ambos gates y el desmontaje diferido de `main.tscn`.
- [x] Regresión completa Godot 4.7 aprobada en [44750715923](https://github.com/Franilover/Game/actions/runs/44750715923), commit `ccd2ee7773`.
- [~] Esta prueba cubre la escena principal y su orden de inicialización con un snapshot de prueba en memoria; todavía no simula cerrar y volver a abrir dos procesos independientes ni valida el archivo real desde el arranque de `main.tscn`.
- [ ] Mantener pendientes el reinicio real del proceso, la migración exhaustiva de saves antiguos y la continuidad integrada de interiores/offline.


### Normalización de saves legacy — 2026-11-20

- [x] Centralizada la migración de partidas en `_migrar_datos_partida()`: valida primero el contrato, trabaja sobre una copia profunda, preserva campos desconocidos y normaliza la versión.
- [x] Añade semilla y `generador_version` cuando faltan, sin regenerar una semilla ya guardada.
- [x] `iniciar_partida()` aplica la normalización antes de restaurar el estado y persiste el archivo migrado; si falla la escritura, avisa y permite abrir los datos normalizados en memoria.
- [x] Pruebas para versión 1 sin campo `version`, preservación de progreso desconocido, no mutación del original y rechazo de versiones futuras.
- [x] CI Godot 4.7 y calidad GDScript aprobadas: [regresión 44751938817](https://github.com/Franilover/Game/actions/runs/44751938817), [calidad 44751938797](https://github.com/Franilover/Game/actions/runs/44751938797).
- [~] La compatibilidad explícita cubierta es la forma legacy conocida (v1 sin versión, stamina antigua y ausencia de semilla). No se inventaron transformaciones para campos históricos cuya semántica no está documentada.


### Guardado entre procesos independientes — 2026-11-20

- [x] Nuevo contrato `tests/persistence/test_save_process_restart.gd` lanza dos instancias independientes de Godot con `OS.execute`: una escribe y termina; la segunda arranca y lee el archivo desde el mismo `user://`.
- [x] El lector verifica PID distinto, versión, semilla y versión de generador, salud/Eterium, posición, zona, inventario, progreso de misión y reclamación de recompensa.
- [x] El proceso padre valida códigos de salida y marcadores de éxito de ambos procesos; elimina el fixture al terminar.
- [x] Integrado en `.github/workflows/procedural-world-tests.yml`. Regresión Godot 4.7 aprobada: [run 44752576177](https://github.com/Franilover/Game/actions/runs/44752576177). Calidad GDScript aprobada en el commit del script: [run 44752557244](https://github.com/Franilover/Game/actions/runs/44752557244).
- [~] Este contrato demuestra persistencia de archivo entre procesos independientes, pero usa un payload representativo con `SaveFileRepository`; todavía no inicia el juego desde el menú y carga una partida real mediante `GameState.iniciar_partida()` en el segundo proceso.



### Reinicio completo desde el menú — 2026-11-20

- [x] El contrato `tests/persistence/test_full_save_restart.gd` lanza procesos escritores y lectores independientes. El escritor crea una partida mediante `GameState.crear_partida()` y guarda un snapshot; el lector inicia el menú real, abre el selector, ejecuta `_jugar_partida()` y carga mediante `GameState.iniciar_partida()`.
- [x] Verifica la entrada en `main.tscn`, zona Torres, posición/orientación, salud, Eterium, stamina, inventario, hotbar y estado/progreso/recompensas de misiones.
- [x] Se detectó y corrigió un defecto real: JSON.parse entrega la versión serializada como `float` en Godot 4.7. El validador acepta ahora enteros representados como int o float y rechaza versiones fraccionarias.
- [x] El callback de readiness vital se reintenta tras resolver reglas locales de Eterium en la prueba offline; el jugador se congela en `Events.scene_changed` para evitar que la física altere la muestra antes de verificarla.
- [x] Pruebas de payload, reinicio completo y reinicio de repositorio entre procesos aprobadas. Regresión completa Godot 4.7: [run 44756242924](https://github.com/Franilover/Game/actions/runs/44756242924). Calidad GDScript: [run 44756242844](https://github.com/Franilover/Game/actions/runs/44756242844).
- [~] El reinicio ahora queda cubierto desde el menú hasta Main para el snapshot de contrato. Aún faltan escenarios reales de interiores, reanudación de mundo procedural y recuperación offline/reconexión.


### Hogar e interior — continuidad del estado — 2026-11-20

- [x] HogarZone implementa restaurar_estado_guardado() para cumplir el contrato que usa GameState al reanudar la zona activa.
- [x] La carga de estado ahora programa la reapertura del interior después de aplicar decoraciones y muebles; evita que el call_deferred inicial de _ready ocurra antes de recibir el snapshot.
- [x] Nuevo contrato tests/persistence/test_home_interior_persistence.tscn: verifica decoraciones exteriores, identidad y contenido de cofres exteriores/interiores, muebles, contador de cofres y restauración del interior abierto.
- [x] CI Godot 4.7 del contrato de hogar: [run 44757104913](https://github.com/Franilover/Game/actions/runs/44757104913), prueba de hogar aprobada. La regresión completa del commit de integración de guardado anterior también está aprobada: [run 44756242924](https://github.com/Franilover/Game/actions/runs/44756242924).
- [x] Nuevo contrato tests/persistence/test_home_process_restart.tscn ejecuta escritor y lector en procesos Godot independientes. El lector entra por el menú/selector real, carga Main, reanuda Hogar con el interior abierto y verifica posición del jugador, muebles, identidad/contenido de cofres exteriores e interiores y contador de cofres.
- [x] Integrado en CI. Regresión completa Godot 4.7 aprobada: [run 44811784110](https://github.com/Franilover/Game/actions/runs/44811784110); calidad GDScript aprobada: [run 44811757973](https://github.com/Franilover/Game/actions/runs/44811757973).
- [~] Continúan pendientes la continuidad del mundo procedural tras reinicio y la recuperación offline/reconexión de extremo a extremo.

### Reanudación de posición en Hogar — 2026-11-20

- [x] Hallazgo: ZoneManager guardaba las coordenadas del jugador dentro de hogar_estado al salir de la parcela, pero no las consumía al volver a entrar. La restauración podía depender de que otro snapshot global tuviera la posición correcta.
- [x] Tras añadir la escena Hogar al árbol, ZoneManager restaura las coordenadas locales guardadas si son numéricas y finitas; valores ausentes, malformados o no finitos no alteran la posición actual.
- [x] Nuevo contrato tests/persistence/test_zone_manager_home_position.tscn cubre coordenadas válidas y rechaza datos inválidos. También se mantienen aprobadas las pruebas de muebles/interior y reinicio general.
- [x] Regresión completa Godot 4.7 aprobada: [run 44811300461](https://github.com/Franilover/Game/actions/runs/44811300461). Calidad GDScript del cambio: [run 44811288159](https://github.com/Franilover/Game/actions/runs/44811288159).
- [~] Esto cierra la restauración de posición al reingresar a Hogar desde otra zona. Sigue pendiente el ciclo de dos procesos que guarde y reabra directamente una partida mientras el jugador permanece dentro del interior.

### Persistencia local de entidades del mundo procedural — 2026-11-20

- [x] Hallazgo: WorldEntityManager ya capturaba/restauraba el estado dinámico de criaturas y props, pero el único consumidor de esa API era GlobalWorldStore. Las partidas locales no conservaban esos cambios entre procesos.
- [x] GameState guarda deltas por tipo de zona en entidades_mundo_local_por_zona. Se serializan Vector2 y Vector2i con etiquetas explícitas para sobrevivir al JSON y recuperar sus tipos al cargar.
- [x] GameState captura el manager al guardar una partida; ZoneManager también captura antes de descargar Mundo Abierto/Expedición. Main restaura el estado local antes de registrar al jugador y activar el streaming.
- [x] Servidor dedicado continúa usando GlobalWorldStore; los clientes de mundo global no mezclan su save privado con el estado autoritativo de la sesión.
- [x] Nuevo contrato tests/persistence/test_local_world_entity_state.tscn verifica JSON roundtrip, posiciones/velocidades, coordenadas de chunk, tombstones de props y aislamiento entre zonas. Regresión completa Godot 4.7: [run 44812559373](https://github.com/Franilover/Game/actions/runs/44812559373); calidad GDScript: [run 44812537936](https://github.com/Franilover/Game/actions/runs/44812537936).
- [x] Nuevo contrato tests/persistence/test_local_world_entity_process_restart.tscn: un proceso crea la partida y serializa el estado del manager en el save real; otro proceso lee el JSON, reconstruye Vector2/Vector2i, verifica posición/velocidad/salud/necesidades de criatura y tombstone de prop, y vuelve a cargar el estado en WorldEntityManager.
- [x] CI completa Godot 4.7 aprobada con los contratos local y entre procesos: [run 44813051758](https://github.com/Franilover/Game/actions/runs/44813051758); calidad GDScript: [run 44813028917](https://github.com/Franilover/Game/actions/runs/44813028917).
- [~] Sigue pendiente probar el ciclo con WorldGenerator real, chunks materializados por WorldStreamer y entidades modificadas reapareciendo en gameplay. La prueba nueva cruza procesos y reconstruye el manager, pero no instancia el mundo procedural completo.
- [x] `tests/persistence/test_procedural_world_entity_materialization.tscn` ahora genera los datos de criaturas desde el catálogo/ecosistema/semilla reales del chunk, materializa una criatura natural, modifica posición/velocidad, captura el snapshot, descarga y rematerializa sin duplicarla ni inyectar registros de criatura.
- [x] La prueba también intenta generar/materializar props naturales y comprobar su posición runtime. En el snapshot local actual `WorldData` reporta 0 props activos, por lo que esa rama no se ejecutó en CI; la persistencia/tombstones de props sí conserva su contrato unitario independiente (`WorldPropPersistence: PASS`). No se marca como validada la regeneración natural de props.
- [x] Regresión completa Godot 4.7 aprobada con la prueba de materialización natural y todos los contratos de persistencia: [run 44817299898](https://github.com/Franilover/Game/actions/runs/44817299898). Calidad GDScript: [run 44817299858](https://github.com/Franilover/Game/actions/runs/44817299858).
- [~] Pendiente para cerrar continuidad procedural entre procesos: guardar una criatura generada/modificada por gameplay, reiniciar Godot, regenerar el chunk con la misma semilla y comprobar que el spawner real aplica el delta. El test de dos procesos actual sigue usando un payload controlado para aislar serialización/JSON/manager.
