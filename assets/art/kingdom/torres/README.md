# Sprites del Reino de Torres

El cargador de `scripts/world/reino_torres.gd` busca sprites aquí:

`res://assets/art/kingdom/torres/`

Puedes agregar PNG con transparencia. Se recomienda pixel art, fondo transparente y dimensiones coherentes; el juego conserva el filtrado nearest-neighbor.

## Estructura y nombres reconocidos

```
assets/art/kingdom/torres/
├── castillo.png
├── casas/
│   ├── panaderia.png
│   ├── posada.png
│   ├── vivienda_mason.png
│   ├── casa_oriente_a.png
│   ├── casa_oriente_b.png
│   ├── casa_oriente_c.png
│   ├── casa.png
│   ├── vivienda.png
│   ├── vivienda_oeste_01.png ... vivienda_oeste_11.png
└── edificios/
    ├── forja.png
    ├── establos.png
    ├── archivo_real.png
    ├── sala_consejo.png
    ├── casa_estudio.png
    ├── casa_comercio.png
    ├── alojamiento.png
    ├── cuartel.png
    ├── registro.png
    ├── reparaciones.png
    ├── almacen.png
    ├── carpinteria.png
    ├── granero.png
    ├── molino.png
    ├── aguas.png
    ├── corrales.png
    ├── casa_granjeros.png
    ├── semillas.png
    ├── telares.png
    ├── alfareria.png
    ├── banos.png
    ├── taller.png
    ├── posada.png
    └── edificio.png
```

## Reglas

- El cargador intenta primero el archivo específico de cada edificio, incluidas las 11 viviendas del barrio oeste (`casas/vivienda_oeste_01.png` a `casas/vivienda_oeste_11.png`).
- Si falta, prueba las alternativas genéricas definidas en el script (por ejemplo, `casas/casa.png` o `edificios/edificio.png`).
- Si tampoco encuentra una imagen, genera automáticamente una textura pixel-art propia para ese edificio; ya no depende de los polígonos planos de placeholder para verse correctamente.
- Cuando encuentra un sprite, oculta únicamente las formas visuales de ese edificio; las colisiones y los rótulos se conservan.
- El sprite se ajusta automáticamente dentro del tamaño objetivo definido para cada edificio, sin deformar su proporción.
- El generador `scripts/world/torres_pixel_art.gd` crea fachadas, tejados, ventanas, puertas y detalles por oficio a baja resolución. También rasteriza el césped, caminos, plaza, canal, muros, campos, árboles y puestos con filtrado nearest.
- El generador es determinista y no necesita paquetes ni imágenes externas. Añadir un PNG específico sigue teniendo prioridad, de modo que se pueden reemplazar partes por arte hecho a mano sin cambiar el código.
- Para cambiar el tamaño o la posición de un sprite, modifica el registro correspondiente en `SPRITE_BUILDINGS` dentro de `scripts/world/reino_torres.gd`.

Los nombres deben coincidir exactamente con los de la lista. No hace falta editar la escena cada vez que se añade una imagen.
