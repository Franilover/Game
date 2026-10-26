# Garlia — Implementación del contrato temporal de combate

Estado: rama de trabajo `fix/combat-temporal-contract-v1`. Esta documentación distingue las reglas implementadas de las reglas que siguen pendientes.

## Cambios aplicados en esta iteración

### Contacto efectivo independiente del daño

- `CombatSystem.contacto_efectivo(atacante, objetivo, origen)` publica el contacto confirmado de ataques cuerpo a cuerpo, proyectiles y ataques de contacto ejecutados por la IA.
- `CombatProjectile.contacto_detectado` se emite cuando un proyectil contacta con un objetivo válido, antes de consultar si se aplicó daño.
- `objetivo_impactado` conserva su significado anterior: solo se emite si `CombatDamage.aplicar()` confirma una reducción real de salud.
- Un proyectil se consume al contactar con un objetivo válido aunque el daño sea cero o no reduzca la salud. Así se evita que atraviese al mismo objetivo por un resultado de daño nulo.
- La presentación del impacto del proyectil se delega al consumidor de `objetivo_impactado`, evitando que `CombatProjectile` y `CombatSystem` ejecuten el mismo feedback dos veces.
- La señal de contacto puede alimentar en el futuro reglas de torneo que dependan del contacto, aunque el daño sea cero. Intercepciones, escudos y geometría de torneo todavía no están implementados.

### Progreso de recuperación de Eterium

- `PlayerEteriumRuntime.actualizar_recuperacion()` no avanza ni borra el progreso existente mientras el recurso ya está al máximo.
- Si la propia recuperación pasiva completa un tick y llena el recurso, el contador queda en cero al completar ese tick; el tiempo restante del mismo `delta` no se almacena como recuperaciones futuras.
- Si una fuente externa —por ejemplo, absorción— llena el recurso durante un intervalo parcial, ese progreso se conserva mientras el recurso permanece lleno. Al gastar Eterium, la recuperación continúa desde el progreso pausado.
- Esta corrección conserva la configuración existente de recuperación y fisiología del jugador; no traslada aún el runtime al reloj individual de cada Garumi.

## Pruebas añadidas

La prueba headless `tests/combat/test_combat_temporal_contract.gd` comprueba:

1. Contacto de proyectil con daño cero, con salud intacta.
2. Separación entre `contacto_detectado` y `objetivo_impactado`.
3. Contacto melee para una herramienta sin daño.
4. Contacto de IA con daño cero sin declarar daño aplicado.
5. Aplicación de daño positivo exactamente una vez y publicación de un contacto.
6. Ausencia de contactos nuevos contra objetivos muertos.
7. Conservación del progreso fraccionario cuando una fuente externa llena Eterium.
8. Reanudación de la recuperación tras gastar Eterium.
9. Finalización limpia del tick pasivo que alcanza el máximo.
10. Ausencia de recuperaciones acumuladas después del máximo cuando un `delta` es grande.

El workflow de Godot 4.7 ejecuta esta prueba para los cambios del sistema de combate y del runtime de Eterium.

## Primitivas temporales añadidas en la siguiente fase

- `CombatClock`: reloj lógico entero que no retrocede.
- `CombatEventQueue`: cola ordenada por tiempo y secuencia, con rechazo de IDs duplicados y eventos anteriores al reloj actual.
- `CombatActionLifecycle`: máquina de estados de orden que diferencia rechazo, compromiso, ejecución, interrupción y cancelación.
- `GarumiEteriumClock`: recuperación individual con progreso pausado al máximo y reanudación tras gasto.
- `tests/combat/test_combat_event_queue.gd`: pruebas de reloj, cola, ciclo de vida y recuperación individual.

Estas primitivas siguen aisladas del flujo real de `CombatSystem` para permitir validación incremental. Las pruebas están **PENDING** hasta que se ejecute Godot 4.7 y se inspeccione la salida.

## Reglas aún no implementadas

- Reloj lógico determinista del combate y cola de eventos.
- Ciclo de vida temporal completo de órdenes, preparación, compromiso e interrupción.
- Resolución determinista de eventos simultáneos y de gasto/recuperación.
- Relojes de recuperación individuales para Garumis.
- Intercepciones, escudos, trayectorias barridas y contacto de torneo con entrenador.
- Política de pausa/reanudación de la simulación y autoridad multijugador.

No se ha cambiado el canon de Supabase. Esta rama solo prepara una primera capa de runtime y pruebas antes de integrar el contrato temporal completo.
