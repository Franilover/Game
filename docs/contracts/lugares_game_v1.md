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

### Criterios de habilitación espacial

La implementación Godot incluye ahora un diagnóstico explícito en
`WorldDataService.obtener_diagnostico_lugares_game()` y lo imprime al iniciar
`WorldGenerator`. El diagnóstico comprueba la existencia de un objeto
`ancla_espacial` con `latitud_deg` y `longitud_deg` dentro de sus rangos
geográficos. Por ahora, el campo aún no viene en el snapshot y la materialización
permanece bloqueada deliberadamente.

Antes de habilitarla, deben cumplirse todos estos puntos:

1. Calibrar `geografia_mundos_v1`: modelo de superficie, radio/escala y
   proyección con unidades explícitas. No derivar coordenadas de juego desde
   una escala nula.
2. Asociar cada lugar a una geometría geográfica mediante
   `geografia_geometria_entidades_v1`, con rol semántico inequívoco.
3. Para un lugar puntual (manantial, claro, cueva o paso), registrar un ancla
   puntual validada; no usar el centroide de un área como sustituto automático.
4. Extender el snapshot con la geometría/ancla y estado de calibración, y
   rechazar ubicaciones con geometría inválida, calibración pendiente o
   relaciones ecológicas incompatibles.
5. Convertir coordenadas a tiles mediante una transformación central y estable,
   no mediante RNG por chunk. La identidad global será `lugar_id`; el streamer
   solo carga/descarga su representación visual, sin crear otra instancia.
6. Resolver `asset_key` contra el registro real de assets y validar la huella
   completa contra el terreno antes de instanciar.

Estado auditado al preparar esta etapa: las tablas de geometrías, entidades y
vértices no tienen filas; el mundo geográfico tiene calibración pendiente y sus
escalas por unidad están nulas. Por eso todavía no hay datos válidos para
materializar lugares y no se han insertado coordenadas ni alterado lugares
canónicos.

## Assets

`asset_key` es una clave lógica, no una ruta absoluta de archivo. El resolvedor visual debe validar la clave contra el registro de assets actual del juego. Esta implementación no modifica ni renombra assets.
