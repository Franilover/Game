# Sistema compartido de presentación

## Objetivo

Todos los reinos, interiores y expediciones reutilizan los mismos sistemas de presentación. Un escenario puede aportar arte, paletas, fondos, criaturas y reglas propias, pero no debe volver a implementar el render del jugador, las capas de skin, el equipo, las animaciones comunes ni el estilo general de UI.

La regla es **una implementación compartida + datos/configuración por contexto**.

## Piezas canónicas

| Sistema | Responsabilidad | No debe absorber |
|---|---|---|
| `SharedAssetLibrary` | Cargar recursos `res://` desde un punto único; recordar rutas inexistentes y usar referencias débiles para no retener recursos liberables | Catálogos de canon de Supabase o decisiones de gameplay |
| `CharacterAppearance` | Catálogo visual del personaje, capas de ropa/cabello/ojos y orientación de cabello | Movimiento, colisiones, IA o reglas del reino |
| `PlayerVisualController` | Render del jugador, orientaciones, apariencia, manos/equipo y animaciones visuales de herramientas/comida | Física, input, daño, inventario canónico o cámara |
| `SharedSpriteAnimationController` | Temporización y avance de spritesheets, con reproducción en bucle o de una sola ejecución | Qué animación debe elegir la IA o el gameplay |
| `PixelUITheme` | Estilos base de botones, slots, textos, barras y controles; cache de texturas y StyleBox | Estructura, navegación o contenido específico de cada pantalla |
| `Creature` | Presentación de criaturas del mundo usando recursos y animador compartidos | La IA o el comportamiento propio de cada especie |

## Árbol de responsabilidades

```text
scripts/
  shared/
    assets/
      shared_asset_library.gd
    animation/
      shared_sprite_animation_controller.gd
  characters/
    character_appearance.gd
    player_visual_controller.gd
    player_equipment_animation_controller.gd
  ui/
    pixel_ui_theme.gd
    item_icon_resolver.gd
  creatures/
    creature.gd

scenes/
  characters/
    player_visual.tscn
```

## Jugador entre reinos y expediciones

`scenes/characters/player_visual.tscn` es la escena visual base. El jugador de mundo libre y los jugadores de expedición deben instanciar esa misma escena.

`PlayerVisualController` tiene dos presentaciones que reutilizan la misma identidad visual:

- `top_down`: orientación arriba/abajo/lateral para el mundo libre.
- `platformer`: orientación lateral para expediciones como Saltus.

El perfil modifica cómo se muestra el personaje, no crea otra skin. El jugador conserva la misma textura base, las capas de apariencia y el equipo del inventario. La expedición solo comunica su perfil y su dirección de movimiento.

La física, el salto, el agarre de paredes, las colisiones, el input y las reglas específicas del nivel continúan en el controlador del personaje correspondiente.

## Catálogo de apariencia y procedencia de arte

`CharacterAppearance` es la única puerta de acceso al arte base del jugador y sus piezas de personalización. Las escenas no deben precargar por su cuenta la textura de Torres ni crear copias de la misma skin.

Por compatibilidad, los PNG que ya existen siguen almacenados en su carpeta histórica `assets/art/kingdom/Torres/Personajes/`. El código consumidor ya no debe depender de esa ubicación: consulta las claves del catálogo. No se copiaron ni movieron archivos de imagen en esta etapa, para evitar duplicados, cambios de UID y referencias de importación innecesarias.

Los personajes propios de un reino pueden declarar su ruta de sprite dentro de `assets/art/kingdom/<reino>/Personajes/`. La ruta cambia el arte de ese habitante, no el sistema de presentación.

## Animaciones

`SharedSpriteAnimationController` controla el reloj y la selección del cuadro de cualquier `Sprite2D` con spritesheet. El consumidor configura FPS, primer cuadro, cantidad de cuadros y repetición. La IA o el movimiento decide cuándo reproducir la animación; el reproductor compartido se encarga del tiempo.

Las animaciones específicas pueden conservar sus texturas y velocidades propias. Lo que no deben duplicar es el avance de cuadros y sus temporizadores.

No se deben crear texturas, nodos o tweens cada frame. Los recursos se resuelven al configurar la entidad o cambiar de estado; el reproductor solo escribe `Sprite2D.frame` cuando el cuadro realmente cambia.

## Interfaz

`PixelUITheme` es el estilo base de todas las interfaces. Los menús, inventario, relaciones, crafteo, pausa y paneles reutilizan sus superficies de botón, estados, slots, contornos y barras.

Los estilos y texturas se cachean. Los paneles conservan el diseño de su propia escena; el tema no debe imponer un fondo genérico a todos los paneles. En particular, no se aplica `panel_background.png` como fondo automático de menús o diálogos. Las pantallas pueden tener composiciones distintas, pero no duplicar la definición de los estados visuales comunes.

Una pantalla nueva debe llamar a `PixelUITheme.apply(root)` y aportar únicamente los controles o superficies verdaderamente específicos de su función.

## Reglas para añadir un reino, expedición, criatura o pantalla

1. **No copiar controladores visuales.** Instanciar la escena de jugador y usar `PlayerVisualController`.
2. **No cargar la skin base por ruta desde una escena o reino.** Consultar `CharacterAppearance`.
3. **No mantener relojes duplicados para spritesheets.** Usar `SharedSpriteAnimationController`.
4. **No implementar otro tema de UI.** Extender el uso de `PixelUITheme`; añadir una variante compartida si el estado se repite en varias pantallas.
5. **Mantener aislado lo que sí cambia.** Física, IA, navegación, clima, terreno, tiles, reglas de criatura y arte ambiental pueden pertenecer al reino o expedición.
6. **No consultar archivos en cada frame.** Resolver recursos durante carga/configuración y usar la caché. Las rutas ausentes también quedan cacheadas; cuando una herramienta del editor crea o reemplaza un recurso en caliente, debe invalidar esa ruta con `SharedAssetLibrary.invalidar(ruta)`.
7. **No duplicar PNG para crear una variante visual.** Reutilizar el mismo recurso con orientación, escala, modulación o configuración, salvo que el arte realmente sea distinto.

## Restricciones de rendimiento

- Carga diferida: solo se solicitan los recursos que la entidad o interfaz necesita.
- Caché negativa de rutas ausentes; las referencias positivas son débiles y no fijan texturas en memoria. `ResourceLoader` mantiene su propio caché.
- Sin `ResourceLoader.load`, `ResourceLoader.exists` o enumeración de carpetas dentro de `_process` o `_physics_process`.
- Sin recrear sprites de equipo en cada cambio de frame; se conservan los nodos de cada mano.
- Sin recalcular capas de apariencia si el diccionario no cambió.
- Sin alterar IA o física de las criaturas al compartir únicamente su presentación.

## Estado de esta migración

- La escena de jugador de Saltus instancia ahora `scenes/characters/player_visual.tscn`.
- El jugador normal y Saltus usan `PlayerVisualController` para piel, equipo y animaciones visuales.
- La apariencia de creación, el render del jugador y los NPC humanos de respaldo obtienen la textura base a través de `CharacterAppearance`.
- El equipamiento y los iconos utilizan la caché común de recursos.
- Las criaturas del mundo libre y las criaturas 2D de Saltus usan `SharedSpriteAnimationController` para spritesheets.
- `PixelUITheme` cachea sus estilos y deja de imponer un panel de fondo genérico.
- La física, el comportamiento, la IA, el contenido del mundo y el canon permanecen separados de esta capa de presentación.

La migración es una consolidación de código y referencias; requiere una comprobación de ejecución en Godot para validar pivotes, offsets, capas, orientación y timing en cada escena.
