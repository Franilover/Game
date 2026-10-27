# Garlia — Checkpoints de presencia de Garumis

## Estado actual

- **Rama de trabajo:** `feat/garumi-world-presence`
- **Base intacta:** `fix/combat-temporal-contract-v1` en `77e23937ea1ee8c2b69803717aecc883b3aff603`
- **Main:** no se ha modificado ni mezclado esta rama.
- **Supabase:** sin cambios de esquema, RPC ni datos canónicos.
- **Checkpoint previo:** `942613000ce072dacb8825a17f4b0b891d0bf9ea`
- **Checkpoint de filtro Orumi generación 1:** `7817be330709ef3d8a01c285d0494d7c8187903c` (test actualizado; ver HEAD de rama para docs posteriores)
- **Rama base:** `fix/combat-temporal-contract-v1`; esta rama no se ha mezclado con `main`.

## Puntos de recuperación

### GP-00 — Base anterior a presencia de Garumis

`77e23937ea1ee8c2b69803717aecc883b3aff603`

Incluye los cambios de combate temporal y sus checkpoints previos a esta rama. Usarlo como referencia de la base, no como destino para resetear la rama actual.

### GP-01 — Catálogo, reglas de aparición y ruta de sprite

`c0757974ee45f8243e88e174bbb1ae5828a7071a`

Añade el catálogo independiente `garumis_game`, selectores ecológicos de aparición, probabilidad/peso, resolución de sprites en `assets/art/garumis/`, proxy geométrico de desarrollo e integración inicial del spawner.

### GP-02 — Escena y clase separadas

`65c44c71602f123aecd3516cfee7b90889ca9be0`

Añade `Garumi` y `scenes/creatures/garumi.tscn`, piscina separada en `WorldEntityFactory`, grupo `garumis`, exclusión de `creatures`/daño común y una base visual sin el `AIController` normal.

### GP-03 — Presencia compatible con streaming y persistencia

`c38990bcd3ff5890653678d7862149044c41b418`

Añade selección Garumi en DATA LOD, recuperación de categoría/clave de sprite/contexto de hábitat y pruebas de catálogo, selectores, escena, resistencia al daño común y persistencia del estado en chunks.

### GP-04 — Sprite prototipo de depuración

`8facf8926cc8f4c297473e481e975002a19ded7b`

Añade `assets/art/garumis/Garumi_Prototipo.svg`, un sprite abstracto hecho a mano y expresamente no canónico. El cargador de Garumis reconoce SVG además de PNG.

### GP-05 — Presencia de prueba sin catálogo canónico

`8318f69c1eca01de3f7a0c3084999f532183e14c`

Si el snapshot no tiene `garumis_game`, en builds de depuración el spawner puede insertar una entidad `Garumi prototipo (DEBUG)` mediante la misma ruta DATA/FULL y el ciclo de vida de chunks. La probabilidad se configura con `probabilidad_prototipo_garumi_debug` (0.35 por defecto), y el interruptor `mostrar_prototipo_garumi_en_debug_sin_catalogo` permite desactivarla. El fallback está protegido por `OS.is_debug_build()`; no genera una especie falsa en builds de lanzamiento.

El prototipo guarda y restaura su marcador de depuración, nombre, asset key y hábitat para no convertirse en una instancia canónica durante el streaming.

## Fase GP-06 — Sólo normales de primera generación de Orumi

- Filtro añadido a `WorldSpawnRules`: categoría `normal`, `original_id` de Orumi y `numero_origen = 1`.
- Si un registro incluye `estado_documentacion`, se exige `aprobado`; `borrador` queda excluido explícitamente.
- `WorldEntitySpawner` usa el ID de Orumi `24f86486-aced-4a23-bd1b-f025561a8aa3`, generación `1`, y desactiva por defecto el prototipo no canónico de debug.
- Pruebas añadidas para rechazar Varum, generación 2, categoría Original, ID de linaje vacío y registros en borrador.
- Supabase sigue sin cambios. El descendiente Oruvan (ID `4a409bba-fc4a-4b58-931f-9af1a6831710`) es la primera generación de Orumi, pero está en borrador.
- **Consecuencia actual:** hasta que exista un registro aprobado que el snapshot exporte con reglas de aparición, no habrá apariciones canónicas de Garumis. No tratar el prototipo debug como si fuese un descendiente real.

## Estado de verificación

- Prueba: `godot --headless --path . --script res://tests/world/test_garumi_world_presence.gd`
- Prueba estática/runtime parcial: la salida manual de Godot aportada el 27-10-2026 muestra `Garumi prototipo DEBUG -> chunk=(1, -1) | sprite=cargado`. Fallback de aparición y carga de sprite **observados**.
- Suite headless automatizada: **PENDING**. No se ha observado ejecución completa Godot 4.7 ni CI exitoso; no declararla como PASS.
- Revisión estática: el flujo de datos y las rutas de materialización se revisaron; eso no sustituye compilación ni prueba en ejecución.
- El snapshot `data/world_initial.json` actual no incluye `garumis_game`.
- Diagnóstico read-only: `public.garumis` tiene 24 filas y todas están en `borrador`; los RPC `get_mundo_inicial`, `get_mundo_inicial_ambiental_v1` y `get_mundo_inicial_ambiental_v2` no emiten `garumis_game`.
- `assets/art/garumis/Garumi_Prototipo.svg` es un sprite abstracto dibujado a mano, exclusivo del prototipo no canónico. En builds de depuración puede aparecer cuando falta el catálogo; builds de lanzamiento no lo generan. No hay sprites canónicos aprobados todavía.
- Sin el catálogo de la fuente canónica y sprites aprobados, el mundo no mostrará apariciones canónicas de Garumis. El runtime está preparado para consumir esos datos, pero su exportación no se ha modificado. El fallback de depuración sólo valida render/posición/streaming y no representa el canon.

## Protocolo para el siguiente bloque

1. No resetear ni revertir la rama completa para arreglar un fallo localizado.
2. Leer la salida de la prueba y el primer error de compilación de Godot, corregirlo y volver a ejecutar la misma prueba.
3. Verificar una transición DATA → FULL → DATA → FULL, comprobando que el Garumi conserva identidad, sprite, posición/contexto y no se duplica.
4. Antes de modificar Supabase o añadir nombres/arte como canon, revisar y autorizar expresamente ese bloque.
