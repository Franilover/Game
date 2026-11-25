# Saltus V2 — mapa de expedición

## Objetivo

Sustituir la distribución horizontal anterior por un recorrido continuo, vertical y ramificado. La escena conserva el jugador, fondos, criaturas, flores y sistemas de checkpoint, pero el terreno antiguo deja de construirse: `_ready()` llama a la geometría V2.

## Regiones

| Región | Coordenadas aproximadas | Función |
|---|---:|---|
| Entrada y claro | x 0–1050, y 0–700 | Inicio, salto y lectura del terreno |
| Sendero de parkour | x 850–1950, y 0–700 | Plataformas y primer uso obligatorio del dash para cruzar el gran hueco |
| Arboleda vertical | x 1850–4450, y -850–700 | Ascenso principal, ruta alta alternativa y descenso |
| Raíces profundas | x 1200–4200, y 650–1350 | Recorrido inferior con escalera de retorno |
| Cruce de copas | x 3600–5100, y -850–500 | Corrientes, plataformas elevadas y conexión hacia la salida |
| Claro del primer jefe | x 5000–6400, y 0–700 | Aproximación y arena vacía para diseñar el jefe posteriormente |

## Circuitos y retornos

- Entrada → sendero → arboleda → copas → claro del jefe.
- Sendero → raíces profundas → copas.
- Arboleda ↔ raíces profundas mediante una conexión lateral.
- La ruta superior de la arboleda asciende hasta una cresta de copas a más de 500 px sobre el suelo y desciende por otra vertiente.
- Tres shafts controlados desde el suelo superior permiten descubrir las galerías inferiores.
- Las raíces tienen una escalera de plataformas que permite regresar al nivel principal.
- Todos los enlaces del grafo son bidireccionales y no exigen habilidades futuras.

## Enseñanza integrada

1. **Salto:** primeras plataformas a poca altura desde el punto inicial.
2. **Parkour:** secuencia escalonada con plataformas a distintas alturas.
3. **Dash:** hueco entre el final del primer tramo de suelo y el siguiente; se conserva una plataforma de aproximación, no una escalera que permita evitar la prueba.
4. **Detectora:** flor visible junto a una puerta que abre un paso.
5. **Saltarina:** colocada en cruces y accesos verticales para enseñar el impulso.
6. **Combate:** Zlish en el sendero y Flaxis en las rutas elevadas, separados por progresión.
7. **Jefe:** arena despejada sin entidad ni lógica de combate todavía.

## Checkpoints

- Entrada.
- Final del primer tramo de enseñanza.
- Raíces profundas.
- Cruce de copas.
- Antes de la arena del jefe.

## Criterios de revisión dentro de Godot

- Recorrer el mapa desde el inicio hasta la arena sin quedar atrapado.
- Volver desde la arena por una ruta distinta y comprobar el regreso a las raíces y al claro.
- Probar el hueco de dash con el salto y el dash actuales.
- Confirmar que la escalera de raíces permite subir sin una habilidad no implementada.
- Revisar que los checkpoints estén apoyados sobre superficies y que sus posiciones no queden suspendidas.
- Verificar visualmente que la cámara acompaña tanto el ascenso como el descenso.
- Comprobar que las criaturas no aparezcan dentro de paredes o fuera de plataformas.

No se considera validado hasta ejecutar y recorrer la escena en Godot. El código mantiene el renderer dual y los fondos existentes, pero el nuevo terreno necesita una pasada visual y de colisiones en juego.
