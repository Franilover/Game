# Auditoría inicial: Main y composición del runtime

**Fecha:** 2026-11-19  
**Rama:** `feat/npc-relational-memory-decay`  
**Archivo:** `scripts/world/main.gd`  
**Estado:** análisis estático; sin cambios funcionales en Main.

## 1. Tamaño y responsabilidad

`main.gd` contiene 2.426 líneas y 78 funciones. Es el punto de composición del runtime: conecta sistemas de la escena, servicios globales, datos del mundo y jugador. Parte de esa responsabilidad es legítima; no conviene convertirlo en un script que implemente cada sistema, ni fragmentarlo en muchos helpers que solo reenvíen llamadas.

La escena `scenes/world/main.tscn` ya declara explícitamente jugador, cámara, ZoneManager, UI, WorldAtmosphere, ClimateSystem, WorldContext, GameplayInputRouter, WorldItems, InteractionSystem, CombatSystem, DialogueSystem, IUMRepository e IUMManager. Esta composición editable debe conservarse.

## 2. Grupos funcionales

| Rango aproximado | Responsabilidad | Observación |
|---|---|---|
| 71–245 | Arranque, dependencias, carga de datos y servidor dedicado | Punto central de inicialización; depende de autoloads y señales |
| 246–420 | Input, cambio de reino, viajes y detección de descubrimientos | Coordina navegación y estado de GameState |
| 421–693 | Cambio de zona y configuración del runtime | Es el composition root principal; enlaza muchos sistemas |
| 694–1090 | Retirada, deduplicación y materialización de NPC de Torres | Alta dependencia de WorldData, GameState, relaciones, horarios e interiores |
| 1102–1428 | Bienvenida inicial, tour de Elian y rutinas | Contenido narrativo y coreografía de NPC |
| 1429–1604 | Restauración de Garumis, cámara y arena de combate | Coordina subsistemas de gameplay |
| 1605–1713 | Configuración de HUD, interacción, combate, input, inventario y diálogo | Adaptadores de dependencias; responsabilidad apropiada para Main |
| 1714–2258 | Eventos y cola de cinemáticas de proximidad | Bloque grande con políticas de prioridad, caducidad, elegibilidad y ejecución |
| 2259–2317 | Admin, pantalla y diagnóstico de ventana | El diagnóstico de ventana está siempre programado al iniciar |
| 2322–2426 | IUM, recompensas de misiones y relaciones sociales | Mezcla adaptadores de UI con callbacks de sistemas |

## 3. Contratos que deben mantenerse

- `Main` es la raíz de `scenes/world/main.tscn`; el jugador está en `Entities/Player` y los sistemas se encuentran en `Systems`.
- `ZoneManager.zona_cambiada` llama a `_al_cambio_de_zona`; este prepara generadores, contexto, límites de cámara, clima y UI según el tipo de zona.
- `WorldData.mundo_listo` y `mundo_actualizado` disparan la materialización de NPC en Torres.
- Los NPC de Torres se identifican mediante `torres_game_npc`; deduplicación y retirada eliminan también `interactable` antes de diferir `queue_free()`.
- `NPCScheduleSystem` y `NPCConversationSystem` se instancian dinámicamente como hijos de Main y reciben dependencias explícitas.
- `CutsceneDirector` ejecuta las secuencias; Main recibe sus señales y mantiene la cola de solicitudes de proximidad.
- La cola protege escenas narrativas de menor prioridad, aplica caducidades distintas a eventos opcionales y espera a que jugador, cámara, zona, NPC y diálogo permitan ejecutar.
- La configuración de IUM, inventario, HUD, misiones y relaciones utiliza instancias de la escena y autoloads; no debe duplicar su estado en Main.

## 4. Candidatos de mejora y riesgo

### Candidato A: diagnóstico de ventana
**Riesgo bajo.** `_diagnostico_ventana_diferido()` y `_registrar_diagnostico_ventana()` solo consultan DisplayServer y escriben logs. Se puede convertir en diagnóstico opt-in o restringirlo a builds de depuración. Antes hay que confirmar que los logs no forman parte de una herramienta de soporte activa.

### Candidato B: sistemas NPC creados dinámicamente
**Riesgo medio.** Main instancia dos nodos con scripts conocidos y les inyecta dependencias. Podrían declararse en `main.tscn` para que su composición sea visible/editable, pero antes hay que verificar si dependen de ser hijos directos de Main y conservar el orden de configuración.

### Candidato C: cola de cinemáticas de proximidad
**Riesgo alto.** Es una unidad funcional diferenciable, pero depende de métodos de Main, del ZoneManager, del estado interior de Torres, de metadatos de NPC y del CutsceneDirector. No extraerla hasta definir una interfaz de callbacks y pruebas para prioridad, deduplicación, caducidad, participantes y cancelación.

### Candidato D: materialización de NPC
**Riesgo alto.** Mantiene identidad, persistencia y compatibilidad entre habitantes canónicos y locales. No es seguro dividirla solo por longitud.

## 5. Conclusión

Main debe permanecer como composition root, pero no debería absorber reglas internas de NPC, cinemáticas o gameplay. La primera oportunidad de mejora es revisar si los dos sistemas NPC deben declararse en la escena, manteniendo su inyección de dependencias. La cola de cinemáticas y la materialización requieren contratos y pruebas antes de extraerlas.

No se ha confirmado código muerto en Main. Los métodos privados pueden recibir señales, llamadas diferidas o callbacks; cualquier eliminación requiere rastrear referencias estáticas y dinámicas.

## 6. Validación

Esta auditoría se basa en el script y la escena del repositorio. No se ha ejecutado un refactor de Main ni se han cambiado escenas, autoloads o datos de Supabase.
