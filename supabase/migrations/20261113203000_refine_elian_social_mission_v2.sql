-- La primera misión de Elian usa conversaciones entre NPC, sin depender
-- de un recurso físico que todavía no tiene un punto de recolección garantizado.
begin;

do $$
declare
    v_mision_id uuid;
    v_elian_id uuid := 'ca96b5e8-7fce-4db5-a15c-88ed19913454'::uuid;
    v_darven_id uuid := 'eab4b01e-a4e6-41eb-961f-7e55f57f040c'::uuid;
begin
    select id into v_mision_id
    from public.misiones_game
    where clave = 'ayuda_horno_elian';

    if v_mision_id is null then
        raise exception 'No existe la misión ayuda_horno_elian.';
    end if;

    update public.misiones_objetivos_game
    set tipo = 'hablar_personaje',
        descripcion = 'Pregunta a Darven si la carreta con harina ya llegó a Torres.',
        cantidad_requerida = 1,
        item_id = null,
        personaje_id = v_darven_id,
        clave = 'consulta_elian',
        datos = '{}'::jsonb,
        updated_at = timezone('utc', now())
    where mision_id = v_mision_id and clave = 'reunir_lenia';

    if not found then
        raise exception 'No se encontró el objetivo inicial de la misión de Elian.';
    end if;

    update public.misiones_objetivos_game
    set datos = jsonb_build_object('requiere_objetivo_clave', 'consulta_elian'),
        updated_at = timezone('utc', now())
    where mision_id = v_mision_id and clave = 'regreso';

    if not found then
        raise exception 'No se encontró el objetivo de regreso de la misión de Elian.';
    end if;

    update public.dialogos_game
    set dialogo = jsonb_set(
        coalesce(dialogo, '{}'::jsonb),
        '{variantes}',
        coalesce((
            select jsonb_agg(v.value)
            from jsonb_array_elements(coalesce(dialogo->'variantes', '[]'::jsonb)) as v(value)
            where v.value->>'clave' not in ('principal', 'encargo_activo', 'regreso', 'despedida')
        ), '[]'::jsonb)
        ||
        $elian$
        [
          {
            "clave": "despedida",
            "prioridad": 30,
            "requisito": {"mision_clave": "ayuda_horno_elian", "estado": "completada"},
            "lineas": [
              {"hablante": "Elian", "texto": "Darven me confirmó que la carreta viene de camino. Podré organizar la hornada sin dejar esperando a nadie."},
              {"hablante": "Elian", "texto": "Gracias por volver con la respuesta. Me has quitado un peso de encima."},
              {"hablante": "Elian", "texto": "Cuando pases por la panadería, ya sabes que eres bienvenido."}
            ],
            "acciones": [
              {
                "tipo": "evento_social",
                "evento": "promesa_cumplida",
                "evento_id": "elian_una_hornada_a_tiempo",
                "contexto": {"mision": "ayuda_horno_elian", "resultado": "promesa_cumplida"},
                "texto": "Aceptar agradecimiento"
              }
            ]
          },
          {
            "clave": "regreso",
            "prioridad": 20,
            "requisito": {
              "mision_clave": "ayuda_horno_elian",
              "estado": "activa",
              "objetivo_clave": "consulta_elian",
              "progreso_objetivo_min": 1
            },
            "lineas": [
              {"hablante": "Elian", "texto": "¿Has podido hablar con Darven? ¿Qué te ha dicho sobre la carreta?"},
              {"hablante": "Elian", "texto": "Entiendo. Si ya está en camino, puedo mantener el horno a una temperatura más baja hasta que llegue."},
              {"hablante": "Elian", "texto": "Gracias por tomarte la molestia de averiguarlo."}
            ]
          },
          {
            "clave": "encargo_activo",
            "prioridad": 10,
            "requisito": {"mision_clave": "ayuda_horno_elian", "estado": "activa"},
            "lineas": [
              {"hablante": "Elian", "texto": "¿Podrías acercarte al puesto de guardia y preguntarle a Darven si la carreta con harina ya llegó?"},
              {"hablante": "Elian", "texto": "No puedo alejarme del horno ahora mismo. Cuando tengas noticias, vuelve a verme."}
            ]
          },
          {
            "clave": "principal",
            "prioridad": 0,
            "requisito": {"mision_clave": "ayuda_horno_elian", "estado": "disponible"},
            "lineas": [
              {"hablante": "Elian", "texto": "¡Buenos días! La primera tanda ya está en el horno, pero tengo un problema con la siguiente."},
              {"hablante": "Elian", "texto": "La carreta que trae la harina todavía no ha llegado. No puedo dejar el horno para averiguar qué ocurrió."},
              {"hablante": "Elian", "texto": "¿Podrías preguntarle a Darven si la carreta ya entró a Torres? Me ayudarías mucho."}
            ],
            "acciones": [
              {"tipo": "aceptar_mision", "mision_clave": "ayuda_horno_elian", "texto": "Ayudar a Elian"}
            ]
          }
        ]
        $elian$::jsonb,
        true
    ),
    updated_at = timezone('utc', now())
    where personaje_id = v_elian_id and clave = 'principal';

    if not found then
        raise exception 'No se encontró el diálogo principal de Elian.';
    end if;

    update public.dialogos_game
    set dialogo = jsonb_set(
        coalesce(dialogo, '{}'::jsonb),
        '{variantes}',
        coalesce((
            select jsonb_agg(v.value)
            from jsonb_array_elements(coalesce(dialogo->'variantes', '[]'::jsonb)) as v(value)
            where v.value->>'clave' not in ('principal', 'consulta_elian')
        ), '[]'::jsonb)
        ||
        $darven$
        [
          {
            "clave": "consulta_elian",
            "prioridad": 30,
            "requisito": {"mision_clave": "ayuda_horno_elian", "estado": "activa"},
            "lineas": [
              {"hablante": "Darven", "texto": "¿Vienes de parte de Elian? La carreta de harina aún no ha cruzado la entrada."},
              {"hablante": "Darven", "texto": "El conductor informó que tuvo que detenerse para reparar una rueda en el camino. Ya retomó la marcha."},
              {"hablante": "Darven", "texto": "Avisaré a los guardias de la entrada para que la dejen pasar en cuanto llegue. Puedes decirle a Elian que no debería tardar demasiado."}
            ]
          },
          {
            "clave": "principal",
            "prioridad": 0,
            "lineas": [
              {"hablante": "Darven", "texto": "Alto. Este acceso se mantiene vigilado por orden de la guardia."},
              {"hablante": "Darven", "texto": "Si vienes a Torres por primera vez, procura registrar tu llegada."},
              {"hablante": "Darven", "texto": "No es desconfianza personal. Es mi trabajo."}
            ]
          }
        ]
        $darven$::jsonb,
        true
    ),
    updated_at = timezone('utc', now())
    where personaje_id = v_darven_id and clave = 'principal';

    if not found then
        raise exception 'No se encontró el diálogo principal de Darven.';
    end if;
end
$$;

commit;
