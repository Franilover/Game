-- Define efectos de consumo modestos para alimentos básicos.
-- Manzana: recupera 4 puntos de vida.
-- Pan: recupera 6 puntos de vida.
-- Se preservan las demás propiedades jugables de cada objeto.

DO $$
DECLARE
    v_actualizados integer;
BEGIN
    UPDATE public.items_game AS g
    SET propiedades = jsonb_set(
        COALESCE(g.propiedades, '{}'::jsonb),
        '{uso}',
        jsonb_build_object(
            'tipo', 'consumir',
            'permitido', true,
            'efectos', jsonb_build_array(
                jsonb_build_object(
                    'recurso', 'vida',
                    'magnitud',
                    CASE i.nombre
                        WHEN 'Manzana' THEN 4
                        WHEN 'Pan' THEN 6
                    END
                )
            )
        ),
        true
    ),
    updated_at = timezone('utc'::text, now())
    FROM public.items AS i
    WHERE g.item_id = i.id
      AND i.nombre IN ('Manzana', 'Pan')
      AND g.categoria_clave = 'alimentos_bebidas';

    GET DIAGNOSTICS v_actualizados = ROW_COUNT;

    IF v_actualizados <> 2 THEN
        RAISE EXCEPTION
            'Se esperaban actualizar 2 alimentos (Manzana y Pan), pero se actualizaron %.',
            v_actualizados;
    END IF;
END
$$;
