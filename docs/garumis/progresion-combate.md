# Progresión y combate de Garumis

## Alcance

Estas reglas son la primera implementación jugable y ajustable del motor. No convierten los valores fallback en canon biológico. Las estadísticas de especie deben proceder del snapshot canónico de Supabase cuando esté disponible.

## Niveles y experiencia

- Nivel mínimo: 1.
- Nivel máximo: 100.
- XP para pasar del nivel N al N+1: `ceil(100 × N^1.5)`.
- La experiencia se conserva como total acumulado.
- Las estadísticas aumentan un 2,5 % de su base por nivel adicional, redondeadas al entero más cercano.
- El umbral de la evolución física inicial está configurado provisionalmente en nivel 30.
- La forma pura de Garumi sigue siendo una manifestación distinta; no se trata como la segunda evolución física y su referencia de nivel es aproximadamente 100, con uso limitado.

## Estadísticas

El sistema consume `vida_maxima`, `ataque`, `defensa`, `velocidad` y `eterium_maximo` desde `estadisticas_combate` o desde campos equivalentes del snapshot. Cuando faltan, utiliza valores fallback de prototipo: vida 40, ataque 10, defensa 5, velocidad 10 y Eterium 30. Esos fallbacks son provisionales y no sustituyen los valores de especie en Supabase.

## Daño

Para potencia porcentual P, ataque A y defensa D:

```text
daño = max(1, round(A × P / 100 × 100 / (100 + D)))
```

Potencia 100 equivale al daño base. La defensa reduce el daño con rendimientos decrecientes y nunca lo anula.

## Evolución física

El motor sólo permite una transición cuando:

1. La instancia actual está en estado evolutivo inicial y alcanza el umbral.
2. La relación evolutiva identifica exactamente el ID de origen y el de destino.
3. La relación y la forma destino están en estado `canon` o `aprobado`.
4. El destino es un Garumi normal de la misma línea y está marcado como forma final.

La transición actualiza la identidad y sprite de la instancia existente y conserva nivel, experiencia, vínculo y proporción de vida. El filtro de aparición excluye las formas finales, para que no aparezcan como encuentros silvestres.

## Bloqueo de datos pendiente

Las cuatro relaciones de evolución de Orumi en `garumi_evoluciones` todavía están en borrador y sus condiciones registradas indican que el umbral exacto está por definir. Por seguridad, el motor no las ejecuta hasta que esas relaciones se documenten y aprueben como canon. La progresión y las fórmulas de combate ya están implementadas; la recompensa automática de XP necesita conectarse al evento de victoria del controlador de combate.