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


## 10. Cuarta extracción: calendario comunitario

La resolución del evento comunitario se separó como `NPCScheduleRules.obtener_evento_comunitario(dia_estacion, dia_semana, minutos)`. El sistema de NPC conserva la lectura de `WorldAtmosphere`; la función pura decide qué evento corresponde a esos tres valores.

Se documentan y prueban las franjas de 09:00–17:00 (mercado), 17:00–20:00 (comida comunitaria) y 14:00–20:00 (celebración estacional en el primer día de estación). La celebración estacional conserva prioridad si coincide con el quinto día.

La prueba también cubre los límites de inicio y fin, así como días sin evento. No se cambia el calendario ni se agregan eventos nuevos.


## 11. Quinta extracción: tiempo hasta la siguiente rutina

Se separó `NPCScheduleRules.obtener_minutos_hasta_siguiente_rutina(rutinas, dia_semana, minutos)`. El cálculo recorre el ciclo de cinco días, ignora entradas inactivas o mal formadas y devuelve los minutos hasta el próximo inicio válido.

El sistema NPC conserva la llamada desde la selección de ocio; la función no necesita consultar al NPC, su estado ni servicios globales.

Pruebas añadidas: siguiente inicio el mismo día, día posterior, vuelta del ciclo, rutina sin días específicos, entradas inválidas/inactivas y lista vacía. Se conserva el comportamiento anterior de devolver cero si no encuentra un inicio dentro de la ventana recorrida.


## 12. Auditoría de referencias y limpieza de código inaccesible

Se revisaron las referencias internas y los puntos de integración de los métodos de `NPCScheduleSystem`. Se eliminaron:

- `_obtener_rutina_reunion_castillo()`: método privado sin llamadas ni referencias dinámicas.
- `_debe_asistir_grupo_reunion_castillo()`: sólo era invocado por el método anterior.
- `_fecha_asistencia_reunion_cache` y `_asistencia_reunion_cache`: estado usado exclusivamente por esa cadena inaccesible.

Se conservaron `_actualizar_movimiento_reunion_castillo()` y sus reglas de agrupación: tienen un punto de llamada activo cuando una rutina tiene la clave de reunión, por lo que no corresponde borrarlos sólo porque la asignación automática de reuniones esté desactivada.

También se conservó `_iniciar_idle_postura_npc()`. Aunque no tenía llamadas directas, una animación lo invoca mediante `Callable(self, "_iniciar_idle_postura_npc")`; el análisis estático inicial no detectó esa referencia indirecta. La función fue restaurada antes de validar el estado final.

Esta revisión deja una regla de auditoría explícita: antes de eliminar un método hay que revisar llamadas directas, `Callable`, `call/call_deferred`, señales, grupos y contratos externos; el conteo textual por sí solo no basta.


## 10. Cuarta extracción: necesidades y elegibilidad de eventos

Se movieron dos reglas independientes a `NPCScheduleRules`:

- `obtener_satisfaccion_actividad(actividad)`: mantiene las palabras clave y ponderaciones existentes para descanso, socialización, diversión, curiosidad, autonomía y seguridad.
- `puede_participar_en_evento(rutina)`: permite eventos cuando no hay rutina o cuando la rutina corresponde a un día libre; trabajo y guardia siguen excluidos.

La clase de simulación conserva sus métodos de delegación, por lo que los puntos de llamada y el contrato interno permanecen iguales. Se añadieron pruebas para cada ponderación y para los casos de elegibilidad.

No se cambiaron valores de necesidades ni criterios de diseño: sólo se aisló el algoritmo existente y se fijó mediante pruebas.

**Validación:** pendiente de CI para esta extracción.


## 11. Quinta extracción: respaldo horario del castillo

El horario provisional de Abel y Liam se movió a `NPCScheduleRules.seleccionar_rutina_respaldo_castillo(minutos)`. Se mantiene el mismo intervalo: salida a la plaza desde las 08:00 (incluido) hasta las 20:00 (excluido), y regreso al castillo fuera de ese intervalo.

La clase de simulación conserva el método de delegación. La prueba fija los cuatro límites: 07:59, 08:00, 19:59 y 20:00.

**Validación:** pendiente de CI para el commit de esta extracción.


## 12. Sexta extracción: desplazamiento determinista de ocio

El cálculo del pequeño desplazamiento local de ocio se movió a `NPCScheduleRules.obtener_desplazamiento_ocio(nombre, clave_dia, tramo)`. Se conserva exactamente la lista de cinco posiciones y la firma hash usada para distribuir a los habitantes en la plaza.

La prueba verifica que las mismas entradas producen el mismo desplazamiento y que el resultado pertenece a las posiciones locales permitidas. La capa de simulación sigue decidiendo cuándo aplicar el desplazamiento y sólo lo usa para actividades ubicadas en la plaza.

**Validación:** pendiente de CI para el commit de esta extracción.


## 13. Catálogo de ocio y corrección del ejecutor de pruebas

El catálogo estático de actividades por habitante se movió a `NPCScheduleRules.obtener_opciones_ocio_npc(nombre)`. Se conservaron sus identificadores, destinos, necesidades, afinidades y costes; el sistema de simulación sigue normalizando el nombre y resolviendo disponibilidad, navegación y elección con NPCMind.

Se añadieron comprobaciones para los diez habitantes, tres opciones por personaje, estructura de cada opción y respuesta vacía para identificadores desconocidos.

**Hallazgo importante del harness:** al revisar el test se detectó que varias funciones de comprobación estaban declaradas, pero `_ready()` no las invocaba. Por eso, las ejecuciones anteriores del test no cubrían realmente todas las reglas añadidas. Se corrigió el ejecutor para llamar explícitamente a cada bloque de regresión antes de cerrar el proceso. Las validaciones previas de CI sólo confirman los casos que el ejecutor sí ejecutaba; la suite ampliada debe considerarse pendiente hasta completar la nueva ejecución.

Esta corrección es parte del trabajo de calidad: no basta con que el archivo de pruebas compile, también debe ejecutar los casos que pretende proteger.


## 14. Séptima extracción: distribución determinista en eventos

Se movió la selección del punto local de reunión a `NPCScheduleRules.obtener_desplazamiento_evento(nombre_npc, clave_evento, fecha)`. La capa `NPCScheduleSystem` conserva la consulta a `WorldAtmosphere` y construye la firma de fecha con año, día y estación; el helper sólo calcula el índice y devuelve una de las 16 posiciones existentes.

Se conserva la normalización del nombre, el texto de la clave del evento, el formato de fecha y el uso de `posmod(hash(...), 16)`. No se alteran los puntos de reunión ni el calendario.

La prueba comprueba estabilidad para entradas iguales, variación posible al cambiar NPC/fecha y pertenencia al catálogo exacto de 16 posiciones. No se trasladan lecturas del mundo ni estado de NPC al helper.

## 15. Octava extracción: asignación de turnos comerciales

La decisión de asignar a un vendedor rotativo se trasladó a `NPCScheduleRules.debe_asignar_turno_comercio(nombre_npc, rutina_actual, dia_semana, minutos)`. La regla recibe datos simples y devuelve un booleano; no accede a nodos ni cambia rutinas.

`NPCScheduleSystem` conserva la validación de instancia y la construcción de la rutina de puesto. Se mantienen el catálogo de siete vendedores rotativos, Saira como coordinadora excluida, las franjas 09:00–14:00 y 14:00–18:00, la fórmula de rotación por día/franja y la prioridad de trabajo, eventos, invitaciones y encuentros.

Se añadieron casos para inicio y fin de horario, coordinadora, oficio existente, evento comunitario y NPC fuera del catálogo. La validación CI debe confirmar esta extracción junto con la corrección del orden de declaración en la prueba de desplazamientos de evento.

## 16. Novena extracción: evaluación pura de invitaciones

La evaluación de fecha, estado de aceptación y franja horaria se trasladó a `NPCScheduleRules.evaluar_invitacion_npc(invitacion, anio_actual, dia_actual, minutos)`. El helper devuelve si la invitación caducó o si está activa, junto con su ubicación normalizada. No modifica el diccionario recibido ni accede al reloj del mundo.

`NPCScheduleSystem` conserva la lectura de `GameState.world_state.flags`, la copia profunda de los datos, la persistencia del estado `caducada`, el guardado diferido, la validación de ubicaciones contra `POSICIONES` y el metadato `invitacion_npc_activa` del NPC.

Se preservan el orden de validación y los límites temporales existentes: sólo se evalúa entre 17:00 y 19:00, la hora final es exclusiva y una invitación sólo se activa en el día exacto y con estado `aceptada`. La caducidad conserva la comparación por año y día.

Las pruebas cubren activación, límites horarios, fecha futura, estado no aceptado, caducidad y ausencia de mutación del diccionario original. No se cambia el formato persistido de las invitaciones.


## 17. Unificación de requisitos del encuentro de Mara, Ivo y Nima

Se mantuvo el encuentro dentro de `NPCScheduleSystem`; no se creó un gestor ni un subsistema paralelo. La clase conserva la consulta de participantes vivos, el progreso narrativo desde `GameState`, las relaciones desde `RelationshipSystemService`, la disponibilidad horaria, las invitaciones aceptadas y la aplicación de la rutina en la plaza.

La comprobación compartida de requisitos se concentró en `NPCScheduleRules.cumple_requisitos_encuentro_trio()`. Recibe los datos ya consultados y valida, en un único lugar:

- Etapa mínima de `mara_ivo_apoyo` y `nima_ivo_investigacion`.
- Existencia de las tres relaciones entre Mara, Ivo y Nima.
- Al menos una interacción por pareja.
- Cercanía conjunta mínima de 0.5 (amistad + confianza + afecto + colaboración).
- Tensión inferior a 4.0 en cada vínculo.

La regla es pura: no consulta servicios, no modifica progreso ni relaciones y no decide el día de reunión. La planificación semanal y la prioridad de rutinas siguen en `NPCScheduleSystem`, que es donde ya se coordinan.

Se añadieron pruebas para historia incompleta, falta de interacciones, vínculo insuficiente, tensión alta, relaciones incompletas y ausencia de mutación. El objetivo de esta mejora es reducir duplicación y hacer verificables los requisitos existentes, no cambiar el diseño narrativo ni la frecuencia del encuentro.

Se revisó también su relación con `_actualizar_objetivo_social_npc()`: ese flujo sigue siendo distinto porque selecciona parejas dinámicamente según necesidades, personalidad y motivos concretos, y después persiste objetivos y experiencias. El encuentro del trío, en cambio, es una cita narrativa fija condicionada por dos progresos y tres vínculos. No se fusionan ambos flujos por compartir la palabra «encuentro»; sólo se compartirán reglas cuando exista una condición realmente idéntica. Las invitaciones al jugador conservan asimismo su contrato y persistencia propios.


## 18. Evaluación de invitaciones sin efectos secundarios durante la planificación

La comprobación de disponibilidad del encuentro de Mara, Ivo y Nima ya no llama a `_obtener_rutina_invitacion()`. Esa función no era una consulta: además de evaluar, podía marcar invitaciones caducadas en `GameState` y programar un guardado. Consultarla para los tres participantes podía persistir cambios como efecto colateral de decidir si el encuentro era posible.

Se unificó la lectura y evaluación en `_evaluar_invitacion_personaje()`, que devuelve el registro y su evaluación mediante la regla existente `NPCScheduleRules.evaluar_invitacion_npc()`. No escribe en `GameState`, no guarda y no modifica metadatos.

Los dos usos ahora comparten esa evaluación:
- El encuentro del trío sólo consulta si alguno tiene una invitación activa.
- La rutina normal de invitación aplica los efectos que le corresponden: persistir la caducidad o activar el metadato del NPC.

No se agregó un sistema nuevo ni se alteraron las prioridades de rutinas, la franja del encuentro o las reglas de caducidad. La separación evita que una comprobación de disponibilidad modifique el estado del mundo.


La evaluación del evento comunitario también se reutiliza ahora: el planificador calcula el evento una vez y pasa ese resultado al selector del encuentro privado. Se evita repetir la misma consulta de calendario en cada participante sin alterar la prioridad del evento ni sus condiciones.

## 19. Búsqueda única de participantes del encuentro

La disponibilidad del encuentro de Mara, Ivo y Nima necesitaba localizar a cada participante mediante `_buscar_npc_por_nombre()`. Como esa función recorre el grupo `torres_game_npc`, la comprobación podía recorrer el mismo grupo hasta tres veces por evaluación.

Ahora el encuentro reúne a los tres participantes durante un único recorrido y conserva el primer nodo `Creature` válido encontrado para cada nombre. Después valida que los tres sigan siendo instancias válidas y estén vivos. Esto mantiene el comportamiento anterior ante nombres duplicados —no sustituye al primer resultado por otro posterior— y reduce los recorridos del grupo de hasta tres a uno.

La misma reducción se aplicó a `_actualizar_interaccion_panaderia()`: Ivo y Elian también se resuelven en un único recorrido, conservando el primer resultado de cada nombre y deteniendo la búsqueda cuando ambos están localizados. Esta interacción se actualiza desde el ciclo del sistema, por lo que evitar un segundo recorrido es especialmente útil.

No se cambió la búsqueda general por nombre ni se creó un registro global de NPC: las optimizaciones quedan limitadas a los dos flujos que necesitan consultar varios personajes juntos.

## 20. Reutilización de la lista de NPC al elegir puestos interiores

`_actualizar_rutina_interior()` prueba varios puntos de descanso o actividad dentro de una habitación. Antes consultaba `get_nodes_in_group("torres_game_npc")` dentro del bucle de puntos, repitiendo la obtención de la misma lista aunque durante esa selección no se modifica el grupo.

Ahora obtiene una única instantánea del grupo antes de probar los puntos y reutiliza esa lista para comprobar ocupación. Se mantienen el orden de los candidatos, el filtro por tipo e instancia, la exclusión del NPC actual, la comparación de habitación y la distancia mínima de 38 px. No se guarda un registro persistente ni se reutiliza la lista entre ciclos: sólo dentro de esta decisión local.
