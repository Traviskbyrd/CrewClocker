-- Proposed migration for the existing prototype schema. NOT APPLIED.
-- This narrowly enables admin job creation. Full company isolation and
-- assignment-aware read policies remain a separate release gate.
begin;
create or replace function public.crewclocker_save_job_v1(site jsonb)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  job_id uuid;
  site_name text := trim(site->>'name');
  latitude numeric := (site->>'lat')::numeric;
  longitude numeric := (site->>'lng')::numeric;
  radius numeric := (site->>'radius_meters')::numeric;
begin
  if auth.uid() is null or not exists (
    select 1 from public.profiles where id = auth.uid() and role = 'admin'
  ) then raise exception 'Administrator access required' using errcode = '42501'; end if;
  if site_name is null or site_name = '' or length(site_name) > 200
    or latitude is null or not (latitude between -90 and 90)
    or longitude is null or not (longitude between -180 and 180)
    or radius is null or not (radius between 100 and 1000)
    then raise exception 'Invalid job site' using errcode = '22023'; end if;
  insert into public.jobs(name,address,lat,lng,radius_meters,status)
    values(site_name,nullif(trim(site->>'address'),''),latitude,longitude,round(radius)::integer,'active')
    returning id into job_id;
  return job_id;
end;
$$;
revoke all on function public.crewclocker_save_job_v1(jsonb) from public, anon;
grant execute on function public.crewclocker_save_job_v1(jsonb) to authenticated;
-- Invoker RPC intentionally still obeys the underlying INSERT policy.
create policy "crewclocker_admin_create_job" on public.jobs
for insert to authenticated with check (
  exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
);
grant insert on public.jobs to authenticated;
commit;
