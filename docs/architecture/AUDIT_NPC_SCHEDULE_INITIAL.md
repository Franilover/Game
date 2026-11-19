# Auditoría inicial: NPCScheduleSystem

**Fecha:** 2026-11-19  
**Rama de trabajo:** `work/design-and-architecture`  
**Rama base protegida:** `feat/npc-relational-memory-decay`  
**Archivo:** `scripts/world/npc_schedule_system.gd`  
**Estado:** análisis estático; no se han extraído bloques en esta pasada.

## 1. Tamaño y responsabilidad

El script contiene 3.393 líneas y 79 funciones, con 14 variables de estado. No es únicamente un planificador horario: también administra navegación, detección de cambios de colisión, desplazamiento y animación de NPC, rutinas interiores, actividades sociales, recuerdos, eventos comunitarios y reuniones del castillo.

Main conserva el ciclo de actualización y llama a `actualizar(delta)`; el sistema recibe dependencias explícitas mediante `configurar(atmosfera, zone_manager, relationship_system)`. No implementa `_process` propio.

## 2. Áreas funcionales identificadas

| Rango aproximado | Responsabilidad | Riesgo |
|---|---|---|
| 101–340 | Configuración, actualización principal y actividades sociales inmediatas | Medio-alto: punto de entrada de varios subsistemas |
| 341–506 | Firma de colisiones, detección de cambios y construcción de AStarGrid2D | Medio: depende de geometría de la zona y reinicio de rutas |
| 507–1307 | Selección y aplicación de rutinas, reuniones, refugios y encuentros | Alto: reglas de agenda y estado de NPC |
| 1308–1613 | Rutinas interiores y animaciones de actividad/ocio | Medio-alto: nodos, metadatos y sprites de cada NPC |
| 1614–1909 | Separación física, paseos, panadería y entrada a edificios | Alto: colisiones, navegación y contratos de Torres |
| 1911–2157 | Variación del tiempo libre, agenda y opciones de ocio | Medio-alto: afecta selección de actividad |
| 2158–2757 | Necesidades, mente, objetivos sociales, recuerdos y relaciones | Alto: estado persistente y comportamiento social |
| 2758–3241 | Satisfacción, invitaciones, eventos comunitarios, castillo y turnos de comercio | Alto: mezcla de reglas temporales y consecuencias sociales |
| 3242–3393 | Selección de rutina, interpretación de horarios y pathfinding | Medio: helpers usados por varios bloques |

## 3. Dependencias y contratos

- Main llama a `actualizar(delta)` y configura el sistema con WorldAtmosphere, ZoneManager y RelationshipSystem.
- `_zona` y `_terreno_visual` representan el contexto de navegación y su terreno.
- La navegación usa una malla AStarGrid2D de 104 × 68 celdas, origen (-1664, -1088) y tamaño de celda de 32 px; una prueba existente protege esos límites y las entradas de Torres.
- El sistema localiza NPC y otros actores por grupos, usa metadatos para estados de rutina/sociales y reacciona al estado de interiores de ReinoTorres.
- Las rutinas interiores dependen de que el NPC esté reparentado bajo `Habitacion_<id>`; no es seguro separar esta lógica de interiores sin revisar el contrato de entrada/salida de Torres.
- Las actividades sociales actualizan RelationshipSystem y NPCMindService; los recuerdos y preferencias pueden persistir en GameState.
- Los turnos del mercado y las reuniones del castillo están vinculados a la agenda y a la identidad de NPC.

## 4. Problemas y oportunidades

### Responsabilidades mezcladas
El mismo nodo decide qué debe hacer un NPC, encuentra una ruta, cambia metadatos, anima sprites y registra consecuencias sociales. Eso hace difícil probar reglas sin instanciar el contexto de mundo.

### Funciones extensas
`_aplicar_rutina()` (desde la línea 507) y varios métodos de actividad social concentran muchas decisiones. No conviene reescribirlos de una vez: primero identificar subreglas puras y contratos observables.

### Datos duplicados
Las coordenadas de entradas aparecen en Torres y en `ENTRADAS_INTERIORES` / `POSICIONES`. Hay una prueba que compara puertas con el mapa. La duplicación está protegida parcialmente, pero a largo plazo debería existir una fuente de datos compartida o una validación automática, sin quitar la edición visual de la escena.

### Calidad estática
El linter identifica métodos con más de seis retornos y numerosas líneas largas en este archivo. Es una señal para revisar complejidad local, no una orden de reducir retornos a costa de anidar condiciones.

## 5. Orden recomendado

1. Mantener `actualizar(delta)` como fachada estable y no mover la cadencia desde Main.
2. Añadir pruebas de contrato para las reglas puras de horarios, preferencias de mobiliario y selección de rutina.
3. Separar primero utilidades puras con entrada/salida explícita, no funciones que manipulan nodos.
4. Evaluar después un componente de animación/actividad interior, manteniendo metadatos y nombres de nodos existentes.
5. Dejar para el final navegación, persistencia social, reuniones y eventos, porque tienen más dependencias.
6. No eliminar métodos o variables por ausencia de llamadas textuales: hay `call()`, metadatos, grupos y llamadas desde Main.

## 6. Cambio puntual ya aplicado durante la revisión

La prueba `tests/persistence/test_npc_mind_core.gd` detectó que `descansar` se clasificaba como mobiliario de silla/asiento. Se ajustó `obtener_preferencias_mueble_actividad()` para que `descansar` prefiera cama/litera y `sentarse` prefiera silla/asiento. La suite completa de Godot 4.7 pasó en CI después del cambio.

No se extrajeron más responsabilidades ni se modificó Supabase.


## 7. Primera extracción segura: reglas puras de horario

En la rama `work/design-and-architecture` se extrajeron dos funciones sin estado a `scripts/world/npc_schedule_rules.gd`:

- `hora_a_minutos(valor)`: interpreta `HH:MM` y devuelve `-1` si la hora no es válida.
- `coincide_dia(dias, dia)`: conserva la compatibilidad con arrays numéricos enteros, decimales y cadenas numéricas recibidas desde WorldData.

`NPCScheduleSystem` conserva la selección de rutina y sus diagnósticos; sólo delega estas dos operaciones puras. Así no se mueve todavía la lógica de prioridad, los cruces de medianoche ni el registro de errores.

Se añadió `tests/world/test_npc_schedule_rules.tscn` para cubrir horas límite, entradas inválidas, arrays vacíos, números JSON decimales y cadenas numéricas. El workflow de regresión incluye el test y se habilitó para esta rama de trabajo.

**Estado de validación:** cambios enviados a GitHub; falta el resultado de la ejecución de CI de esta rama. No se afirma que el test haya pasado hasta ver ese resultado.


## 8. Segunda extracción: selección pura de rutinas

Se movió el algoritmo de selección horaria a `NPCScheduleRules.seleccionar_rutina(rutinas, dia_semana, minutos)`.

La función devuelve dos datos: la rutina ganadora y una lista de motivos de rechazo. No consulta nodos, metadatos, calendario global ni servicios; tampoco modifica el catálogo recibido. La capa `NPCScheduleSystem` conserva la responsabilidad de emitir el diagnóstico en consola y de guardar la firma que evita repetirlo.

Contratos protegidos por pruebas:

- Una rutina inactiva o con hora inválida nunca gana.
- Gana la prioridad más alta.
- Si la prioridad empata, gana la rutina cuyo inicio es más tardío.
- Si también empatan los inicios, se conserva la primera de la lista.
- Los turnos que cruzan medianoche usan el día de inicio; la franja posterior a medianoche pertenece al día anterior.
- La rutina devuelta es una copia profunda y no permite alterar el catálogo original.

No se extrajeron todavía las reglas de ocio, invitaciones, eventos comunitarios, clima ni la resolución de destinos. Esas reglas consultan estado persistente o servicios y requieren contratos independientes antes de moverlas.

**Validación:** la primera extracción ya pasó la prueba dedicada y la suite completa anterior. Esta segunda extracción está pendiente de CI.


## 9. Tercera extracción: rutinas de día libre

La selección de actividades del día libre se movió a `NPCScheduleRules.seleccionar_rutina_dia_libre(nombre_npc, minutos)`. Se conserva el mapa de hogares y las excepciones por personaje; `NPCScheduleSystem` sólo obtiene el nombre visible y delega la decisión.

La prueba ahora cubre los diez habitantes con reglas específicas en la mañana y la tarde, además de los límites de encuentro (17:00), regreso al hogar (20:00) y normalización del nombre.

Esta extracción es de reglas locales de simulación. No altera horarios de Supabase ni el catálogo de rutinas de WorldData.

**Validación:** pendiente de CI para el commit que incorpora esta extracción y sus casos.
