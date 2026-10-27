# Sprites de Garumis

Guarda aquí los sprites creados para Garlia en PNG o SVG, con transparencia cuando corresponda.

El basename debe coincidir con el campo `asset_key` del registro en `garumis_game`, por ejemplo `<asset_key>.png`. Los sprites de esta carpeta se cargan de forma independiente de `assets/art/creatures/`.

`Oruvan.svg` es el sprite provisional usado para la prueba de presencia en Godot. Se renombró desde el prototipo de depuración para conectarlo al único Garumi marcado como canon para esta prueba. La forma abstracta actual **no es arte definitivo**; debe reemplazarse cuando se diseñe el sprite final de Oruvan.

En builds de depuración, si el catálogo `garumis_game` está vacío, el motor puede mostrar esta textura como fallback de prueba. En cuanto el catálogo remoto de Oruvan carga, la instancia canónica usa la misma clave `Oruvan`.
