-- Additive field-test schema. Existing prototype records are not migrated/deleted.
begin;
create schema if not exists cc_private;
revoke all on schema cc_private from public, anon;
grant usage on schema cc_private to authenticated;

create table public.cc_companies (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null unique references auth.users(id),
 name text not null check (length(trim(name)) between 1 and 160),
 created_at timestamptz not null default now()
);
create table public.cc_memberships (
 company_id uuid not null references public.cc_companies(id),
 user_id uuid not null references auth.users(id),
 display_name text not null check(length(trim(display_name)) between 1 and 120),
 primary key(company_id,user_id)
);
-- Narrow private policy helper: answers only whether the current caller owns a company.
-- Definer avoids policy recursion; no caller-supplied identity or public API exposure.
create function cc_private.is_owner(company uuid) returns boolean
language sql stable security definer set search_path = '' as $$
 select auth.uid() is not null and exists (
 select 1 from public.cc_companies c where c.id=company and c.owner_id=auth.uid())
$$;
revoke all on function cc_private.is_owner(uuid) from public,anon;
grant execute on function cc_private.is_owner(uuid) to authenticated;

create table public.cc_sites (
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null references public.cc_companies(id),
 name text not null check(length(trim(name)) between 1 and 160),
 address text not null default '' check(length(address)<=500),
 lat double precision not null check(lat between -90 and 90),
 lng double precision not null check(lng between -180 and 180),
 radius_meters integer not null check(radius_meters between 100 and 1000),
 created_at timestamptz not null default now(),
 unique(company_id,id)
);
create table public.cc_assignments (
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null,
 site_id uuid not null,
 user_id uuid not null,
 version integer not null default 1 check(version>0),
 active boolean not null default true,
 foreign key(company_id,site_id) references public.cc_sites(company_id,id),
 foreign key(company_id,user_id) references public.cc_memberships(company_id,user_id),
 unique(site_id,user_id), unique(id,user_id)
);
create index cc_memberships_user_idx on public.cc_memberships(user_id);
create index cc_sites_company_idx on public.cc_sites(company_id);
create index cc_assignments_company_user_idx on public.cc_assignments(company_id,user_id);
create index cc_assignments_user_idx on public.cc_assignments(user_id);

create table public.cc_observations (
 event_id uuid primary key,
 assignment_id uuid not null,
 employee_id uuid not null default auth.uid(),
 device_id uuid not null,
 assignment_version integer not null check(assignment_version>0),
 transition text not null check(transition in ('enter','dwell','exit')),
 observed_at timestamptz not null,
 received_at timestamptz not null default now(),
 foreign key(assignment_id,employee_id) references public.cc_assignments(id,user_id)
);
create index cc_observations_employee_time_idx on public.cc_observations(employee_id,observed_at desc);
create index cc_observations_assignment_idx on public.cc_observations(assignment_id);

alter table public.cc_companies enable row level security;
alter table public.cc_memberships enable row level security;
alter table public.cc_sites enable row level security;
alter table public.cc_assignments enable row level security;
alter table public.cc_observations enable row level security;
revoke all on public.cc_companies,public.cc_memberships,public.cc_sites,public.cc_assignments,public.cc_observations from public,anon,authenticated;
grant select,insert on public.cc_companies,public.cc_memberships,public.cc_sites,public.cc_assignments to authenticated;
grant select on public.cc_observations to authenticated;
-- No direct client updates, deletes or received_at spoofing.
grant insert(event_id,assignment_id,employee_id,device_id,assignment_version,transition,observed_at) on public.cc_observations to authenticated;

create policy company_read on public.cc_companies for select to authenticated using (
 owner_id=(select auth.uid()) or id in (select company_id from public.cc_memberships where user_id=(select auth.uid())));
create policy company_create on public.cc_companies for insert to authenticated with check(owner_id=(select auth.uid()));
create policy membership_read on public.cc_memberships for select to authenticated using(user_id=(select auth.uid()) or cc_private.is_owner(company_id));
create policy membership_create on public.cc_memberships for insert to authenticated with check(cc_private.is_owner(company_id));
create policy site_read on public.cc_sites for select to authenticated using(cc_private.is_owner(company_id) or id in (
 select site_id from public.cc_assignments where user_id=(select auth.uid()) and active));
create policy site_create on public.cc_sites for insert to authenticated with check(cc_private.is_owner(company_id));
create policy assignment_read on public.cc_assignments for select to authenticated using(user_id=(select auth.uid()) or cc_private.is_owner(company_id));
create policy assignment_create on public.cc_assignments for insert to authenticated with check(cc_private.is_owner(company_id));
create policy observation_read on public.cc_observations for select to authenticated using(employee_id=(select auth.uid()) or assignment_id in (
 select a.id from public.cc_assignments a where cc_private.is_owner(a.company_id)));
create policy observation_capture on public.cc_observations for insert to authenticated with check(employee_id=(select auth.uid()) and exists (
 select 1 from public.cc_assignments a where a.id=assignment_id and a.user_id=(select auth.uid()) and a.version=assignment_version));

create function public.cc_create_company(company_name text, person_name text) returns uuid
language plpgsql security invoker set search_path='' as $$
declare company uuid;
begin
 if auth.uid() is null then raise exception 'Sign in first' using errcode='42501'; end if;
 select id into company from public.cc_companies where owner_id=auth.uid();
 if company is not null then return company; end if;
 insert into public.cc_companies(owner_id,name) values(auth.uid(),trim(company_name)) returning id into company;
 insert into public.cc_memberships(company_id,user_id,display_name) values(company,auth.uid(),trim(person_name));
 return company;
end $$;

create function public.cc_create_site(company uuid, site jsonb, assigned_user uuid) returns uuid
language plpgsql security invoker set search_path='' as $$
declare saved uuid;
begin
 if not cc_private.is_owner(company) then raise exception 'Owner access required' using errcode='42501'; end if;
 insert into public.cc_sites(company_id,name,address,lat,lng,radius_meters)
 values(company,trim(site->>'name'),coalesce(site->>'address',''),(site->>'lat')::double precision,
 (site->>'lng')::double precision,(site->>'radius_meters')::integer) returning id into saved;
 insert into public.cc_assignments(company_id,site_id,user_id) values(company,saved,assigned_user);
 return saved;
end $$;

-- Atomic retry-safe ingestion. An ID is acknowledged only after its exact payload
-- is stored. Reused IDs with altered payloads or other users' IDs are rejected.
create function public.cc_ingest_observations(events jsonb) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare e jsonb; saved public.cc_observations%rowtype; ids jsonb:='[]'::jsonb;
begin
 if auth.uid() is null then raise exception 'Sign in first' using errcode='42501'; end if;
 if jsonb_typeof(events)<>'array' or jsonb_array_length(events)>500 then
 raise exception 'Expected at most 500 events' using errcode='22023'; end if;
 for e in select value from jsonb_array_elements(events) loop
  if (e->>'employee_id')::uuid is distinct from auth.uid() then raise exception 'Wrong event owner' using errcode='42501'; end if;
  insert into public.cc_observations(event_id,assignment_id,employee_id,device_id,assignment_version,transition,observed_at)
  values((e->>'event_id')::uuid,(e->>'assignment_id')::uuid,auth.uid(),(e->>'device_id')::uuid,
  (e->>'assignment_version')::integer,e->>'transition',(e->>'observed_at')::timestamptz)
  on conflict(event_id) do nothing;
  select * into saved from public.cc_observations where event_id=(e->>'event_id')::uuid;
  if saved.event_id is null or saved.employee_id is distinct from auth.uid()
   or saved.assignment_id is distinct from (e->>'assignment_id')::uuid
   or saved.device_id is distinct from (e->>'device_id')::uuid
   or saved.assignment_version is distinct from (e->>'assignment_version')::integer
   or saved.transition is distinct from e->>'transition'
   or saved.observed_at is distinct from (e->>'observed_at')::timestamptz then
   raise exception 'Event ID payload conflict' using errcode='22023';
  end if;
  ids:=ids||jsonb_build_array(saved.event_id);
 end loop;
 return ids;
end $$;
revoke all on function public.cc_create_company(text,text),public.cc_create_site(uuid,jsonb,uuid),public.cc_ingest_observations(jsonb) from public,anon;
grant execute on function public.cc_create_company(text,text),public.cc_create_site(uuid,jsonb,uuid),public.cc_ingest_observations(jsonb) to authenticated;

-- Close the prototype's unrestricted reads while preserving all records.
alter policy "Crew view own time" on public.time_entries to authenticated using(crew_id=(select auth.uid()));
alter policy "Everyone can view active jobs" on public.jobs to authenticated using(public.is_admin((select auth.uid())));
revoke all on public.profiles,public.jobs,public.time_entries from anon;
notify pgrst,'reload schema';
commit;
