# Saltus — arquitectura del mundo interconectado

## Decisiones

- Saltus es un único mundo continuo; las habitaciones son unidades lógicas y de diseño, no pantallas de carga.
- Las habitaciones se identifican por un ID estable y un rectángulo en coordenadas globales.
- Las conexiones relacionan habitaciones y pueden ser bidireccionales, unidireccionales o exigir una habilidad/condición.
- El mapa descubre habitaciones progresivamente.
- Los descubrimientos y desbloqueos se serializan para integrarlos con el guardado de la partida.
- El streaming futuro cargará/descargará módulos por proximidad sin interrumpir el desplazamiento visible.

## Primer sector implementado

La escena `expedicion_saltus.tscn` mantiene una única escena y una sola coordenada global para el jugador y la cámara. El sector inicial ahora contiene:

- **Claro central:** zona de inicio, descansadero y cruces de superficie.
- **Arboleda vertical:** ruta escalonada por plataformas, con ascenso hasta las copas y retorno por plataformas inferiores.
- **Raíces profundas:** galerías bajo el claro, accesibles por una caída controlada. Una escalera de plataformas permite regresar a la superficie por otra ruta.
- **Copa oriental:** extensión elevada al este de Raíces, descubierta al cruzar el paso sellado.
- **Paso sellado:** una barrera vertical separa Raíces de Copa oriental. El núcleo se encuentra en una plataforma alta de Arboleda; recogerlo abre el paso y registra la habilidad de prototipo `impulso_aereo`.
- **Descansos y caída:** hay puntos de descanso en Claro y Raíces. Caer fuera del límite inferior devuelve al último punto activado.

El Impulso Aéreo habilita un dash adicional durante el salto. El núcleo y la habilidad son contenido de prototipo para validar exploración y desbloqueos; su nombre, comportamiento definitivo y adquisición siguen sujetos al diseño de habilidades de Saltus.

## Primera base técnica

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

## Límites de esta primera implementación

- El terreno y las plataformas se generan en la escena actual; todavía no hay streaming por proximidad.
- El mapa visual progresivo y su integración con el guardado general aún no están conectados.
- El núcleo ya activa el dash aéreo adicional y abre la barrera física; la persistencia de esa habilidad todavía no está conectada al guardado general.
- El equilibrio de saltos, distancias, colisiones y cámara debe verificarse ejecutando el juego.

## Siguiente fase

Probar en Godot el recorrido completo: Claro → Arboleda → Raíces → escalera de retorno; después alcanzar el núcleo en Arboleda, volver a Raíces y abrir el paso hacia Copa oriental. Verificar que el jugador no pueda rodear la barrera por arriba o abajo, y ajustar alturas/distancias antes de ampliar el mundo.
