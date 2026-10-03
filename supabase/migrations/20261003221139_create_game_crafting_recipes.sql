create table if not exists public.recetas_game (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  descripcion text,
  categoria text not null default 'herramienta',
  ingredientes jsonb not null default '[]'::jsonb,
  resultado jsonb not null,
  propiedades jsonb not null default '{}'::jsonb,
  desbloqueada_por_defecto boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint recetas_game_ingredientes_array check (jsonb_typeof(ingredientes) = 'array'),
  constraint recetas_game_resultado_object check (jsonb_typeof(resultado) = 'object')
);

create index if not exists recetas_game_categoria_idx on public.recetas_game(categoria);
create index if not exists recetas_game_resultado_item_idx on public.recetas_game((resultado->>'item_id'));

alter table public.recetas_game enable row level security;

create policy "recetas_game_select_publicado"
on public.recetas_game
for select to anon, authenticated
using (true);
