# Progresión y combate de Garumis

## Alcance

La progresión de una instancia modifica sus estadísticas y recursos. La identidad de especie permanece fija durante toda su existencia: no hay etapas, formas finales ni transformaciones de especie.

Las estadísticas de especie deben proceder del snapshot canónico de Supabase cuando esté disponible. Los valores fallback siguen siendo provisionales.

## Niveles y experiencia

- Nivel mínimo: 1.
- Nivel máximo: 100.
- XP para pasar del nivel N al N+1: `ceil(100 × N^1.5)`.
- La experiencia se conserva como total acumulado.
- Las estadísticas aumentan un 2,5 % de su base por nivel adicional, redondeadas al entero más cercano.
- Subir de nivel no cambia la especie ni su identidad.

## Manifestaciones

La manifestación de Eterium puro es una modalidad distinta de la forma física y no constituye una evolución de especie. Su disponibilidad se rige por las reglas de manifestación del Garumi.

## Estadísticas

El sistema consume `vida_maxima`, `ataque`, `defensa`, `velocidad` y `eterium_maximo` desde `estadisticas_combate` o desde campos equivalentes del snapshot. Cuando faltan, utiliza valores fallback de prototipo: vida 40, ataque 10, defensa 5, velocidad 10 y Eterium 30. Esos fallbacks son provisionales y no sustituyen los valores de especie en Supabase.

## Daño

Para potencia porcentual P, ataque A y defensa D:

```text
daño = max(1, round(A × P / 100 × 100 / (100 + D)))
```

Potencia 100 equivale al daño base. La defensa reduce el daño con rendimientos decrecientes y nunca lo anula.

## Persistencia

El streaming conserva nivel, experiencia, Eterium y el estado de la instancia sin sustituir la identidad de especie definida por el catálogo actual de Supabase.
