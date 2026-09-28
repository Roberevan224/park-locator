create extension if not exists pgcrypto;
create table if not exists public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 display_name text not null default 'Trail Navigator',
 created_at timestamptz not null default now()
);
create table if not exists public.obstruction_reports (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 latitude double precision not null check(latitude between -90 and 90),
 longitude double precision not null check(longitude between -180 and 180),
 type text not null check(type in ('fallen-tree','flooding','rockfall','washout','closed-trail','ice-snow','wildlife','other')),
 description text not null default '',
 status text not null default 'open' check(status in ('open','confirmed','resolved')),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
alter table public.profiles enable row level security;
alter table public.obstruction_reports enable row level security;
create policy "profiles own read" on public.profiles for select using (auth.uid()=id);
create policy "profiles own insert" on public.profiles for insert with check (auth.uid()=id);
create policy "profiles own update" on public.profiles for update using (auth.uid()=id) with check (auth.uid()=id);
create policy "reports public read" on public.obstruction_reports for select using (true);
create policy "reports authenticated insert" on public.obstruction_reports for insert with check (auth.uid()=user_id);
create policy "reports owner update" on public.obstruction_reports for update using (auth.uid()=user_id) with check (auth.uid()=user_id);
create index if not exists obstruction_reports_location_idx on public.obstruction_reports(latitude,longitude);
create index if not exists obstruction_reports_created_idx on public.obstruction_reports(created_at desc);
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path=public as $$
begin
 insert into public.profiles(id,display_name)
 values(new.id,coalesce(new.raw_user_meta_data->>'display_name','Trail Navigator'))
 on conflict(id) do nothing;
 return new;
end;
$$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();