-- Piedra Grande requiere una herramienta de recolección de tipo pico nivel 2.
-- El Pico de Piedra es nivel 2; el Pico de Madera permanece en nivel 1.

UPDATE public.items_game
SET propiedades = jsonb_set(
  COALESCE(propiedades,'{}'::jsonb),
  '{herramienta_recoleccion,nivel}',
  '2'::jsonb,
  true
),
updated_at=now()
WHERE item_id = (
  SELECT id FROM public.items WHERE nombre='Pico de Piedra' LIMIT 1
);

DELETE FROM public.props_game
WHERE clave='piedra_grande';

INSERT INTO public.props_game (
  clave,nombre,tipo,activo,orden,peso,escala,offset_x,offset_y,
  propiedades,bioma_id,ecosistema_id,habitat_id,item_id
)
SELECT
  'piedra_grande',
  'Piedra Grande',
  'recurso',
  true,
  33,
  8.0,
  1.5,
  0,
  0,
  jsonb_build_object(
    'item_id', piedra.id::text,
    'recolectable', true,
    'herramienta_recoleccion', jsonb_build_object(
      'tipo','pico',
      'nivel',2
    )
  ),
  p.bioma_id,
  p.ecosistema_id,
  p.habitat_id,
  piedra.id
FROM public.items piedra
CROSS JOIN (
  SELECT bioma_id,ecosistema_id,habitat_id
  FROM public.props_game
  WHERE clave='piedra_mediana'
  LIMIT 1
) p
WHERE piedra.nombre='Piedra Mediana';
