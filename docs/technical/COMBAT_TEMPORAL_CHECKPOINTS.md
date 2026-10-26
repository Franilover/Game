# Garlia — Marcadores de progreso del contrato temporal

Este archivo es la bitácora de puntos de recuperación para la implementación del combate. Mantenerlo actualizado en cada bloque funcional facilita aislar regresiones aunque todavía no se pueda probar localmente.

## CP-01 — Separación de contacto y daño + pausa de Eterium

- **Rama:** `fix/combat-temporal-contract-v1`
- **Punto base antes de continuar:** `8871605fb454c7bafcdc58d00f1d58c12ac298d3`
- **Estado:** cambios publicados; ejecución local de Godot 4.7 aún no confirmada.
- **Incluye:**
  - Señal `CombatSystem.contacto_efectivo` separada de daño aplicado.
  - `CombatProjectile.contacto_detectado` emitida antes de intentar aplicar daño.
  - Progreso parcial de recuperación conservado cuando una fuente externa llena Eterium.
  - El tick pasivo que llena Eterium termina en el máximo sin acumular tiempo posterior.
  - Prueba headless de regresión para proyectil, melee, ruta de IA y recuperación.
- **Prueba que debe ejecutarse:** `godot --headless --path . --script res://tests/combat/test_combat_temporal_contract.gd`
- **Resultado:** pendiente de ejecutar; no asumir PASS hasta ver salida real.
- **Cómo volver a este punto:** revisar el commit `8871605fb454c7bafcdc58d00f1d58c12ac298d3` o hacer checkout de ese commit en modo detached en un clon local. No mover ni resetear `main`.

## CP-02 — Reloj lógico y cola determinista de eventos

- **Estado:** siguiente bloque de implementación.
- **Objetivo:** introducir primitivas independientes del árbol de escenas para tiempo lógico entero, secuencia estable y deduplicación de eventos.
- **Criterio de aceptación:** el mismo conjunto de eventos con el mismo tiempo y secuencia se procesa en el mismo orden; un evento ya resuelto no puede resolverse dos veces.
- **Límite de este bloque:** todavía no conectar la cola con ataques activos, física, recuperación ni victoria hasta que sus pruebas unitarias sean claras.

## CP-03 — Ciclo de vida temporal de órdenes

- **Estado:** no iniciado.
- **Objetivo:** representar validación, preparación, compromiso, ejecución, finalización, interrupción y cancelación como estados explícitos.
- **Dependencia:** CP-02 y pruebas del contrato de eventos.

## CP-04 — Integración del reloj de recuperación por Garumi

- **Estado:** no iniciado.
- **Objetivo:** separar el reloj individual de Eterium de `PlayerEteriumRuntime` sin romper fisiología, sprint, curación ni absorción del jugador.
- **Dependencia:** contrato temporal y auditoría de consumidores existentes.

## Protocolo de depuración

1. Cada bloque funcional debe actualizar este archivo con commit base, archivos cambiados, comando de prueba y estado real.
2. Los estados de prueba permitidos son `PASS` (salida observada), `FAIL` (fallo observado) y `PENDING` (no ejecutado).
3. Si aparece una regresión, comparar primero con el checkpoint anterior más reciente; no revertir bloques posteriores a ciegas.
4. No declarar el juego probado a partir de que el workflow o el archivo de pruebas existan.
5. Esta rama no cambia el canon de Supabase ni modifica `main`.
