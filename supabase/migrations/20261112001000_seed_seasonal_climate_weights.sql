update public.calendario_estaciones as e
set config_climatica = jsonb_set(
  jsonb_set(coalesce(e.config_climatica, '{}'::jsonb), '{perfiles}', v.perfiles, true),
  '{eventos}',
  coalesce(e.config_climatica->'eventos', '[]'::jsonb),
  true
)
from (
  values
  ('Florial1', '[
    {"tipo":"despejado","peso":34,"intensidad_min":0.75,"intensidad_max":1.0},
    {"tipo":"nublado","peso":20,"intensidad_min":0.55,"intensidad_max":0.9},
    {"tipo":"lluvia","peso":18,"intensidad_min":0.45,"intensidad_max":0.95},
    {"tipo":"niebla","peso":12,"intensidad_min":0.45,"intensidad_max":0.85},
    {"tipo":"tormenta","peso":6,"intensidad_min":0.65,"intensidad_max":1.0},
    {"tipo":"nieve","peso":1,"intensidad_min":0.4,"intensidad_max":0.8},
    {"tipo":"ola_calor","peso":3,"intensidad_min":0.5,"intensidad_max":0.9}
  ]'::jsonb),
  ('Florial2', '[
    {"tipo":"despejado","peso":34,"intensidad_min":0.75,"intensidad_max":1.0},
    {"tipo":"nublado","peso":18,"intensidad_min":0.55,"intensidad_max":0.9},
    {"tipo":"lluvia","peso":20,"intensidad_min":0.45,"intensidad_max":0.95},
    {"tipo":"niebla","peso":10,"intensidad_min":0.45,"intensidad_max":0.85},
    {"tipo":"tormenta","peso":7,"intensidad_min":0.65,"intensidad_max":1.0},
    {"tipo":"nieve","peso":1,"intensidad_min":0.4,"intensidad_max":0.8},
    {"tipo":"ola_calor","peso":10,"intensidad_min":0.5,"intensidad_max":0.9}
  ]'::jsonb),
  ('Erial1', '[
    {"tipo":"despejado","peso":50,"intensidad_min":0.8,"intensidad_max":1.0},
    {"tipo":"nublado","peso":15,"intensidad_min":0.5,"intensidad_max":0.85},
    {"tipo":"lluvia","peso":8,"intensidad_min":0.4,"intensidad_max":0.8},
    {"tipo":"niebla","peso":3,"intensidad_min":0.4,"intensidad_max":0.75},
    {"tipo":"tormenta","peso":3,"intensidad_min":0.6,"intensidad_max":0.95},
    {"tipo":"nieve","peso":0.5,"intensidad_min":0.4,"intensidad_max":0.8},
    {"tipo":"ola_calor","peso":20,"intensidad_min":0.55,"intensidad_max":1.0}
  ]'::jsonb),
  ('Erial2', '[
    {"tipo":"despejado","peso":54,"intensidad_min":0.8,"intensidad_max":1.0},
    {"tipo":"nublado","peso":14,"intensidad_min":0.5,"intensidad_max":0.85},
    {"tipo":"lluvia","peso":6,"intensidad_min":0.4,"intensidad_max":0.8},
    {"tipo":"niebla","peso":3,"intensidad_min":0.4,"intensidad_max":0.75},
    {"tipo":"tormenta","peso":3,"intensidad_min":0.6,"intensidad_max":0.95},
    {"tipo":"nieve","peso":0.5,"intensidad_min":0.4,"intensidad_max":0.8},
    {"tipo":"ola_calor","peso":19,"intensidad_min":0.55,"intensidad_max":1.0}
  ]'::jsonb),
  ('Sivial1', '[
    {"tipo":"despejado","peso":42,"intensidad_min":0.75,"intensidad_max":1.0},
    {"tipo":"nublado","peso":20,"intensidad_min":0.55,"intensidad_max":0.9},
    {"tipo":"lluvia","peso":14,"intensidad_min":0.45,"intensidad_max":0.9},
    {"tipo":"niebla","peso":12,"intensidad_min":0.45,"intensidad_max":0.9},
    {"tipo":"tormenta","peso":6,"intensidad_min":0.6,"intensidad_max":0.95},
    {"tipo":"nieve","peso":1,"intensidad_min":0.4,"intensidad_max":0.8},
    {"tipo":"ola_calor","peso":5,"intensidad_min":0.5,"intensidad_max":0.85}
  ]'::jsonb),
  ('Orial1', '[
    {"tipo":"despejado","peso":38,"intensidad_min":0.75,"intensidad_max":1.0},
    {"tipo":"nublado","peso":22,"intensidad_min":0.55,"intensidad_max":0.9},
    {"tipo":"lluvia","peso":14,"intensidad_min":0.45,"intensidad_max":0.9},
    {"tipo":"niebla","peso":10,"intensidad_min":0.45,"intensidad_max":0.85},
    {"tipo":"tormenta","peso":6,"intensidad_min":0.6,"intensidad_max":0.95},
    {"tipo":"nieve","peso":5,"intensidad_min":0.45,"intensidad_max":0.9},
    {"tipo":"ola_calor","peso":3,"intensidad_min":0.5,"intensidad_max":0.85}
  ]'::jsonb),
  ('Orial2', '[
    {"tipo":"despejado","peso":32,"intensidad_min":0.7,"intensidad_max":1.0},
    {"tipo":"nublado","peso":23,"intensidad_min":0.55,"intensidad_max":0.9},
    {"tipo":"lluvia","peso":15,"intensidad_min":0.45,"intensidad_max":0.9},
    {"tipo":"niebla","peso":12,"intensidad_min":0.45,"intensidad_max":0.9},
    {"tipo":"tormenta","peso":7,"intensidad_min":0.6,"intensidad_max":1.0},
    {"tipo":"nieve","peso":9,"intensidad_min":0.5,"intensidad_max":0.95},
    {"tipo":"ola_calor","peso":1,"intensidad_min":0.45,"intensidad_max":0.8}
  ]'::jsonb),
  ('Hiberial1', '[
    {"tipo":"despejado","peso":30,"intensidad_min":0.65,"intensidad_max":0.95},
    {"tipo":"nublado","peso":22,"intensidad_min":0.55,"intensidad_max":0.9},
    {"tipo":"lluvia","peso":8,"intensidad_min":0.4,"intensidad_max":0.8},
    {"tipo":"niebla","peso":12,"intensidad_min":0.45,"intensidad_max":0.9},
    {"tipo":"tormenta","peso":5,"intensidad_min":0.6,"intensidad_max":0.95},
    {"tipo":"nieve","peso":23,"intensidad_min":0.55,"intensidad_max":1.0},
    {"tipo":"ola_calor","peso":0,"intensidad_min":0.4,"intensidad_max":0.8}
  ]'::jsonb),
  ('Hiberial2', '[
    {"tipo":"despejado","peso":29,"intensidad_min":0.65,"intensidad_max":0.95},
    {"tipo":"nublado","peso":22,"intensidad_min":0.55,"intensidad_max":0.9},
    {"tipo":"lluvia","peso":10,"intensidad_min":0.4,"intensidad_max":0.8},
    {"tipo":"niebla","peso":14,"intensidad_min":0.45,"intensidad_max":0.9},
    {"tipo":"tormenta","peso":6,"intensidad_min":0.6,"intensidad_max":0.95},
    {"tipo":"nieve","peso":19,"intensidad_min":0.55,"intensidad_max":1.0},
    {"tipo":"ola_calor","peso":0,"intensidad_min":0.4,"intensidad_max":0.8}
  ]'::jsonb),
  ('Sivial2', '[
    {"tipo":"despejado","peso":38,"intensidad_min":0.75,"intensidad_max":1.0},
    {"tipo":"nublado","peso":20,"intensidad_min":0.55,"intensidad_max":0.9},
    {"tipo":"lluvia","peso":16,"intensidad_min":0.45,"intensidad_max":0.9},
    {"tipo":"niebla","peso":12,"intensidad_min":0.45,"intensidad_max":0.9},
    {"tipo":"tormenta","peso":6,"intensidad_min":0.6,"intensidad_max":0.95},
    {"tipo":"nieve","peso":5,"intensidad_min":0.45,"intensidad_max":0.9},
    {"tipo":"ola_calor","peso":3,"intensidad_min":0.5,"intensidad_max":0.85}
  ]'::jsonb)
) as v(nombre, perfiles)
where e.nombre = v.nombre;
