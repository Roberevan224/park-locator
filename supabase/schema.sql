create extension if not exists pgcrypto;

create table if not exists public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 display_name text not null default 'Trail Navigator',
 created_at timestamptz not null default now()
);

create table if not exists public.account_profiles (
 id uuid primary key default gen_random_uuid(),
 account_id uuid not null references auth.users(id) on delete cascade,
 display_name text not null default 'Profile',
 avatar text not null default '🧭',
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);

create table if not exists public.user_devices (
 id uuid primary key default gen_random_uuid(),
 account_id uuid not null references auth.users(id) on delete cascade,
 device_key text not null,
 device_name text not null default 'My device',
 platform text not null default 'Web',
 last_seen_at timestamptz not null default now(),
 created_at timestamptz not null default now(),
 unique(account_id, device_key)
);

create table if not exists public.obstruction_reports (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 profile_id uuid references public.account_profiles(id) on delete set null,
 latitude double precision not null check(latitude between -90 and 90),
 longitude double precision not null check(longitude between -180 and 180),
 type text not null check(type in ('fallen-tree','flooding','rockfall','washout','closed-trail','ice-snow','wildlife','other')),
 description text not null default '',
 status text not null default 'open' check(status in ('open','confirmed','resolved')),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.account_profiles enable row level security;
alter table public.user_devices enable row level security;
alter table public.obstruction_reports enable row level security;

drop policy if exists "profiles own read" on public.profiles;
drop policy if exists "profiles own insert" on public.profiles;
drop policy if exists "profiles own update" on public.profiles;
create policy "profiles own read" on public.profiles for select using (auth.uid()=id);
create policy "profiles own insert" on public.profiles for insert with check (auth.uid()=id);
create policy "profiles own update" on public.profiles for update using (auth.uid()=id) with check (auth.uid()=id);

drop policy if exists "account profiles own read" on public.account_profiles;
drop policy if exists "account profiles own insert" on public.account_profiles;
drop policy if exists "account profiles own update" on public.account_profiles;
drop policy if exists "account profiles own delete" on public.account_profiles;
create policy "account profiles own read" on public.account_profiles for select using (auth.uid()=account_id);
create policy "account profiles own insert" on public.account_profiles for insert with check (auth.uid()=account_id);
create policy "account profiles own update" on public.account_profiles for update using (auth.uid()=account_id) with check (auth.uid()=account_id);
create policy "account profiles own delete" on public.account_profiles for delete using (auth.uid()=account_id);

drop policy if exists "devices own read" on public.user_devices;
drop policy if exists "devices own insert" on public.user_devices;
drop policy if exists "devices own update" on public.user_devices;
drop policy if exists "devices own delete" on public.user_devices;
create policy "devices own read" on public.user_devices for select using (auth.uid()=account_id);
create policy "devices own insert" on public.user_devices for insert with check (auth.uid()=account_id);
create policy "devices own update" on public.user_devices for update using (auth.uid()=account_id) with check (auth.uid()=account_id);
create policy "devices own delete" on public.user_devices for delete using (auth.uid()=account_id);

drop policy if exists "reports public read" on public.obstruction_reports;
drop policy if exists "reports authenticated insert" on public.obstruction_reports;
drop policy if exists "reports owner update" on public.obstruction_reports;
create policy "reports public read" on public.obstruction_reports for select using (true);
create policy "reports authenticated insert" on public.obstruction_reports for insert with check (auth.uid()=user_id);
create policy "reports owner update" on public.obstruction_reports for update using (auth.uid()=user_id) with check (auth.uid()=user_id);

create index if not exists account_profiles_account_idx on public.account_profiles(account_id);
create index if not exists user_devices_account_idx on public.user_devices(account_id);
create index if not exists obstruction_reports_location_idx on public.obstruction_reports(latitude,longitude);
create index if not exists obstruction_reports_created_idx on public.obstruction_reports(created_at desc);

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path=public as $$
begin
 insert into public.profiles(id,display_name)
 values(new.id,coalesce(new.raw_user_meta_data->>'display_name','Trail Navigator'))
 on conflict(id) do nothing;
 insert into public.account_profiles(account_id,display_name,avatar)
 values(new.id,coalesce(new.raw_user_meta_data->>'display_name','Main Profile'),'🧭');
 return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();

-- Backfill a profile for accounts created before multi-profile support.
insert into public.account_profiles(account_id,display_name,avatar)
select p.id,p.display_name,'🧭'
from public.profiles p
where not exists(select 1 from public.account_profiles ap where ap.account_id=p.id);

-- Anonymous, privacy-preserving trail activity.
-- Stores only a coarse ~1.1 km location cell and an anonymous session id.
create table if not exists public.trail_activity (
 id uuid primary key default gen_random_uuid(),
 session_id uuid not null unique,
 cell_lat double precision not null,
 cell_lon double precision not null,
 last_seen_at timestamptz not null default now()
);

alter table public.trail_activity enable row level security;
revoke all on public.trail_activity from anon, authenticated;

create or replace function public.touch_trail_activity(
 p_session_id uuid,
 p_lat double precision,
 p_lon double precision
) returns void
language plpgsql
security definer
set search_path=public
as $$
begin
 if auth.uid() is null then
   raise exception 'Authentication required';
 end if;
 if p_lat < -90 or p_lat > 90 or p_lon < -180 or p_lon > 180 then
   raise exception 'Invalid location';
 end if;
 delete from public.trail_activity where session_id=p_session_id;
 insert into public.trail_activity(session_id,cell_lat,cell_lon,last_seen_at)
 values(
   p_session_id,
   round(p_lat::numeric,2)::double precision,
   round(p_lon::numeric,2)::double precision,
   now()
 );
end;
$$;

create or replace function public.get_trail_activity(
 p_lat double precision,
 p_lon double precision
) returns table(people_count bigint)
language sql
security definer
set search_path=public
as $$
 select count(*)
 from public.trail_activity
 where last_seen_at > now() - interval '5 minutes'
   and cell_lat between round(p_lat::numeric,2)::double precision - 0.02
                       and round(p_lat::numeric,2)::double precision + 0.02
   and cell_lon between round(p_lon::numeric,2)::double precision - 0.02
                       and round(p_lon::numeric,2)::double precision + 0.02;
$$;

grant execute on function public.touch_trail_activity(uuid,double precision,double precision) to authenticated;
grant execute on function public.get_trail_activity(double precision,double precision) to authenticated;

create index if not exists trail_activity_seen_idx on public.trail_activity(last_seen_at);
create index if not exists trail_activity_cell_idx on public.trail_activity(cell_lat,cell_lon);
