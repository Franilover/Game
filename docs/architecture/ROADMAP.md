# Garlia — Hoja de ruta técnica activa

**Rama de trabajo:** `refactor/p1-player-locomotion`  
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
- [~] Unificar restauración de salud/maná, Eterium compartido, reaparición y máximos administrativos mediante `VitalState`; falta auditar todos los efectos secundarios y validar CI.
- [~] Añadir contratos de daño/restauración, absorción y agotamiento para fisiología compartida; falta auditar curación, regeneración y límites de todos los caminos.
- [ ] Detectar escrituras directas que omitan al dueño del estado.
- [ ] Impedir operaciones sobre entidades eliminadas o inválidas.

### 1.2 Guardado y restauración
- [x] Mantener snapshots separados: `PlayerState`, `WorldState` y `DiscoveryState`.
- [x] Mantener `GameStateService` como coordinador, sin duplicar una fachada.
- [~] Implementar escritura temporal, validación JSON, respaldo y recuperación del último save válido en `SaveFileRepository`; además se protege el respaldo cuando el destino bloquea la recuperación. Falta ejecución de CI.
- [ ] Validar la recuperación ante interrupción real del proceso y errores de filesystem.
- [~] Añadir contrato automatizado para sobrescribir, recuperar, eliminar y rechazar IDs/payloads inválidos; falta ejecución de CI.
- [ ] Validar versión y migraciones de saves antiguos.
- [ ] Rechazar estructuras corruptas o incompletas sin destruir el último save válido.
- [ ] Comprobar restauración de posición, zona/interior, salud, maná, stamina, inventario, IUM, misiones, Garumis y tiempo.
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
- [x] Distinguir solicitud aceptada, contacto y daño real mediante `CombatAttackResult`.
- [ ] Auditar todos los tipos de daño, defensas, resistencias e inmunidades.
- [ ] Verificar IUM y ataques especiales sin alterar las fórmulas canónicas.
- [ ] Probar ataques simultáneos, múltiples objetivos, colisiones y proyectiles fuera de escena.
- [ ] Verificar cooldown, cancelación, interrupciones y atribución de daño.
- [~] Cubrir fisiología compartida, absorción y muerte al agotar Eterium en `PlayerVitalStateContract`; falta ampliar a todos los caminos y validar CI.
- [ ] Mantener el balance separado de la infraestructura.

### 2.2 IA de criaturas
- [x] Separar la salud y el estado vital de las decisiones de IA.
- [x] Comunicar configuración y daño mediante señales.
- [ ] Separar percepción, selección de objetivo, decisión y ejecución.
- [ ] Auditar navegación, memoria, pérdida de objetivo y reacciones.
- [ ] Verificar IA fuera de rango y transiciones de simulación.
- [ ] Revisar perfiles y `ia_config` de las especies existentes.
- [ ] Comprobar sincronización de configuración desde los datos canónicos.
- [ ] Medir coste por frame y evitar trabajo repetido.

### 2.3 Interacciones y progresión
- [ ] Auditar el flujo completo de misiones: aceptar, progreso, completar, recompensa y persistencia.
- [ ] Verificar que las recompensas se apliquen una sola vez y no se pierdan al recargar.
- [ ] Revisar diálogos interrumpidos, ramas y condiciones.
- [ ] Auditar relaciones, regalos, memoria social y persistencia.
- [ ] Verificar interacciones con NPC, objetos, estaciones y zonas.
- [ ] Separar eventos de dominio de la presentación.

---

## Fase 3 — Mundo, inventario y datos de partida (P1/P2)

### 3.1 Mundo y generación
- [ ] Reducir responsabilidades de `WorldGenerator` mediante fronteras reales.
- [ ] Auditar `WorldTerrain`, `WorldStreamer`, `WorldEntityManager`, factory y reglas de spawn.
- [ ] Garantizar generación determinista para una misma semilla y versión.
- [ ] Evitar duplicados al cargar/descargar chunks.
- [ ] Verificar persistencia de cambios del mundo y de interiores.
- [ ] Comprobar límites, transiciones entre reinos y restauración de posición.
- [ ] Revisar entidades globales frente a entidades sujetas al streaming.
- [ ] Probar mundos largos y sesiones con muchas criaturas.

### 3.2 Inventario y objetos
- [x] Separar estado/controlador de la presentación del inventario.
- [x] Separar hotbar de equipamiento.
- [~] `InventoryRuntime` ya revierte recogidas parciales que no caben; se añadió contrato de cantidades, pendiente de ejecución en CI.
- [ ] Verificar soltar objetos: retirar del inventario solo tras crear y registrar el objeto del mundo.
- [ ] Auditar identidad por ID, apilamiento, límites y capacidad.
- [ ] Probar durabilidad, consumibles, transferencia entre manos y equipamiento.
- [ ] Verificar restauración completa del inventario y compatibilidad con saves antiguos.
- [ ] Unificar validaciones para recoger, soltar, intercambiar, usar y equipar.

### 3.3 Datos y modo sin conexión
- [~] Introducir `WorldSnapshotValidator` compartido por `WorldData` y `SupabaseClient`; contrato cubre jerarquía y snapshot incluido, pendiente de CI.
- [~] Rechazar snapshots con jerarquía obligatoria incompleta o tipos incorrectos; falta validar el flujo completo de fallback/cache en CI.
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
- [~] Añadir contrato de recuperación de `SaveFileRepository` al workflow.
- [ ] Añadir contratos de inventario, misiones, datos offline y restauración completa.
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
6. Continuar IA y división de `WorldGenerator`.
7. Perfilar y ampliar pruebas de integración.

**Límites:** esta hoja de ruta no autoriza cambios en Supabase ni cambios de canon de Garlia. Los cambios de código permanecen aislados en la rama indicada; no se hace merge a `main` sin autorización explícita.
