# Saltus — expedición completa editable en Godot

La escena de trabajo es `scenes/world/expedicion_saltus.tscn`. El objetivo del constructor es guardar el escenario completo dentro de esa escena: terreno, colisiones, fondos, vegetación, criaturas, mecanismos, checkpoints y zona del primer jefe.

## Conversión inicial (una sola vez)

1. Actualiza la rama `work/design-and-architecture`.
2. Abre el proyecto en Godot.
3. Abre `scenes/world/expedicion_saltus.tscn` como escena activa.
4. En FileSystem abre `tools/editor/build_saltus_editable_map.gd`.
5. Ejecuta el EditorScript con **File → Run**.
6. El script organiza los nodos y guarda la misma escena `expedicion_saltus.tscn`.
7. Recarga la escena en el editor para ver el árbol completo.

No ejecutes el constructor sobre otra escena. Tampoco lo ejecutes otra vez después de personalizar Saltus: está diseñado para la conversión inicial y advierte si detecta que ya fue ejecutado.

## Árbol esperado

```text
ExpedicionSaltus
├── Player
├── Mapa
│   ├── TerrenoSaltusV2
│   ├── Terreno_*
│   └── Plataforma_*
├── Vegetacion
│   ├── FloraImpulsora_*
│   └── FlorDetectora_Tutorial
├── Criaturas
│   ├── Zlish_*
│   └── Flaxis_*
├── Mecanismos
│   ├── PuertaFlorDetectora
│   └── CorrienteAerea_*
├── PuntosDeControl
├── Fondos
├── Ambiente
└── ElementosTutorial
    ├── Indicacion_*
    └── ZonaPrimerJefe
```

Los nodos son instancias editables dentro de la escena. Puedes seleccionar y mover criaturas, plantas, checkpoints, puertas, corrientes, fondos y elementos de tutorial desde el viewport o el Inspector. El TileMapDual conserva sus celdas y recursos en la escena.

## Colisiones y cambios de terreno

Las colisiones del terreno y plataformas son nodos `StaticBody2D` independientes dentro de `Mapa`. Si pintas o borras tiles, ajusta también las colisiones correspondientes. Mover un objeto de vegetación o una criatura no requiere editar GDScript.

## Qué ocurre al iniciar el juego

`saltus_expedition.gd` ya no construye el escenario durante el juego. La escena serializada contiene el mundo; el script inicializa el grafo de regiones, progreso y cámara. Si ejecutas el juego antes de hacer la conversión inicial, aparecerá un error indicando que falta el contenido editable.
