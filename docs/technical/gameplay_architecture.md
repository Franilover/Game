# Garlia — Arquitectura de Gameplay

## Principio

Cada responsabilidad tiene un único dueño.

Flujo general:

SUPABASE → datos canónicos → runtime → sistemas de gameplay → entidades → eventos → UI.

La UI representa estado. No es la fuente de verdad.

## Combate

El combate se divide progresivamente en:

- CombatSystem: compatibilidad/orquestación del combate del jugador.
- CombatAttackArea: ciclo de vida de un ataque cuerpo a cuerpo, incluyendo hitbox y representación visual.
- CombatTargeting: selección y validación de objetivos.
- CombatDamage: resolución común del daño.
- CombatProjectile: ataques a distancia.
- CreatureAI: decide cuándo y contra quién intenta atacar; no debe duplicar la lógica de resolución de daño.

### Regla crítica

Un ataque cuerpo a cuerpo debe tener un único dueño de ciclo de vida:

CombatAttackArea
├── Hitbox
└── AttackVisual

Crear, actualizar, detectar impactos y destruir esos elementos pertenece al mismo objeto.

Nunca crear el hitbox en un nodo y la visual del ataque en otro sistema.

## Daño

Entity.take_damage() es la frontera de aplicación de daño.

Los sistemas de combate entregan:

- cantidad
- origen

La entidad decide:

- cuánto daño recibe realmente
- actualización de vida
- muerte
- señales de estado

La entidad no decide quién inició el ataque.

## Input

El gameplay debe consultar una única puerta de entrada para saber si puede procesar input.

No duplicar comprobaciones como:

- inventory.visible
- estado interno del inventario
- visibilidad de HUD
- estado del diálogo

## Inventario

Separación prevista:

- runtime de items
- equipment
- hotbar
- UI

El estado de equipamiento no depende de qué slot de hotbar está seleccionado.

## IA

La IA decide comportamiento:

- objetivo
- intención
- momento del ataque

La IA no debe mantener una segunda implementación del sistema de daño.

## GameState

GameState conserva el estado global necesario, pero sus responsabilidades se irán extrayendo progresivamente:

- SaveState
- WorldState
- DiscoveryState
- GameplayInputGate

No se realiza una reescritura total de GameState mientras el guardado actual siga funcionando.

## Migración

Orden:

1. Unificar ataque cuerpo a cuerpo.
2. Extraer targeting.
3. Extraer resolución de daño.
4. Unificar ataques de jugador e IA.
5. Centralizar input.
6. Separar inventario runtime/equipment/hotbar/UI.
7. Reducir GameState.

Cada fase debe dejar el juego funcional antes de iniciar la siguiente.
