# Contrato de lugares del mundo v1

## Estado

Esta rama incorpora el catálogo de configuración `public.lugares_game` y lo expone en el snapshot ambiental v3. El catálogo es independiente de `props_game`; no cambia las definiciones canónicas de `public.lugares` ni las relaciones ecológicas existentes.

## Flujo de datos

1. `public.lugares` mantiene identidad, nombre, tipo y relaciones canónicas.
2. `public.lugares_game` configura aparición del juego: activación, peso, escala, offsets, huella, clave visual y parámetros JSON validados como objeto.
3. `get_mundo_inicial_ambiental_v3()` agrega los lugares activos al campo `lugares_game` del snapshot.
4. `GarliaSupabaseClient` solicita v3 y `WorldDataService` indexa las definiciones para consumo del generador.

Las filas están desactivadas por defecto. La RPC omite definiciones sin tipo o nombre, y la capa de juego omite registros sin `lugar_id` o `asset_key`.

## Reglas de integridad

- `lugar_id` es único y referencia `public.lugares(id)`.
- El borrado de un lugar configurado se restringe para evitar perder configuración.
- Las definiciones activas requieren una `asset_key` no vacía.
- `reglas_generacion` debe ser un objeto JSON.
- No se escriben ni modifican filas canónicas de lugares en esta migración.

## Límite espacial pendiente

Este contrato sincroniza el catálogo, pero no debe considerarse una generación espacial completa. El terreno actual expone contexto ecológico y transitabilidad, pero el contrato revisado no entrega todavía evidencia espacial suficiente para validar correctamente cavidades, pasos de montaña, visibilidad, surgencias de agua ni distribución de vegetación. Tampoco existe una coordenada canónica para cada lugar.

Por eso, no se debe colocar cada definición en una posición aleatoria por chunk: una misma ubicación canónica podría duplicarse y aparecer en un lugar físicamente imposible. La siguiente etapa debe definir la identidad global de la instancia y su ancla espacial, conectadas con el motor geográfico, antes de activar el materializado visual.

## Assets

`asset_key` es una clave lógica, no una ruta absoluta de archivo. El resolvedor visual debe validar la clave contra el registro de assets actual del juego. Esta implementación no modifica ni renombra assets.
