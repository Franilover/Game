-- Espadas crafteables. Los IDs se resuelven por nombre para evitar referencias UUID hardcodeadas.

UPDATE public.items
SET origen='Artificial',
    descripcion=COALESCE(descripcion,'Una espada sencilla tallada en madera.'),
    publicado=true,
    publicado_at=COALESCE(publicado_at, now()),
    updated_at=now()
WHERE nombre='Espada de Madera';

INSERT INTO public.items (nombre,descripcion,origen,publicado,publicado_at)
SELECT 'Espada de Piedra','Una espada sencilla fabricada con piedra y madera.','Artificial',true,now()
WHERE NOT EXISTS (SELECT 1 FROM public.items WHERE nombre='Espada de Piedra');

INSERT INTO public.items_game (item_id,tipo,max_stack,propiedades)
SELECT i.id,'arma',1,jsonb_build_object('danio',8,'alcance',64,'ancho_ataque',48,'modo_ataque','cuerpo')
FROM public.items i WHERE i.nombre='Espada de Madera'
ON CONFLICT (item_id) DO UPDATE SET tipo=EXCLUDED.tipo,max_stack=EXCLUDED.max_stack,propiedades=EXCLUDED.propiedades,updated_at=now();

INSERT INTO public.items_game (item_id,tipo,max_stack,propiedades)
SELECT i.id,'arma',1,jsonb_build_object('danio',12,'alcance',68,'ancho_ataque',52,'modo_ataque','cuerpo')
FROM public.items i WHERE i.nombre='Espada de Piedra'
ON CONFLICT (item_id) DO UPDATE SET tipo=EXCLUDED.tipo,max_stack=EXCLUDED.max_stack,propiedades=EXCLUDED.propiedades,updated_at=now();

DELETE FROM public.recetas_game WHERE nombre IN ('Espada de Madera','Espada de Piedra');

INSERT INTO public.recetas_game (nombre,descripcion,categoria,ingredientes,resultado,propiedades,desbloqueada_por_defecto)
SELECT 'Espada de Madera','Una espada sencilla tallada en madera.','arma',
       jsonb_build_array(jsonb_build_object('item_id',madera.id::text,'cantidad',3)),
       jsonb_build_object('item_id',espada.id::text,'cantidad',1),'{}'::jsonb,true
FROM public.items madera CROSS JOIN public.items espada
WHERE madera.nombre='Madera' AND espada.nombre='Espada de Madera';

INSERT INTO public.recetas_game (nombre,descripcion,categoria,ingredientes,resultado,propiedades,desbloqueada_por_defecto)
SELECT 'Espada de Piedra','Una espada sencilla fabricada con piedra y madera.','arma',
       jsonb_build_array(
         jsonb_build_object('item_id',madera.id::text,'cantidad',2),
         jsonb_build_object('item_id',piedra.id::text,'cantidad',3)
       ),
       jsonb_build_object('item_id',espada.id::text,'cantidad',1),'{}'::jsonb,true
FROM public.items madera CROSS JOIN public.items piedra CROSS JOIN public.items espada
WHERE madera.nombre='Madera' AND piedra.nombre='Piedra Mediana' AND espada.nombre='Espada de Piedra';
