# Escenas editables en Godot

## Catálogos de vista previa

Abre el proyecto en Godot y usa **Escena > Abrir escena**:

- `scenes/previews/creature_garumi_catalog.tscn`: muestra las criaturas y Garumis que ya tienen sprites exportados, separados por categoría y distribuidos en una cuadrícula centrada por cámara. Cada instancia conserva su escena individual como origen editable.
- `scenes/previews/ui_components_preview.tscn`: muestra componentes reutilizables de inventario y paneles del HUD.
- `scenes/previews/eterium_radial_menu_preview.tscn`: permite inspeccionar el menú radial de Eterium.
- `scenes/ui/character_appearance_preview.tscn`: permite inspeccionar las capas visuales de personalización del personaje.
- `scenes/previews/realm_menu_preview.tscn`: muestra el menú de viaje con destinos de ejemplo.
- `scenes/previews/crafting_panel_preview.tscn`: permite inspeccionar la distribución del panel de fabricación.

Para ejecutar una vista previa, abre la escena y pulsa **F6** (Ejecutar escena actual). También puedes inspeccionar y modificar sus nodos directamente en el árbol de escena.

## Escenas individuales

- Criaturas: `scenes/creatures/` (una escena por sprite disponible).
- Garumis: `scenes/garumis/`.
- Objetos del mundo: `scenes/world/world_item.tscn` define el icono y la etiqueta de interacción; `scenes/world/world_prop.tscn` contiene el nodo `Sprite` que recibe la textura y transformaciones de `props_game`. Ambas escenas conservan sus datos y lógica de interacción en los scripts. La textura incluida en `world_item.tscn` es solo una referencia visual de editor y se reemplaza al configurar el objeto real.
- Componentes UI: `scenes/ui/inventory_group.tscn`, `inventory_slot.tscn`, `inventory_equipment_slot.tscn`, `hud_mission_panel.tscn` y `hud_interaction_panel.tscn`, `hud_dash_charges.tscn`, `hud_discovery_notice.tscn`, `hud_calendar_clock.tscn` y `eterium_radial_menu.tscn`, `hud_garumi_linked_panel.tscn`, `hud_garumi_linked_slot.tscn`, `hud_hand_slot.tscn` y `hud_hand_item_selector.tscn`.

## Cómo se relacionan con el runtime

Las escenas de criatura heredan las plantillas existentes `creature.tscn` y `garumi.tscn`. El juego puede seguir reemplazando la textura al configurar la entidad con los datos recibidos en runtime. Las escenas de panel del HUD contienen la estructura y el estilo; el código continúa rellenando misiones, texto y acciones.

`inventory_group.tscn` define el contenedor y la rejilla; el inventario sigue creando los slots según `slot_count`. Esto conserva la capacidad configurable.

`crafting_panel.tscn` define el estado de carga, rejilla desplazable de recetas y panel de detalle/ingredientes/acción. `crafting.gd` mantiene la consulta de recetas, el renderizado dinámico de tarjetas y las operaciones de inventario. La escena de preview permite ajustar la composición sin editar el script.

`realm_menu.tscn` define el overlay, panel, cabecera y lista de destinos del menú de viaje; `realm_menu.gd` conserva la consulta de destinos desbloqueados y crea los botones según el estado real. `realm_menu_preview.tscn` añade destinos ficticios solo para inspeccionar el diseño, sin modificar el catálogo remoto.

`character_creation.tscn` contiene la estructura del formulario y utiliza `character_appearance_preview.tscn` para las capas de vista previa. Cada fila de opciones utiliza `character_appearance_option_row.tscn`; el script rellena su catálogo con los archivos disponibles y conecta la selección y el selector de color. Esto deja la geometría, los nodos y los estilos de las piezas editables sin duplicar la lógica de personalización.

## Cobertura pendiente

No todos los assets del repositorio tienen todavía una escena propia: los archivos fuente Aseprite sin exportación PNG no se convierten automáticamente en escenas visuales. Tampoco se han extraído aún todos los paneles y controles construidos dinámicamente por HUD e inventario. La lógica de entrada, minijuego, actualización de vida, selección de objetos y acciones permanece en scripts.

La personalización declara una capa `body`, pero actualmente no existe `assets/art/characters/customization/body/`; por eso esa capa queda disponible en la escena pero no ofrece opciones en el catálogo. No se ha inventado ni sustituido ningún sprite corporal.
