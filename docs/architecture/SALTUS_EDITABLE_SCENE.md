# Saltus — edición visual del mapa

El terreno de Saltus se carga desde `scenes/world/saltus_map_v2.tscn`. La expedición ya no llama a `_crear_terreno()` al iniciar el juego.

## Crear la escena editable por primera vez

1. Actualiza la rama `work/design-and-architecture`.
2. Abre el proyecto en Godot.
3. En el panel FileSystem, abre `tools/editor/build_saltus_editable_map.gd`.
4. Con el script abierto, usa **File → Run** (o el botón Run del EditorScript).
5. Se generará `scenes/world/saltus_map_v2.tscn`.
6. Abre esa escena. Selecciona `TerrenoSaltusV2` para editar el TileMapDual con las herramientas TileMap.

El generador utiliza la geometría V2 existente y la guarda como celdas serializadas en la escena. No se ejecuta durante el juego.

## Qué puedes editar

- Pintar y borrar tiles en el panel TileMap.
- Cambiar la forma del terreno y las plataformas.
- Mover el nodo `TerrenoSaltusV2` completo.
- Editar las colisiones estáticas serializadas dentro de la escena.

## Importante: colisiones

El generador también serializa los cuerpos de colisión del terreno y las plataformas. Si cambias mucho la forma del TileMap, revisa y ajusta esos nodos de colisión en la misma escena. En esta primera conversión las colisiones son nodos independientes, no colisión automática por tile.

## Responsabilidades

- `saltus_map_v2.tscn`: terreno, tiles y colisiones base editables.
- `saltus_expedition.gd`: lógica de expedición, cámara, criaturas, flores, checkpoints, fondos y grafo de regiones.

El mapa resultante es una escena normal de Godot que se puede abrir, editar y guardar con Ctrl+S. Si vuelves a ejecutar el generador, reconstruirá el archivo a partir de la geometría codificada; por eso no debes volver a ejecutarlo después de empezar a personalizar el TileMap, salvo que quieras regenerarlo desde cero.
