-- NPC humanos de Reino Torres, perfiles sociales, diálogos y rutinas.
-- La migración es idempotente: conserva registros existentes y sólo completa los ausentes.

ALTER TABLE public.personajes_game
  ADD COLUMN IF NOT EXISTS ubicacion_clave text;

CREATE TABLE IF NOT EXISTS public.personaje_game_rutinas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  personaje_game_id uuid NOT NULL REFERENCES public.personajes_game(id) ON DELETE CASCADE,
  clave text NOT NULL,
  dias_semana smallint[] NOT NULL DEFAULT ARRAY[0,1,2,3,4,5,6]::smallint[],
  hora_inicio time NOT NULL,
  hora_fin time NOT NULL,
  ubicacion_clave text NOT NULL,
  actividad_clave text NOT NULL,
  prioridad integer NOT NULL DEFAULT 0,
  condiciones jsonb NOT NULL DEFAULT '{}'::jsonb,
  activo boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT personaje_game_rutinas_personaje_clave_key UNIQUE (personaje_game_id, clave),
  CONSTRAINT personaje_game_rutinas_horario_valido CHECK (hora_fin > hora_inicio),
  CONSTRAINT personaje_game_rutinas_dias_validos CHECK (
    dias_semana <@ ARRAY[0,1,2,3,4,5,6]::smallint[]
  ),
  CONSTRAINT personaje_game_rutinas_ubicacion_no_vacia CHECK (nullif(btrim(ubicacion_clave), '') IS NOT NULL),
  CONSTRAINT personaje_game_rutinas_actividad_no_vacia CHECK (nullif(btrim(actividad_clave), '') IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS idx_personaje_game_rutinas_personaje_hora
  ON public.personaje_game_rutinas (personaje_game_id, hora_inicio)
  WHERE activo;

ALTER TABLE public.personaje_game_rutinas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS personaje_game_rutinas_read_active ON public.personaje_game_rutinas;
CREATE POLICY personaje_game_rutinas_read_active
  ON public.personaje_game_rutinas
  FOR SELECT TO anon, authenticated
  USING (activo = true);
DROP POLICY IF EXISTS personaje_game_rutinas_admin_all ON public.personaje_game_rutinas;
CREATE POLICY personaje_game_rutinas_admin_all
  ON public.personaje_game_rutinas
  FOR ALL TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());
GRANT SELECT ON public.personaje_game_rutinas TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.personaje_game_rutinas TO authenticated;

INSERT INTO public.personajes
  (nombre, sobre, reino, especie, caracteristicas, ciudad_id, publicado)
SELECT v.nombre, v.sobre, 'Torres', 'Humano', v.caracteristicas,
       '6d34fd41-b0ec-4ac5-82ae-74204986fbfa'::uuid, false
FROM (VALUES
('Elian', 'Panadero', 'Elian es el panadero de Torres. Mantiene la panadería en funcionamiento desde temprano, conoce los pedidos habituales y suele reservar pan para quienes llegan tarde. Disfruta conversar mientras trabaja y presta atención a las necesidades del barrio.', 'Amable, sociable, constante, generoso y atento a las costumbres de los vecinos.', 'panaderia'),
('Bruna', 'Herrera', 'Bruna es la herrera de Torres. Trabaja con precisión y paciencia, cuida sus herramientas y prefiere entregar pocas piezas bien hechas antes que aceptar encargos que no puede cumplir. Su carácter es reservado, aunque valora a quienes respetan su oficio.', 'Meticulosa, paciente, orgullosa de su trabajo, prudente y directa al hablar.', 'forja'),
('Darven', 'Guardia', 'Darven sirve como guardia de Torres. Vigila los accesos, recorre los alrededores y procura reconocer a residentes y viajeros habituales. Es disciplinado y no concede confianza con facilidad, pero escucha antes de juzgar.', 'Disciplinado, observador, prudente, reservado y firme ante los riesgos.', 'cuartel'),
('Saira', 'Comerciante', 'Saira administra la casa de comercio de Torres. Organiza mercancías, negocia con viajeros y conoce las rutas por las que llegan productos de otros reinos. Es sociable y perspicaz, y rara vez olvida una conversación útil.', 'Sociable, perspicaz, curiosa, negociadora y cuidadosa con sus recursos.', 'casa_comercio'),
('Narel', 'Investigador de Oris', 'Narel investiga fenómenos relacionados con Oris en la casa de estudio de Torres. Consulta documentos, compara observaciones y registra resultados con método. Su curiosidad puede hacer que pierda la noción del tiempo cuando encuentra una pregunta interesante.', 'Muy curioso, metódico, prudente, reservado y dedicado a la investigación.', 'casa_estudio')
) AS v(nombre, rol, sobre, caracteristicas, ubicacion)
WHERE NOT EXISTS (
  SELECT 1 FROM public.personajes p WHERE lower(p.nombre) = lower(v.nombre)
);

INSERT INTO public.personajes_game
  (nombre, criatura_id, personaje_id, reino_game_id, ubicacion_clave, activo)
SELECT p.nombre,
       '51cabb9f-cb8e-44fe-9172-2049c40f2276'::uuid,
       p.id,
       'd2b3833f-db72-4803-8cab-bdeebdffbf8a'::uuid,
       v.ubicacion,
       true
FROM (VALUES
  ('Elian','panaderia'),
  ('Bruna','forja'),
  ('Darven','cuartel'),
  ('Saira','casa_comercio'),
  ('Narel','casa_estudio')
) AS v(nombre, ubicacion)
JOIN public.personajes p ON lower(p.nombre) = lower(v.nombre)
WHERE NOT EXISTS (
  SELECT 1 FROM public.personajes_game pg WHERE pg.personaje_id = p.id
)
ON CONFLICT (nombre) DO UPDATE
SET ubicacion_clave = EXCLUDED.ubicacion_clave,
    activo = true,
    updated_at = now();

INSERT INTO public.personaje_social_v1
  (personaje_game_id, amistad_inicial, confianza_inicial, respeto_inicial, afecto_inicial,
   sociabilidad, curiosidad, generosidad, prudencia, agresividad, activo)
SELECT pg.id, 0, 0, 0, 0,
       v.sociabilidad, v.curiosidad, v.generosidad, v.prudencia, v.agresividad, true
FROM (VALUES
('Elian', 0, 0, 0, 0, 78, 50, 80, 45, 10),
('Bruna', 0, 0, 0, 0, 40, 45, 55, 80, 20),
('Darven', 0, 0, 0, 0, 35, 35, 45, 90, 30),
('Saira', 0, 0, 0, 0, 88, 85, 45, 60, 10),
('Narel', 0, 0, 0, 0, 35, 95, 55, 70, 5)
) AS v(nombre, amistad, confianza, respeto, afecto, sociabilidad, curiosidad, generosidad, prudencia, agresividad)
JOIN public.personajes_game pg ON lower(pg.nombre) = lower(v.nombre)
ON CONFLICT (personaje_game_id) DO NOTHING;

INSERT INTO public.dialogos_game (personaje_id, clave, dialogo, activo)
SELECT pg.id, 'principal', v.dialogo::jsonb, true
FROM (VALUES
('Elian', '{"variantes":[{"clave":"principal","prioridad":0,"lineas":[{"hablante":"Elian","texto":"¡Buenos días! El horno lleva un rato encendido y la primera tanda acaba de salir."},{"hablante":"Elian","texto":"La panadería suele estar más tranquila antes de que empiece el movimiento del mercado."},{"hablante":"Elian","texto":"¿Buscabas pan o solo querías saludar?"}]},{"clave":"cercano","prioridad":10,"requisito_social":{"amistad_min":20},"lineas":[{"hablante":"Elian","texto":"¡Me alegra verte otra vez! Ya sé qué tipo de pan sueles llevar."},{"hablante":"Elian","texto":"Te guardé una pieza de la última tanda. Hoy quedó especialmente bien."}]},{"clave":"confianza","prioridad":20,"requisito_social":{"confianza_min":30},"lineas":[{"hablante":"Elian","texto":"Te voy a pedir un favor poco habitual. A veces los viajeros dejan encargos pagados y no vuelven."},{"hablante":"Elian","texto":"Quiero asegurarme de que lleguen a quienes los necesitan. Sé que puedo contar contigo."}]}]}'::jsonb),
('Bruna', '{"variantes":[{"clave":"principal","prioridad":0,"lineas":[{"hablante":"Bruna","texto":"Cuidado con el paso. No te acerques al yunque cuando estoy trabajando."},{"hablante":"Bruna","texto":"Si necesitas una herramienta, dime para qué la usarás. No fabrico piezas a ciegas."},{"hablante":"Bruna","texto":"La calidad depende tanto del material como de quien lo trabaja."}]},{"clave":"respeto","prioridad":10,"requisito_social":{"respeto_min":25},"lineas":[{"hablante":"Bruna","texto":"He visto cómo te desenvuelves. No improvisas cuando algo requiere cuidado."},{"hablante":"Bruna","texto":"Puedo enseñarte a reconocer cuándo una pieza está bien equilibrada."}]},{"clave":"confianza","prioridad":20,"requisito_social":{"confianza_min":30},"lineas":[{"hablante":"Bruna","texto":"Hay un encargo que todavía no acepté. El material es bueno, pero su procedencia no me convence."},{"hablante":"Bruna","texto":"Quiero que me ayudes a averiguar de dónde salió antes de trabajarlo."}]}]}'::jsonb),
('Darven', '{"variantes":[{"clave":"principal","prioridad":0,"lineas":[{"hablante":"Darven","texto":"Alto. Este acceso se mantiene vigilado por orden de la guardia."},{"hablante":"Darven","texto":"Si vienes a Torres por primera vez, procura registrar tu llegada."},{"hablante":"Darven","texto":"No es desconfianza personal. Es mi trabajo."}]},{"clave":"respeto","prioridad":10,"requisito_social":{"respeto_min":25},"lineas":[{"hablante":"Darven","texto":"Has demostrado que sabes mantener la calma cuando la situación se complica."},{"hablante":"Darven","texto":"Eso vale más que hablar fuerte. Puedo explicarte cómo organizamos las rondas."}]},{"clave":"confianza","prioridad":20,"requisito_social":{"confianza_min":35},"lineas":[{"hablante":"Darven","texto":"Hay movimientos extraños cerca de uno de los caminos de entrada."},{"hablante":"Darven","texto":"No quiero alarmar a los vecinos sin pruebas. Necesito a alguien discreto que observe conmigo."}]}]}'::jsonb),
('Saira', '{"variantes":[{"clave":"principal","prioridad":0,"lineas":[{"hablante":"Saira","texto":"¡Pasa! Si buscas algo concreto, quizá pueda conseguirlo aunque hoy no esté en los estantes."},{"hablante":"Saira","texto":"Los viajeros traen mercancías, noticias y, a veces, problemas."},{"hablante":"Saira","texto":"¿Qué te interesa encontrar?"}]},{"clave":"cercano","prioridad":10,"requisito_social":{"amistad_min":20},"lineas":[{"hablante":"Saira","texto":"Justo estaba pensando en ti. Llegó un cargamento con algunas cosas que podrían interesarte."},{"hablante":"Saira","texto":"Te las mostraré antes de ponerlas a la venta."}]},{"clave":"confianza","prioridad":20,"requisito_social":{"confianza_min":30},"lineas":[{"hablante":"Saira","texto":"No todos los comerciantes comparten sus contactos, pero contigo haré una excepción."},{"hablante":"Saira","texto":"Puedo presentarte a un proveedor que no suele tratar con desconocidos."}]}]}'::jsonb),
('Narel', '{"variantes":[{"clave":"principal","prioridad":0,"lineas":[{"hablante":"Narel","texto":"Un momento, estoy comparando dos registros y no quiero perder el hilo."},{"hablante":"Narel","texto":"Estudio cómo se manifiestan ciertos fenómenos de Oris en condiciones distintas."},{"hablante":"Narel","texto":"Si tienes una observación concreta, me interesa escucharla."}]},{"clave":"respeto","prioridad":10,"requisito_social":{"respeto_min":20},"lineas":[{"hablante":"Narel","texto":"Tus preguntas han sido bastante precisas. Eso ayuda más de lo que imaginas."},{"hablante":"Narel","texto":"Podrías revisar conmigo unas notas de campo. Necesito otra perspectiva."}]},{"clave":"confianza","prioridad":20,"requisito_social":{"confianza_min":30},"lineas":[{"hablante":"Narel","texto":"Hay una observación que todavía no he incluido en el registro público."},{"hablante":"Narel","texto":"No tengo una explicación segura y prefiero contrastarla contigo antes de sacar conclusiones."}]}]}'::jsonb)
) AS v(nombre, dialogo)
JOIN public.personajes_game pg ON lower(pg.nombre) = lower(v.nombre)
WHERE NOT EXISTS (
  SELECT 1 FROM public.dialogos_game dg
  WHERE dg.personaje_id = pg.id AND dg.clave = 'principal'
);

INSERT INTO public.personaje_game_rutinas
  (personaje_game_id, clave, dias_semana, hora_inicio, hora_fin,
   ubicacion_clave, actividad_clave, prioridad, condiciones, activo)
VALUES
((select id from public.personajes_game where nombre='Elian'), 'preparar_pan', ARRAY[0,1,2,3,4,5,6]::smallint[], '06:00'::time, '10:00'::time, 'panaderia', 'hornear', 0, '{"tipo":"rutina_base"}'::jsonb, true),
((select id from public.personajes_game where nombre='Elian'), 'atender_panaderia', ARRAY[0,1,2,3,4,5,6]::smallint[], '10:00'::time, '15:00'::time, 'panaderia', 'atender', 0, '{"tipo":"rutina_base"}'::jsonb, true),
((select id from public.personajes_game where nombre='Elian'), 'cerrar_panaderia', ARRAY[0,1,2,3,4,5,6]::smallint[], '15:00'::time, '16:00'::time, 'panaderia', 'limpiar', 0, '{"tipo":"rutina_base"}'::jsonb, true),
((select id from public.personajes_game where nombre='Bruna'), 'forja_manana', ARRAY[0,1,2,3,4,5,6]::smallint[], '08:00'::time, '12:00'::time, 'forja', 'forjar', 0, '{"tipo":"rutina_base"}'::jsonb, true),
((select id from public.personajes_game where nombre='Bruna'), 'forja_tarde', ARRAY[0,1,2,3,4,5,6]::smallint[], '13:00'::time, '18:00'::time, 'forja', 'forjar', 0, '{"tipo":"rutina_base"}'::jsonb, true),
((select id from public.personajes_game where nombre='Bruna'), 'revisar_herramientas', ARRAY[0,1,2,3,4,5,6]::smallint[], '18:00'::time, '19:00'::time, 'forja', 'revisar_herramientas', 0, '{"tipo":"rutina_base"}'::jsonb, true),
((select id from public.personajes_game where nombre='Darven'), 'vigilar_registro', ARRAY[0,1,2,3,4,5,6]::smallint[], '06:00'::time, '10:00'::time, 'registro', 'vigilar_acceso', 0, '{"tipo":"rutina_base"}'::jsonb, true),
((select id from public.personajes_game where nombre='Darven'), 'descanso_cuartel', ARRAY[0,1,2,3,4,5,6]::smallint[], '10:00'::time, '11:00'::time, 'cuartel', 'descansar', 0, '{"tipo":"rutina_base"}'::jsonb, true),
((select id from public.personajes_game where nombre='Darven'), 'guardia_cuartel', ARRAY[0,1,2,3,4,5,6]::smallint[], '11:00'::time, '16:00'::time, 'cuartel', 'vigilar', 0, '{"tipo":"rutina_base"}'::jsonb, true),
((select id from public.personajes_game where nombre='Darven'), 'ronda_tarde', ARRAY[0,1,2,3,4,5,6]::smallint[], '16:00'::time, '22:00'::time, 'registro', 'patrullar', 0, '{"tipo":"rutina_base"}'::jsonb, true),
((select id from public.personajes_game where nombre='Saira'), 'abrir_comercio', ARRAY[0,1,2,3,4,5,6]::smallint[], '09:00'::time, '13:00'::time, 'casa_comercio', 'comerciar', 0, '{"tipo":"rutina_base"}'::jsonb, true),
((select id from public.personajes_game where nombre='Saira'), 'ordenar_mercancia', ARRAY[0,1,2,3,4,5,6]::smallint[], '13:00'::time, '14:00'::time, 'casa_comercio', 'ordenar_mercancia', 0, '{"tipo":"rutina_base"}'::jsonb, true),
((select id from public.personajes_game where nombre='Saira'), 'comercio_tarde', ARRAY[0,1,2,3,4,5,6]::smallint[], '14:00'::time, '18:00'::time, 'casa_comercio', 'comerciar', 0, '{"tipo":"rutina_base"}'::jsonb, true),
((select id from public.personajes_game where nombre='Narel'), 'investigar_manana', ARRAY[0,1,2,3,4,5,6]::smallint[], '08:00'::time, '12:00'::time, 'casa_estudio', 'investigar_oris', 0, '{"tipo":"rutina_base"}'::jsonb, true),
((select id from public.personajes_game where nombre='Narel'), 'consultar_archivo', ARRAY[0,1,2,3,4,5,6]::smallint[], '12:00'::time, '13:00'::time, 'archivo_real', 'consultar_archivos', 0, '{"tipo":"rutina_base"}'::jsonb, true),
((select id from public.personajes_game where nombre='Narel'), 'investigar_tarde', ARRAY[0,1,2,3,4,5,6]::smallint[], '13:00'::time, '18:00'::time, 'casa_estudio', 'investigar_oris', 0, '{"tipo":"rutina_base"}'::jsonb, true),
((select id from public.personajes_game where nombre='Narel'), 'registrar_observaciones', ARRAY[0,1,2,3,4,5,6]::smallint[], '18:00'::time, '20:00'::time, 'casa_estudio', 'registrar_observaciones', 0, '{"tipo":"rutina_base"}'::jsonb, true)
ON CONFLICT (personaje_game_id, clave) DO UPDATE
SET dias_semana = EXCLUDED.dias_semana,
    hora_inicio = EXCLUDED.hora_inicio,
    hora_fin = EXCLUDED.hora_fin,
    ubicacion_clave = EXCLUDED.ubicacion_clave,
    actividad_clave = EXCLUDED.actividad_clave,
    prioridad = EXCLUDED.prioridad,
    condiciones = EXCLUDED.condiciones,
    activo = true,
    updated_at = now();

CREATE OR REPLACE FUNCTION public.get_mundo_inicial()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
SELECT base.mundo || jsonb_build_object(
  'reinos_game', coalesce((
    SELECT jsonb_agg(
      jsonb_build_object(
        'id', rg.id,
        'reino_id', rg.reino_id,
        'clave', rg.clave,
        'nombre', r.nombre,
        'descripcion', r.descripcion,
        'orden', rg.orden,
        'propiedades', rg.propiedades,
        'bioma_ids', coalesce((
          SELECT jsonb_agg(br.bioma_id ORDER BY b.orden, b.nombre)
          FROM public.bioma_reinos br
          JOIN public.biomas b ON b.id = br.bioma_id
          WHERE br.reino_id = r.id
        ), '[]'::jsonb)
      )
      ORDER BY rg.orden, r.nombre, rg.id
    )
    FROM public.reinos_game rg
    JOIN public.reinos r ON r.id = rg.reino_id
    WHERE rg.activo
  ), '[]'::jsonb),

  'props_game', coalesce((
    SELECT jsonb_agg(
      jsonb_build_object(
        'id', pg.id,
        'clave', pg.clave,
        'nombre', pg.nombre,
        'bioma_id', pg.bioma_id,
        'bioma_nombre', b.nombre,
        'ecosistema_id', pg.ecosistema_id,
        'ecosistema_nombre', e.nombre,
        'habitat_id', pg.habitat_id,
        'habitat_nombre', h.nombre,
        'tipo', pg.tipo,
        'orden', pg.orden,
        'peso', pg.peso,
        'escala', pg.escala,
        'offset_x', pg.offset_x,
        'offset_y', pg.offset_y,
        'propiedades', pg.propiedades
      )
      ORDER BY b.orden, b.nombre, e.orden, e.nombre, h.orden, h.nombre, pg.orden, pg.nombre, pg.id
    )
    FROM public.props_game pg
    JOIN public.biomas b ON b.id = pg.bioma_id
    JOIN public.ecosistemas e ON e.id = pg.ecosistema_id AND e.bioma_id = pg.bioma_id
    JOIN public.habitats h ON h.id = pg.habitat_id AND h.ecosistema_id = e.id
    WHERE pg.activo
  ), '[]'::jsonb),

  'personajes_game', coalesce((
    SELECT jsonb_agg(
      jsonb_build_object(
        'id', pg.id,
        'nombre', p.nombre,
        'ubicacion_clave', pg.ubicacion_clave,
        'rutinas', coalesce((
          SELECT jsonb_agg(
            jsonb_build_object(
              'id', r.id,
              'clave', r.clave,
              'dias_semana', r.dias_semana,
              'hora_inicio', r.hora_inicio,
              'hora_fin', r.hora_fin,
              'ubicacion_clave', r.ubicacion_clave,
              'actividad_clave', r.actividad_clave,
              'prioridad', r.prioridad,
              'condiciones', r.condiciones
            )
            ORDER BY r.hora_inicio, r.prioridad DESC, r.clave
          )
          FROM public.personaje_game_rutinas r
          WHERE r.personaje_game_id = pg.id AND r.activo
        ), '[]'::jsonb),
        'criatura_id', pg.criatura_id,
        'personaje_id', p.id,
        'reino_id', r.id,
        'reino_game_id', rg.id,
        'reino_clave', rg.clave,
        'reino_nombre', r.nombre,
        'bioma_ids', coalesce((
          SELECT jsonb_agg(br.bioma_id ORDER BY b.orden, b.nombre)
          FROM public.bioma_reinos br
          JOIN public.biomas b ON b.id = br.bioma_id
          WHERE br.reino_id = r.id
        ), '[]'::jsonb)
      )
      ORDER BY p.nombre
    )
    FROM public.personajes_game pg
    JOIN public.personajes p ON p.id = pg.personaje_id
    LEFT JOIN public.reinos r ON lower(r.nombre) = lower(p.reino)
    LEFT JOIN public.reinos_game rg ON rg.reino_id = r.id AND rg.activo
    WHERE pg.activo
  ), '[]'::jsonb),

  'dialogos_game', coalesce((
    SELECT jsonb_agg(
      jsonb_build_object(
        'id', dg.id,
        'personaje_id', dg.personaje_id,
        'clave', dg.clave,
        'dialogo', dg.dialogo
      )
      ORDER BY dg.personaje_id, dg.clave
    )
    FROM public.dialogos_game dg
    WHERE dg.activo
  ), '[]'::jsonb),

  'misiones_game', coalesce((
    SELECT jsonb_agg(
      jsonb_build_object(
        'id', m.id,
        'clave', m.clave,
        'nombre', m.nombre,
        'descripcion', m.descripcion,
        'tipo', m.tipo,
        'orden', m.orden,
        'auto_aceptar', m.auto_aceptar,
        'objetivos', coalesce((
          SELECT jsonb_agg(
            jsonb_build_object(
              'id', o.id,
              'orden', o.orden,
              'tipo', o.tipo,
              'descripcion', o.descripcion,
              'cantidad_requerida', o.cantidad_requerida,
              'item_id', o.item_id,
              'criatura_id', o.criatura_id,
              'personaje_id', o.personaje_id,
              'clave', o.clave,
              'datos', o.datos
            )
            ORDER BY o.orden, o.id
          )
          FROM public.misiones_objetivos_game o
          WHERE o.mision_id = m.id AND o.activo
        ), '[]'::jsonb),
        'recompensas', coalesce((
          SELECT jsonb_agg(
            jsonb_build_object(
              'id', rw.id,
              'orden', rw.orden,
              'tipo', rw.tipo,
              'cantidad', rw.cantidad,
              'item_id', rw.item_id,
              'datos', rw.datos
            )
            ORDER BY rw.orden, rw.id
          )
          FROM public.misiones_recompensas_game rw
          WHERE rw.mision_id = m.id AND rw.activo
        ), '[]'::jsonb)
      )
      ORDER BY m.orden, m.nombre
    )
    FROM public.misiones_game m
    WHERE m.activo
  ), '[]'::jsonb),

  'garumis_game', coalesce((
    SELECT jsonb_agg(
      jsonb_build_object(
        'id', g.id,
        'nombre', g.nombre,
        'categoria_garumi', g.categoria_garumi,
        'original_id', g.original_id,
        'numero_origen', g.numero_origen,
        'numero_global', g.numero_global,
        'estado_documentacion', g.estado_documentacion,
        'concepto', g.concepto,
        'descripcion', g.descripcion,
        'asset_key', g.nombre,
        'aparicion', jsonb_build_object(
          'habitat_claves', jsonb_build_array('general'),
          'habitat_clave', 'general',
          'probabilidad_chunk', 1.0,
          'peso_spawn', 1.0
        )
      )
      ORDER BY g.numero_global
    )
    FROM public.garumis g
    WHERE g.estado_documentacion IN ('aprobado', 'canon')
      AND g.categoria_garumi = 'normal'
      AND g.original_id = '24f86486-aced-4a23-bd1b-f025561a8aa3'::uuid
      
  ), '[]'::jsonb)
)
FROM (
  SELECT public.get_mundo_inicial_base_v1() AS mundo
) base;
$function$

