-- PROPUESTA PARA REVISION; NO EJECUTAR HASTA APROBACION EXPLICITA.
-- Objetivo: calibrar solo la conversion de unidad fisica de longitud a km.
-- No define km_por_unidad_mapa ni proyeccion cartografica.
-- Fuente canonica: v_cuerpo_celeste_ficha_fisica_v1 + valores_fisicos.
-- Garlia: radio_medio = 6400000 uL_longitud; unidad factor_si = 1 m/uL.
-- Conversion dimensional: 1 uL_longitud = 0.001 km.

begin;

do $$
declare
    v_mundo_id uuid;
    v_cuerpo_id uuid;
    v_unidad_id uuid;
    v_radio numeric;
    v_factor_si numeric;
    v_estado text;
begin
    select id, cuerpo_celeste_id, unidad_longitud_id, estado_calibracion
      into v_mundo_id, v_cuerpo_id, v_unidad_id, v_estado
      from public.geografia_mundos_v1
     where cuerpo_celeste_id = 'f379127e-b271-4548-ab77-4b4782129ac1';

    if v_mundo_id is null then
        raise exception 'No existe una calibracion geografica para Garlia';
    end if;

    if v_estado not in ('pendiente_calibracion', 'radio_calibrado') then
        raise exception 'Estado inesperado para calibracion de radio: %', v_estado;
    end if;

    select valor into v_radio
      from public.valores_fisicos
     where entidad_id = v_cuerpo_id
       and entidad_tipo = 'cuerpo_celeste'
       and parametro_clave = 'radio_medio'
     order by created_at desc
     limit 1;

    select factor_si into v_factor_si
      from public.unidades_fisicas
     where id = v_unidad_id;

    if v_radio is distinct from 6400000::numeric then
        raise exception 'El radio canonico de Garlia no coincide con el auditado; abortando';
    end if;

    if v_factor_si is distinct from 1::numeric then
        raise exception 'La unidad de longitud no tiene factor SI 1; abortando';
    end if;

    update public.geografia_mundos_v1
       set km_por_unidad_longitud = 0.001,
           estado_calibracion = 'radio_calibrado',
           notas = concat_ws(E'\n',
               nullif(notas, ''),
               'Calibracion de longitud propuesta desde radio_medio canonico de Garlia (6400000 uL_longitud; factor SI 1 m/uL). La escala cartografica sigue pendiente.'
           ),
           updated_at = now()
     where id = v_mundo_id
       and cuerpo_celeste_id = v_cuerpo_id
       and unidad_longitud_id = v_unidad_id;

    if not found then
        raise exception 'No se actualizo el registro esperado; abortando';
    end if;
end $$;

commit;
