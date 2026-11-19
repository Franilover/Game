-- Individual item exemplars inherit their base item's visual and gameplay data.
-- Only narrative overrides and explicit world links are stored per exemplar.

create table if not exists public.item_ejemplares (
  id uuid primary key default gen_random_uuid(),
  item_base_id uuid not null references public.items(id) on delete restrict,
  nombre text not null check (nullif(btrim(nombre), '') is not null),
  descripcion text,
  descripcion_detallada text,
  metadatos jsonb not null default '{}'::jsonb check (jsonb_typeof(metadatos) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint item_ejemplares_nombre_por_base_unique unique (item_base_id, nombre)
);

comment on table public.item_ejemplares is
'Variantes narrativas individuales de un objeto base. Heredan sprite, tipo y propiedades del objeto base; solo almacenan diferencias.';

comment on column public.item_ejemplares.descripcion_detallada is
'Texto exclusivo de este ejemplar, disponible para análisis cuando no sea nulo ni vacío.';

create index if not exists idx_item_ejemplares_item_base_id
  on public.item_ejemplares(item_base_id);

create table if not exists public.item_ejemplar_vinculos (
  id uuid primary key default gen_random_uuid(),
  ejemplar_id uuid not null references public.item_ejemplares(id) on delete cascade,
  tipo_vinculo text not null check (tipo_vinculo in ('personaje', 'lugar', 'evento')),
  personaje_id uuid references public.personajes(id) on delete restrict,
  lugar_id uuid references public.lugares(id) on delete restrict,
  evento_id uuid references public.eventos_mundo(id) on delete restrict,
  etiqueta text,
  created_at timestamptz not null default now(),
  constraint item_ejemplar_vinculo_target_check check (
    (tipo_vinculo = 'personaje' and personaje_id is not null and lugar_id is null and evento_id is null)
    or (tipo_vinculo = 'lugar' and lugar_id is not null and personaje_id is null and evento_id is null)
    or (tipo_vinculo = 'evento' and evento_id is not null and personaje_id is null and lugar_id is null)
  ),
  constraint item_ejemplar_vinculo_unique_personaje unique (ejemplar_id, personaje_id),
  constraint item_ejemplar_vinculo_unique_lugar unique (ejemplar_id, lugar_id),
  constraint item_ejemplar_vinculo_unique_evento unique (ejemplar_id, evento_id)
);

comment on table public.item_ejemplar_vinculos is
'Relaciones explícitas de un ejemplar con personajes, lugares o eventos del mundo.';

create index if not exists idx_item_ejemplar_vinculos_ejemplar
  on public.item_ejemplar_vinculos(ejemplar_id);

alter table public.item_ejemplares enable row level security;
alter table public.item_ejemplar_vinculos enable row level security;

create policy item_ejemplares_public_read
  on public.item_ejemplares for select
  using (
    exists (
      select 1 from public.items i
      left join public.items_game ig on ig.item_id = i.id
      where i.id = item_ejemplares.item_base_id
        and (ig.item_id is not null or i.publicado is true or i.creador_id = auth.uid() or public.is_admin())
    )
  );

create policy item_ejemplares_admin_write
  on public.item_ejemplares for all
  using (public.is_admin())
  with check (public.is_admin());

create policy item_ejemplar_vinculos_public_read
  on public.item_ejemplar_vinculos for select
  using (
    exists (
      select 1 from public.item_ejemplares e
      join public.items i on i.id = e.item_base_id
      left join public.items_game ig on ig.item_id = i.id
      where e.id = item_ejemplar_vinculos.ejemplar_id
        and (ig.item_id is not null or i.publicado is true or i.creador_id = auth.uid() or public.is_admin())
    )
  );

create policy item_ejemplar_vinculos_admin_write
  on public.item_ejemplar_vinculos for all
  using (public.is_admin())
  with check (public.is_admin());

grant select on public.item_ejemplares to anon, authenticated;
grant select on public.item_ejemplar_vinculos to anon, authenticated;
grant insert, update, delete on public.item_ejemplares to authenticated;
grant insert, update, delete on public.item_ejemplar_vinculos to authenticated;
