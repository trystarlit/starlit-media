-- starlit: one backup row per (anonymous) user.
-- Supabase → SQL Editor → paste this → Run. Also turn on Authentication → Sign In / Providers → "Allow anonymous sign-ins".

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  onboarded boolean not null default false,
  name text not null default '',
  goals text[] not null default '{}',
  want_minutes int not null default 1380,
  actual_minutes int not null default 1530,
  wake_minutes int not null default 420,
  mornings text not null default '',
  keeps_up text[] not null default '{}',
  nights_kept int not null default 0,
  streak int not null default 0,
  best_streak int not null default 0,
  rest_days_left int not null default 1,
  rest_week int not null default 0,
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- each user can only see and change their own row
create policy "own profile: read" on public.profiles for select using (auth.uid() = id);
create policy "own profile: insert" on public.profiles for insert with check (auth.uid() = id);
create policy "own profile: update" on public.profiles for update using (auth.uid() = id) with check (auth.uid() = id);

create or replace function public.touch_updated_at() returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

drop trigger if exists profiles_touch on public.profiles;
create trigger profiles_touch before update on public.profiles
  for each row execute function public.touch_updated_at();
