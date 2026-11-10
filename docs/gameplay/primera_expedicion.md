# Primera expedición jugable desde Torres

Estado: plan técnico aprobado para desarrollo; no modifica canon de Garlia ni Supabase.

## Objetivo

Construir una primera ruta de aventura completa, repetible y guardable que conecte Torres con una zona nueva de bosque, use los sistemas de gameplay existentes y termine con un encuentro principal y regreso a Torres.

Duración objetivo de la primera versión: 15–20 minutos. La ruta debe enseñar sus mecánicas jugando, sin convertirla en un tutorial largo.

## Auditoría de `main`

Rama auditada: `main`  
HEAD auditado: `a231714daf13a5d59b5d260be396bbdb0bcc44fd`  
Fecha del último commit observado: 2026-11-10.

### Sistemas reutilizables confirmados

- **Zonas:** `ZoneManager` cambia entre Torres y Mundo Abierto. Torres es una escena fija; Mundo Abierto usa `WorldGenerator`. El cambio de zona emite `zona_cambiada` y Main vuelve a enlazar jugador, HUD y sistemas.
- **Terreno:** `WorldTerrain` y `WorldTerrainAreas` generan biomas y ecosistemas a partir de una semilla. El catálogo incluido contiene nueve biomas, incluido Bosque.
- **Entidades:** `WorldEntitySpawner`, `WorldSpawnRules`, `WorldEntityFactory` y `WorldEntityManager` ya resuelven candidatos ecológicos, aparición, creación, pooling y ciclo de vida.
- **Criaturas:** `Creature` y `CreatureAI` tienen movimiento, percepción, estados, combate y rutinas. El factory conecta IA con jugador, inventario, combate, diálogo, misiones y atmósfera.
- **Interacción y diálogo:** `InteractionSystem` prioriza interacciones contextuales sobre el uso de objetos; `DialogueSystem` soporta líneas, acciones y registro de conversación.
- **Combate:** el sistema está separado en controlador, resolución de ataques, daño, defensa, proyectiles, eventos y efectos. Existen contratos de regresión para armas, entidades, proyectiles y temporalidad.
- **Misiones:** `MissionManager` acepta objetivos por conversación, recolección, derrotar criaturas y otros eventos; expone progreso y serializa estado/progreso.
- **Guardado:** `GameState` captura inventario, estado de misiones, tiempo, semilla y estado del jugador. Hay restauración y pruebas de persistencia.
- **Garumis:** existen vínculo, presencia en el mundo, IA, combate y progresión con pruebas específicas.
- **Clima y luz:** existen ciclo de iluminación, perfiles de clima, transiciones y ciclo de vida de fenómenos. Por ahora son principalmente estado y datos; no se deben presentar como lluvia visual, rayos o efectos de gameplay ya implementados.

### Límites y riesgos que condicionan la ruta

1. **El bosque no está garantizado en una partida nueva.** La selección de bioma depende de ruido y semilla. Una expedición crítica no puede depender de que el jugador encuentre bosque por azar.
2. **ZoneManager no tiene todavía un destino local de expedición.** Actualmente conoce Torres y Mundo Abierto; los demás reinos dependen del catálogo de reinos configurado.
3. **El snapshot incluido no contiene una colección de misiones.** Su estructura superior contiene biomas, versión, fecha y ecosistemas sin bioma. Antes de depender de una misión de catálogo hay que verificar cómo se alimenta `obtener_misiones_game()` en una instalación nueva sin conexión.
4. **La misión se puede guardar, pero la ruta completa aún no tiene un contrato propio de progreso.** Conviene que los hitos de expedición tengan IDs estables y se guarden en el estado de partida, no en variables de una escena que desaparece al cambiar de zona.
5. **La escena de Mundo Abierto está preparada para generación procedural y streaming.** No conviene duplicar su lógica ni crear otro spawner paralelo para la expedición.
6. **El jugador y los sistemas globales viven en Main.** La nueva zona debe integrarse con ese ciclo de vida y no instanciar una segunda copia de HUD, inventario o jugador.
7. **No se ha realizado una prueba visual/manual del juego en este trabajo.** La auditoría es de código, escenas, datos versionados y CI.

### Estado de calidad observado

El workflow de regresión de Godot 4.7 para HEAD `a231714` terminó correctamente. Pasaron importación/compilación y las pruebas de clima, terreno, IA, entidades, inventario, misiones, guardado, locomoción y combate. Esto acredita esos contratos automatizados; no demuestra que la ruta de expedición exista ni que el juego completo se haya probado visualmente.

## Diseño de la primera ruta

### Recorrido propuesto

1. **Torres — preparación:** un NPC ofrece investigar alteraciones en el bosque. El jugador revisa equipo, selecciona hasta tres Garumis vinculados y recibe el objetivo.
2. **Salida — transición:** se activa una zona de expedición propia y determinista. El regreso a Torres queda disponible desde un punto reconocible.
3. **Borde del bosque — aprendizaje:** camino seguro, señalización ambiental y primera recolección de un recurso útil.
4. **Bosque interior — exploración:** bifurcación corta, un secreto opcional y un punto de interés que enseña a leer el entorno.
5. **Encuentro menor — combate:** criaturas con perfiles distintos; espacio para usar ataque normal, arma/proyectil y Garumi sin introducir enemigos en exceso.
6. **Claro — decisión ligera:** ayudar, investigar o recoger algo antes de avanzar. La elección puede cambiar diálogo/recompensa secundaria, no bloquear el final.
7. **Ruinas — desafío:** una interacción ambiental sencilla y una última preparación antes del jefe.
8. **Encuentro principal — jefe:** patrón legible con anticipación, ventanas de ataque y una segunda fase sólo si el combate base demuestra ser estable.
9. **Regreso a Torres — cierre:** diálogo de resolución, recompensa, registro de descubrimiento y guardado del hito de expedición.

### Principios de diseño

- Ruta principal clara; desvíos opcionales cortos.
- Una mecánica nueva por tramo como máximo.
- Los enemigos deben comunicar intención y dar tiempo de reacción.
- El jefe debe probar habilidades ya enseñadas, no exigir una mecánica sorpresa.
- La recompensa debe tener utilidad inmediata y no romper la economía.
- La expedición debe poder repetirse sin duplicar recompensas únicas.
- La ruta no depende de conexión a Supabase ni de que una semilla aleatoria genere el bioma correcto.
- Mantener el estilo visual y los sprites existentes; no introducir arte o música generados.

## Orden de implementación

### P0 — Contrato y acceso a la expedición

- Definir IDs estables para zona, hitos, NPC, criaturas, recurso y recompensa.
- Añadir el destino local de expedición a `ZoneManager` y el flujo de entrada/salida desde Torres.
- Guardar/restaurar punto de retorno, estado de expedición y semilla de zona.
- Garantizar que al volver a Torres se conserve inventario, vida, Eterium, tiempo y progreso.
- Añadir pruebas de transición, regreso y restauración.

**Criterio de salida:** una partida nueva puede salir de Torres, entrar siempre a la misma expedición y regresar sin perder estado ni quedar en una escena vacía.

### P1 — Zona de bosque controlada

- Reutilizar el pipeline de terreno, streaming, spawn rules, factory y entity manager.
- Crear una configuración de expedición que garantice bosque en el área jugable y limite el tamaño/alcance de esta primera ruta.
- Colocar hitos espaciales deterministas: entrada, bifurcación, claro, ruinas y salida.
- Mantener los ecosistemas y reglas de aparición del catálogo; no inventar entidades en código si ya existen datos válidos.
- Añadir pruebas de que los puntos críticos existen y el bioma de la ruta es el esperado.

**Criterio de salida:** la ruta tiene la misma estructura en todas las partidas y puede cargar/descargar chunks sin perder hitos.

### P2 — Bucle de misión y exploración

- Crear el contrato de hitos de expedición con estados: no iniciado, activo, completado y recompensa reclamada.
- Conectar conversación, descubrimiento, recolección, derrotas e interacción a ese contrato.
- Verificar la disponibilidad offline de definiciones de misión; si no está garantizada, incluir la definición de esta expedición en datos locales versionados.
- Mostrar objetivo actual y progreso en el HUD existente, sin crear una segunda interfaz de misiones.
- Persistir el progreso y evitar duplicar recompensas.

**Criterio de salida:** cerrar el juego en mitad de la ruta y continuar desde el último hito guardado.

### P3 — Combate, criaturas y jefe

- Elegir criaturas que ya estén presentes en el catálogo y tengan sprites/IA configurados.
- Ajustar composición y dificultad por tramo usando estadísticas existentes.
- Implementar el jefe con el mismo pipeline de combate y contratos de ataque.
- Añadir pruebas para victoria, derrota, huida cuando corresponda y reentrada al encuentro.
- Ajustar recompensas después de probar el coste real de curación y Eterium.

**Criterio de salida:** el combate puede completarse con controles actuales, sin softlocks ni daño invisible.

### P4 — Clima, feedback y pulido

- Conectar perfiles climáticos a señales visuales/sonoras existentes o a efectos nuevos pequeños y configurables.
- Añadir feedback de descubrimiento, recolección, impactos y final de misión.
- Revisar colisiones, límites, cámara, puntos de aparición y lectura visual.
- Medir rendimiento con chunks y criaturas de la ruta cargados.
- Ejecutar regresión completa y una prueba manual de la ruta de principio a fin.

**Criterio de salida:** expedición completa, legible y estable en una sesión de 15–20 minutos.

## Fuera de alcance de esta primera expedición

- Reactivar o ampliar multijugador.
- Cambiar el canon de Garlia o modificar Supabase.
- Construir un sistema general de estaciones/eventos climáticos con consecuencias complejas.
- Añadir fabricación extensa, economía nueva o árbol de habilidades.
- Crear una gran región abierta antes de validar este recorrido corto.

## Siguiente tarea concreta

Empezar por **P0**: diseñar e implementar el acceso local a la expedición, el retorno a Torres y el guardado de estado. No comenzar todavía el jefe ni una expansión general del mundo.