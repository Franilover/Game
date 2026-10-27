# Configuración reutilizable de IA para Garumis

`scripts/ai/garumi_brain.gd` es un intérprete genérico. **Supabase define el perfil y sus parámetros; Godot solo implementa las primitivas de conducta disponibles.** No se crean perfiles canónicos por defecto ni una clase por especie.

## Configuración que interpreta el motor

Se admite un perfil declarado en `ia_config.garumi.movimiento.perfil`. Para compatibilidad, si ese campo no existe, se puede usar `ia_config.movimiento.perfil`. La configuración específica de Garumi tiene prioridad cuando declara un perfil.

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
      }
    }
  }
}
```

El ejemplo describe la forma que el intérprete puede consumir; no afirma que esos valores estén cargados en Supabase ni los registra como canon.

## Primitivas de movimiento disponibles

| Perfil configurado | Acción ejecutada por Godot |
| --- | --- |
| `errante` | Desplazamiento con pausas aleatorias. |
| `curioso`, `sociable` | Se aproxima al jugador dentro del radio social y mantiene la distancia configurada. |
| `timido`, `evasivo` | Se aleja si el jugador entra en la distancia de escape configurada. |
| `territorial` | Se aproxima hasta la distancia configurada y se detiene. |
| `explorador` | Alterna desplazamiento y pausas. |
| `acompanante`, `acompañante` | Busca al jugador cercano. |
| `quieto`, `inmovil` | No emite dirección de movimiento. |

Estos nombres son identificadores de primitivas de ejecución, no personalidades asignadas por el código a especies o individuos. Se eliminó la interpretación de rasgos de personalidad que podía competir con el perfil configurado.

## Validación y ausencia de configuración

- Sin un perfil explícito válido, `GarumiBrain` mantiene la dirección en cero para bloquear la patrulla genérica; no inventa un perfil `errante`.
- Un perfil desconocido también queda detenido y no se convierte silenciosamente en otro perfil.
- Los parámetros de movimiento solo se leen de la configuración; los valores de respaldo sirven para que el intérprete funcione físicamente, no para definir canon.
- `CreatureMovement` conserva la responsabilidad de velocidad, colisiones y desplazamiento físico, y mantiene sus restricciones generales de movimiento.
- El seguimiento de Garumis vinculados y la arena de combate tienen prioridad.

## Relaciones y persistencia

El cerebro ya no asigna puntos de confianza, no usa identificadores de instancia como identidad persistente y no almacena relaciones en metadatos. La relación con un jugador debe integrarse a través del servicio de progreso/guardado existente, usando identificadores persistentes y reglas definidas por el backend. Hasta verificar esa ruta, no se simula persistencia ni se aplican incrementos arbitrarios.

## Alcance

- No implementa todavía decisiones de combate ni un catálogo de ataques.
- No sustituye `CreatureAI` ni cambia la IA de otras criaturas.
- No modifica datos ni tablas de Supabase.
