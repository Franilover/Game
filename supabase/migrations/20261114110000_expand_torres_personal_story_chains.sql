-- Amplía las cadenas personales de los cinco habitantes de Torres.
-- Sólo añade temas que no existan; no reemplaza diálogos ni modifica otros datos.
-- Esta migración queda preparada en la rama y no se aplica a Supabase desde aquí.

WITH contenido(nombre, temas) AS (
  VALUES
  ('Elian', $elian$
  [
    {
      "clave":"prueba_compartida",
      "texto":"Preguntar si alguien probó la nueva receta",
      "jugador":"¿Pudiste compartir la nueva receta con los vecinos?",
      "respuesta":"Sí. Preparé una tanda pequeña y dejé que algunas personas la probaran. Hubo opiniones distintas, pero me gustó ver que se tomaban el tiempo de decirme qué cambiarían.",
      "respuesta_repetida":"La receta ya tiene una forma bastante estable. Todavía anoto los comentarios que me hacen; a veces una sugerencia sencilla mejora más que pasar horas intentando adivinar.",
      "evento":"interesarse",
      "importancia":3,
      "requiere_tema":"receta_resultado",
      "requisito_social":{"amistad_min":15},
      "variantes_actitud":[
        {"prioridad":20,"requisito_social":{"afecto_min":15},"respuesta":"Sí, y me hizo ilusión que la probaran. No era una gran ocasión, sólo una tanda pequeña, pero se sintió bonito compartir algo hecho con calma contigo cerca."},
        {"prioridad":10,"requisito_social":{"respeto_min":25},"respuesta":"Sí. Recibí críticas bastante concretas y eso me vino bien. Prefiero que me digan qué no funciona antes que felicitarme por compromiso."}
      ]
    },
    {
      "clave":"pedido_rechazado",
      "texto":"Preguntar por el pedido que decidió rechazar",
      "jugador":"La otra vez dijiste que te costaba rechazar pedidos. ¿Pudiste poner algún límite?",
      "respuesta":"Me pasó hace unos días. Alguien pidió más de lo que podía preparar a tiempo y, por primera vez, le dije que no. No fue agradable, pero habría sido peor prometer algo que sabía que no iba a cumplir.",
      "respuesta_repetida":"No ha sido fácil, pero estoy intentando ser claro desde el principio. Decir que no a tiempo también evita decepcionar a alguien después.",
      "evento":"interesarse",
      "importancia":4,
      "requiere_tema":"preocupacion_pedidos",
      "requisito_social":{"confianza_min":20},
      "variantes_actitud":[
        {"prioridad":20,"requisito_social":{"confianza_min":30},"respuesta":"Quería contártelo porque sé que no vas a pensar que me volví descuidado. Me importa cumplir, pero también estoy entendiendo que no puedo hacerlo todo sin ayuda."},
        {"prioridad":10,"requisito_social":{"amistad_min":20},"respuesta":"Todavía me cuesta un poco. Me preocupa que alguien se marche decepcionado, aunque sé que ser honesto es mejor que aceptar por quedar bien."}
      ]
    },
    {
      "clave":"repartir_tareas",
      "texto":"Preguntar cómo está organizando el trabajo",
      "jugador":"¿Has encontrado una forma de no cargar con todos los pedidos tú solo?",
      "respuesta":"Estoy probando a repartir algunas tareas y a dejar más claro qué puedo preparar cada día. No quiero que la panadería dependa de que yo esté corriendo de un lado a otro.",
      "respuesta_repetida":"La organización va mejor. Aún tengo días en que intento hacerlo todo por costumbre, pero ahora me doy cuenta antes y pido una mano.",
      "evento":"apoyar",
      "importancia":4,
      "requiere_tema":"pedido_rechazado",
      "requisito_social":{"confianza_min":30},
      "variantes_actitud":[
        {"prioridad":20,"requisito_social":{"afecto_min":20},"respuesta":"Me está ayudando más de lo que esperaba. También me ha dejado algo de tiempo para caminar después del trabajo. Creo que necesitaba recordar que mi vida no termina cuando apago el horno."},
        {"prioridad":10,"requisito_social":{"respeto_min":30},"respuesta":"Estoy organizando los turnos y los pedidos con más cuidado. No es una solución espectacular, pero es sostenible; prefiero eso a depender de un esfuerzo imposible."}
      ]
    }
  ]$elian$::jsonb),
  ('Bruna', $bruna$
  [
    {
      "clave":"mango_prototipo",
      "texto":"Preguntar por el prototipo de su herramienta",
      "jugador":"¿Cómo va el mango de la herramienta que estabas diseñando?",
      "respuesta":"Terminé un primer prototipo. El equilibrio es mejor, pero el mango todavía obliga a cerrar demasiado la mano. No voy a darlo por bueno sólo porque ya parezca terminado.",
      "respuesta_repetida":"He cambiado un poco la curva y ahora resulta más cómodo. Aún quiero probarlo durante un trabajo largo antes de decidir que está listo.",
      "evento":"compartir_conocimiento",
      "importancia":3,
      "requiere_tema":"proyecto_personal",
      "requisito_social":{"respeto_min":15},
      "variantes_actitud":[
        {"prioridad":20,"requisito_social":{"confianza_min":20},"respuesta":"Te lo enseño porque has demostrado que sabes escuchar antes de tocar algo. Si ves un problema, dímelo directamente; prefiero eso a que me sigas la corriente."},
        {"prioridad":10,"requisito_social":{"respeto_min":30},"respuesta":"El prototipo ya sirve para evaluar el equilibrio. Quiero una opinión técnica, no un cumplido. Si detectas una falla, señálala."}
      ]
    },
    {
      "clave":"ajuste_con_ayuda",
      "texto":"Preguntar si aceptó ayuda para probar la herramienta",
      "jugador":"¿Llegaste a probar el prototipo con alguien más?",
      "respuesta":"Sí. Dejé que otra persona lo usara durante un rato y detectó algo que yo había pasado por alto: el mango se desliza cuando hay polvo. Me habría ahorrado tiempo si hubiera pedido esa prueba antes.",
      "respuesta_repetida":"Ya incorporé el ajuste antideslizante. No significa que vaya a entregar el diseño sin revisarlo, pero ahora sé qué debía corregir.",
      "evento":"interesarse",
      "importancia":4,
      "requiere_tema":"mango_prototipo",
      "requisito_social":{"confianza_min":20},
      "variantes_actitud":[
        {"prioridad":20,"requisito_social":{"confianza_min":30},"respuesta":"Me costó dejar que alguien más lo probara. Al final fue útil, y no pasó nada por admitir que otra persona podía notar algo que yo no."},
        {"prioridad":10,"requisito_social":{"respeto_min":30},"respuesta":"La prueba confirmó un defecto concreto. Corregirlo fue sencillo una vez que alguien lo señaló. El mérito está en comprobarlo, no en fingir que lo sabía desde el principio."}
      ]
    },
    {
      "clave":"herramienta_terminada",
      "texto":"Preguntar si terminó su herramienta personal",
      "jugador":"¿Al final conseguiste terminar la herramienta para ti?",
      "respuesta":"Sí. La terminé y la he usado varios días. No es perfecta, pero cumple lo que necesitaba. Me alegra haber reservado tiempo para hacer algo que no era un encargo.",
      "respuesta_repetida":"Sigue funcionando bien. Creo que lo mejor del proyecto fue aprender a detenerme cuando necesitaba otra opinión, en vez de insistir hasta agotarme.",
      "evento":"apoyar",
      "importancia":4,
      "requiere_tema":"ajuste_con_ayuda",
      "requisito_social":{"confianza_min":30},
      "variantes_actitud":[
        {"prioridad":20,"requisito_social":{"amistad_min":25},"respuesta":"Quedó lista. Y sí, me alegra que hayas preguntado; fuiste parte de las pruebas aunque no hayas sostenido el martillo todo el tiempo."},
        {"prioridad":10,"requisito_social":{"respeto_min":35},"respuesta":"Está terminada y ya pasó varias pruebas. Me satisface más que haya quedado funcional a que se vea bonita. Eso era lo que buscaba."}
      ]
    }
  ]$bruna$::jsonb),
  ('Darven', $darven$
  [
    {
      "clave":"registro_incompleto",
      "texto":"Preguntar por la revisión del camino",
      "jugador":"¿Pudiste aclarar las diferencias que encontraste en los registros de la ronda?",
      "respuesta":"Encontré una anotación incompleta. No demuestra que haya ocurrido nada peligroso; sólo significa que una parte de la ronda no quedó registrada como debía. Estoy comprobando los horarios antes de sacar conclusiones.",
      "respuesta_repetida":"Los horarios ya coinciden mejor. Aún revisaré el siguiente turno para asegurarme de que no haya sido un error repetido.",
      "evento":"compartir_conocimiento",
      "importancia":3,
      "requiere_tema":"incidente_camino",
      "requisito_social":{"respeto_min":15},
      "variantes_actitud":[
        {"prioridad":20,"requisito_social":{"confianza_min":20},"respuesta":"Te lo cuento porque has sido discreto con lo que te he explicado. No quiero convertir una anotación incompleta en un rumor sobre la guardia."},
        {"prioridad":10,"requisito_social":{"respeto_min":30},"respuesta":"La diferencia está localizada. Por ahora es un fallo de registro, no una prueba de amenaza. Mantener esa distinción evita decisiones precipitadas."}
      ]
    },
    {
      "clave":"conversacion_guardia",
      "texto":"Preguntar si habló con el guardia del turno anterior",
      "jugador":"¿Hablaste con la persona que hizo aquella ronda?",
      "respuesta":"Sí. Estaba cubriendo más tareas de las habituales y dejó una parte para anotarla después. No debió hacerlo, pero entiendo cómo llegó a esa situación. Voy a corregir la organización del turno antes de buscar culpables.",
      "respuesta_repetida":"Hemos reorganizado las tareas y ahora la ronda queda registrada en el momento. No todo se arregla con una sanción; a veces hay que corregir las condiciones que provocaron el error.",
      "evento":"interesarse",
      "importancia":4,
      "requiere_tema":"registro_incompleto",
      "requisito_social":{"confianza_min":20},
      "variantes_actitud":[
        {"prioridad":20,"requisito_social":{"confianza_min":30},"respuesta":"No suelo hablar de asuntos internos con cualquiera. Pero creo que puedes entender que exigir responsabilidad también implica escuchar qué ocurrió."},
        {"prioridad":10,"requisito_social":{"respeto_min":30},"respuesta":"La responsabilidad sigue siendo suya, pero la organización del turno también es mía. Si ignoro esa parte, el mismo fallo puede repetirse con otra persona."}
      ]
    },
    {
      "clave":"nueva_ronda",
      "texto":"Preguntar si cambió la organización de las rondas",
      "jugador":"¿La nueva organización está funcionando mejor?",
      "respuesta":"Sí. Los relevos están más claros y cada guardia sabe qué debe registrar antes de terminar. No elimina todos los errores, pero hace más difícil que uno pase inadvertido.",
      "respuesta_repetida":"Por ahora funciona. Seguiré revisándolo; una norma sólo sirve si se adapta cuando la experiencia demuestra que hace falta.",
      "evento":"apoyar",
      "importancia":4,
      "requiere_tema":"conversacion_guardia",
      "requisito_social":{"confianza_min":30},
      "variantes_actitud":[
        {"prioridad":20,"requisito_social":{"amistad_min":25},"respuesta":"Me alegra poder contártelo. A veces parece que sólo hablo de trabajo, pero también necesito poder compartir cuando algo sale bien."},
        {"prioridad":10,"requisito_social":{"respeto_min":35},"respuesta":"La revisión indica que el cambio funciona. No lo considero resuelto para siempre; lo mantendremos mientras dé resultados y lo corregiremos si deja de hacerlo."}
      ]
    }
  ]$darven$::jsonb),
  ('Saira', $saira$
  [
    {
      "clave":"carta_comerciante",
      "texto":"Preguntar por la respuesta de su contacto viajero",
      "jugador":"¿Te respondió aquel comerciante con el que estabas en contacto?",
      "respuesta":"Sí. Me escribió desde una parada de su ruta. No trae noticias extraordinarias, pero recordó una conversación que tuvimos hace tiempo y me preguntó si sigo pensando en visitar su región.",
      "respuesta_repetida":"Hemos intercambiado un par de mensajes más. Todavía no hay una fecha para vernos, pero me gusta saber que algunas relaciones sobreviven a las distancias.",
      "evento":"interesarse",
      "importancia":3,
      "requiere_tema":"contacto_viajero",
      "requisito_social":{"amistad_min":15},
      "variantes_actitud":[
        {"prioridad":20,"requisito_social":{"afecto_min":15},"respuesta":"Me alegró recibir su carta. Hay personas con las que puedes pasar meses sin hablar y, aun así, la conversación retoma su curso como si nada. Supongo que contigo empieza a pasarme algo parecido."},
        {"prioridad":10,"requisito_social":{"respeto_min":25},"respuesta":"La carta confirmó que sigue recorriendo la ruta. No voy a sacar conclusiones sobre sus planes sólo por un mensaje, pero es una noticia fiable."}
      ]
    },
    {
      "clave":"despedida_pendiente",
      "texto":"Preguntar por qué no ha decidido visitar a su contacto",
      "jugador":"Si te gustaría volver a verlo, ¿por qué no has organizado el viaje?",
      "respuesta":"Porque visitar un lugar también significa volver a despedirse. Suena contradictorio viniendo de alguien que viaja tanto, ¿verdad? A veces prefiero dejar una visita pendiente antes que llegar sabiendo que tendré que marcharme enseguida.",
      "respuesta_repetida":"No he encontrado una respuesta sencilla. Me gusta conocer gente, pero no siempre sé qué hacer cuando empiezo a echarla de menos.",
      "evento":"interesarse",
      "importancia":4,
      "requiere_tema":"carta_comerciante",
      "requisito_social":{"confianza_min":20},
      "variantes_actitud":[
        {"prioridad":20,"requisito_social":{"confianza_min":30},"respuesta":"No suelo admitirlo tan directamente. Contigo puedo decir que algunas despedidas pesan más de lo que dejo ver cuando estoy contando una historia de viaje."},
        {"prioridad":10,"requisito_social":{"amistad_min":25},"respuesta":"Me encanta viajar, pero eso no significa que todas las despedidas sean fáciles. A veces me distraigo hablando de la siguiente ruta para no pensar en la anterior."}
      ]
    },
    {
      "clave":"elegir_quedarse",
      "texto":"Preguntar si piensa quedarse en Torres durante un tiempo",
      "jugador":"¿Has pensado en quedarte en Torres una temporada sin organizar otro viaje?",
      "respuesta":"Sí. No estoy renunciando a viajar, pero quiero quedarme el tiempo suficiente para ver cómo cambian las cosas aquí. Me gustaría tener planes que no dependan siempre de la próxima partida.",
      "respuesta_repetida":"Sigo aquí y, por ahora, no tengo prisa por marcharme. Si aparece una ruta interesante, ya lo pensaré cuando llegue el momento.",
      "evento":"apoyar",
      "importancia":4,
      "requiere_tema":"despedida_pendiente",
      "requisito_social":{"confianza_min":30},
      "variantes_actitud":[
        {"prioridad":20,"requisito_social":{"afecto_min":20},"respuesta":"Parte de la razón es que he encontrado personas con las que me apetece compartir los días normales, no sólo las historias de cuando vuelvo."},
        {"prioridad":10,"requisito_social":{"amistad_min":30},"respuesta":"Quiero probarlo. Torres se ha convertido en algo más que una parada conveniente, aunque todavía no sé cuánto tiempo terminaré quedándome."}
      ]
    }
  ]$saira$::jsonb),
  ('Narel', $narel$
  [
    {
      "clave":"hipotesis_descartada",
      "texto":"Preguntar qué hizo con su hipótesis anterior",
      "jugador":"¿Pudiste revisar la hipótesis que había dejado de convencerte?",
      "respuesta":"La descarté. Al separar las observaciones por condiciones, descubrí que estaba comparando registros que no eran equivalentes. La explicación parecía coherente porque había agrupado datos que no debía mezclar.",
      "respuesta_repetida":"He dejado anotado por qué descarté aquella hipótesis. Quiero conservar el razonamiento, no sólo el resultado; así será más fácil evitar el mismo error.",
      "evento":"compartir_conocimiento",
      "importancia":3,
      "requiere_tema":"observacion_inconclusa",
      "requisito_social":{"respeto_min":15},
      "variantes_actitud":[
        {"prioridad":20,"requisito_social":{"confianza_min":20},"respuesta":"Me incomodó admitirlo, pero contigo puedo decirlo sin adornos: estaba demasiado convencido de mi primera interpretación. Tuve que volver a los registros desde el principio."},
        {"prioridad":10,"requisito_social":{"respeto_min":30},"respuesta":"La hipótesis no superó la revisión. Es un resultado útil aunque no confirme lo que esperaba; ahora sé qué comparación debo evitar."}
      ]
    },
    {
      "clave":"registro_compartido",
      "texto":"Preguntar si quiere revisar las observaciones juntos",
      "jugador":"¿Te serviría que revisáramos algunas observaciones juntos?",
      "respuesta":"Sí, siempre que distingamos lo que cada uno observó de lo que interpreta. Puedes fijarte en detalles que yo haya pasado por alto. No necesito que lleguemos a la misma conclusión; necesito que revisemos bien los datos.",
      "respuesta_repetida":"He añadido tus observaciones al margen, separadas de mis propias notas. Me resulta útil poder volver a ellas sin confundir quién vio cada cosa.",
      "evento":"compartir_conocimiento",
      "importancia":4,
      "requiere_tema":"hipotesis_descartada",
      "requisito_social":{"confianza_min":20},
      "variantes_actitud":[
        {"prioridad":20,"requisito_social":{"confianza_min":30},"respuesta":"Me cuesta compartir registros que todavía considero incompletos. Sin embargo, confío en que no presentarás una posibilidad como si fuera un hecho."},
        {"prioridad":10,"requisito_social":{"respeto_min":30},"respuesta":"Tu disposición a revisar el método antes de discutir el resultado es valiosa. Empezaremos por las condiciones de observación y dejaremos las conclusiones para después."}
      ]
    },
    {
      "clave":"limite_investigacion",
      "texto":"Preguntar si consigue dejar una investigación sin resolver",
      "jugador":"¿Has aprendido a dejar una pregunta pendiente y descansar?",
      "respuesta":"Estoy intentándolo. Antes interpretaba una pausa como tiempo perdido, pero revisar los mismos datos cuando estoy agotado no los vuelve más claros. A veces necesito detenerme para poder pensar mejor después.",
      "respuesta_repetida":"He respetado algunas pausas esta semana. No siempre me resulta natural, aunque empiezo a notar que regreso con preguntas más precisas.",
      "evento":"apoyar",
      "importancia":4,
      "requiere_tema":"registro_compartido",
      "requisito_social":{"confianza_min":25,"amistad_min":25},
      "variantes_actitud":[
        {"prioridad":20,"requisito_social":{"afecto_min":15},"respuesta":"También ayuda saber que puedo hablar contigo de algo que no sea la investigación. No quiero que todas nuestras conversaciones terminen convertidas en notas."},
        {"prioridad":10,"requisito_social":{"respeto_min":35},"respuesta":"He empezado a tratar el descanso como parte del método. No mejora los datos directamente, pero sí la calidad de las decisiones que tomo al analizarlos."}
      ]
    }
  ]$narel$::jsonb)
),
objetivos AS (
  SELECT
    pg.id AS personaje_game_id,
    c.temas
  FROM contenido c
  JOIN public.personajes p ON lower(p.nombre) = lower(c.nombre)
  JOIN public.personajes_game pg ON pg.personaje_id = p.id
)
UPDATE public.dialogos_game dg
SET dialogo = jsonb_set(
  dg.dialogo,
  '{temas_conversacion}',
  coalesce(dg.dialogo->'temas_conversacion', '[]'::jsonb) || agregados.nuevos,
  true
)
FROM objetivos o
CROSS JOIN LATERAL (
  SELECT coalesce(jsonb_agg(nuevo ORDER BY nuevo->>'clave'), '[]'::jsonb) AS nuevos
  FROM jsonb_array_elements(o.temas) AS nuevo
  WHERE NOT EXISTS (
    SELECT 1
    FROM jsonb_array_elements(coalesce(dg.dialogo->'temas_conversacion', '[]'::jsonb)) AS existente
    WHERE existente->>'clave' = nuevo->>'clave'
  )
) agregados
WHERE dg.personaje_id = o.personaje_game_id
  AND dg.clave = 'principal'
  AND jsonb_typeof(dg.dialogo) = 'object'
  AND jsonb_array_length(agregados.nuevos) > 0;
