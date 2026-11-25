# Saltus — arquitectura del mundo interconectado

## Decisiones

- Saltus es un único mundo continuo; las habitaciones son unidades lógicas y de diseño, no pantallas de carga.
- Las habitaciones se identifican por un ID estable y un rectángulo en coordenadas globales.
- Las conexiones relacionan habitaciones y pueden ser bidireccionales, unidireccionales o exigir una habilidad/condición.
- El mapa descubre habitaciones progresivamente.
- Los descubrimientos y desbloqueos se serializan para integrarlos con el guardado de la partida.
- El streaming futuro cargará/descargará módulos por proximidad sin interrumpir el desplazamiento visible.

## Primera base implementada

- `saltus_room_definition.gd`: identidad, región, límites y etiquetas de habitación.
- `saltus_world_connection.gd`: conexión, dirección y requisito de acceso.
- `saltus_world_graph.gd`: búsqueda espacial, descubrimiento, consulta de salidas, validación de requisitos y persistencia del progreso.
- `tests/world/test_saltus_world_graph.gd`: pruebas del grafo, requisitos, direccionalidad y restauración.

## Contrato de integración

1. El jugador y la cámara se mantienen en coordenadas globales.
2. El sistema detecta la habitación lógica actual mediante la posición global del jugador.
3. Al entrar en una habitación nueva, se registra su descubrimiento.
4. Las salidas consultan el grafo y las habilidades/flags del jugador antes de permitir el paso.
5. Los módulos cercanos permanecen cargados; el streaming no debe provocar una pantalla negra ni reiniciar al jugador.
6. Los mecanismos, objetos, criaturas y descansos guardan estado por ID estable, nunca por el orden de carga.

## Migración del Saltus actual

La escena horizontal existente se conserva durante esta primera fase. No se cambia todavía el TileMap, la cámara, las criaturas ni los fondos. La siguiente fase debe construir un prototipo vertical conectado con los assets actuales y verificar el movimiento continuo antes de migrar el escenario completo.
