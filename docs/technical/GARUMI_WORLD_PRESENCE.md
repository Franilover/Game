# Garlia — Presencia de Garumis en el mundo

## GP-01 — Catálogo, ecología, proxy visual y aparición por chunk

- **Rama:** `feat/garumi-world-presence`
- **Base:** `fix/combat-temporal-contract-v1` en el checkpoint publicado actual.
- **Alcance:** sólo Godot. No modifica tablas, RPC ni datos canónicos de Supabase.
- **Estado de ejecución:** la prueba nueva queda **PENDING** hasta observar su salida en Godot 4.7/CI.

### Qué incorpora

- `WorldDataService` lee `garumis_game` desde el snapshot de mundo y lo conserva en un catálogo separado de `_criaturas_por_id`.
- `WorldSpawnRules` comprueba compatibilidad con bioma, ecosistema, hábitat y clave de hábitat. Los selectores presentes se combinan por AND; dentro de cada selector, los IDs se combinan por OR.
- `WorldEntitySpawner` intenta materializar hasta `max_garumis_per_chunk` Garumis por chunk, con probabilidad configurable y semilla derivada del mundo/chunk. Los Garumis usan el ciclo de vida de entidad existente, sin mezclarse con la selección de especies de hábitat.
- Los Garumis se preparan tanto en la ruta de aparición directa como en DATA LOD. Se conserva `categoria_entidad`, `asset_key`, `runtime_instance_key` y `habitat_clave` al descargar/restaurar un chunk; la categoría determina la escena/pool al materializar.
- El grupo `garumis` se mantiene separado del grupo normal `creatures`. El daño común no altera su salud; la absorción por Necromancers requiere su propio contrato y todavía no está implementada.
- `Garumi` tiene script y escena propios (`scripts/creatures/garumi.gd`, `scenes/creatures/garumi.tscn`) y una pool separada de `Creature`. Comparte infraestructura de salud, movimiento y representación, pero no incluye el `AIController` de criaturas normales.
- `Creature` busca sprite propio en `res://assets/art/garumis/<asset_key>.png` o `.PNG`. No reutiliza por accidente un sprite de criatura normal.
- `assets/art/garumis/Garumi_Prototipo.svg` es un sprite abstracto dibujado a mano y no canónico. El prototipo automático queda **desactivado por defecto**; sólo aparece en debug si se activa manualmente `mostrar_prototipo_garumi_en_debug_sin_catalogo`. Así no se mezcla con la primera generación canónica. Si falla también la textura SVG, queda el proxy geométrico de desarrollo.
- Al iniciar el mundo se imprimen cantidades de catálogo, registros con aparición y sprites disponibles; al materializar una instancia aparece su ID/nombre y el estado del sprite.

### Fase de aparición activa: generación 1 de Orumi

- Sólo se admite `categoria_garumi = "normal"`.
- `original_id` debe coincidir con el ID de Orumi en `public.garumi_originales`: `24f86486-aced-4a23-bd1b-f025561a8aa3`.
- `numero_origen` debe ser exactamente `1`; generaciones posteriores quedan fuera.
- Si el registro trae `estado_documentacion`, debe ser `aprobado`. Si ese campo falta en el snapshot, el exportador debe filtrar los estados no aprobados antes de emitir `garumis_game`.
- Orumi y Varum/Nyru no se generan como entidades: son Originales. Los descendientes de los otros dos linajes también quedan fuera.
- La consulta de sólo lectura encontró a **Oruvan** como descendiente normal de primera generación de Orumi (ID `4a409bba-fc4a-4b58-931f-9af1a6831710`), pero está en `borrador`. No debe aparecer hasta que tenga aprobación canónica y el exportador lo suministre con sus reglas de aparición.

La configuración vive en `WorldEntitySpawner`: `garumi_original_id_habilitado` y `garumi_generacion_habilitada`. Los filtros se prueban en `tests/world/test_garumi_world_presence.gd`. Esta selección no modifica los registros de Supabase.

### Contrato de datos esperado por Godot

Cada snapshot puede incluir una clave raíz `garumis_game`, como arreglo independiente. Cada registro válido requiere `id` y `nombre`. El contrato de aparición esperado es:

```json
{
  "id": "id-canónico-del-garumi",
  "nombre": "Nombre canónico",
  "asset_key": "basename-del-sprite",
  "aparicion": {
    "bioma_ids": ["id-bioma"],
    "ecosistema_ids": ["id-ecosistema"],
    "habitat_ids": ["id-habitat"],
    "habitat_claves": ["general"],
    "probabilidad_chunk": 0.15,
    "peso_spawn": 1.0
  }
}
```

Los selectores ecológicos son opcionales individualmente, pero **al menos uno debe estar presente**. Si se indican varios, todos tienen que coincidir con el contexto del tile. `probabilidad_chunk` es un valor entre 0 y 1; si se omite, Godot usa el ajuste `garumi_spawn_probability_per_chunk` del spawner (por defecto 0.15). `peso_spawn` permite ponderar Garumis elegibles en un mismo punto.

El snapshot incluido actualmente en `data/world_initial.json` contiene `biomas`, `ecosistemas_sin_bioma`, `version` y `generado_en`, pero **no contiene `garumis_game`**. La salida runtime proporcionada el 27-10-2026 confirma `catalogo = 0` y registra `Garumi prototipo DEBUG` en el chunk `(1, -1)` con `sprite=cargado`. Esto verifica el fallback visual local; no verifica el catálogo canónico ni la compilación de todos los scripts.

### Diagnóstico de la fuente de datos (lectura, sin escrituras)

- La tabla `public.garumis` contiene 24 registros; los 24 tienen `estado_documentacion = 'borrador'`. No se encontró ninguno aprobado como canon. La tabla `public.garumi_originales` confirma que Orumi tiene ID `24f86486-aced-4a23-bd1b-f025561a8aa3`.
- `public.get_mundo_inicial()`, `public.get_mundo_inicial_ambiental_v1()` y `public.get_mundo_inicial_ambiental_v2()` no contienen referencias a `garumis` ni emiten la clave `garumis_game`.
- El esquema actual de `public.garumis` no contiene `asset_key` ni selectores de aparición ecológica. Por tanto, el cliente Godot no puede inferir de forma segura bioma/hábitat/probabilidad usando sólo los registros actuales.
- Próxima integración canónica: decidir y aprobar el contrato de aparición, definir cómo se asocia cada Garumi con hábitat/bioma, añadir su clave de sprite y extender el exportador para devolver sólo registros aprobados. Todo ello queda bloqueado hasta autorización explícita; no se modificó Supabase.

Este documento define el contrato que el runtime puede consumir; no implica que el exportador de Supabase ya emita esos campos. Ese lado queda sin tocar hasta revisar y autorizar explícitamente su adaptación.

### Arte y siguiente paso

- Carpeta de arte: `assets/art/garumis/`.
- Nombre recomendado: archivo PNG con el basename indicado en `asset_key`; sin ruta ni extensión en el campo.
- Crear y añadir los sprites como arte propio/pixel art; no se generan sprites de IA ni se asigna una criatura existente como si fuese un Garumi.
- El diagnóstico permite distinguir un catálogo vacío, registros sin aparición ecológica y sprites que aún no existen.

### Prueba

Comando: `godot --headless --path . --script res://tests/world/test_garumi_world_presence.gd`

- **Resultado:** PENDING hasta ver salida real.
- **Punto de recuperación:** commit de esta implementación en `feat/garumi-world-presence`. No hacer reset de `main` ni revertir bloques posteriores a ciegas.
