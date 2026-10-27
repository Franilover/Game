# Configuración reutilizable de IA para Garumis

El cerebro común vive en `scripts/ai/garumi_brain.gd`. Cada Garumi puede variar mediante `ia_config`; no se necesita una clase de IA individual por especie o individuo.

## Esquema inicial

Los siguientes campos se leen dentro de `ia_config.garumi`. La configuración de movimiento genérica existente en `ia_config.movimiento` sigue siendo compatible.

```json
{
  "ia_config": {
    "garumi": {
      "movimiento": {
        "perfil": "curioso",
        "radio_social": 100,
        "distancia_preferida": 40,
        "distancia_escape": 72,
        "intervalo_min": 0.8,
        "intervalo_max": 2.2,
        "probabilidad_pausa": 0.3
      },
      "personalidad": {
        "rasgos": ["curioso", "cauteloso"]
      }
    }
  }
}
```

## Perfiles reutilizables

| Perfil | Conducta base |
| --- | --- |
| `errante` | Deambula con pausas aleatorias. |
| `curioso` | Se acerca al jugador cercano y mantiene una distancia preferida. |
| `sociable` | Busca acercarse al jugador, sin necesidad de perseguirlo hasta tocarlo. |
| `timido` | Se aleja cuando el jugador entra en su radio de reacción. |
| `evasivo` | Comparte la reacción de escape del perfil tímido; se puede diferenciar con sus parámetros. |
| `territorial` | Se aproxima hasta su distancia de seguridad y luego se detiene. |
| `explorador` | Alterna desplazamientos y pausas breves. |
| `acompanante` | Busca al jugador cercano. Para un Garumi ya vinculado, el seguimiento existente tiene prioridad. |
| `quieto` | No elige desplazamientos propios. |
| `inmovil` | Se detiene; también respeta la restricción genérica de movimiento. |

## Rasgos iniciales

Los rasgos de `personalidad.rasgos` pueden modular el perfil: `curioso`, `sociable`, `timido`, `cauteloso` y `territorial`.

Ejemplo de reutilización: dos Garumis pueden usar `curioso`, pero uno acercarse hasta 24 unidades y decidir cada 0,8–1,4 segundos, mientras el otro conserva 64 unidades y decide cada 1,5–3 segundos. La conducta sale de los datos; no se duplica el código.

## Relaciones con jugadores

`GarumiBrain.registrar_interaccion(jugador, tipo)` registra en la instancia una confianza provisional por jugador. Los tipos actuales son `ayuda`, `proteger`, `comida`, `regalo`, `amenaza`, `golpe`, `hablar` y `acercamiento_respetuoso`.

**Límite actual:** las relaciones se guardan en metadatos de ejecución y no persisten al cerrar el juego. Antes de usarlas como canon o progreso guardado, deben conectarse al identificador persistente del jugador y al sistema de guardado autorizado. Todavía no controlan automáticamente la aceptación del vínculo.

## Límites de esta primera fase

- No implementa decisiones de combate ni el catálogo de ataques.
- No sustituye `CreatureAI` ni altera las IA de otras criaturas.
- El seguimiento de Garumis vinculados y la arena de combate tienen prioridad.
- Las restricciones de movimiento ya existentes en `ia_config.movimiento` se conservan.
