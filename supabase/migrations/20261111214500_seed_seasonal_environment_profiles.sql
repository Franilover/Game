update public.calendario_estaciones as e
set
  config_visual = v.config_visual,
  config_climatica = v.config_climatica
from (
  values
  (
    'Florial1',
    '{"horarios":{"amanecer_inicio":0.16,"amanecer_fin":0.29,"atardecer_inicio":0.70,"atardecer_fin":0.84},"claves_luz":[{"hora":0.0,"color":"#28334D"},{"hora":0.16,"color":"#594B70"},{"hora":0.22,"color":"#C87983"},{"hora":0.29,"color":"#F3B18B"},{"hora":0.38,"color":"#FFF0D5"},{"hora":0.52,"color":"#FFFDF2"},{"hora":0.70,"color":"#F9D5A1"},{"hora":0.78,"color":"#E98C79"},{"hora":0.84,"color":"#76536F"},{"hora":0.93,"color":"#35405F"},{"hora":1.0,"color":"#28334D"}]}'::jsonb,
    '{"transicion_segundos":16.0}'::jsonb
  ),
  (
    'Florial2',
    '{"horarios":{"amanecer_inicio":0.14,"amanecer_fin":0.26,"atardecer_inicio":0.73,"atardecer_fin":0.86},"claves_luz":[{"hora":0.0,"color":"#293B43"},{"hora":0.14,"color":"#526B68"},{"hora":0.20,"color":"#A6A77A"},{"hora":0.26,"color":"#E4D6A0"},{"hora":0.37,"color":"#F5F2D8"},{"hora":0.53,"color":"#FFFDF0"},{"hora":0.73,"color":"#E8D9A8"},{"hora":0.80,"color":"#C99B70"},{"hora":0.86,"color":"#6C7770"},{"hora":0.94,"color":"#3B5054"},{"hora":1.0,"color":"#293B43"}]}'::jsonb,
    '{"transicion_segundos":18.0}'::jsonb
  ),
  (
    'Erial1',
    '{"horarios":{"amanecer_inicio":0.18,"amanecer_fin":0.31,"atardecer_inicio":0.66,"atardecer_fin":0.82},"claves_luz":[{"hora":0.0,"color":"#303447"},{"hora":0.18,"color":"#66536A"},{"hora":0.24,"color":"#B87968"},{"hora":0.31,"color":"#E6B27E"},{"hora":0.40,"color":"#F4E5C5"},{"hora":0.52,"color":"#FFF7E5"},{"hora":0.66,"color":"#E8C18B"},{"hora":0.75,"color":"#C47B5D"},{"hora":0.82,"color":"#795267"},{"hora":0.93,"color":"#41415B"},{"hora":1.0,"color":"#303447"}]}'::jsonb,
    '{"transicion_segundos":14.0}'::jsonb
  ),
  (
    'Erial2',
    '{"horarios":{"amanecer_inicio":0.20,"amanecer_fin":0.34,"atardecer_inicio":0.68,"atardecer_fin":0.87},"claves_luz":[{"hora":0.0,"color":"#342E38"},{"hora":0.20,"color":"#62434D"},{"hora":0.27,"color":"#A95E4E"},{"hora":0.34,"color":"#D99A6B"},{"hora":0.42,"color":"#EAD6B0"},{"hora":0.54,"color":"#F7EBDD"},{"hora":0.68,"color":"#D9A06D"},{"hora":0.78,"color":"#B8664F"},{"hora":0.87,"color":"#654454"},{"hora":0.95,"color":"#3C3543"},{"hora":1.0,"color":"#342E38"}]}'::jsonb,
    '{"transicion_segundos":12.0}'::jsonb
  ),
  (
    'Sivial1',
    '{"horarios":{"amanecer_inicio":0.12,"amanecer_fin":0.24,"atardecer_inicio":0.75,"atardecer_fin":0.88},"claves_luz":[{"hora":0.0,"color":"#263C4C"},{"hora":0.12,"color":"#496879"},{"hora":0.18,"color":"#91A8A7"},{"hora":0.24,"color":"#D4DCCB"},{"hora":0.38,"color":"#EAF0E5"},{"hora":0.53,"color":"#F8FBF2"},{"hora":0.75,"color":"#D9E1D0"},{"hora":0.82,"color":"#A6B7AD"},{"hora":0.88,"color":"#647D8B"},{"hora":0.95,"color":"#344B5A"},{"hora":1.0,"color":"#263C4C"}]}'::jsonb,
    '{"transicion_segundos":17.0}'::jsonb
  ),
  (
    'Orial1',
    '{"horarios":{"amanecer_inicio":0.16,"amanecer_fin":0.28,"atardecer_inicio":0.70,"atardecer_fin":0.83},"claves_luz":[{"hora":0.0,"color":"#343447"},{"hora":0.16,"color":"#6A566B"},{"hora":0.22,"color":"#B98568"},{"hora":0.28,"color":"#E8C18A"},{"hora":0.39,"color":"#F5E8C9"},{"hora":0.52,"color":"#FFF9E9"},{"hora":0.70,"color":"#E9C68D"},{"hora":0.77,"color":"#D18B61"},{"hora":0.83,"color":"#795B68"},{"hora":0.94,"color":"#41445C"},{"hora":1.0,"color":"#343447"}]}'::jsonb,
    '{"transicion_segundos":15.0}'::jsonb
  ),
  (
    'Orial2',
    '{"horarios":{"amanecer_inicio":0.14,"amanecer_fin":0.28,"atardecer_inicio":0.64,"atardecer_fin":0.82},"claves_luz":[{"hora":0.0,"color":"#2B344D"},{"hora":0.14,"color":"#584B78"},{"hora":0.21,"color":"#A96683"},{"hora":0.28,"color":"#E39A83"},{"hora":0.39,"color":"#F3D4B5"},{"hora":0.52,"color":"#FFF6E9"},{"hora":0.64,"color":"#EBC29B"},{"hora":0.74,"color":"#D47776"},{"hora":0.82,"color":"#765274"},{"hora":0.94,"color":"#39425F"},{"hora":1.0,"color":"#2B344D"}]}'::jsonb,
    '{"transicion_segundos":13.0}'::jsonb
  ),
  (
    'Hiberial1',
    '{"horarios":{"amanecer_inicio":0.21,"amanecer_fin":0.35,"atardecer_inicio":0.63,"atardecer_fin":0.82},"claves_luz":[{"hora":0.0,"color":"#263344"},{"hora":0.21,"color":"#43566E"},{"hora":0.28,"color":"#8195A2"},{"hora":0.35,"color":"#C0CCD0"},{"hora":0.43,"color":"#E2E9E7"},{"hora":0.54,"color":"#F2F5F0"},{"hora":0.63,"color":"#CFD8D9"},{"hora":0.73,"color":"#8998A8"},{"hora":0.82,"color":"#4E607B"},{"hora":0.94,"color":"#303D55"},{"hora":1.0,"color":"#263344"}]}'::jsonb,
    '{"transicion_segundos":20.0}'::jsonb
  ),
  (
    'Hiberial2',
    '{"horarios":{"amanecer_inicio":0.23,"amanecer_fin":0.36,"atardecer_inicio":0.61,"atardecer_fin":0.84},"claves_luz":[{"hora":0.0,"color":"#202A43"},{"hora":0.23,"color":"#3D4A72"},{"hora":0.30,"color":"#667CA0"},{"hora":0.36,"color":"#A9B9C9"},{"hora":0.45,"color":"#D8E0E8"},{"hora":0.55,"color":"#E9EEF2"},{"hora":0.61,"color":"#BFCBDD"},{"hora":0.73,"color":"#7886AE"},{"hora":0.84,"color":"#424F7C"},{"hora":0.95,"color":"#28334F"},{"hora":1.0,"color":"#202A43"}]}'::jsonb,
    '{"transicion_segundos":22.0}'::jsonb
  ),
  (
    'Sivial2',
    '{"horarios":{"amanecer_inicio":0.14,"amanecer_fin":0.27,"atardecer_inicio":0.72,"atardecer_fin":0.86},"claves_luz":[{"hora":0.0,"color":"#293849"},{"hora":0.14,"color":"#536C82"},{"hora":0.20,"color":"#A07C8B"},{"hora":0.27,"color":"#E2B29B"},{"hora":0.39,"color":"#F1E8D8"},{"hora":0.53,"color":"#FBF9F0"},{"hora":0.72,"color":"#D9D7C8"},{"hora":0.79,"color":"#C38F82"},{"hora":0.86,"color":"#65778A"},{"hora":0.95,"color":"#35475A"},{"hora":1.0,"color":"#293849"}]}'::jsonb,
    '{"transicion_segundos":16.0}'::jsonb
  )
) as v(nombre, config_visual, config_climatica)
where e.nombre = v.nombre;
