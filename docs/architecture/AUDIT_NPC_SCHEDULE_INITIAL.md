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

## 21. Reutilización de influencia de recuerdos al evaluar compañeros sociales

`_seleccionar_companero_social()` usa la influencia de recuerdos en dos decisiones: primero para comprobar si cada integrante aceptaría un encuentro casual y después para ponderar al candidato. Antes, cuando no existía un motivo concreto, la misma dirección podía recorrer y copiar las memorias dos veces.

Ahora cada influencia direccional se calcula una vez y se pasa a `_puede_iniciar_encuentro_social()`; el valor calculado también alimenta la puntuación final (pesos 0.7 para quien inicia y 0.45 para el candidato). Se conserva el orden de evaluación y el cortocircuito: si el iniciador no cumple el requisito, no se consulta la memoria del candidato; con un motivo concreto, la memoria se consulta sólo después de que ambos superan la validación, igual que antes para la puntuación.

No se cachean recuerdos entre candidatos ni entre ciclos. Cada decisión usa el estado actual del sistema de relaciones.

## 22. Reutilización diferida de motivos sociales

En la selección de compañeros, la dirección del NPC que inicia el encuentro ahora conserva los resultados de sus consultas de promesas, asuntos pendientes y noticias compartibles. Si una promesa ya constituye un motivo concreto, se mantiene el cortocircuito original y no se consultan todavía los otros dos indicadores. Si el candidato supera los requisitos bilaterales, se completan únicamente los indicadores que faltan y se reutilizan para la puntuación (+16 promesa, +12 asunto, +8 noticia). Si el candidato se descarta, no se realizan consultas que antes sólo ocurrían durante la puntuación.

La dirección inversa sigue usando la comprobación original de motivo concreto y su orden de prioridad. No se guardan resultados entre candidatos ni entre ciclos. El cambio evita repetir consultas de la dirección principal y mantiene la evaluación diferida de datos que sólo afectan a la puntuación.

## 23. Consulta booleana de conocimientos nuevos compartibles

La selección social sólo necesita saber si una persona tiene alguna noticia que pueda compartir y que la otra todavía no conozca. Antes, `_hay_noticia_compartible()` obtenía la lista completa de conocimientos compartibles y, por cada elemento, volvía a consultar los conocimientos del destinatario mediante `conoce_conocimiento_npc()`. Esa segunda consulta volvía a cargar y duplicar el conjunto de conversaciones.

Se añadió `RelationshipSystemService.tiene_conocimiento_compartible_nuevo_npc()`: obtiene una vez los conocimientos de origen y destino, crea un conjunto local de claves conocidas y recorre los conocimientos de origen hasta encontrar uno nuevo que supere `puede_compartir_conocimiento_npc()`. Conserva las reglas existentes de privacidad, permiso de transmisión y confianza; la función que devuelve la lista completa de conocimientos compartibles sigue disponible sin cambios.

El conjunto de claves vive sólo durante la consulta. No hay caché persistente ni cambios en los datos guardados.

## 24. Lecturas puntuales del estado social

Se detectó que consultar una relación entre dos NPC o los conocimientos de uno solo pasaba por `GameState.obtener_conversaciones_npc()`, que devuelve una copia profunda de todo el registro de conversaciones. Esto multiplicaba el coste en consultas sociales frecuentes y también en la nueva comprobación booleana de noticias.

Se añadieron lecturas puntuales en `GameStateService`: `obtener_relacion_npc_entre(clave)`, `obtener_conocimientos_npc(personaje_id)`, `obtener_asuntos_pendientes_npc()` y `obtener_promesas_npc()`. Cada una duplica únicamente el dato solicitado y no expone referencias modificables al estado interno. `RelationshipSystemService` las utiliza cuando están disponibles y conserva el camino anterior como compatibilidad para otros objetos de estado.

La consulta booleana de noticias reutiliza ahora una única relación y su confianza durante el recorrido, y sólo consulta la confianza cuando encuentra conocimiento privado con permiso explícito. El conocimiento público no necesita consultar la relación. Las funciones de lectura completa y guardado siguen intactas, por lo que el formato persistido no cambia.

La prueba de roundtrip de GameState ahora cubre las cuatro lecturas puntuales, el aislamiento de copias, la conservación de otras secciones del registro y la detección de noticias nuevas. También verifica que el conocimiento público ya conocido no vuelva a contar como novedad y que el conocimiento privado requiera permiso y confianza mínima de 30. La validación de CI queda pendiente.

## 25. Escrituras puntuales del estado social

Las operaciones de interacción, conocimiento, asuntos y promesas también reconstruían el diccionario completo `conversaciones_npc` para cambiar una sola sección. Se añadieron métodos de escritura acotados en `GameStateService`: `guardar_relacion_npc_entre()`, `guardar_conocimientos_npc()`, `guardar_asuntos_pendientes_npc()` y `guardar_promesas_npc()`. Cada método reemplaza sólo la sección correspondiente y conserva el resto del registro; las colecciones recibidas se duplican antes de almacenarse y se mantiene la notificación `_al_cambio_guardable()`.

`RelationshipSystemService` utiliza esas operaciones para registrar interacciones, actualizar conocimientos, crear/resolver asuntos y crear/resolver promesas. Las rutas antiguas de lectura y escritura completa permanecen como fallback de compatibilidad cuando el objeto de estado no expone los nuevos métodos. No se modifica el formato de guardado ni se introduce caché.

La prueba de roundtrip ahora también ejercita las escrituras puntuales desde `RelationshipSystemService`, comprobando actualización de confianza e interacciones, alta de conocimiento, asunto y promesa, además de las lecturas aisladas descritas en la sección anterior. La validación de CI queda pendiente.

## 26. Lectura y escritura puntual de recuerdos sociales

El historial `recuerdos_sociales` se consultaba y guardaba como un diccionario completo incluso cuando una operación afectaba a un solo habitante. Esto ocurría al registrar un recuerdo, consultar el recuerdo pendiente de diálogo, asignar un identificador estable a recuerdos antiguos y marcar un recuerdo como mencionado.

Se añadieron `GameStateService.obtener_recuerdos_sociales_npc()` y `guardar_recuerdos_sociales_npc()`. La lectura devuelve una copia profunda del array del NPC solicitado; la escritura duplica el registro exterior de forma superficial y reemplaza únicamente el array de ese NPC con una copia profunda. El resto de historiales conserva sus referencias y contenido; el formato de `world_state.flags["recuerdos_sociales"]` no cambia y se mantiene `_al_cambio_guardable()`.

`RelationshipSystemService` usa estas operaciones en registro, consulta y marcado de recuerdos. Si un GameState antiguo no expone los métodos puntuales, conserva un fallback mediante las operaciones completas anteriores. Se mantienen las reglas de consolidación de `tema_conversacion`, contador, primer momento, importancia máxima, prioridad del recuerdo pendiente, identificador estable, límite de 32 entradas y emisión de `recuerdo_registrado`.

La prueba de roundtrip comprueba aislamiento de copias, actualización de un tema recurrente sin duplicarlo, conservación de primer momento e importancia, actualización del último momento, selección y marcado del recuerdo pendiente y aislamiento del historial de otro NPC. La validación de CI queda pendiente.


## 27. Acceso puntual a relaciones jugador-NPC

La relación del jugador con cada habitante se almacena en `world_state.flags["relaciones_sociales"]`, separada de las relaciones entre NPC guardadas dentro de `conversaciones_npc`. La revisión detectó que `RelationshipSystemService` todavía copiaba el diccionario completo de relaciones jugador-NPC para consultar o modificar a una sola persona.

Se añadieron `GameStateService.obtener_relacion_social_jugador_npc()` y `guardar_relacion_social_jugador_npc()`. El servicio social ahora usa estas operaciones en la consulta inicial, modificación de valores, registro de eventos, registro de diálogos y variantes de diálogo. Los métodos completos permanecen como fallback para implementaciones antiguas de GameState.

La lectura devuelve una copia profunda de la relación solicitada. La escritura duplica el contenedor exterior y sólo la relación modificada, conservando los demás habitantes y el formato persistido. La prueba de roundtrip verifica aislamiento de la copia, modificación de la amistad y conservación de la relación de otro NPC. No se modifican valores sociales ni reglas de evolución.


## 28. Catálogo estático de hogares NPC

`NPCScheduleSystem.obtener_clave_hogar()` reconstruía un diccionario de diez residentes en cada consulta. El contenido no dependía del estado de la partida ni cambiaba durante la ejecución, por lo que se convirtió en la constante `HOGARES_NPC`. La función conserva normalización del nombre, ubicación de respaldo y validación contra `POSICIONES`.

Se amplió la prueba de reglas para cubrir los diez hogares, espacios en los nombres, NPC desconocidos, respaldo personalizado y respaldo inválido. No cambian destinos, identidades ni rutinas.



## 29. Posiciones estables de NPC en la plaza

La rutina de cada NPC reconstruía el diccionario de posiciones individuales de la plaza cada vez que recalculaba su destino. Como las diez posiciones son constantes de diseño, se movieron a `POSICIONES_PLAZA` junto a los demás catálogos estáticos.

Se conservan exactamente las diez coordenadas y el reparto determinista para NPC adicionales mediante hash y perímetro. La prueba de reglas protege las coordenadas originales. El cambio reduce asignaciones repetidas sin alterar destinos ni navegación.

## 30. Simplificación segura de `_aplicar_rutina()`

La función calculaba dos veces la misma condición nocturna (21:00 o antes de 06:00). Ahora conserva una sola variable local, reutilizada tanto para cancelar actividades sociales como para aplicar el regreso nocturno.

El ajuste especial de Elian copiaba profundamente todo el array de rutinas aunque sólo reemplazaba el diccionario correspondiente a `cerrar_panaderia`. Se usa una copia superficial del array y se mantiene la copia independiente del único diccionario que se modifica. Los demás elementos se consultan sin mutarlos.

También se reutiliza el nombre normalizado y el hogar de respaldo calculado al principio de la rutina. No se altera el orden de selección de rutina, invitación, evento, encuentro de grupo, comercio, descanso nocturno, lluvia ni navegación.

## 31. Catálogo estático de paseos exteriores

`_actualizar_paseo_ambiental_exterior()` reconstruía un diccionario con los desplazamientos preferidos de ocho NPC cada vez que actualizaba sus paseos. Esos puntos son constantes de diseño y no dependen del estado del mundo.

El catálogo se trasladó a `DESPLAZAMIENTOS_PASEO_EXTERIOR`, junto a los demás datos estáticos del planificador. Se conservaron los puntos, su orden y el algoritmo que elige el desplazamiento según NPC, fecha y tramo horario. El conjunto de siete posiciones de respaldo también quedó en `DESPLAZAMIENTOS_PASEO_EXTERIOR_DEFAULT`, evitando reconstruirlo para NPC fuera del catálogo.

La prueba de reglas compara los ocho recorridos y el conjunto de respaldo con sus coordenadas originales. El cambio elimina reconstrucciones repetidas de datos sin modificar la selección ni la navegación.


## 32. Catálogos estáticos de posiciones en reglas NPC

Las reglas puras también reconstruían dos listas de posiciones en cada llamada: los cinco desplazamientos de ocio y los dieciséis puntos de distribución de eventos comunitarios. Se trasladaron a las constantes `DESPLAZAMIENTOS_OCIO` y `POSICIONES_EVENTO` de `NPCScheduleRules`.

Se mantienen los mismos puntos y el mismo cálculo hash/modular que selecciona cada uno. Las pruebas ahora verifican tanto la estabilidad del resultado como la composición exacta de ambos catálogos. No se cambia el comportamiento de ocio ni la distribución de asistentes.


## 33. Limpieza única de metadatos de reuniones nocturnas

Al forzar el regreso al hogar, `_aplicar_rutina()` eliminaba seis metadatos de agrupación y fase del castillo. La limpieza general inmediatamente posterior ya elimina esas mismas claves para cualquier rutina que no sea `reunion_nocturna_castillo`; por tanto, el bloque nocturno repetía exactamente el mismo trabajo.

Se eliminó la primera eliminación redundante. La limpieza común sigue ejecutándose después de resolver la clave de rutina, por lo que se conservan las mismas condiciones y el mismo momento de eliminación.


## 34. Regresión del traslado de NPC al salir de un edificio

Se amplió `test_npc_building_entry_collision.gd` para cubrir `ReinoTorres.sacar_npc_del_interior()`. La prueba coloca al NPC en una habitación, simula un cambio de destino y comprueba que vuelve al contenedor exterior, aparece en el umbral correcto, permanece oculto/no interactuable y conserva desactivadas las colisiones exteriores hasta que el planificador reanude su ruta.

La prueba complementa la cobertura previa de captura/restauración de capas y máscaras de colisión. No cambia el comportamiento de producción.


## 35. Una sola lectura del grupo al enriquecer habitantes locales

`Main._materializar_habitantes_sin_oficio()` recorría el grupo `torres_game_npc` una vez para elegir una plantilla y volvía a recorrerlo para construir índices por clave local y nombre. Ambos pasos usaban la misma colección y el mismo orden.

Se combinó en un único recorrido que conserva la primera criatura válida como plantilla, el primer NPC por nombre y las entradas por clave local. No cambian los criterios de identidad ni la prioridad entre habitantes canónicos y locales.


## 36. Catálogo estático de habitantes locales

`Main._materializar_habitantes_sin_oficio()` contenía dentro de su ejecución la definición completa de Mara, Ivo y Nima: identidad local, personalidad, historia, hogar y rutinas. Como esos datos no dependen del estado de la partida, se trasladaron a `HABITANTES_LOCALES` como catálogo constante de `Main`.

La función conserva el mismo recorrido y las mismas reglas de reconciliación con NPC canónicos: reutiliza instancias existentes por clave o nombre, evita duplicar identidades registradas globalmente y sólo instancia habitantes que faltan. Los perfiles, horarios, hogares, textos y sprites permanecen iguales.


La prueba también hizo que Godot compilara directamente `Main` y reveló que el script utilizaba `NPC_SCHEDULE_SYSTEM_SCRIPT` sin declarar su `preload`. Se restauró explícitamente la dependencia a `npc_schedule_system.gd`; ahora el test de catálogo valida el script real y no sólo los datos copiados.

Se añadió `test_local_npc_catalog.tscn` para proteger que existan exactamente Mara, Ivo y Nima y que cada entrada conserve hogar, rutinas, personalidad e historia. El test se ejecuta en la suite de regresión de Godot.


## 37. Captura única del grupo durante la reconciliación de Torres

`_materializar_npcs_reino_torres()` consultaba el grupo `torres_game_npc` por separado para deduplicar, retirar personajes canónicos ausentes y construir el índice de instancias existentes. Ahora captura el grupo una sola vez y entrega ese mismo conjunto a las dos operaciones de limpieza y al indexado final.

El orden de las decisiones se conserva: primero se deduplican identidades; después se retiran personajes canónicos ausentes si el snapshot contiene explícitamente el catálogo; finalmente se indexan sólo instancias que siguen perteneciendo al grupo. Esto último es importante porque `queue_free()` difiere la destrucción física, mientras que retirar del grupo ocurre inmediatamente.

No se combinó la lógica de deduplicación y retirada en una sola regla: tienen criterios distintos y deben conservar su prioridad. La optimización reduce consultas al SceneTree sin cambiar esas reglas.


## 38. Catálogo de posiciones interiores y pertenencia al grupo

`ReinoTorres._ubicar_npcs_del_edificio_en_interior()` reconstruía dos arreglos fijos de coordenadas en cada sincronización: 22 posiciones para el castillo y cuatro posiciones para interiores normales. Se trasladaron a constantes del script, conservando el orden y las coordenadas. El test de transición de edificios ahora protege el tamaño del catálogo del castillo y las cuatro posiciones normales.

En `teletransportar_jugador_a_npc()`, la comprobación de pertenencia al grupo ahora usa `npc.is_in_group("torres_game_npc")` en vez de obtener el arreglo completo sólo para ejecutar `.has(npc)`. La condición comprueba exactamente la misma pertenencia, evitando crear una colección temporal.


## 39. Transición única de NPC desde el interior al exterior

`sacar_npc_del_interior()` y `_devolver_npcs_del_interior_al_exterior()` repetían la misma secuencia: obtener la puerta anterior, reparentar al contenedor exterior, desactivar las colisiones exteriores, ubicar al NPC en el umbral, ocultarlo y quitar su grupo de interacción.

Se consolidó esa secuencia en `_devolver_npc_al_exterior()`. La salida individual conserva su validación de pertenencia a la capa interior; la salida general conserva su recorrido del grupo y delega cada NPC elegible al mismo método. La validación de nodos de contenedor/capa evita operar sobre referencias liberadas.

Se amplió `test_npc_building_entry_collision.tscn` para cubrir ambas rutas: cambio individual de rutina y salida general del edificio. En las dos se comprueban contenedor, umbral, visibilidad, grupo `interactable` y colisiones exteriores desactivadas.

La devolución general recibe ahora el snapshot de NPCs desde `_salir_del_interior()`, en lugar de consultar el SceneTree internamente. Esto hace explícita la dependencia y permite probar la ruta con un conjunto controlado. La primera ejecución del nuevo test reveló que el fixture mantenía `ReinoTorres` fuera del SceneTree; se ajustó el contrato para inyectar el snapshot, evitando forzar el `_ready()` pesado de la escena real sólo para probar esta operación.


## 40. Restauración exacta de interacción de NPC

La entrada a un interior retiraba temporalmente a los NPC del grupo `interactable`. Al salir, `_restaurar_npcs_exteriores()` volvía a añadir ese grupo a cualquier `Creature` visible. Eso cambiaba el estado original de NPC que estaban visibles pero no debían recibir interacción.

Ahora `_guardar_estado_visibilidad_npc()` conserva por instancia tanto la visibilidad como la pertenencia original a `interactable`. Se usa al ocultar el exterior y al registrar NPC materializados mientras el jugador permanece dentro. La restauración devuelve ambos valores, manteniendo la protección adicional de que un NPC que sigue dentro de un edificio permanece oculto y no interactuable.

El test de ciclo de interiores cubre NPC originalmente interactuables, NPC visibles sin interacción y NPC materializados durante la estancia. También comprueba que el nuevo registro no les conceda interacción por defecto.

La captura de NPC también se pasa explícitamente a los métodos de ocultación y restauración. Al salir, `_salir_del_interior()` obtiene un único snapshot y lo reutiliza para devolver NPCs de habitaciones y restaurar su estado exterior, evitando nuevas consultas al grupo en mitad de la transición.



## 41. Snapshot idempotente al registrar NPC materializados

`registrar_npc_materializado()` registra el estado visible/interactuable antes de ocultar un NPC creado mientras el jugador permanece dentro. La captura ahora es idempotente por `instance_id`: si el mismo NPC vuelve a registrarse durante esa estancia, conserva el primer estado y no sustituye los valores originales por el estado temporal oculto/no interactuable.

La prueba de transición repite el registro del mismo NPC y comprueba que al salir se restaure su visibilidad e interacción originales. La cobertura de NPC originalmente no interactuables se mantiene por separado. No se añade caché persistente ni se cambia el ciclo de materialización.



## 42. Cambio de edificio durante una estancia interior

Se añadió una regresión para el caso en que un NPC abandona su edificio de rutina mientras el jugador permanece dentro de otro. El NPC vuelve al contenedor exterior, mantiene temporalmente desactivadas sus colisiones y permanece oculto/no interactuable. Al salir el jugador, recupera la visibilidad, pertenencia a `interactable` y capas/máscaras originales capturadas al entrar.

La prueba verifica explícitamente que el cambio de rutina no reactive al NPC antes de la salida del jugador. No se modifica la prioridad de horarios ni el mecanismo de navegación.



## 43. Transición única al detener paseos interiores

`_aplicar_rutina()` y `_actualizar_rutina_interior()` repetían la detención de `CreatureMovement`, la eliminación de `rutina_paseo_interior_activo` y la actualización de `rutina_en_transito`. Se consolidó esa operación en `_detener_paseo_interior()`.

La transición admite limpiar opcionalmente `rutina_paseo_interior_siguiente`. Al cambiar de edificio se elimina porque el siguiente paseo pertenece al interior anterior; al cerrar temporalmente el interior se conserva para que el NPC retome el horario pendiente cuando corresponda. La prueba de seguridad de movimiento cubre ambas variantes y verifica que la ruta quede detenida. El workflow de regresión ejecuta ahora `test_creature_movement_npc_safety.tscn`, de modo que esta cobertura no queda limitada a la importación/compilación de scripts.

No cambia la selección de muebles, destinos, pausas ni la frecuencia de los paseos.


## 44. Escena ejecutable para la regresión de movimiento NPC

La primera ejecución del paso nuevo de CI para `test_creature_movement_npc_safety.gd` falló antes de iniciar la prueba: el workflow apuntaba a `res://tests/creatures/test_creature_movement_npc_safety.tscn`, pero sólo existía el script GDScript. Se añadió la escena mínima que instancia ese script, siguiendo el patrón de las pruebas de contrato de IA ya existentes.

El log de GitHub Actions confirmó que la importación de recursos y las pruebas anteriores terminaban correctamente; el error fue exclusivamente `Cannot open file` para la escena ausente. La prueba ya tiene una escena de entrada verificable y el siguiente run de CI debe confirmar su ejecución real. No se considera validada hasta que ese run termine correctamente.


## 45. Reutilización del estado nocturno durante la resolución de rutina

`_aplicar_rutina()` ya determina al principio si el horario está dentro del tramo nocturno. La condición que fuerza el regreso al hogar cuando no existe una actividad programada volvía a calcular exactamente el mismo límite horario. Ahora reutiliza `horario_nocturno`, conservando la condición adicional de ausencia de rutina.

Es una simplificación local: no cambia los límites (21:00 inclusive y antes de 06:00), ni la prioridad de turnos esenciales, ni el destino elegido. Se mantiene la misma fuente de verdad durante toda la resolución.


## 46. Fuente única para el tramo horario nocturno

La misma regla (21:00 inclusive hasta antes de 06:00, cruzando medianoche) se calculaba en tres puntos de la simulación: ciclo de actualización NPC, resolución de rutina y postura de descanso dentro del edificio. Se centralizó en `NPCScheduleRules.es_horario_nocturno(minutos)` y los tres consumidores reutilizan esa función.

La prueba unitaria de reglas ahora cubre límites y valores adyacentes: -1, 00:00, 05:59, 06:00, 20:59, 21:00, 23:59 y 24:00. Esto fija el contrato temporal en un único lugar y evita que el planificador y las animaciones diverjan con el tiempo.


## 47. Reutilización de la instantánea de NPC durante un tick

`actualizar()` ya recorría todos los NPC de Torres para resolver sus rutinas. Durante ese mismo recorrido, el paseo interior volvía a consultar el grupo `torres_game_npc` por cada NPC que necesitaba elegir un puesto libre. Ahora el ciclo obtiene una instantánea una sola vez y la comparte con la búsqueda de ocupación interior mientras el tick está activo; fuera de ese ciclo, el método conserva la consulta directa como respaldo.

La lista se limpia al terminar el recorrido para no retener referencias entre ticks. Se mantiene la misma validación de instancias, sala y distancia de ocupación; sólo se evita repetir la consulta al SceneTree y se usa una vista coherente del grupo durante el tick.


## 48. Compartir las consultas de NPC y jugador en el ciclo de simulación

La revisión del mismo ciclo encontró más consultas repetidas al grupo `torres_game_npc` en la selección de encuentros, objetivos sociales, separación y paseos ambientales. Se consolidó el acceso mediante `_obtener_npcs_torres()`: durante `actualizar()` devuelve la instantánea ya tomada para el tick; fuera del ciclo obtiene una lista actual del SceneTree. Así se evita repetir la consulta por cada NPC y se conserva el comportamiento de llamadas independientes.

También se obtiene una sola vez el nodo del jugador al comenzar el tick y se reutiliza en la comprobación de proximidad del paseo ambiental. Ambas referencias se liberan al terminar el recorrido. El snapshot se comparte como contexto temporal, no se convierte en un catálogo persistente ni en una segunda fuente de verdad.


## 49. Instantánea temporal compartida durante la simulación NPC

El ciclo de Torres obtiene el calendario del mundo una vez para decidir el día y el minuto. Varias rutinas sociales, eventos, ocio y resúmenes diarios volvían a solicitar el mismo diccionario de tiempo durante el recorrido de NPC. Se añadió `_obtener_tiempo_actual()`: durante el tick devuelve la instantánea compartida y fuera de él conserva la consulta a `WorldAtmosphere` como respaldo. La instantánea se libera junto con el resto del contexto temporal al terminar el tick.

La fecha de la reunión del castillo también se calcula una vez por actualización del grupo y se reutiliza para todos sus integrantes, en vez de consultar dos veces el calendario por cada integrante. No se cambia el reloj del mundo ni se guarda una copia persistente.


## 50. Separación de la memoria diaria de reuniones

`_aplicar_rutina()` acumulaba la selección del horario y la escritura de la memoria diaria que usan los diálogos nocturnos. La actualización de esa memoria se movió a `_actualizar_resumen_diario_reunion()`, con entradas explícitas para fecha, rutina, actividad y ubicación. El planificador conserva el orden de la llamada después de resolver el destino de la rutina.

La extracción mantiene las reglas existentes: reiniciar al cambiar la fecha, conservar la última actividad significativa, ignorar descanso/regreso y usar el estado previo cuando el NPC ya está en la reunión. No introduce almacenamiento nuevo ni modifica el formato de metadatos.


## 51. Contrato de contexto y memoria NPC automatizado

Se añadió `tests/world/test_npc_schedule_context.tscn` para proteger tres comportamientos conectados: uso de la instantánea de NPC durante el tick y consulta del grupo fuera de él; reutilización del calendario compartido y respaldo vacío cuando no hay WorldAtmosphere; y memoria diaria de la reunión (guardar actividad significativa, no reemplazarla por descanso y recuperar el estado actual al cambiar de fecha durante la reunión).

La escena se incorpora al workflow de regresión headless. Esta prueba cubre el contrato del contexto y la memoria extraída; no pretende sustituir una prueba de recorrido completo de la vida diaria, que seguirá siendo una etapa de cobertura distinta.


## 52. Separación NPC: descarte por distancia al cuadrado

`CreatureMovement._direccion_evitar_superposicion_npcs()` recorría los NPC del grupo y calculaba `Vector2.length()` para cada candidato, incluso si estaba muy lejos. Ahora compara primero `length_squared()` con el radio de separación al cuadrado y calcula la raíz sólo para vecinos dentro del radio. La dirección normalizada y el ID del NPC actual también se calculan una vez por consulta y se reutilizan en la decisión lateral.

Se conservan los contratos: mismo grupo y padre, sólo criaturas vivas, exclusión de NPC con el mismo edificio objetivo, radio de separación de 34 px, cesión de paso a 27 px y prioridad lateral estable por ID. La prueba `test_creature_movement_npc_safety` ahora comprueba además que un NPC lejano no altere el rumbo y que a 34 px exactos no se active la separación.

La mejora reduce raíces cuadradas y normalizaciones innecesarias en la comprobación de cada pareja; no cambia el algoritmo de vecinos ni elimina la búsqueda de grupo. Validación: Godot 4.7 46/46 pasos correctos y GDScript Quality success; ver sección 53.


## 53. Corrección final de solapamientos: filtro por distancia al cuadrado

`_separar_npcs_superpuestos()` también recorría las parejas de NPC y calculaba una distancia completa antes de saber si había solapamiento. Ahora compara primero `length_squared()` con el cuadrado de la distancia mínima (28 px) y calcula la raíz sólo para parejas que necesitan corrección. La referencia al padre y el umbral se calculan una vez por NPC/llamada, respectivamente.

Se conserva la separación simétrica, el desplazamiento determinista para posiciones idénticas, los filtros de visibilidad/actividad y el límite de 28 px. La prueba de seguridad de movimiento ahora ejecuta la corrección con dos NPC superpuestos y verifica que recuperan la distancia mínima.

**Validación de la optimización anterior:** Godot 4.7 46/46 pasos correctos, 0 fallos en [run #44623203556](https://github.com/Franilover/Game/actions/runs/44623203556); GDScript Quality success en [run #44623203373](https://github.com/Franilover/Game/actions/runs/44623203373). Validación completa: Godot 4.7 **46/46 pasos correctos, 0 fallos** en [run #44623523513](https://github.com/Franilover/Game/actions/runs/44623523513); GDScript Quality **success** en [run #44623523563](https://github.com/Franilover/Game/actions/runs/44623523563).


## 54. Extracción de selección de rutina y prioridades sociales

Se extrajo el bloque inicial de `_aplicar_rutina()` a `_resolver_rutina_base_y_eventos()`. El helper reúne la copia local del calendario especial de Elian, selección de rutina/día libre, variación de tiempo libre, invitaciones, eventos comunitarios y encuentro del trío. Devuelve un contexto acotado con `rutinas`, `rutina` y `evento_comunitario`; `_aplicar_rutina()` conserva la aplicación de turnos comerciales, prioridad nocturna, normalización de hogar/clima y ejecución del desplazamiento.

La extracción no cambia las prioridades ni persiste datos. El calendario de Elian se copia superficialmente como antes y sólo se duplica profundamente el diccionario de cierre modificado. Se añadió una regresión en `test_npc_schedule_context` que comprueba que la rutina de cierre se extiende hasta las 17:00 sin alterar el array original y que no se inventan eventos si no hay calendario mundial disponible.

Validación: Godot 4.7 **46/46 pasos correctos, 0 fallos** en [run #44624623124](https://github.com/Franilover/Game/actions/runs/44624623124); GDScript Quality **success** en [run #44624623318](https://github.com/Franilover/Game/actions/runs/44624623318).


## 55. Extracción de navegación de Torres

La malla AStar, la detección de cambios de colisión, la preferencia de terreno, la conversión de posición a celda y la búsqueda de celdas transitables se trasladaron a `NPCNavigationSystem`, declarado como nodo editable bajo `Main/Systems`. El servicio conserva el tamaño y origen del mapa, el radio de colisión, el coste de terreno y los límites de llegada que ya utilizaba la agenda.

`NPCScheduleSystem` conserva la selección y aplicación de rutinas, actividades sociales, interiores y el estado de movimiento de cada NPC. Recibe el servicio por inyección, solicita su sincronización al actualizar Torres y delega el cálculo de rutas. La señal `malla_reconstruida` permite que la agenda reinicie sólo las rutas de rutina que quedaron obsoletas; no mueve esa decisión de dominio al servicio de geometría.

Las pruebas de límites ahora consultan las dimensiones del servicio de navegación y la prueba de seguridad de movimiento ejercita la búsqueda de celda transitable a través de su API estática. Se añadió `test_npc_navigation_system.tscn` para comprobar en integración la construcción real de la malla, el cálculo de una ruta y la invalidación del servicio. La escena de límites de Torres también quedó conectada al workflow. Se conserva el catálogo de puertas en `NPCScheduleSystem`. No se modifican escenas de edificios, datos guardados ni Supabase.

Validación: Godot 4.7 **48/48 pasos completados, 0 fallos** en [run #44626438272](https://github.com/Franilover/Game/actions/runs/44626438272); GDScript Quality **success** en [run #44626236415](https://github.com/Franilover/Game/actions/runs/44626236415).


## 56. Transición de salida al cambiar de edificio

El bloque de salida de `_aplicar_rutina()` se extrajo a `_salir_de_edificio_para_cambiar_rutina()`. La operación cancela las animaciones y paseos interiores activos, devuelve la misma instancia al contenedor exterior, restaura las colisiones cuando el jugador ya no está dentro y limpia los metadatos del edificio anterior. La agenda conserva la decisión de cuándo ejecutar la transición y qué destino tendrá el NPC.

La posición de salida ahora tiene una sola fuente: `ReinoTorres.sacar_npc_del_interior()` y su catálogo de puertas. Se eliminó el segundo cálculo desde `NPCScheduleSystem.ENTRADAS_INTERIORES`, que podía sobrescribir la posición correcta con coordenadas divergentes. Si el jugador continúa dentro, el NPC permanece oculto y sin interacción hasta la restauración exterior.

La regresión `test_npc_building_entry_collision` ahora ejercita directamente la transición extraída y verifica reparentado, umbral, metadatos, visibilidad, interacción y colisiones. La primera ejecución detectó la discrepancia de coordenadas; se corrigió usando la posición autoritativa de `ReinoTorres` antes de validar.

Validación final: Godot 4.7 **48/48 pasos completados, 0 fallos** en [run #44628441771](https://github.com/Franilover/Game/actions/runs/44628441771); GDScript Quality **success** en [run #44628441413](https://github.com/Franilover/Game/actions/runs/44628441413).


## 57. Resolución del destino de rutina

El cálculo de coordenadas locales se extrajo a `_resolver_destino_rutina_local()`. La función recibe el NPC, la rutina, la ubicación, el indicador de horario y el edificio; la variación individual llega ya tipada desde la rutina. No modifica metadatos, no solicita rutas y no mueve al NPC: sólo devuelve el punto local que debe usar el desplazamiento.

Se mantienen las prioridades originales: posición personal del hogar cuando no hay actividad programada; umbral a 28 px de la puerta para destinos de edificio; posición absoluta de plaza cuando está definida; posición estable por habitante y variación individual; y distribución radial de 118 px para NPC sin entrada propia en el catálogo.

`test_npc_schedule_context` cubre esos cinco contratos directamente. La extracción no cambia los puntos de llegada ni la firma de rutina.

Validación: Godot 4.7 **48/48 pasos completados, 0 fallos** en [run #44628969650](https://github.com/Franilover/Game/actions/runs/44628969650); GDScript Quality **success** en [run #44628969766](https://github.com/Franilover/Game/actions/runs/44628969766).


## 58. Búsqueda compartida de mobiliario interior

Las rutinas interiores y las animaciones de postura recorrían por separado los hijos de la habitación para localizar camas, literas, sillas y asientos. Se unificó el filtro por nombre en `_obtener_muebles_por_tokens()`, que devuelve los sprites coincidentes en el orden original de los hijos.

La rutina conserva la selección de todos los muebles compatibles para buscar un puesto libre y sigue descartando los que no tienen textura. La animación de postura conserva la prioridad del primer mueble coincidente. No se cambian nombres de nodos, posiciones, preferencias de actividad ni recursos visuales.

`test_npc_schedule_context` comprueba coincidencias de cama/litera, silla/asiento, orden de escena y búsqueda vacía. Validación final: Godot 4.7 **48/48 pasos completados, 0 fallos** en [run #44629354647](https://github.com/Franilover/Game/actions/runs/44629354647); GDScript Quality **success** en [run #44629354490](https://github.com/Franilover/Game/actions/runs/44629354490).


## 59. Interrupción de paseos interiores por cinemáticas

El ciclo de actividad interior ahora distingue dos interrupciones con contratos diferentes. Una conversación ambiental conserva la ruta de locomoción para que el sistema de conversación pueda pausarla y reanudarla. Una cinemática, en cambio, cancela el paseo interior activo mediante `_detener_paseo_interior()`, libera `rutina_en_transito` y conserva `rutina_paseo_interior_siguiente`.

La animación de actividad interior también se detiene antes de ceder el control. La prueba de contexto de agenda configura una ruta real de `CreatureMovement`, activa una cinemática y comprueba que no quede locomoción activa ni se pierda el próximo horario.

Validación CI pendiente para este cambio.


### Complemento de la sección 59: reanudación del paseo

La regresión ahora comprueba también el ciclo de vuelta: después de retirar la marca de cinemática, el planificador recibe el mismo minuto programado y debe reconstruir la ruta interior mediante `CreatureMovement`, restaurando `rutina_paseo_interior_activo` y `rutina_en_transito` sin modificar `rutina_paseo_interior_siguiente`. La prueba usa una habitación de prueba con el identificador real esperado por el planificador y un NPC con su componente de movimiento real.

Validación CI de esta ampliación pendiente.
