-- Complaint app admin RPCs and row-level security policies.
-- Run this in Supabase SQL Editor or via `supabase db push`.

create extension if not exists "pgcrypto";

alter table if exists public.users enable row level security;
alter table if exists public.complaints enable row level security;
alter table if exists public.notifications enable row level security;

create or replace function public.is_admin(uid uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.users
    where id = uid
      and lower(role) = 'admin'
  );
$$;

create or replace function public.update_complaint_by_admin(
  complaint_id uuid,
  new_status text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  updated_row jsonb;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if not public.is_admin(auth.uid()) then
    raise exception 'Access denied: admin privileges required';
  end if;

  update public.complaints as c
  set status = new_status
  where c.id = complaint_id
  returning to_jsonb(c) into updated_row;

  if updated_row is null then
    raise exception 'Complaint not found for id %', complaint_id;
  end if;

  return updated_row;
end;
$$;

create or replace function public.add_reply_by_admin(
  complaint_id uuid,
  reply_data jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  updated_row jsonb;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if not public.is_admin(auth.uid()) then
    raise exception 'Access denied: admin privileges required';
  end if;

  update public.complaints as c
  set replies = coalesce(c.replies, '[]'::jsonb) || jsonb_build_array(reply_data)
  where c.id = complaint_id
  returning to_jsonb(c) into updated_row;

  if updated_row is null then
    raise exception 'Complaint not found for id %', complaint_id;
  end if;

  return updated_row;
end;
$$;

drop policy if exists "users_select_own_or_admin" on public.users;
create policy "users_select_own_or_admin"
on public.users
for select
to authenticated
using (
  id = auth.uid()
  or public.is_admin(auth.uid())
);

drop policy if exists "users_insert_own_profile" on public.users;
create policy "users_insert_own_profile"
on public.users
for insert
to authenticated
with check (
  id = auth.uid()
  or public.is_admin(auth.uid())
);

drop policy if exists "users_update_own_or_admin" on public.users;
create policy "users_update_own_or_admin"
on public.users
for update
to authenticated
using (
  id = auth.uid()
  or public.is_admin(auth.uid())
)
with check (
  id = auth.uid()
  or public.is_admin(auth.uid())
);

drop policy if exists "complaints_select_own_or_admin" on public.complaints;
create policy "complaints_select_own_or_admin"
on public.complaints
for select
to authenticated
using (
  public.is_admin(auth.uid())
  or exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and u.student_id = complaints.student_id
  )
);

drop policy if exists "complaints_insert_own" on public.complaints;
create policy "complaints_insert_own"
on public.complaints
for insert
to authenticated
with check (
  exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and u.student_id = complaints.student_id
  )
);

drop policy if exists "complaints_update_own_or_admin" on public.complaints;
create policy "complaints_update_own_or_admin"
on public.complaints
for update
to authenticated
using (
  public.is_admin(auth.uid())
  or exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and u.student_id = complaints.student_id
  )
)
with check (
  public.is_admin(auth.uid())
  or exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and u.student_id = complaints.student_id
  )
);

drop policy if exists "notifications_select_own" on public.notifications;
create policy "notifications_select_own"
on public.notifications
for select
to authenticated
using (user_id = auth.uid() or public.is_admin(auth.uid()));

drop policy if exists "notifications_insert_admin" on public.notifications;
create policy "notifications_insert_admin"
on public.notifications
for insert
to authenticated
with check (public.is_admin(auth.uid()));

drop policy if exists "notifications_update_own_or_admin" on public.notifications;
create policy "notifications_update_own_or_admin"
on public.notifications
for update
to authenticated
using (user_id = auth.uid() or public.is_admin(auth.uid()))
with check (user_id = auth.uid() or public.is_admin(auth.uid()));
