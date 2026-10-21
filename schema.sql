-- Lowry Family Secret Santa: database schema (one login per person).
-- Run once in the Supabase SQL editor on a fresh project.
-- All access goes through the santa_* functions at the bottom. The tables have RLS on
-- and no policies, so the public (anon) key can't read them directly.

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.people (
  id         int primary key,
  name       text not null,
  partner_id int,                 -- your partner can't be your match
  pin_hash   text,
  wishlist   text not null default '',
  gives_to   int references public.people(id)
);

create table if not exists public.settings (
  id        int primary key default 1 check (id = 1),
  drawn     boolean not null default false,
  reveal_at timestamptz not null default '2026-12-25 00:00:00 Europe/London'   -- when the big reveal unlocks
);

alter table public.people   enable row level security;
alter table public.settings enable row level security;

insert into public.people (id, name, partner_id) values
  (1, 'Patrick', 2),  (2, 'Rebecca', 1),
  (3, 'Chris', 4),    (4, 'Lauren', 3),
  (5, 'Matthew', 6),  (6, 'Jane', 5),
  (7, 'Frances', 8),  (8, 'Billy', 7),
  (9, 'Charlotte', 10), (10, 'Simon', 9)
on conflict (id) do nothing;

insert into public.settings (id, drawn) values (1, false) on conflict (id) do nothing;

-- internal: raises unless the PIN matches an already-claimed person
create or replace function public._santa_auth(w int, p text)
returns void language plpgsql security definer set search_path = public, extensions as $$
declare h text;
begin
  select pin_hash into h from people where id = w;
  if h is null or h <> crypt(coalesce(p, ''), h) then
    raise exception 'Wrong PIN';
  end if;
end $$;

-- public: who exists and who has joined (no secrets)
create or replace function public.santa_status()
returns json language sql security definer set search_path = public as $$
  select json_build_object(
    'drawn', (select drawn from settings where id = 1),
    'people', (select json_agg(json_build_object('id', id, 'name', name, 'joined', pin_hash is not null) order by id) from people));
$$;

-- first login claims the person and sets their PIN; later logins check it
create or replace function public.santa_login(w int, p text)
returns json language plpgsql security definer set search_path = public, extensions as $$
declare h text;
begin
  select pin_hash into h from people where id = w;
  if not found then raise exception 'Unknown person'; end if;
  if h is null then
    if coalesce(length(p), 0) < 4 then raise exception 'PIN must be at least 4 characters'; end if;
    update people set pin_hash = crypt(p, gen_salt('bf')) where id = w;
    return json_build_object('ok', true, 'first', true);
  end if;
  perform _santa_auth(w, p);
  return json_build_object('ok', true, 'first', false);
end $$;

create or replace function public.santa_save_wishlist(w int, p text, wl text)
returns void language plpgsql security definer set search_path = public, extensions as $$
begin
  perform _santa_auth(w, p);
  update people set wishlist = left(coalesce(wl, ''), 4000) where id = w;
end $$;

-- the draw: one random loop through everyone, so each person gives to exactly one person and
-- receives from exactly one. Nobody gets themselves or their own partner. It runs automatically the
-- first time anyone logs in and covers everyone, including people who haven't logged in yet.
create or replace function public._santa_do_draw()
returns void language plpgsql security definer set search_path = public as $$
declare ord int[]; n int; i int; d boolean; ok boolean; tries int := 0;
begin
  select drawn into d from settings where id = 1 for update;
  if d then return; end if;
  loop
    tries := tries + 1;
    select array_agg(id order by random()) into ord from people;
    n := array_length(ord, 1);
    ok := true;
    for i in 1..n loop
      if exists (select 1 from people where id = ord[i] and partner_id = ord[i % n + 1]) then
        ok := false; exit;
      end if;
    end loop;
    exit when ok;
    if tries > 2000 then raise exception 'Could not find a valid draw'; end if;
  end loop;
  for i in 1..n loop
    update people set gives_to = ord[i % n + 1] where id = ord[i];
  end loop;
  update settings set drawn = true where id = 1;
end $$;

-- my wish list and my match; the first person to get here triggers the draw for everyone
create or replace function public.santa_me(w int, p text)
returns json language plpgsql security definer set search_path = public, extensions as $$
declare me people; r people;
begin
  perform _santa_auth(w, p);
  perform _santa_do_draw();
  select * into me from people where id = w;
  select * into r from people where id = me.gives_to;
  return json_build_object(
    'wishlist', me.wishlist,
    'drawn', true,
    'recipient', json_build_object('id', r.id, 'name', r.name, 'wishlist', r.wishlist));
end $$;

-- internal: the whole gift loop in order, starting from person 1 (each name gives to the next; the last gives to the first)
create or replace function public._santa_chain()
returns json language plpgsql security definer set search_path = public as $$
declare cur int := 1; names text[] := '{}'; n int; i int := 0;
begin
  select count(*) into n from people;
  loop
    names := names || (select name from people where id = cur);
    select gives_to into cur from people where id = cur;
    i := i + 1;
    exit when cur is null or cur = 1 or i >= n;
  end loop;
  return to_json(names);
end $$;

-- Christmas Day big reveal (logged-in only): before reveal_at it just says when; from then it returns the whole loop
create or replace function public.santa_reveal(w int, p text)
returns json language plpgsql security definer set search_path = public, extensions as $$
declare at timestamptz; d boolean;
begin
  perform _santa_auth(w, p);
  select reveal_at, drawn into at, d from settings where id = 1;
  if now() < at or not d then
    return json_build_object('ready', false, 'at', at);
  end if;
  return json_build_object('ready', true, 'chain', _santa_chain());
end $$;

revoke all on function public._santa_auth(int, text) from public, anon, authenticated;
revoke all on function public._santa_chain() from public, anon, authenticated;
revoke all on function public._santa_do_draw() from public, anon, authenticated;
revoke all on function public.santa_status(), public.santa_login(int, text), public.santa_me(int, text), public.santa_save_wishlist(int, text, text), public.santa_reveal(int, text) from public;
grant execute on function
  public.santa_status(), public.santa_login(int, text), public.santa_me(int, text),
  public.santa_save_wishlist(int, text, text), public.santa_reveal(int, text)
to anon;
