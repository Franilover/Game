# Hitos de preguntas personales

## Objetivo

Cada personaje tiene exactamente cuatro preguntas personales en `public.dialogos_game.dialogo.temas_conversacion`.
Todas usan `tipo: "preguntar"` y se desbloquean mediante cuatro hitos diferentes. Los temas `tipo: "hablar"` permanecen como conversación casual.

Godot comprueba y persiste el progreso; Supabase contiene los textos, las claves y la condición declarativa. No se crean preguntas de respaldo en GDScript.

## Contrato de datos

Cada una de las cuatro entradas conserva los campos habituales:

- `clave`: identificador estable y único por personaje.
- `tipo`: `preguntar`.
- `hito`: entero entre 1 y 4.
- `texto`: título de la opción.
- `jugador`: frase que dice el jugador.
- `respuesta`: respuesta base del NPC.
- `desbloqueo`: configuración de la condición.

Las respuestas pueden conservar los campos de variantes ya admitidos por el motor (por ejemplo, `variantes_actitud`, `respuestas_repetidas`). La selección de respuesta contextual se puede ampliar sin cambiar la identidad del hito.

### Hito 1 — Amistad máxima

```json
{
  "tipo": "preguntar",
  "hito": 1,
  "desbloqueo": {
    "tipo": "amistad_maxima",
    "amistad_min": 100
  }
}
```

Si se omite `amistad_min`, Godot usa 100.

### Hito 2 — Evento o descubrimiento

```json
{
  "tipo": "preguntar",
  "hito": 2,
  "desbloqueo": {
    "tipo": "evento_descubrimiento",
    "descubrimiento": "narel_viaje_antiguo"
  }
}
```

La clave es global, no está ligada al NPC con quien se conversa. Un diálogo o evento de cualquier personaje puede registrar el descubrimiento mediante el contexto de una acción social:

```json
{
  "tipo": "evento_social",
  "evento": "compartir_conocimiento",
  "evento_id": "revela_viaje_narel",
  "contexto": {
    "descubrimiento_clave": "narel_viaje_antiguo"
  }
}
```

También existe `RelationshipSystem.registrar_descubrimiento_social(clave, contexto)` para integraciones con misiones, exploración y eventos del mundo.

### Hito 3 — Regalo importante o devolución

Regalo:

```json
{
  "tipo": "preguntar",
  "hito": 3,
  "desbloqueo": {
    "tipo": "regalo_o_devolucion",
    "item_id": "objeto_recuerdo_narel"
  }
}
```

El regalo debe tener un registro real para ese NPC en el sistema social; no basta con entregar cualquier objeto. Para una devolución, la integración debe llamar a `RelationshipSystem.registrar_devolucion_importante(personaje_id, item_id, nombre_item)`.

### Hito 4 — Cierre de la historia personal

```json
{
  "tipo": "preguntar",
  "hito": 4,
  "desbloqueo": {
    "tipo": "cierre",
    "requiere_hitos": [1, 2, 3]
  }
}
```

Si se omite `requiere_hitos`, se exigen los hitos 1, 2 y 3.

## Comportamiento del menú

- `Hablar` sigue disponible desde el primer encuentro.
- `Preguntar` no aparece hasta que exista al menos una pregunta personal desbloqueada.
- Los temas personales antiguos sin `hito` quedan ocultos; no se asigna un hito por suposición.
- Los hitos 1, 2 y 3 se pueden conseguir en cualquier orden.
- El hito 4 se evalúa después de preparar los tres anteriores.
- Los desbloqueos se guardan en la relación del NPC dentro del guardado de la partida y no se pierden al cerrar el diálogo.

## Estado de implementación

- Implementado en Godot: evaluación y persistencia de los cuatro hitos, descubrimientos globales, coincidencia de regalo/devolución y ocultación de preguntas sin clasificar.
- Pendiente de contenido: clasificar exactamente cuatro preguntas por NPC en Supabase, con sus textos y sus claves reales de descubrimiento/objeto.
- Pendiente de integración: conectar los eventos concretos del mundo y las devoluciones de objetos a las dos funciones de registro descritas arriba.
- No se han modificado tablas ni filas de Supabase.
