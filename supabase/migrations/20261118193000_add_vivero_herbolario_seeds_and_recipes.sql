-- Semillas iniciales y cadena de procesamiento del Vivero/Herbolario.
-- El estado de cultivo y las cantidades de cada partida permanecen locales.

begin;

do $$
declare
    v_semilla_azul uuid := 'b1000000-0000-4000-8000-000000000001';
    v_semilla_morada uuid := 'b1000000-0000-4000-8000-000000000002';
    v_semilla_verde uuid := 'b1000000-0000-4000-8000-000000000003';
    v_petalo_seco uuid := 'b1000000-0000-4000-8000-000000000004';
    v_extracto uuid := 'b1000000-0000-4000-8000-000000000005';
    v_flor_azul uuid := '6791be24-76b2-415e-8726-5838cc4343e8';
    v_flor_morada uuid := '222f21a0-21f6-4a35-8239-862c6e072f2e';
    v_flor_verde uuid := '1906b182-d6b4-44ec-ba6e-cb36f5f81a3d';
    v_hojas uuid := '9cf4d4f3-d65f-4971-a5fa-a77594a1b7d7';
begin
    insert into public.items (id,nombre,descripcion,categoria,origen,publicado,propiedades_fisicas)
    values
      (v_semilla_azul,'Semillas de Flor Azul','Semillas para cultivar flores de pétalos azules en el vivero.','Recurso','Natural',false,'{"cultivo":{"item_cosecha_id":"6791be24-76b2-415e-8726-5838cc4343e8","dias_crecimiento":2,"riegos_requeridos":2}}'::jsonb),
      (v_semilla_morada,'Semillas de Flor Morada','Semillas para cultivar flores de pétalos morados en el vivero.','Recurso','Natural',false,'{"cultivo":{"item_cosecha_id":"222f21a0-21f6-4a35-8239-862c6e072f2e","dias_crecimiento":2,"riegos_requeridos":2}}'::jsonb),
      (v_semilla_verde,'Semillas de Flor Verde','Semillas para cultivar flores de pétalos verdes en el vivero.','Recurso','Natural',false,'{"cultivo":{"item_cosecha_id":"1906b182-d6b4-44ec-ba6e-cb36f5f81a3d","dias_crecimiento":2,"riegos_requeridos":2}}'::jsonb),
      (v_petalo_seco,'Pétalos secos','Pétalos preparados mediante secado en el herbolario.','Recurso','Natural',false,'{"procesamiento":{"estacion":"herbolario_secado"}}'::jsonb),
      (v_extracto,'Extracto vegetal','Preparado concentrado obtenido al procesar hojas en el herbolario.','Recurso','Natural',false,'{"procesamiento":{"estacion":"herbolario"}}'::jsonb)
    on conflict (id) do update set
      nombre=excluded.nombre, descripcion=excluded.descripcion, categoria=excluded.categoria,
      origen=excluded.origen, propiedades_fisicas=excluded.propiedades_fisicas,
      updated_at=now();

    insert into public.items_game (item_id,tipo,max_stack,categoria_clave,propiedades)
    values
      (v_semilla_azul,'recurso',64,'naturaleza','{"semilla":true,"cultivo":{"item_cosecha_id":"6791be24-76b2-415e-8726-5838cc4343e8","dias_crecimiento":2,"riegos_requeridos":2},"colocable":false}'::jsonb),
      (v_semilla_morada,'recurso',64,'naturaleza','{"semilla":true,"cultivo":{"item_cosecha_id":"222f21a0-21f6-4a35-8239-862c6e072f2e","dias_crecimiento":2,"riegos_requeridos":2},"colocable":false}'::jsonb),
      (v_semilla_verde,'recurso',64,'naturaleza','{"semilla":true,"cultivo":{"item_cosecha_id":"1906b182-d6b4-44ec-ba6e-cb36f5f81a3d","dias_crecimiento":2,"riegos_requeridos":2},"colocable":false}'::jsonb),
      (v_petalo_seco,'recurso',64,'medicina_preparados','{"procesado":true,"estacion":"herbolario_secado"}'::jsonb),
      (v_extracto,'recurso',32,'medicina_preparados','{"procesado":true,"estacion":"herbolario"}'::jsonb)
    on conflict (item_id) do update set
      tipo=excluded.tipo,max_stack=excluded.max_stack,categoria_clave=excluded.categoria_clave,
      propiedades=excluded.propiedades,updated_at=now();

    insert into public.recetas_game
      (id,nombre,descripcion,categoria,ingredientes,resultado,propiedades,desbloqueada_por_defecto)
    values
      ('b2000000-0000-4000-8000-000000000001','Secar pétalos azules','Seca una Flor Azul para obtener pétalos preparados.','herbolario',
       jsonb_build_array(jsonb_build_object('item_id',v_flor_azul,'cantidad',1)),
       jsonb_build_object('item_id',v_petalo_seco,'cantidad',2),
       '{"estacion":"herbolario_secado","tipo_proceso":"secado"}'::jsonb,true),
      ('b2000000-0000-4000-8000-000000000002','Secar pétalos morados','Seca una Flor Morada para obtener pétalos preparados.','herbolario',
       jsonb_build_array(jsonb_build_object('item_id',v_flor_morada,'cantidad',1)),
       jsonb_build_object('item_id',v_petalo_seco,'cantidad',2),
       '{"estacion":"herbolario_secado","tipo_proceso":"secado"}'::jsonb,true),
      ('b2000000-0000-4000-8000-000000000003','Secar pétalos verdes','Seca una Flor Verde para obtener pétalos preparados.','herbolario',
       jsonb_build_array(jsonb_build_object('item_id',v_flor_verde,'cantidad',1)),
       jsonb_build_object('item_id',v_petalo_seco,'cantidad',2),
       '{"estacion":"herbolario_secado","tipo_proceso":"secado"}'::jsonb,true),
      ('b2000000-0000-4000-8000-000000000004','Preparar extracto vegetal','Procesa hojas para obtener un extracto vegetal.','herbolario',
       jsonb_build_array(jsonb_build_object('item_id',v_hojas,'cantidad',2)),
       jsonb_build_object('item_id',v_extracto,'cantidad',1),
       '{"estacion":"herbolario","tipo_proceso":"extraccion"}'::jsonb,true)
    on conflict (id) do update set
      nombre=excluded.nombre,descripcion=excluded.descripcion,categoria=excluded.categoria,
      ingredientes=excluded.ingredientes,resultado=excluded.resultado,
      propiedades=excluded.propiedades,desbloqueada_por_defecto=excluded.desbloqueada_por_defecto,
      updated_at=now();
end $$;

commit;
