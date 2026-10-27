# Garlia — Presencia de Garumis en el mundo

## GP-01 — Catálogo, ecología, proxy visual y aparición por chunk

- **Rama:** `feat/garumi-world-presence`
- **Base:** `fix/combat-temporal-contract-v1` en el checkpoint publicado actual.
- **Alcance:** Godot + prueba de integración controlada. En Supabase se canonizó únicamente Oruvan por autorización explícita y se actualizó el RPC del mundo; no se añadieron columnas ni se aprobaron otros Garumis.
- **Estado de ejecución:** la prueba nueva queda **PENDING** hasta observar su salida en Godot 4.7/CI.

### Qué incorpora

- `WorldDataService` lee `garumis_game` desde el snapshot de mundo y lo conserva en un catálogo separado de `_criaturas_por_id`.
- `WorldSpawnRules` comprueba compatibilidad con bioma, ecosistema, hábitat y clave de hábitat. Los selectores presentes se combinan por AND; dentro de cada selector, los IDs se combinan por OR.
- `WorldEntitySpawner` intenta materializar hasta `max_garumis_per_chunk` Garumis por chunk, con probabilidad configurable y semilla derivada del mundo/chunk. Los Garumis usan el ciclo de vida de entidad existente, sin mezclarse con la selección de especies de hábitat.
- Los Garumis se preparan tanto en la ruta de aparición directa como en DATA LOD. Se conserva `categoria_entidad`, `asset_key`, `runtime_instance_key` y `habitat_clave` al descargar/restaurar un chunk; la categoría determina la escena/pool al materializar.
- El grupo `garumis` se mantiene separado del grupo normal `creatures`. El daño común no altera su salud; la absorción por Necromancers requiere su propio contrato y todavía no está implementada.
- `Garumi` tiene script y escena propios (`scripts/creatures/garumi.gd`, `scenes/creatures/garumi.tscn`) y una pool separada de `Creature`. Comparte infraestructura de salud, movimiento y representación, pero no incluye el `AIController` de criaturas normales.
- `Creature` busca sprite propio en `res://assets/art/garumis/<asset_key>.png` o `.PNG`. No reutiliza por accidente un sprite de criatura normal.
- `assets/art/garumis/Oruvan.svg` es un sprite abstracto dibujado a mano y no canónico. Mientras `garumis_game` esté vacío, el prototipo automático está **activado por defecto en builds debug** y su probabilidad es 1.0 para cada chunk que tenga una posición caminable válida. Se puede desactivar con `mostrar_prototipo_garumi_en_debug_sin_catalogo`. Lleva metadata explícita de prueba visual de Orumi gen. 1; no es un registro canónico ni reemplaza a Oruvan. En builds de lanzamiento, `OS.is_debug_build()` impide que aparezca. Si falla también la textura SVG, queda el proxy geométrico de desarrollo.
- Al iniciar el mundo se imprimen cantidades de catálogo, registros con aparición y sprites disponibles; al materializar una instancia aparece su ID/nombre y el estado del sprite.

### Disponibilidad visual en depuración (corrección inmediata)

La vista de depuración utiliza `asset_key = Oruvan` y probabilidad de prueba 1.0 si el catálogo sigue vacío, bajo `OS.is_debug_build()`. Tras la integración, el registro canónico de Oruvan usa el mismo `Oruvan.svg` desde `garumis_game`. El dibujo actual sigue siendo provisional y no debe interpretarse como el diseño visual definitivo.

### Fase de aparición activa: generación 1 de Orumi

- Sólo se admite `categoria_garumi = "normal"`.
- `original_id` debe coincidir con el ID de Orumi en `public.garumi_originales`: `24f86486-aced-4a23-bd1b-f025561a8aa3`.
- `numero_origen` debe ser exactamente `1`; generaciones posteriores quedan fuera.
- Si el registro trae `estado_documentacion`, debe ser `aprobado` o `canon`. Si ese campo falta en el snapshot, el exportador debe filtrar los estados no aprobados antes de emitir `garumis_game`.
- Orumi y Varum/Nyru no se generan como entidades: son Originales. Los descendientes de los otros dos linajes también quedan fuera.
- La consulta identificó a **Oruvan** como descendiente normal de primera generación de Orumi (ID `4a409bba-fc4a-4b58-931f-9af1a6831710`). Para esta prueba se marcó como `canon`; el RPC lo suministra únicamente para el filtro de Orumi generación 1.

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

- `public.garumis` tenía 24 borradores; sólo Oruvan (`4a409bba-fc4a-4b58-931f-9af1a6831710`) se actualizó a `estado_documentacion = 'canon'` para esta prueba. Orumi tiene ID `24f86486-aced-4a23-bd1b-f025561a8aa3`; los otros 23 Garumis no se modificaron.
- La migración `emitir_garumi_orumi_gen1_para_prueba` añadió `garumis_game` a `public.get_mundo_inicial()`. Los RPC ambientales v1 y v2 heredan esa clave. La consulta de verificación al RPC v2 devolvió exactamente un registro: Oruvan.
- `public.garumis` sigue sin columna `asset_key` ni selectores ecológicos. Para esta prueba, el RPC deriva `asset_key` desde el nombre (`Oruvan`) y añade temporalmente `habitat_claves = ["general"]`, probabilidad 1.0 y peso 1.0. No es la distribución ecológica definitiva.
- Para la prueba el exportador filtra por categoría `normal`, linaje Orumi, `numero_origen = 1` y estado `aprobado/canon`. No se modificaron otros registros ni el esquema de tablas.

El RPC ya emite el único registro autorizado para esta prueba. El arte de Oruvan es provisional y la regla de aparición `general` debe sustituirse cuando se defina su ecología definitiva.

### Arte y siguiente paso

- Carpeta de arte: `assets/art/garumis/`.
- Nombre recomendado: archivo PNG con el basename indicado en `asset_key`; sin ruta ni extensión en el campo.
- Crear y añadir los sprites como arte propio/pixel art; no se generan sprites de IA ni se asigna una criatura existente como si fuese un Garumi.
- El diagnóstico permite distinguir un catálogo vacío, registros sin aparición ecológica y sprites que aún no existen.

### Prueba

Comando: `godot --headless --path . --script res://tests/world/test_garumi_world_presence.gd`

- **Resultado del RPC:** verificado, devuelve Oruvan con `asset_key = Oruvan` y probabilidad 1.0. **Resultado runtime Godot:** PENDING hasta confirmar materialización y `sprite=cargado` después de sincronizar y reiniciar.
- **Punto de recuperación:** commit de esta implementación en `feat/garumi-world-presence`. No hacer reset de `main` ni revertir bloques posteriores a ciegas.
