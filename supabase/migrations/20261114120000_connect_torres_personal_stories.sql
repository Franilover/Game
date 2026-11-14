-- Conecta las cadenas personales de Torres mediante un acontecimiento comunitario.
-- La carreta de harina ya existe en la introducción y la misión ayuda_horno_elian.
-- Añade temas progresivos a cada NPC sin reemplazar contenido existente.
-- Esta migración se prepara en Git; no se aplica a Supabase automáticamente.

WITH contenido(nombre, temas) AS (
  VALUES
  ('Elian', $elian$
  [
    {
      "clave":"carreta_apoyo_torres",
      "texto":"Hablar de cómo ayudó el resto de Torres con la entrega",
      "jugador":"Al final, parece que no fuiste el único que tuvo que adaptarse por el retraso de la carreta.",
      "respuesta":"No, y eso me hizo pensar. Darven confirmó por dónde venía la carreta, Saira consiguió noticias del conductor y Bruna revisó la rueda cuando llegó. Narel también estuvo comprobando qué pudo dañarla. Cada uno aportó algo distinto.",
      "respuesta_repetida":"Me alegra que aquella entrega terminara siendo un esfuerzo compartido. A veces uno se concentra tanto en resolver su parte que olvida cuánta gente está sosteniendo las demás.",
      "evento":"compartir_conocimiento",
      "importancia":4,
      "requiere_tema":"repartir_tareas",
      "variantes_actitud":[
        {"prioridad":20,"requisito_social":{"afecto_min":20},"respuesta":"Me sentí acompañado, la verdad. No tuve que pedirle a todo el mundo que dejara lo suyo; cada uno se acercó cuando pudo. Me gustaría que pudiéramos hacer eso más seguido, sin esperar a que haya un problema."},
        {"prioridad":10,"requisito_social":{"respeto_min":30},"respuesta":"Fue una buena coordinación. Darven confirmó los hechos, Saira aportó información del camino, Bruna revisó la rueda y Narel examinó el desgaste. No dependimos de una sola suposición."}
      ]
    },
    {
      "clave":"hornada_compartida",
      "texto":"Preguntar qué hizo con la harina cuando llegó",
      "jugador":"¿Qué terminaste haciendo con la harina de aquella carreta?",
      "respuesta":"Pude completar los pedidos, aunque cambié el orden de trabajo. Guardé una parte para preparar una hornada pequeña y compartirla con quienes ayudaron. No era una recompensa; simplemente quería que todos probaran el resultado de aquel esfuerzo.",
      "respuesta_repetida":"Todavía recuerdo esa hornada. No fue la más grande ni la más perfecta, pero me gustó que terminara reuniendo a varias personas alrededor de algo sencillo.",
      "evento":"apoyar",
      "importancia":4,
      "requiere_tema":"carreta_apoyo_torres",
      "variantes_actitud":[
        {"prioridad":20,"requisito_social":{"afecto_min":25},"respuesta":"También guardé una pieza para ti. No quería convertirlo en una ceremonia, sólo agradecerte que estuvieras pendiente cuando las cosas se complicaron."},
        {"prioridad":10,"requisito_social":{"amistad_min":30},"respuesta":"La compartí con Bruna, Darven, Saira y Narel cuando coincidimos. Fue agradable verlos hablar de algo que no fuera su trabajo por un rato."}
      ]
    }
  ]$elian$::jsonb),
  ('Bruna', $bruna$
  [
    {
      "clave":"revision_rueda_entrega",
      "texto":"Preguntar qué encontró al revisar la rueda de la carreta",
      "jugador":"¿Pudiste revisar la rueda de la carreta que traía la harina?",
      "respuesta":"Sí. El daño era compatible con el tramo irregular que recorrió. No vi señales de manipulación; el eje recibió más presión de la que debía y la rueda terminó cediendo. Le expliqué a Darven qué conviene revisar antes de que otra carreta pase por allí.",
      "respuesta_repetida":"La rueda quedó reparada, pero también recomendé revisar el eje y no cargar tanto peso de un solo lado. Cambiar una pieza sin corregir la causa sólo aplaza el siguiente problema.",
      "evento":"compartir_conocimiento",
      "importancia":4,
      "requiere_tema":"herramienta_terminada",
      "variantes_actitud":[
        {"prioridad":20,"requisito_social":{"confianza_min":25},"respuesta":"Narel me enseñó sus anotaciones del camino y Darven explicó dónde se detuvo la carreta. Con esa información pude revisar el daño sin desmontar piezas a ciegas. Fue útil trabajar con gente que presta atención."},
        {"prioridad":10,"requisito_social":{"respeto_min":35},"respuesta":"La inspección fue suficiente para descartar una reparación improvisada. El desgaste coincidía con el terreno y la distribución de la carga; no hay motivo para inventar una causa más complicada."}
      ]
    },
    {
      "clave":"mejora_camino_carretas",
      "texto":"Preguntar si propuso algún cambio para evitar otro daño",
      "jugador":"¿Les propusiste alguna forma de evitar que vuelva a pasar?",
      "respuesta":"Sí. Le señalé a Darven el tramo que necesita revisión y preparé una pieza de refuerzo que puede llevarse como repuesto. No voy a prometer que una rueda nunca volverá a romperse, pero podemos reducir las posibilidades.",
      "respuesta_repetida":"El repuesto ya está listo y Darven sabe qué tramo vigilar. Ahora falta comprobar si el mantenimiento se hace con regularidad, no sólo después de un problema.",
      "evento":"apoyar",
      "importancia":4,
      "requiere_tema":"revision_rueda_entrega",
      "variantes_actitud":[
        {"prioridad":20,"requisito_social":{"amistad_min":25},"respuesta":"Elian se ofreció a guardar el repuesto en un lugar seco y Saira dijo que avisaría a los comerciantes que usan esa ruta. No está mal cuando la gente se organiza sin que nadie tenga que dar órdenes."},
        {"prioridad":10,"requisito_social":{"respeto_min":40},"respuesta":"La propuesta es sencilla: revisar el tramo, distribuir mejor la carga y llevar una pieza compatible. Prefiero una solución práctica que pueda mantenerse."}
      ]
    }
  ]$bruna$::jsonb),
  ('Darven', $darven$
  [
    {
      "clave":"informe_carreta_torres",
      "texto":"Preguntar qué averiguó finalmente sobre la carreta",
      "jugador":"¿Qué conclusión sacaste después de hablar con todos los que revisaron la carreta?",
      "respuesta":"La información coincide. El conductor tuvo que tomar un tramo irregular y la rueda cedió por la carga. Saira confirmó el recorrido que le comunicaron, Bruna examinó la pieza y Narel comparó las condiciones del camino. No encontramos indicios de una amenaza.",
      "respuesta_repetida":"El informe quedó cerrado como un incidente de transporte. Mantendremos la revisión del tramo, pero no hay razón para alarmar a los vecinos con sospechas que no se sostienen.",
      "evento":"compartir_conocimiento",
      "importancia":4,
      "requiere_tema":"nueva_ronda",
      "variantes_actitud":[
        {"prioridad":20,"requisito_social":{"confianza_min":30},"respuesta":"Me tranquilizó poder contrastarlo con ellos. Bruna no exagera un desperfecto, Narel distingue observación de hipótesis y Saira conoce bien a quienes recorren esas rutas. Pude confiar en sus aportes."},
        {"prioridad":10,"requisito_social":{"respeto_min":35},"respuesta":"Las versiones coinciden con la evidencia material. El caso no justifica una investigación mayor. La vigilancia debe centrarse en prevenir otro accidente, no en buscar culpables sin fundamento."}
      ]
    },
    {
      "clave":"acuerdo_mantenimiento_ruta",
      "texto":"Preguntar si se organizó una revisión del camino",
      "jugador":"¿Llegaron a un acuerdo para revisar ese tramo del camino?",
      "respuesta":"Sí. Bruna indicó qué piezas conviene llevar como repuesto, Narel dejó registradas las condiciones que observó y Saira avisará a quienes viajen por allí. Yo organizaré una revisión periódica. No hace falta convertirlo en una operación; basta con que cada uno cumpla su parte.",
      "respuesta_repetida":"La revisión se está haciendo. Es un cambio pequeño, pero prefiero una rutina que podamos sostener a una respuesta apresurada que se olvide en unos días.",
      "evento":"apoyar",
      "importancia":4,
      "requiere_tema":"informe_carreta_torres",
      "variantes_actitud":[
        {"prioridad":20,"requisito_social":{"amistad_min":25},"respuesta":"Elian incluso se ofreció a preparar algo para quienes participen en la próxima revisión. No es necesario, pero ese tipo de gesto ayuda a que el trabajo compartido no se sienta como una obligación."},
        {"prioridad":10,"requisito_social":{"respeto_min":40},"respuesta":"Quedaron responsabilidades concretas: mantenimiento, observación del terreno, avisos a viajeros y control de la ruta. Así podemos comprobar si el acuerdo funciona."}
      ]
    }
  ]$darven$::jsonb),
  ('Saira', $saira$
  [
    {
      "clave":"noticias_conductor_carreta",
      "texto":"Preguntar qué supo del conductor de la carreta",
      "jugador":"¿Tu contacto consiguió contarte qué pasó durante el viaje de la carreta?",
      "respuesta":"Sí. El conductor tuvo que desviarse porque el tramo habitual estaba peor de lo que esperaba. La carga se desplazó y la rueda sufrió. Darven ya tenía parte de esa información, pero mi contacto pudo confirmar el recorrido y avisar a otros comerciantes para que fueran con cuidado.",
      "respuesta_repetida":"Mi contacto sigue usando esa ruta, aunque ahora sabe que debe revisar la carga antes de cruzar el tramo. Me pidió que le avise si Darven confirma alguna mejora.",
      "evento":"compartir_conocimiento",
      "importancia":4,
      "requiere_tema":"elegir_quedarse",
      "variantes_actitud":[
        {"prioridad":20,"requisito_social":{"confianza_min":25},"respuesta":"Me gustó que esta vez la noticia no fuera sólo un intercambio comercial. Pude ayudar a alguien que conozco y, de paso, aportar algo útil a la gente de aquí. Empiezo a entender por qué me apetece quedarme."},
        {"prioridad":10,"requisito_social":{"amistad_min":30},"respuesta":"Fue una buena ocasión para conectar a personas que normalmente sólo se cruzan de pasada. Darven necesitaba datos fiables y mi contacto necesitaba saber que alguien revisaría el camino."}
      ]
    },
    {
      "clave":"ruta_mas_segura",
      "texto":"Preguntar si los viajeros recibieron el aviso",
      "jugador":"¿Pudiste avisar a los demás comerciantes sobre el camino?",
      "respuesta":"Sí. Ya compartí el aviso con quienes suelen pasar por Torres. Bruna preparó un repuesto, Darven organizó revisiones y Narel dejó constancia de las condiciones del terreno. No todos viajan por el mismo motivo, pero todos necesitan llegar sin perder mercancía ni tiempo.",
      "respuesta_repetida":"El aviso sigue circulando entre los comerciantes. Me han llegado preguntas sobre el estado del camino, así que parece que la información está siendo útil.",
      "evento":"apoyar",
      "importancia":4,
      "requiere_tema":"noticias_conductor_carreta",
      "variantes_actitud":[
        {"prioridad":20,"requisito_social":{"afecto_min":20},"respuesta":"También conté que Elian consiguió completar sus pedidos. Me hizo gracia: al final una carreta retrasada terminó dándonos una razón para conocernos un poco mejor."},
        {"prioridad":10,"requisito_social":{"respeto_min":30},"respuesta":"La información se transmitió sin exageraciones: tramo irregular, carga desplazada y revisión en curso. Un aviso claro es más útil que una historia adornada."}
      ]
    }
  ]$saira$::jsonb),
  ('Narel', $narel$
  [
    {
      "clave":"analisis_dano_carreta",
      "texto":"Preguntar qué concluyó al comparar sus observaciones",
      "jugador":"¿Qué descubriste al comparar tus notas con la revisión de Bruna?",
      "respuesta":"Que el daño no necesitaba una explicación extraordinaria. Las marcas del eje y la distribución de la carga coinciden con el tramo irregular que señaló Darven. La información del conductor que consiguió Saira también encaja con esa secuencia. Mi primera tarea fue comprobar si los datos coincidían, no buscar una hipótesis llamativa.",
      "respuesta_repetida":"Conservé las observaciones y añadí la conclusión de Bruna. Es importante registrar también los casos en que una explicación sencilla basta.",
      "evento":"compartir_conocimiento",
      "importancia":4,
      "requiere_tema":"limite_investigacion",
      "variantes_actitud":[
        {"prioridad":20,"requisito_social":{"confianza_min":25},"respuesta":"Me sentí más cómodo trabajando con ellos de lo que esperaba. Bruna fue precisa con el daño, Darven aportó el recorrido y Saira consiguió una segunda fuente. No tuve que defender una hipótesis; sólo revisar lo que sabíamos."},
        {"prioridad":10,"requisito_social":{"respeto_min":35},"respuesta":"La coincidencia entre evidencia material, recorrido y testimonio es suficiente para la conclusión actual. No demuestra que todos los tramos sean seguros, pero explica este incidente concreto."}
      ]
    },
    {
      "clave":"registro_compartido_ruta",
      "texto":"Preguntar si compartió sus notas con los demás",
      "jugador":"¿Dejaste tus observaciones disponibles para que los demás puedan consultarlas?",
      "respuesta":"Sí. Preparé un registro breve para Darven y una copia para Saira, con las condiciones observadas y los límites de la conclusión. Bruna añadió las especificaciones de la pieza dañada. Es un registro compartido, no una teoría definitiva.",
      "respuesta_repetida":"El registro se actualizó con las últimas revisiones. Si cambian las condiciones del camino, podremos comparar los datos en lugar de depender de recuerdos imprecisos.",
      "evento":"apoyar",
      "importancia":4,
      "requiere_tema":"analisis_dano_carreta",
      "variantes_actitud":[
        {"prioridad":20,"requisito_social":{"amistad_min":25},"respuesta":"Elian también pidió una copia sencilla para saber cuándo conviene esperar una entrega. Me pareció una buena idea: la información tiene más valor cuando puede ayudar a alguien fuera de mi investigación."},
        {"prioridad":10,"requisito_social":{"respeto_min":40},"respuesta":"Separé observaciones, testimonios e inferencias. Cualquiera que consulte el documento podrá distinguir qué está comprobado y qué tendría que revisarse de nuevo."}
      ]
    }
  ]$narel$::jsonb)
),
objetivos AS (
  SELECT pg.id AS personaje_game_id, c.temas
  FROM contenido c
  JOIN public.personajes p ON lower(p.nombre) = lower(c.nombre)
  JOIN public.personajes_game pg ON pg.personaje_id = p.id
),
cambios AS (
  SELECT dg.id AS dialogo_id,
    jsonb_set(
      dg.dialogo,
      '{temas_conversacion}',
      coalesce(dg.dialogo->'temas_conversacion', '[]'::jsonb) || agregados.nuevos,
      true
    ) AS dialogo_actualizado
  FROM public.dialogos_game dg
  JOIN objetivos o ON dg.personaje_id = o.personaje_game_id
  CROSS JOIN LATERAL (
    SELECT coalesce(jsonb_agg(nuevo ORDER BY nuevo->>'clave'), '[]'::jsonb) AS nuevos
    FROM jsonb_array_elements(o.temas) AS nuevo
    WHERE NOT EXISTS (
      SELECT 1
      FROM jsonb_array_elements(coalesce(dg.dialogo->'temas_conversacion', '[]'::jsonb)) AS existente
      WHERE existente->>'clave' = nuevo->>'clave'
    )
  ) agregados
  WHERE dg.clave = 'principal'
    AND dg.activo
    AND jsonb_typeof(dg.dialogo) = 'object'
    AND jsonb_array_length(agregados.nuevos) > 0
)
UPDATE public.dialogos_game dg
SET dialogo = cambios.dialogo_actualizado
FROM cambios
WHERE dg.id = cambios.dialogo_id;
