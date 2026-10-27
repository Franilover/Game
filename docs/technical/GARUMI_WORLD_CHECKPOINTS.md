# Garlia — Checkpoints de presencia de Garumis

## Estado actual

- **Rama de trabajo:** `feat/garumi-world-presence`
- **Base intacta:** `fix/combat-temporal-contract-v1` en `77e23937ea1ee8c2b69803717aecc883b3aff603`
- **Main:** no se ha modificado ni mezclado esta rama.
- **Supabase:** sin cambios de esquema, RPC ni datos canónicos.
- **Checkpoint completo del bloque GP-01/GP-02:** `c38990bcd3ff5890653678d7862149044c41b418`
- **Checkpoint más reciente que incluye esta bitácora:** se actualiza al crear este archivo.

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

## Estado de verificación

- Prueba: `godot --headless --path . --script res://tests/world/test_garumi_world_presence.gd`
- Resultado: **PENDING**. No se ha observado una ejecución de Godot 4.7 ni un resultado de CI asociado a este commit; no declararlo como PASS.
- Revisión estática: el flujo de datos y las rutas de materialización se revisaron; eso no sustituye compilación ni prueba en ejecución.
- El snapshot `data/world_initial.json` actual no incluye `garumis_game`.
- `assets/art/garumis/` aún no contiene sprites canónicos; por ahora, una textura ausente utiliza un proxy geométrico temporal.
- Sin el catálogo de la fuente canónica y sprites aprobados, el mundo no mostrará apariciones canónicas de Garumis. El runtime está preparado para consumir esos datos, pero su exportación no se ha modificado.

## Protocolo para el siguiente bloque

1. No resetear ni revertir la rama completa para arreglar un fallo localizado.
2. Leer la salida de la prueba y el primer error de compilación de Godot, corregirlo y volver a ejecutar la misma prueba.
3. Verificar una transición DATA → FULL → DATA → FULL, comprobando que el Garumi conserva identidad, sprite, posición/contexto y no se duplica.
4. Antes de modificar Supabase o añadir nombres/arte como canon, revisar y autorizar expresamente ese bloque.
