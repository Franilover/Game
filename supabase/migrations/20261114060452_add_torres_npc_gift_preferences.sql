-- Añade Manzana al catálogo de juego como borrador.
-- La publicación canónica queda sujeta a la auditoría de integridad existente.
-- También configura preferencias iniciales de regalos para los cinco NPC de Torres.

WITH manzana_nueva AS (
    INSERT INTO public.items (
        nombre, descripcion, origen, publicado, categoria,
        propiedades_fisicas, geometria_fisica, es_heredado
    )
    SELECT
        'Manzana',
        'Una manzana fresca y crujiente, fácil de llevar durante un paseo o un viaje.',
        'Natural',
        false,
        'Comida',
        '{}'::jsonb,
        '{}'::jsonb,
        false
    WHERE NOT EXISTS (
        SELECT 1 FROM public.items WHERE lower(trim(nombre)) = 'manzana'
    )
    RETURNING id
),
manzana_id AS (
    SELECT id FROM manzana_nueva
    UNION ALL
    SELECT id FROM public.items
    WHERE lower(trim(nombre)) = 'manzana'
      AND NOT EXISTS (SELECT 1 FROM manzana_nueva)
    LIMIT 1
),
registrar_manzana_game AS (
    INSERT INTO public.items_game (item_id, tipo, max_stack, propiedades)
    SELECT id, 'recurso', 64, '{}'::jsonb
    FROM manzana_id
    ON CONFLICT (item_id) DO NOTHING
    RETURNING item_id
),
preferencias(personaje_game_id, item_nombre, reaccion, amistad, confianza, respeto, afecto) AS (
    VALUES
    -- Elian: comida sencilla y detalles hogareños.
    ('ca96b5e8-7fce-4db5-a15c-88ed19913454'::uuid, 'Pan', 'encanta', 5, 0, 0, 4),
    ('ca96b5e8-7fce-4db5-a15c-88ed19913454'::uuid, 'Manzana', 'gusta', 2, 0, 0, 1),
    ('ca96b5e8-7fce-4db5-a15c-88ed19913454'::uuid, 'Flor Morada', 'neutral', 0, 0, 0, 0),

    -- Bruna: materiales y herramientas útiles.
    ('c84d2653-4244-40f5-a094-d19d14c308a0'::uuid, 'Pico de Piedra', 'gusta', 1, 0, 3, 0),
    ('c84d2653-4244-40f5-a094-d19d14c308a0'::uuid, 'Madera', 'gusta', 1, 0, 2, 0),
    ('c84d2653-4244-40f5-a094-d19d14c308a0'::uuid, 'Flor Azul', 'neutral', 0, 0, 0, 0),

    -- Darven: equipo de entrenamiento, mantenimiento y provisiones.
    ('eab4b01e-a4e6-41eb-961f-7e55f57f040c'::uuid, 'Espada de Madera', 'gusta', 2, 0, 3, 0),
    ('eab4b01e-a4e6-41eb-961f-7e55f57f040c'::uuid, 'Pala de Piedra', 'gusta', 2, 0, 2, 0),
    ('eab4b01e-a4e6-41eb-961f-7e55f57f040c'::uuid, 'Pan', 'gusta', 2, 0, 0, 1),

    -- Saira: objetos curiosos y recuerdos de otros lugares.
    ('dac6a98b-abee-4397-9ce6-9753c60edf3e'::uuid, 'Plumas Aoris', 'encanta', 4, 0, 0, 4),
    ('dac6a98b-abee-4397-9ce6-9753c60edf3e'::uuid, 'Flor Azul', 'gusta', 2, 0, 0, 2),
    ('dac6a98b-abee-4397-9ce6-9753c60edf3e'::uuid, 'Flor Morada', 'gusta', 2, 0, 0, 2),
    ('dac6a98b-abee-4397-9ce6-9753c60edf3e'::uuid, 'Manzana', 'neutral', 0, 0, 0, 0),

    -- Narel: muestras que observar y comparar.
    ('734f80a6-fde9-4641-8b84-e16fdb81f3a7'::uuid, 'Piedra Mediana', 'encanta', 2, 0, 4, 0),
    ('734f80a6-fde9-4641-8b84-e16fdb81f3a7'::uuid, 'Plumas Aoris', 'gusta', 1, 0, 3, 0),
    ('734f80a6-fde9-4641-8b84-e16fdb81f3a7'::uuid, 'Piedra Pequeña', 'gusta', 2, 0, 1, 0)
),
catalogo_items AS (
    SELECT id, nombre FROM public.items
    UNION ALL
    SELECT id, 'Manzana'::text FROM manzana_id
)
INSERT INTO public.personaje_regalos_v1 (
    personaje_game_id, item_id, reaccion, amistad, confianza, respeto, afecto, activo
)
SELECT
    p.personaje_game_id,
    i.id,
    p.reaccion,
    p.amistad,
    p.confianza,
    p.respeto,
    p.afecto,
    true
FROM preferencias p
JOIN catalogo_items i ON lower(trim(i.nombre)) = lower(trim(p.item_nombre))
ON CONFLICT (personaje_game_id, item_id) DO NOTHING;
