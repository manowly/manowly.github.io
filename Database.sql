-- Extension pour les UUID
create extension if not exists "uuid-ossp";

-- Profile (lié à auth.users, remplace ta table User)
create table Profile (
  id uuid references auth.users(id) on delete cascade primary key,
  name text not null,
  picture text
);

-- Post
create table Post (
  id uuid default gen_random_uuid() primary key,
  created_by uuid references Profile(id) on delete cascade not null,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now(),
  content text not null
);

-- Comment
create table Comment (
  id uuid default gen_random_uuid() primary key,
  id_post uuid references Post(id) on delete cascade not null,
  created_by uuid references Profile(id) on delete cascade not null,
  created_at timestamp with time zone default now(),
  content text not null
);

-- Heart
create table Heart(
  id uuid default gen_random_uuid() primary key,
  id_post uuid references Post(id) on delete cascade not null,
  id_user uuid references Profile(id) on delete cascade not null,
  unique(id_post, id_user)
);

-- Row Level Security
alter table Profile enable row level security;
alter table Post enable row level security;
alter table Comment enable row level security;
alter table Heart enable row level security;

-- Policies Profile
create policy "Lecture publique" on Profile
  for select using (true);
create policy "Modifier son propre profil" on Profile
  for update using (auth.uid() = id);
create policy "Créer son profil" on Profile
  for insert with check (auth.uid() = id);

-- Policies Post
create policy "Lecture publique" on Post
  for select using (true);
create policy "Créer un post" on Post
  for insert with check (auth.uid() = created_by);
create policy "Modifier son post" on Post
  for update using (auth.uid() = created_by);
create policy "Supprimer son post" on Post
  for delete using (auth.uid() = created_by);

-- Policies Comment
create policy "Lecture publique" on Comment
  for select using (true);
create policy "Créer un commentaire" on Comment
  for insert with check (auth.uid() = created_by);
create policy "Supprimer son commentaire" on Comment
  for delete using (auth.uid() = created_by);

-- Policies Heart
create policy "Lecture publique" on Heart
  for select using (true);
create policy "Liker" on Heart
  for insert with check (auth.uid() = id_user);
create policy "Unliker" on Heart
  for delete using (auth.uid() = id_user);

-- Trigger : créer un profil automatiquement à l'inscription
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.Profile (id, name)
  values (new.id, new.raw_user_meta_data->>'name');
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
