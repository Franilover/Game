-- Add canonical armor equipment slots.

update public.items_game
set propiedades = coalesce(propiedades, '{}'::jsonb) || '{"ranura_equipamiento":"pies"}'::jsonb,
    updated_at = now()
where item_id = '5cf49bfb-fd6d-4c51-97b1-2584e5ddcd64' and tipo = 'armadura';

update public.items_game
set propiedades = coalesce(propiedades, '{}'::jsonb) || '{"ranura_equipamiento":"cabeza"}'::jsonb,
    updated_at = now()
where item_id in ('58bca445-d9dd-4db1-b7ba-b3be5b73f12c','7529cd14-7523-4d57-90d9-bd9bc9e28859') and tipo = 'armadura';

update public.items_game
set propiedades = coalesce(propiedades, '{}'::jsonb) || '{"ranura_equipamiento":"torso"}'::jsonb,
    updated_at = now()
where item_id = 'e5100787-8d50-4a39-b799-5e2484ac6a7f' and tipo = 'armadura';
