-- Primera misión social de Torres: Elian, el panadero.
-- Se apoya en los objetivos existentes y en el diálogo contextual de NPC.
begin;

do $$
declare
    v_mision_id uuid;
    v_elian_id uuid := 'ca96b5e8-7fce-4db5-a15c-88ed19913454'::uuid;
    v_madera_id uuid := '768a51e5-e34b-4f11-92e7-a6e7dd3bf55c'::uuid;
begin
    insert into public.misiones_game (
        clave, nombre, descripcion, tipo, activo, orden, auto_aceptar
    )
    values (
        'ayuda_horno_elian',
        'Una hornada a tiempo',
        'Ayuda a Elian a reunir leña para mantener encendido el horno y terminar la hornada.',
        'social',
        true,
        30,
        false
    )
    on conflict (clave) do update
    set nombre = excluded.nombre,
        descripcion = excluded.descripcion,
        tipo = excluded.tipo,
        activo = excluded.activo,
        orden = excluded.orden,
        auto_aceptar = excluded.auto_aceptar,
        updated_at = timezone('utc', now())
    returning id into v_mision_id;

    if v_mision_id is null then
        select id into v_mision_id
        from public.misiones_game
        where clave = 'ayuda_horno_elian';
    end if;

    if not exists (
        select 1 from public.misiones_objetivos_game
        where mision_id = v_mision_id and clave = 'reunir_lenia'
    ) then
        insert into public.misiones_objetivos_game (
            mision_id, orden, tipo, descripcion, cantidad_requerida,
            item_id, clave, datos, activo
        )
        values (
            v_mision_id,
            10,
            'recoger_item',
            'Reúne 3 piezas de madera para Elian.',
            3,
            v_madera_id,
            'reunir_lenia',
            '{}'::jsonb,
            true
        );
    end if;

    if not exists (
        select 1 from public.misiones_objetivos_game
        where mision_id = v_mision_id and clave = 'regreso'
    ) then
        insert into public.misiones_objetivos_game (
            mision_id, orden, tipo, descripcion, cantidad_requerida,
            personaje_id, clave, datos, activo
        )
        values (
            v_mision_id,
            20,
            'hablar_personaje',
            'Vuelve a hablar con Elian después de reunir la madera.',
            1,
            v_elian_id,
            'regreso',
            jsonb_build_object('requiere_objetivo_clave', 'reunir_lenia'),
            true
        );
    end if;

    update public.dialogos_game
    set dialogo = jsonb_set(
        coalesce(dialogo, '{}'::jsonb),
        '{variantes}',
        coalesce((
            select jsonb_agg(v.value)
            from jsonb_array_elements(
                coalesce(dialogo->'variantes', '[]'::jsonb)
            ) as v(value)
            where v.value->>'clave' not in (
                'principal',
                'encargo_activo',
                'regreso',
                'despedida'
            )
        ), '[]'::jsonb)
        ||
        $dialogos$
        [
          {
            "clave": "despedida",
            "prioridad": 30,
            "requisito": {
              "mision_clave": "ayuda_horno_elian",
              "estado": "completada"
            },
            "lineas": [
              {
                "hablante": "Elian",
                "texto": "¡La hornada salió a tiempo! La madera llegó justo cuando la necesitaba."
              },
              {
                "hablante": "Elian",
                "texto": "Gracias por cumplir tu palabra. Me alegra saber que puedo contar contigo."
              },
              {
                "hablante": "Elian",
                "texto": "Cuando pases por la panadería, no dudes en saludar. Siempre habrá un momento para conversar."
              }
            ],
            "acciones": [
              {
                "tipo": "evento_social",
                "evento": "promesa_cumplida",
                "evento_id": "elian_una_hornada_a_tiempo",
                "contexto": {
                  "mision": "ayuda_horno_elian",
                  "resultado": "promesa_cumplida"
                },
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
              "objetivo_clave": "reunir_lenia",
              "progreso_objetivo_min": 3
            },
            "lineas": [
              {
                "hablante": "Elian",
                "texto": "¡Has conseguido la madera! Justo lo que necesitaba para mantener el horno encendido."
              },
              {
                "hablante": "Elian",
                "texto": "Con esto podré terminar la hornada sin dejar esperando a quienes hicieron sus encargos."
              },
              {
                "hablante": "Elian",
                "texto": "De verdad, gracias por echarme una mano."
              }
            ]
          },
          {
            "clave": "encargo_activo",
            "prioridad": 10,
            "requisito": {
              "mision_clave": "ayuda_horno_elian",
              "estado": "activa"
            },
            "lineas": [
              {
                "hablante": "Elian",
                "texto": "El horno sigue encendido, pero todavía necesito tres piezas de madera para terminar la hornada."
              },
              {
                "hablante": "Elian",
                "texto": "Cuando las tengas, vuelve a hablar conmigo. Estaré aquí en la panadería."
              }
            ]
          },
          {
            "clave": "principal",
            "prioridad": 0,
            "lineas": [
              {
                "hablante": "Elian",
                "texto": "¡Buenos días! El horno lleva un rato encendido y la primera tanda acaba de salir."
              },
              {
                "hablante": "Elian",
                "texto": "Hoy me he quedado corto de leña. Si no consigo un poco más, no podré terminar la hornada que me encargaron."
              },
              {
                "hablante": "Elian",
                "texto": "¿Podrías traerme tres piezas de madera? Te estaría muy agradecido."
              }
            ],
            "acciones": [
              {
                "tipo": "aceptar_mision",
                "mision_clave": "ayuda_horno_elian",
                "texto": "Ayudar a Elian"
              }
            ]
          }
        ]
        $dialogos$::jsonb,
        true
    ),
    updated_at = timezone('utc', now())
    where personaje_id = v_elian_id
      and clave = 'principal';

    if not found then
        raise exception 'No se encontró el diálogo principal de Elian (%).', v_elian_id;
    end if;
end
$$;

commit;
