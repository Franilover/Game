# Núcleo procedural de Garlia — v1

Este núcleo se añade de forma aislada y todavía no sustituye a `WorldTerrain`,
`WorldTerrainAreas`, `WorldStreamer` ni a TileMapDual.

## Archivos

- `world_generation_config.gd`: parámetros y validación.
- `world_seed.gd`: derivación reproducible a partir de claves estables.
- `world_chunk_data.gd`: resultado de datos sin nodos ni presentación.
- `world_generator_kernel.gd`: primera generación determinista de elevación,
  humedad y temperatura en coordenadas globales.

## Contratos

- Un chunk se identifica por coordenadas enteras.
- La generación no depende del orden de petición de chunks.
- Los campos se muestrean en coordenadas globales, manteniendo continuidad
  matemática entre los bordes de chunks.
- Los IDs canónicos de biomas/ecosistemas deben usarse como claves estables;
  no se debe usar la posición en una lista como identidad.
- Cualquier cambio incompatible en las reglas debe incrementar
  `algorithm_version`.

## Limitaciones de esta primera etapa

Los campos ambientales aún no se clasifican en biomas y no se conectan al
renderizador ni a Supabase. La temperatura usa un gradiente sencillo como
punto de partida; el cálculo final deberá respetar la topología y reglas
canónicas del universo. El núcleo debe compilarse y probarse en Godot antes
de integrarlo en el juego.
