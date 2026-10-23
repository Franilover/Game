# PLAN DE TRABAJO Y CONTRATOS DEL EQUIPO — GARLIA

> Documento operativo para humanos y otras IAs que modifiquen Garlia.
>
> **Regla principal: SUPABASE MANDA.**
>
> Si una regla, dato o relación pertenece al dominio/canon del juego, la fuente de verdad es Supabase. Godot presenta, simula y orquesta; no inventa una segunda base de datos del mundo.

## 0. Objetivo

Este documento evita que distintas personas o IAs creen sistemas duplicados, rompan dependencias existentes o modifiquen una capa que no le corresponde.

Antes de cambiar código:
1. Leer este documento.
2. Inspeccionar el sistema existente.
3. Identificar la fuente de verdad.
4. Buscar si ya existe una función/sistema que resuelva el problema.
5. Cambiar el mínimo necesario.
6. Compilar/verificar.
7. Documentar el cambio si altera una regla o arquitectura.

**Nunca crear una segunda implementación solo porque la primera no fue encontrada.**

## 1. Arquitectura de autoridad

### 1.1 Supabase
Supabase es autoridad para datos canónicos del mundo: biomas, ecosistemas, hábitats, criaturas, objetos, tipos/clases, materiales, estructuras, compuestos, partículas, relaciones, configuraciones persistentes y datos de generación definidos en la base.

Godot consume estos datos. Godot no crea una copia paralela del catálogo para sustituir a Supabase.

### 1.2 Godot
Godot es responsable de presentación visual, escenas, animaciones, entrada, física, simulación local, renderizado, UI, resolución contextual, instanciación, estado temporal y comunicación con servicios canónicos.

El estado temporal de ejecución no se convierte automáticamente en canon.

### 1.3 GitHub
GitHub es la autoridad del código y assets versionados. Un archivo local no se considera definitivo hasta comprobar que está en GitHub.

## 2. Regla anti-duplicación
Antes de crear una función, clase, servicio, tabla o archivo:
- Buscar si ya existe un servicio, controlador, vista/RPC, resolver, función equivalente o escena que haga el trabajo.
- Si existe: extender o corregir el sistema existente.
- Si no existe: crear una única implementación en la capa correcta.

Prohibido:
- Segundo InventoryManager.
- Segundo sistema de interacción.
- Segundo catálogo de objetos.
- Segundo WorldData.
- Copiar reglas de Supabase dentro de GDScript.
- Hardcodear nombres cuando Supabase ya proporciona categoría/clase.
- Crear excepciones específicas cuando existe una regla general.

## 3. Flujo obligatorio para agregar un objeto/prop
Un objeto nuevo no se considera completo porque exista un PNG.

### 3.1 Datos canónicos
Comprobar en Supabase: `items`, `items_game`, tipo/categoría, relaciones, `props_game` si corresponde, contexto bioma/ecosistema/hábitat y configuración de spawn/generación.

### 3.2 Asset
El asset visual debe existir en GitHub dentro de la estructura correspondiente, por ejemplo `assets/art/props/Flor Morada.png`.

El nombre visual no sustituye a la clave canónica. La asociación debe seguir el dato canónico de Supabase.

### 3.3 Generación
Comprobar la cadena: Supabase → WorldData → reglas de generación → WorldProp/entidad → asset.

No añadir un `if` por nombre si el sistema ya debería funcionar genéricamente.

### 3.4 Interacción
Si es recolectable: prop del mundo → InteractionController → inventario. Reutilizar el resolver contextual existente. No crear otro sistema de pickup.

## 4. Flujo de objetos e inventario
Supabase define el objeto. Los servicios canónicos cargan los datos. HUD/inventario los presentan. La acción usa el objeto seleccionado/equipado y sus propiedades canónicas.

Manos y mochila:
- Click izquierdo → objeto activo de la mano izquierda, seleccionada con `Q`.
- Click derecho → objeto activo de la mano derecha, seleccionada con `E`.
- La hotbar no forma parte de la interfaz ni decide qué objeto se usa.
- Las recogidas intentan apilar/guardar primero en mochila (índices 6–11), luego ocupan ranuras libres de mano izquierda (0–5) y derecha (12–17).
- Si no cabe el objeto completo, la operación se revierte y el objeto del mundo se conserva.
- Ambos clics pasan por el mismo resolver contextual; después se intenta usar el objeto de la mano correspondiente, colocar y finalmente combatir.
- Los campos de hotbar antiguos pueden leerse desde partidas guardadas para compatibilidad, pero no dirigen el gameplay actual.

No duplicar lógica primaria y secundaria si la diferencia solo es la mano elegida.

## 5. Flujo del mundo
Cadena: Supabase → WorldDataService / WorldData → WorldGenerator / WorldTerrain / WorldStreamer → WorldEntityManager / Factory / Spawner → entidades visuales → interacción/simulación.

Si un sistema necesita información de biomas, usa WorldData. No crear otro catálogo ni otra consulta paralela para el mismo dato.

## 6. Servicios y dependencias
Los sistemas principales deben recibir dependencias explícitas, como `GameState`, `WorldData`, `GarliaAuth`, `MissionManager`, `RelationshipSystem`, `GarliaInventory` y `GarliaWorldItems`.

La composición de dependencias pertenece al nivel superior de la aplicación. Los sistemas especializados no deben buscar arbitrariamente otros sistemas si ya existe inyección de dependencias.

Autoloads/servicios globales existentes pueden utilizarse cuando forman parte de la arquitectura establecida.

## 7. Interacción
Existe un único concepto de interacción contextual.

Flujo: Input → GameplayInputGate → InteractionSystem → InteractionController → objetivo contextual → acción.

El objetivo puede ser hablar, recoger, usar, atacar u otra acción definida por el sistema.

Si un objeto se elimina con `queue_free()`, todavía puede ser válido durante el frame actual. Después de una interacción que elimina el objetivo, limpiar inmediatamente el objetivo contextual cuando corresponda.

No solucionar esto creando otro detector.

## 8. Combate
El combate reutiliza datos canónicos de objetos.

No hardcodear nombres de armas, daño por nombre, categorías por nombre ni comportamiento especial por sprite.

Preferir: items → tipo_objeto → categoría/propiedades → CombatSystem.

Para determinar si un arma es a distancia, usar la categoría canónica (`arma_distancia`) y no comprobar si el nombre contiene `arco`.

## 9. Assets
### 9.1 Assets que SÍ deben versionarse
Los recursos fuente del juego: PNG/JPG/WebP utilizados por el juego, tilesets, sprites, audio fuente, fuentes necesarias y recursos `.tres`/`.tscn` que formen parte del proyecto.

**No borrar un asset porque parezca antiguo sin comprobar si el juego o el estado actual lo necesita.**

### 9.2 Archivos generados
Los archivos generados por Godot o herramientas locales no deben confundirse con el asset fuente. Ejemplos típicos: `.uid` generados y contenido/cache de `.godot/` cuando no corresponda versionarlos.

Antes de eliminar algo, comprobar su función.

### 9.3 Regla especial
Si un asset aparece en una subida reciente del usuario, **preservarlo por defecto**. Primero determinar si es asset intencional, generado, duplicado o basura. Nunca asumir que un PNG es basura solo porque no aparezca en una escena actualmente.

## 10. Git: flujo seguro
Antes de trabajar: `git fetch origin`.

Si el usuario quiere descartar cambios locales: `git reset --hard origin/main`.

Para revisar archivos no versionados antes de eliminarlos: `git clean -fdn`. Solo después: `git clean -fd`.

Después de cambios locales: `git status` y `git diff`.

Antes de commit: no incluir `.godot/`, no incluir generados excluidos por la política, no eliminar assets intencionales y no incluir archivos temporales.

Una IA no debe borrar archivos para limpiar el repositorio sin verificar qué representan.

## 11. Supabase: flujo obligatorio
Para cualquier cambio de dominio:
1. Consultar el esquema existente.
2. Consultar registros relacionados.
3. Identificar FK y relaciones.
4. Comprobar si existe una vista/RPC que ya resuelva el problema.
5. Modificar la fuente canónica.
6. Verificar el resultado.
7. Comprobar que Godot consume el dato.

No inventar columnas, relaciones ni tablas. No crear datos paralelos en Godot. No resolver un problema de datos mediante hardcode en GDScript.

## 12. Cómo investigar un bug
Orden obligatorio:
1. Reproducir exactamente qué funciona y qué falla.
2. Encontrar la autoridad: Supabase, carga, lógica o presentación.
3. Seguir el flujo: dato canónico → servicio → sistema → UI/entidad.
4. Encontrar la primera divergencia.
5. Corregir la primera capa donde el dato deja de ser correcto.

No parchear el síntoma.

Ejemplo: si un árbol no aparece, no empezar con `if árbol: spawn_tree()`. Comparar árbol Supabase → WorldData → generación → prop → asset.

## 13. Protocolo para otras IAs
1. Leer este documento antes de modificar arquitectura.
2. Revisar archivos actuales antes de crear otros.
3. Consultar Supabase cuando el problema pertenezca al dominio.
4. Buscar implementaciones existentes.
5. No duplicar sistemas.
6. No hardcodear datos que pertenecen a Supabase.
7. No eliminar assets sin verificar su propósito.
8. Mantener dependencias explícitas.
9. Hacer cambios pequeños y verificables.
10. Explicar qué archivo/capa fue modificado y por qué.
11. Si una hipótesis no está comprobada, declararla como hipótesis.
12. No afirmar que algo funciona hasta que haya sido probado.
13. Si aparece un error nuevo después de un cambio, investigar el estado actual; no asumir que el código sigue igual.
14. Mantener compatibilidad con la arquitectura existente.
15. Si una decisión cambia una regla canónica, documentarla.

## 14. Formato recomendado de cada cambio
### Problema
Qué estaba fallando.

### Causa
En qué capa estaba la divergencia.

### Fuente de verdad
Qué sistema es responsable del dato.

### Cambio
Qué archivos/tablas se modificaron.

### Flujo resultante
Cómo viaja ahora el dato.

### Verificación
Qué se comprobó automáticamente y qué debe probar el usuario.

### Riesgos
Qué sistemas relacionados podrían verse afectados.

## 15. Regla de oro
> **No arreglar Garlia agregando excepciones.**
>
> **Arreglar la arquitectura para que el caso correcto funcione de forma general.**

> **SUPABASE MANDA. GODOT PRESENTA Y SIMULA. GITHUB VERSIONA.**

## Zonas del runtime

Las zonas pueden ser escenas independientes y deben cargarse exclusivamente mediante `ZoneManager`.

- `Main` conserva Player, HUD, Inventory, InputRouter y sistemas compartidos.
- `ReinoTorres.tscn` es una zona fija y no contiene generación procedural.
- `MundoAbierto.tscn` contiene `WorldGenerator`, streaming y aparición procedural.
- Sólo una zona está cargada a la vez.
- Cambiar de zona no crea un segundo Player, HUD, inventario ni sistema.
- El generador procedural no debe existir dentro de Reino Torres.
