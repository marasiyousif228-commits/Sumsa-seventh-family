-- SUMSA 7th Batch Family: run in Supabase SQL Editor.
create extension if not exists pgcrypto;
create table if not exists public.secretariats (
 id uuid primary key default gen_random_uuid(),
 name text not null unique,
 branch text not null check (branch in ('executive_office','executive_committee')),
 created_at timestamptz not null default now()
);
insert into public.secretariats(name,branch) values
 ('مكتب الرئاسة','executive_office'),('السكرتارية العامة','executive_office'),('السكرتارية المالية','executive_office'),
 ('السكرتارية الإعلامية','executive_committee'),('الشؤون الثقافية','executive_committee'),
 ('الشؤون الاجتماعية والرياضية','executive_committee'),('الشؤون الأكاديمية والبحث العلمي','executive_committee'),('الصحة العامة','executive_committee')
on conflict(name) do nothing;
create table if not exists public.sub_offices(
 id uuid primary key default gen_random_uuid(), secretariat_id uuid not null references public.secretariats(id) on delete cascade,
 name text not null, created_at timestamptz not null default now(), unique(secretariat_id,name)
);
create table if not exists public.profiles(
 id uuid primary key references auth.users(id) on delete cascade,
 full_name text not null, email text not null, phone text, role text not null default 'member'
 check(role in ('president','secretary_general','finance_secretary','secretary','member')),
 position text, secretariat_id text references public.secretariats(name), sub_office_id uuid references public.sub_offices(id),
 avatar_url text, membership_status text not null default 'active', created_at timestamptz not null default now()
);
create table if not exists public.tasks(
 id uuid primary key default gen_random_uuid(), title text not null, description text,
 secretariat_id text not null references public.secretariats(name), sub_office_id uuid references public.sub_offices(id),
 assignee_id uuid not null references public.profiles(id), created_by uuid not null references public.profiles(id),
 assigned_at timestamptz not null default now(), due_at date not null, priority text not null default 'medium'
 check(priority in ('low','medium','high','urgent')), status text not null default 'not_started'
 check(status in ('not_started','in_progress','completed')), notes text, completed_at timestamptz,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.notification_settings(
 id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete cascade,
 enabled boolean not null default true, reminder_days integer not null default 2, overdue_enabled boolean not null default true,
 unique(user_id)
);
create table if not exists public.notification_log(
 id uuid primary key default gen_random_uuid(), task_id uuid not null references public.tasks(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade, kind text not null,
 sent_at timestamptz not null default now(), unique(task_id,user_id,kind)
);
create or replace function public.current_role() returns text language sql stable security definer set search_path=public
as $$ select role from public.profiles where id=auth.uid() $$;
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path=public
as $$ select coalesce(public.current_role() in ('president','secretary_general'),false) $$;
create or replace function public.can_manage_secretariat(target text) returns boolean language sql stable security definer set search_path=public
as $$ select public.is_admin() or exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='secretary' and p.secretariat_id=target) $$;
create or replace function public.enforce_task_assignment() returns trigger language plpgsql security definer set search_path=public
as $$
declare assignee_secretariat text; creator_role text; creator_secretariat text;
begin
 select secretariat_id into assignee_secretariat from public.profiles where id=new.assignee_id;
 if assignee_secretariat is distinct from new.secretariat_id then raise exception 'Assignee must belong to the selected secretariat'; end if;
 select role,secretariat_id into creator_role,creator_secretariat from public.profiles where id=auth.uid();
 if creator_role='secretary' and creator_secretariat is distinct from new.secretariat_id then raise exception 'Secretary can only assign tasks within own secretariat'; end if;
 if tg_op='UPDATE' and old.assignee_id=auth.uid() and not public.can_manage_secretariat(old.secretariat_id) then
   if new.title is distinct from old.title or new.description is distinct from old.description or new.secretariat_id is distinct from old.secretariat_id or new.sub_office_id is distinct from old.sub_office_id or new.assignee_id is distinct from old.assignee_id or new.created_by is distinct from old.created_by or new.due_at is distinct from old.due_at or new.priority is distinct from old.priority or new.notes is distinct from old.notes then
     raise exception 'Members may only update task status';
   end if;
 end if;
 if new.status='completed' and (tg_op='INSERT' or old.status is distinct from 'completed') then new.completed_at=now(); end if;
 new.updated_at=now(); return new;
end $$;
drop trigger if exists task_assignment_guard on public.tasks;
create trigger task_assignment_guard before insert or update on public.tasks for each row execute function public.enforce_task_assignment();
alter table public.secretariats enable row level security;
alter table public.sub_offices enable row level security;
alter table public.profiles enable row level security;
alter table public.tasks enable row level security;
alter table public.notification_settings enable row level security;
alter table public.notification_log enable row level security;
create policy "signed in read secretariats" on public.secretariats for select to authenticated using(true);
create policy "signed in read suboffices" on public.sub_offices for select to authenticated using(true);
create policy "profiles read directory" on public.profiles for select to authenticated using(true);
create policy "profile update self or admin" on public.profiles for update to authenticated using(id=auth.uid() or public.is_admin()) with check(id=auth.uid() or public.is_admin());
create policy "tasks read own or managed" on public.tasks for select to authenticated using(assignee_id=auth.uid() or public.can_manage_secretariat(secretariat_id));
create policy "tasks insert managed" on public.tasks for insert to authenticated with check(public.can_manage_secretariat(secretariat_id) and created_by=auth.uid());
create policy "tasks update assignee or manager" on public.tasks for update to authenticated using(assignee_id=auth.uid() or public.can_manage_secretariat(secretariat_id)) with check(assignee_id=auth.uid() or public.can_manage_secretariat(secretariat_id));
create policy "notification settings self" on public.notification_settings for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy "notification log self read" on public.notification_log for select to authenticated using(user_id=auth.uid());
-- Provision profile rows through trusted admin tooling after creating Auth users.
-- Never expose the Supabase service-role key in the browser.
