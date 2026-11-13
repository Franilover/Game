# Misiones sociales: plantilla de implementación

## Flujo común

1. **Inicio en diálogo**: una variante condicionada por el estado `disponible` ofrece una acción `aceptar_mision` con `mision_clave`.
2. **Aceptación**: MissionManager cambia el estado local a `activa` y crea progreso vacío.
3. **Objetivos**: las definiciones vienen de `misiones_game` y `misiones_objetivos_game`. Las dependencias se expresan en `datos.requiere_objetivo_clave`.
4. **Seguimiento**: cada interacción registra el evento mediante MissionManager. El diálogo posterior consulta estado y progreso.
5. **Cierre**: el NPC presenta una variante condicionada por estado `completada`. Las acciones sociales se ejecutan desde DialogueSystem.
6. **Recompensas**: MissionManager emite `recompensa_disponible`; Main solicita la entrega al inventario. Las recompensas de objeto deben incluir una definición de runtime completa en `datos.item_data` (id, nombre, tipo, max_stack y propiedades_game). Si el inventario no puede recibirlas, el progreso no se marca como reclamado y se puede reintentar.
7. **Persistencia**: el estado, el progreso y `recompensas_reclamadas` se serializan en el archivo local de la partida. La reclamación no cambia el estado narrativo `completada`.

## Reglas

- Las recompensas se entregan una sola vez.
- La inserción de varios objetos es transaccional a nivel de inventario: si uno falla, se restaura el inventario anterior.
- Un tipo de recompensa no implementado o una definición de objeto incompleta mantiene la recompensa pendiente; nunca se descarta silenciosamente.
- No se inventan identificadores de objetos. Deben proceder del catálogo o de una definición validada.
- Las relaciones sociales son efectos narrativos separados del inventario y se aplican mediante `evento_social`.

## Aplicación a Elian

Misión: `ayuda_horno_elian` — Una hornada a tiempo.

- Hablar con Elian y aceptar ayudarle.
- Preguntar a Darven por la carreta de harina.
- Volver con Elian y contarle la respuesta.
- El diálogo de cierre aplica `promesa_cumplida` con un identificador estable.

La misión no tiene todavía un objeto de recompensa registrado. El cierre social constituye el reconocimiento narrativo actual. No se asigna un objeto arbitrario del catálogo solo para rellenar la tabla.

## Plantilla para Bruna

La variante de confianza ya presenta el conflicto: Bruna recibió una oferta de material cuya procedencia no le convence y pide investigar antes de trabajarlo.

Antes de registrar la misión definitiva, completar estos datos de diseño:

- Qué material concreto es y qué característica genera dudas.
- Qué evidencia puede encontrar el jugador y en qué lugar/NPC.
- Qué resultado verificable permite a Bruna decidir si acepta el encargo.
- Qué recompensa del catálogo corresponde al esfuerzo.
- Qué consecuencias sociales tiene entregar información cierta, incompleta o falsa.

Con esos datos, la misión reutiliza el mismo flujo: diálogo de aceptación, objetivos encadenados, diálogo de devolución, resolución social y recompensa reclamable. No debe inventar un material ni un origen sin respaldo del catálogo/lore.
