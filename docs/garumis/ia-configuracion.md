# Configuración reutilizable de IA para Garumis

`scripts/ai/garumi_brain.gd` interpreta perfiles y parámetros procedentes de `ia_config`. Supabase define la configuración; Godot ejecuta primitivas conocidas. El cerebro no crea perfiles canónicos por especie ni cambia las reglas de vínculo.

## Contrato de datos

La configuración específica del Garumi tiene prioridad sobre los parámetros generales. Ejemplo de estructura compatible:

```json
{
  "ia_config": {
    "garumi": {
      "movimiento": {
        "perfil": "jugueton",
        "radio_social": 120,
        "distancia_preferida": 40,
        "distancia_escape": 72,
        "intervalo_min": 0.8,
        "intervalo_max": 2.2,
        "probabilidad_pausa": 0.3
      },
      "comportamiento": {
        "curiosidad": 0.8,
        "temor": 0.2,
        "sociabilidad": 0.5,
        "agresividad": 0.1,
        "territorialidad": 0.2
      },
      "elementos": ["terava", "lumora"]
    }
  }
}
```

Este es un ejemplo de contrato, no una asignación canónica a una especie. Los nombres de elementos deben coincidir con los códigos de `public.garumi_elementos`.

## Perfiles de movimiento disponibles

| Perfil | Conducta |
| --- | --- |
| `errante` | Se desplaza por su cuenta con pausas. |
| `curioso` | Se aproxima al jugador si está dentro del radio social; después vuelve a explorar. |
| `sociable`, `gregario` | Busca proximidad sin iniciar combate por sí solo. |
| `timido`, `evasivo` | Se aleja cuando el jugador entra en su distancia de escape. |
| `territorial` | Se aproxima hasta su distancia preferida y mantiene la posición. |
| `explorador`, `independiente` | Alterna desplazamientos autónomos y pausas. |
| `acompanante` | Busca al jugador cercano; el seguimiento persistente de un Garumi vinculado sigue teniendo prioridad. |
| `agresivo`, `cazador` | Presiona y se aproxima; no inflige daño ni inicia un enfrentamiento automáticamente. |
| `defensivo`, `vigilante` | Retrocede si alguien entra en su distancia de reacción y protege su espacio inmediato. |
| `jugueton` | Alterna aproximación y retirada según la distancia. |
| `quieto`, `inmovil` | No emite dirección de movimiento. |

Los acentos se normalizan para resolver identificadores como `juguetón` y `acompañante`. Un perfil desconocido no se traduce silenciosamente a otro: el Garumi permanece quieto hasta recibir una configuración soportada.

## Elementos y conducta son capas distintas

- `elementos` se lee como una lista de códigos y queda disponible mediante `GarumiBrain.obtener_elementos()`.
- `comportamiento` aporta rasgos como curiosidad, temor y sociabilidad.
- `movimiento` define la primitiva ejecutable y sus distancias/intervalos.
- Los elementos todavía no modifican el daño ni las efectividades en este cerebro. La resolución elemental debe conectarse al sistema de combate y a las tablas canónicas de asignaciones/efectividades antes de afectar el balance.
- No se asignan elementos a especies por inferencia automática ni se cambian estados de documentación en Supabase.

## Límites y prioridades

- El seguimiento de Garumis vinculados, el estado guardado y el enfrentamiento existente tienen prioridad sobre la conducta autónoma.
- `CreatureMovement` conserva velocidad, colisiones y desplazamiento físico.
- Esta capa no sustituye `CreatureAI` ni cambia la IA de otras criaturas.
- La relación persistente con el jugador no se inventa ni se almacena en metadatos.
- Prueba: `godot --headless --path . --script res://tests/world/test_garumi_brain.gd`.
