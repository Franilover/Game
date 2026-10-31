# Mundo global multijugador

## Arquitectura

Garlia usa un solo proceso de servidor dedicado como autoridad del mundo. Los jugadores se conectan al mismo dominio y puerto; no crean salas ni actúan como anfitriones.

- **Transporte:** WebSocket sobre TLS (wss://). La sesión de Supabase se transmite únicamente dentro del canal cifrado.
- **Identidad:** el servidor comprueba el bearer token con Supabase Auth, obtiene el nombre del perfil y valida la especie elegida contra el catálogo jugable. Las capas visuales se filtran a rutas de recursos permitidas. El runtime de Eterium y sus reglas de especie se cargan desde Supabase usando la sesión autenticada y se aplican en el servidor.
- **Límite actual:** 8 jugadores conectados.
- **Movimiento:** el cliente envía dirección, carrera, salto, dash y sprint de Eterium; el servidor calcula el movimiento y publica posición, orientación, estado de animación y estado vital. La identidad visual y la especie se envían por mensajes fiables al entrar; los snapshots periódicos llevan solo estado dinámico.
- **Acciones:** las acciones primaria y secundaria se envían al servidor. En esta fase el servidor resuelve combate desarmado y acciones contextuales que no requieran modificar inventario. El input de movimiento se descarta si deja de renovarse durante 300 ms, y las acciones tienen un límite por jugador.
- **Zonas, calendario, criaturas y props:** descubrimientos y viajes se validan/ejecutan en el servidor; los desbloqueos confirmados se difunden a todos los clientes y el reloj global se entrega en el handshake y se corrige periódicamente. Las criaturas y WorldProp materializados en chunks activos se replican por clave determinista de zona/chunk/instancia; las definiciones se envían de forma fiable al entrar o al aparecer una entidad nueva, mientras que los snapshots frecuentes solo llevan estado dinámico compacto.
- **Datos:** cada usuario conserva su guardado personal local. El servidor guarda por zona la semilla, calendario, desbloqueos, estado runtime de criaturas y datos Garumi, además de la posición/datos runtime de WorldProp activos, en user://garlia_global_world.json.

## Certificado TLS requerido

El servidor no inicia WSS si no encuentra el certificado y la clave privada. Usa un certificado válido para el dominio al que se conectarán los jugadores. Por ejemplo, con Let's Encrypt:

- Certificado/cadena: /etc/letsencrypt/live/juego.example.com/fullchain.pem
- Clave privada: /etc/letsencrypt/live/juego.example.com/privkey.pem

La clave privada permanece únicamente en el servidor. No la copies al repositorio ni a los clientes. El cliente verifica el certificado y el nombre del dominio; no se usa TLS inseguro ni se omite la validación. Una IP directa solo funcionará si el certificado también incluye esa IP como SAN.

## Arranque

Desde la carpeta del proyecto:

~~~bash
godot --headless --path . -- --garlia-server --port=7777 \
  --tls-cert=/etc/letsencrypt/live/juego.example.com/fullchain.pem \
  --tls-key=/etc/letsencrypt/live/juego.example.com/privkey.pem
~~~

En el firewall y proveedor de hosting, permite **TCP 7777**. El transporte actual es WebSocket seguro, no ENet/UDP.

Los argumentos TLS son opcionales solo porque hay rutas predeterminadas. Sin argumentos, el servidor busca:

- user://certs/garlia_server.crt
- user://certs/garlia_server.key

Esas rutas deben existir en el directorio de datos de usuario de Godot del usuario que ejecuta el servidor. Para un despliegue real es preferible pasar las rutas de Let's Encrypt.

En el menú multijugador, introduce el dominio que aparece en el certificado y el puerto 7777. No escribas http:// ni ws://; el cliente construye la conexión wss://.

## Mundo vacío y reentrada

Cuando se desconecta el último jugador, el servidor escribe el estado global y pausa el árbol de escenas. El proceso y el socket WSS permanecen activos para aceptar una reconexión; al entrar un jugador, el árbol se reanuda.

Esto evita perder el mundo y permite volver sin arrancar otro proceso. **No apaga el VPS ni detiene el proceso del servidor.** El apagado real con reactivación automática requiere un supervisor/coordinador externo que no forma parte de este cambio.

El archivo user://garlia_global_world.json debe residir en almacenamiento persistente. Ejecuta una sola instancia de servidor sobre ese archivo; varias instancias producirían mundos divergentes y escrituras en conflicto. La persistencia guarda por zona las criaturas que el WorldEntityManager ya conoce, incluidos posición, velocidad, vida/muerte y progreso de Garumi. El guardado se realiza cada 15 segundos, antes de cambiar de zona y cuando se desconecta el último jugador. También captura las posiciones y los datos runtime de los WorldProp que siguen activos cuando se guarda o descarga un chunk. La eliminación/colección de recursos, drops y objetos colocados todavía no tiene sincronización ni persistencia global completa.

## Alcance de esta primera integración

Ya están conectados: servidor dedicado WSS, verificación de identidad, entrada de jugadores, límite de sesiones, validación de especie y carga del runtime de Eterium, movimiento autoritativo (andar/correr/salto/dash/sprint de Eterium), interpolación de jugadores, identidad visual sincronizada una sola vez, snapshots compactos de jugadores, réplicas de criaturas y WorldProp materializados en chunks activos, sincronización del calendario y desbloqueos de reinos, acciones de combate sin arma, interacciones contextuales sin inventario, viajes de zona, descubrimientos verificados, guardado global por zona y pausa del árbol cuando no quedan jugadores.

Todavía no es una simulación global completa de todos los objetos:

- El inventario, equipo, consumibles y colocación de objetos siguen en el guardado local y no tienen sincronización servidor-cliente.
- Las criaturas silvestres y WorldProp se emparejan por clave determinista. Si falta una instancia local, el servidor envía una definición fiable una sola vez y el cliente crea una réplica sin autoridad de IA. Los Garumis vinculados siguen siendo privados de cada jugador y quedan excluidos. Los snapshots periódicos no retransmiten los datos completos de las entidades. La recolección/desaparición y los drops todavía no tienen tombstones persistentes compartidos.
- El streaming del servidor sigue un centroide de jugadores; si el grupo se dispersa mucho, los chunks lejanos pueden no generarse en el servidor. Las réplicas de criaturas también se limitan a esos chunks activos.
- El movimiento y los snapshots se intercambian aproximadamente cada 50 ms (20 Hz) sobre WSS/TCP. Los clientes interpolan los snapshots, pero no hay predicción local. Al ir sobre TCP, la pérdida de paquetes puede retrasar los mensajes posteriores y sentirse como movimiento entrecortado. El salto se resuelve en servidor y su estado llega en snapshots.
- El servidor no replica el inventario personal: equipamiento, consumibles, herramientas, recolección, drops y colocación de objetos no están sincronizados ni validados como operaciones de red. La recolección está bloqueada en el modo global y el prompt la identifica como no sincronizada. Los sistemas de interacción del jugador remoto se crean sin inventario, y los WorldProp del servidor no reciben el inventario del jugador ancla.
- No se ha desplegado un servidor ni configurado un dominio/certificado real.

No se debe anunciar todavía como multijugador persistente terminado para público. La siguiente etapa técnica es sincronizar inventario individual con validación del servidor, implementar recolección/drops como operaciones autoritativas persistentes, ampliar el streaming para grupos dispersos y completar el inventario individual, la recolección/desaparición y los drops.
