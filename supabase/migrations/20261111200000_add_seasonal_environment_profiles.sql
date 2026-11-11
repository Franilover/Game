alter table public.calendario_estaciones
  add column if not exists config_visual jsonb not null default '{}'::jsonb,
  add column if not exists config_climatica jsonb not null default '{}'::jsonb;

comment on column public.calendario_estaciones.config_visual is
  'Configuracion visual por estacion: horarios de transicion y claves de color para la iluminacion ambiental de Godot.';

comment on column public.calendario_estaciones.config_climatica is
  'Configuracion climatica por estacion: perfiles disponibles, pesos, condiciones ambientales y transiciones ejecutadas por Godot.';

create or replace function public.get_mundo_inicial_ambiental_v1()
returns jsonb
language sql
stable
security definer
set search_path to 'public', 'pg_temp'
as $function$
with definiciones as (
  select
    f.id,
    f.clave,
    f.nombre,
    f.categoria,
    f.tipo_valor,
    f.descripcion,
    f.rango_min,
    f.rango_max,
    f.magnitud_id,
    m.nombre as magnitud,
    m.simbolo as simbolo_magnitud,
    f.unidad_id,
    u.nombre as unidad,
    u.simbolo as simbolo_unidad
  from public.factores_abioticos f
  left join public.magnitudes_fisicas m on m.id=f.magnitud_id
  left join public.unidades_fisicas u on u.id=f.unidad_id
  where f.activo
),
ecosistemas as (
  select
    v.ecosistema_id,
    jsonb_object_agg(
      v.factor_clave,
      jsonb_build_object(
        'valor_numerico', v.valor_numerico,
        'opcion', v.opcion,
        'fuente_nivel', v.fuente_nivel,
        'origen', v.origen,
        'fuente', v.fuente,
        'metodo', v.metodo
      )
      order by v.factor_clave
    ) as factores
  from public.v_ecosistema_factores_abioticos_v1 v
  where v.valor_numerico is not null or v.opcion_id is not null
  group by v.ecosistema_id
),
habitats as (
  select
    v.habitat_id,
    jsonb_object_agg(
      v.factor_clave,
      jsonb_build_object(
        'valor_numerico', v.valor_numerico,
        'opcion', v.opcion,
        'fuente_nivel', v.fuente_nivel,
        'origen', v.origen,
        'fuente', v.fuente,
        'metodo', v.metodo
      )
      order by v.factor_clave
    ) as factores
  from public.v_habitat_factores_abioticos_v1 v
  where v.valor_numerico is not null or v.opcion_id is not null
  group by v.habitat_id
)
select
  public.get_mundo_inicial()
  ||
  jsonb_build_object(
    'calendario',
    jsonb_build_object(
      'config', (
        select jsonb_build_object(
          'dias_por_semana', c.dias_por_semana,
          'horas_por_dia', c.horas_por_dia,
          'anio_inicio', c.anio_inicio
        )
        from public.calendario_config c
        order by c.id
        limit 1
      ),
      'estaciones', coalesce(
        (
          select jsonb_agg(
            jsonb_build_object(
              'id', e.id,
              'nombre', e.nombre,
              'duracion_dias', e.duracion_dias,
              'orden', e.orden,
              'config_visual', coalesce(e.config_visual, '{}'::jsonb),
              'config_climatica', coalesce(e.config_climatica, '{}'::jsonb)
            )
            order by e.orden, e.nombre
          )
          from public.calendario_estaciones e
        ),
        '[]'::jsonb
      ),
      'dias_por_anio', coalesce(
        (select sum(e.duracion_dias) from public.calendario_estaciones e),
        0
      )
    ),
    'factores_abioticos',
    jsonb_build_object(
      'definiciones', coalesce(
        (
          select jsonb_agg(to_jsonb(d) order by d.clave)
          from definiciones d
        ),
        '[]'::jsonb
      ),
      'ecosistemas', coalesce(
        (
          select jsonb_object_agg(e.ecosistema_id::text, e.factores)
          from ecosistemas e
        ),
        '{}'::jsonb
      ),
      'habitats', coalesce(
        (
          select jsonb_object_agg(h.habitat_id::text, h.factores)
          from habitats h
        ),
        '{}'::jsonb
      )
    )
  );
$function$;
