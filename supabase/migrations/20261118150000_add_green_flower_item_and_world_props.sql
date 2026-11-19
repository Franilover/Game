-- Registra la Flor Verde como objeto de inventario y prop ecológico.
-- Reutiliza el sprite existente: assets/art/props/Flor Verdel.png

do $$
declare
    v_item_id uuid;
    v_prop_id uuid;
begin
    select id
      into v_item_id
      from public.items
     where lower(btrim(nombre)) = 'flor verde'
     order by created_at
     limit 1;

    if v_item_id is null then
        insert into public.items (
            nombre,
            descripcion,
            categoria,
            origen,
            publicado
        )
        values (
            'Flor Verde',
            'Una flor de pétalos verdes que crece de forma silvestre.',
            'Decoración',
            'Natural',
            false
        )
        returning id into v_item_id;
    else
        update public.items
           set descripcion = 'Una flor de pétalos verdes que crece de forma silvestre.',
               categoria = 'Decoración',
               origen = 'Natural',
               updated_at = now()
         where id = v_item_id;
    end if;

    insert into public.props_game (
        clave, nombre, tipo, activo, orden, peso, escala,
        offset_x, offset_y, propiedades,
        bioma_id, ecosistema_id, habitat_id, item_id
    )
    values
        (
            'flor_verde', 'Flor Verde', 'flor', true, 0, 1, 1,
            0, 0,
            jsonb_build_object(
                'item_id', v_item_id,
                'recolectable', true,
                'recoleccion', jsonb_build_object('cantidad', 1)
            ),
            '4050b74b-0925-4666-9387-7322ff8ee1c6',
            '2a3291e5-162d-4dbe-bad6-f91846f33758',
            '92010e53-ad64-4ba8-8371-94ded4975de3',
            v_item_id
        ),
        (
            'flor_verde_bosque_humedo', 'Flor Verde (Bosque húmedo)', 'flor', true, 0, 1, 1,
            0, 0,
            jsonb_build_object(
                'item_id', v_item_id,
                'recolectable', true,
                'recoleccion', jsonb_build_object('cantidad', 1)
            ),
            'fdc97953-f400-4f39-9b54-0a1c85f2c9a1',
            '9372cd47-1d83-4473-b2e4-e29d5600edf1',
            '190adea1-edb1-4e5f-ade6-c5cd8f09b805',
            v_item_id
        ),
        (
            'flor_verde_bosque_interior', 'Flor Verde (Bosque interior)', 'flor', true, 0, 1, 1,
            0, 0,
            jsonb_build_object(
                'item_id', v_item_id,
                'recolectable', true,
                'recoleccion', jsonb_build_object('cantidad', 1)
            ),
            'fdc97953-f400-4f39-9b54-0a1c85f2c9a1',
            '2040daab-f2d9-4658-8a46-27767b96f57e',
            'c3880259-b89e-4839-b251-9c505be96496',
            v_item_id
        )
    on conflict (clave) do update
       set nombre = excluded.nombre,
           tipo = excluded.tipo,
           activo = excluded.activo,
           propiedades = excluded.propiedades,
           bioma_id = excluded.bioma_id,
           ecosistema_id = excluded.ecosistema_id,
           habitat_id = excluded.habitat_id,
           item_id = excluded.item_id,
           updated_at = now();

    select id
      into v_prop_id
      from public.props_game
     where clave = 'flor_verde';

    insert into public.items_game (
        item_id,
        tipo,
        max_stack,
        categoria_clave,
        propiedades
    )
    values (
        v_item_id,
        'decoracion',
        64,
        'naturaleza',
        jsonb_build_object('prop_id', v_prop_id, 'colocable', true)
    )
    on conflict (item_id) do update
       set tipo = excluded.tipo,
           max_stack = excluded.max_stack,
           categoria_clave = excluded.categoria_clave,
           propiedades = excluded.propiedades,
           updated_at = now();
end
$$;
