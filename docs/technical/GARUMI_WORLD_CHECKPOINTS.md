# Garlia — Checkpoints de presencia de Garumis

## Estado actual

- **Rama de trabajo:** `feat/garumi-world-presence`
- **Base intacta:** `fix/combat-temporal-contract-v1` en `77e23937ea1ee8c2b69803717aecc883b3aff603`
- **Main:** no se ha modificado ni mezclado esta rama.
- **Supabase:** sin cambios de esquema, RPC ni datos canónicos.
- **Último checkpoint de código + regresión:** `fd0a413f21daf45e3ea6cec8ebb0ba6d08e8caab`
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

## Estado de verificación

- Prueba: `godot --headless --path . --script res://tests/world/test_garumi_world_presence.gd`
- Resultado: **PENDING**. No se ha observado una ejecución de Godot 4.7 ni un resultado de CI asociado al checkpoint de esta actualización; no declararlo como PASS.
- Revisión estática: el flujo de datos y las rutas de materialización se revisaron; eso no sustituye compilación ni prueba en ejecución.
- El snapshot `data/world_initial.json` actual no incluye `garumis_game`.
- `assets/art/garumis/Garumi_Prototipo.svg` es un sprite abstracto dibujado a mano, exclusivo del prototipo no canónico. En builds de depuración puede aparecer cuando falta el catálogo; builds de lanzamiento no lo generan. No hay sprites canónicos aprobados todavía.
- Sin el catálogo de la fuente canónica y sprites aprobados, el mundo no mostrará apariciones canónicas de Garumis. El runtime está preparado para consumir esos datos, pero su exportación no se ha modificado. El fallback de depuración sólo valida render/posición/streaming y no representa el canon.

## Protocolo para el siguiente bloque

1. No resetear ni revertir la rama completa para arreglar un fallo localizado.
2. Leer la salida de la prueba y el primer error de compilación de Godot, corregirlo y volver a ejecutar la misma prueba.
3. Verificar una transición DATA → FULL → DATA → FULL, comprobando que el Garumi conserva identidad, sprite, posición/contexto y no se duplica.
4. Antes de modificar Supabase o añadir nombres/arte como canon, revisar y autorizar expresamente ese bloque.
