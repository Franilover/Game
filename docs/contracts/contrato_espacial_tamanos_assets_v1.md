# Garlia — contrato espacial y tamaños visuales v1

Estado: propuesta para revisión técnica. No crea coordenadas, no modifica Supabase y no cambia assets.

## A. Unidades que no deben mezclarse

1. **Geodesia:** kilómetros sobre la esfera canónica de Garlia (radio medio 6400 km).
2. **Coordenadas cartográficas:** coordenadas planas derivadas de latitud/longitud mediante una proyección elegida.
3. **Coordenadas de juego:** píxeles, tiles y posiciones de escenas de Godot.
4. **Tamaño de sprite:** dimensiones del archivo/viewport visual; no equivalen por sí solas al tamaño geográfico de una entidad.

No inferir latitud/longitud desde `reinos.coord_x/coord_y`: son coordenadas abstractas de presentación y no existe una transformación documentada y calibrada entre ellas y la esfera. Tampoco inferir kilómetros por tile desde el tamaño de la ventana.

## B. Base de render existente

La configuración del proyecto consultada en la rama de trabajo declara:

- Godot 4.7, renderer GL Compatibility.
- Viewport base de 960 × 540 px.
- `WorldGenerator.tile_size = 32` px.
- `chunk_size_tiles = 32` por defecto.
- Mundo de prueba referido en el historial del proyecto: 80 × 44 tiles, sujeto a verificación contra la escena/configuración actual antes de tratarlo como contrato global.

Por tanto, para los assets de terreno que realmente usen la cuadrícula de `WorldGenerator`, el módulo de referencia provisional es 32 × 32 px. Esto define una convención de dibujo, no una escala física.

## C. Guía inicial de sprites en píxeles

Todos los tamaños de abajo son guías de producción visual, no tamaños físicos canónicos. Se deben ajustar a la silueta y al footprint real.

| Clase visual | Lienzo inicial sugerido | Huella de juego sugerida | Regla |
|---|---:|---:|---|
| Recurso/objeto pequeño | 16×16 o 32×32 | 1×1 tiles | Centrar en la celda; evitar padding transparente excesivo |
| Planta pequeña / roca | 32×32 | 1×1 tiles | Pivote en la base |
| Arbusto / recurso mediano | 32×48 o 48×48 | 1×1–2×2 tiles | Pivote inferior central |
| Árbol | 64×96 como punto de partida | 1×1 o 2×2 tiles de colisión, según tronco | Copa puede sobresalir; la colisión no debe abarcar toda la copa |
| Puerta/entrada/cueva | 32×32 o múltiplos de 32 | Huella real de acceso, no de la ilustración completa | Separar área visual de área transitable |
| Edificio pequeño | 64×64 o 96×96 | 2×2 o 3×3 tiles | Colisión y ocupación explícitas |
| Edificio grande / hito | 128×96, 128×128 o tamaño modular | Según plano y accesos | Componer por módulos cuando convenga; no escalar assets arbitrariamente |
| Personaje estándar | 32×48 como base de trabajo | Colisión aproximada de 16×16 o 16×24, según animación | Pivote inferior central; la colisión es independiente del frame |
| Criatura grande | 64×64 o más | Según volumen y movimiento | Definir huella por entidad, no por el tamaño de cada frame |
| Lugar natural grande | Arte modular por tiles de 32 px | Polígono/huella de ocupación independiente | El paisaje no debe convertirse automáticamente en una sola colisión |

No ampliar o reducir imágenes fuente automáticamente para forzar estas dimensiones. Mantener proporción, pixel art nítido y pivotes coherentes; registrar excepciones por asset.

## D. Contrato de definición visual de lugares

Cada fila de `lugares_game` debería describir por separado:

- `asset_key`: clave estable resuelta por un registro de assets existente.
- `escala`: multiplicador visual explícito, por defecto 1.0; no expresa kilómetros.
- `offset_x`, `offset_y`: corrección de render en píxeles o unidades claramente documentadas; no cambia la coordenada canónica.
- `huella_ancho_tiles`, `huella_alto_tiles`: rectángulo lógico mínimo de ocupación/transitabilidad, independiente del tamaño del sprite.
- `reglas_generacion`: restricciones verificables del terreno y contexto; no usarla para guardar coordenadas canónicas.
- Ancla geográfica: identidad y coordenadas procedentes del motor geográfico, separadas de la configuración visual.

Antes de activar un lugar, validar que la huella cabe en terreno compatible, que no bloquea pasos necesarios y que la clave de asset existe. Un lugar canónico se instancia una sola vez por `lugar_id`; el streamer solo gestiona carga/descarga visual.

## E. Primeras anclas geográficas: criterio

Las tablas de geometría estaban vacías en la última auditoría. El catálogo `public.lugares` también devolvió cero filas en esa consulta, mientras `public.reinos` contiene coordenadas `coord_x/coord_y` de presentación y nombres existentes; solo una fila se mostró como publicada. Esos datos no son anclas geodésicas.

Procedimiento seguro:

1. Elegir un lugar canónico existente con identidad y descripción suficientemente completas, o completar el canon mediante un proceso aparte y aprobado.
2. Obtener/definir latitud y longitud a partir de un mapa canónico de Garlia o una decisión explícita de worldbuilding. No derivarlas de `coord_x/coord_y`.
3. Registrar una geometría `punto` en estado de propuesta; verificar cuerpo celeste, vértice único, rango de coordenadas y relación semántica inequívoca.
4. Validar la geometría y su relación con el lugar tras revisión; solo entonces será un ancla elegible.
5. Usar al menos dos anclas y una referencia de separación acordada para contrastar la escala cartográfica. Un único punto no determina la escala.

No se debe insertar una coordenada inventada ni cambiar `public.lugares`, `public.reinos` o los assets como parte de esta propuesta.

## F. Bloqueo actual y próximos entregables

- Física: `1 uL_longitud = 0.001 km`, radio medio 6400 km.
- Escala mapa/unidad: pendiente.
- Proyección: pendiente de decisión; equirectangular solo candidata de prototipo.
- Anclas canónicas: pendientes de selección y coordenadas aprobadas.
- Tamaños visuales: módulo de dibujo provisional 32 px; guía de sprites en esta propuesta.
- Materialización espacial: bloqueada hasta que anclas, proyección, escala, asset y huella sean válidos.

Antes de usar 32 px como contrato definitivo de todo el juego, verificar escenas, tilesets, escala de cámara y colisiones. Esta guía no modifica ninguna escena ni asset existente.
