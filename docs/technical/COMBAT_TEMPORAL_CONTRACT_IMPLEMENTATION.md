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

- `PlayerEteriumRuntime.actualizar_recuperacion()` pausa la actualización cuando el recurso está al máximo sin poner a cero `recovery_accumulator`.
- Al gastar Eterium, el siguiente intervalo continúa usando el progreso fraccionario conservado.
- Esta corrección conserva la configuración existente de recuperación, absorción y fisiología del jugador; no traslada aún el runtime al reloj individual de cada Garumi.

## Pruebas añadidas

La prueba headless `tests/combat/test_combat_temporal_contract.gd` comprueba:

1. Contacto de proyectil con daño cero.
2. Ausencia de reducción de salud cuando el daño es cero.
3. Separación entre `contacto_detectado` y `objetivo_impactado`.
4. Aplicación de daño positivo exactamente una vez.
5. Conservación del progreso fraccionario de recuperación al máximo.
6. Reanudación de la recuperación tras gastar Eterium.

El workflow de Godot 4.7 ejecuta esta prueba para los cambios del sistema de combate y del runtime de Eterium.

## Reglas aún no implementadas

- Reloj lógico determinista del combate y cola de eventos.
- Ciclo de vida temporal completo de órdenes, preparación, compromiso e interrupción.
- Resolución determinista de eventos simultáneos y de gasto/recuperación.
- Relojes de recuperación individuales para Garumis.
- Intercepciones, escudos, trayectorias barridas y contacto de torneo con entrenador.
- Política de pausa/reanudación de la simulación y autoridad multijugador.

No se ha cambiado el canon de Supabase. Esta rama solo prepara una primera capa de runtime y pruebas antes de integrar el contrato temporal completo.
