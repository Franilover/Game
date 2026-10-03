-- Add the canonical tree world prop.
insert into public.props_game
(id, clave, nombre, tipo, activo, orden, peso, escala, offset_x, offset_y, propiedades, bioma_id, ecosistema_id, habitat_id, item_id)
values
(
  '8f0f4a2b-8e2c-4d2e-9c0e-4c0b9c6e7a31',
  'arbol',
  'Árbol',
  'decoracion',
  true,
  34,
  20.0,
  2.0,
  0,
  0,
  '{}'::jsonb,
  'c2ff5a5d-6727-4a94-a19d-3921f52bdfc7',
  '6dd0a416-b88c-4377-82aa-bdfb17570166',
  'e85bd5c5-0cf1-42a1-9d1c-7d1b673caac2',
  null
)
on conflict (clave) do update set
  nombre = excluded.nombre,
  tipo = excluded.tipo,
  activo = excluded.activo,
  orden = excluded.orden,
  peso = excluded.peso,
  escala = excluded.escala,
  offset_x = excluded.offset_x,
  offset_y = excluded.offset_y,
  propiedades = excluded.propiedades,
  bioma_id = excluded.bioma_id,
  ecosistema_id = excluded.ecosistema_id,
  habitat_id = excluded.habitat_id,
  item_id = excluded.item_id,
  updated_at = now();
