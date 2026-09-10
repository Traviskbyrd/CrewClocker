begin;
-- Retain immutable site/assignment snapshots for historical and delayed events.
alter table public.cc_sites add column retired boolean not null default false;
alter table public.cc_sites drop constraint cc_sites_radius_meters_check;
alter table public.cc_sites add constraint cc_sites_radius_meters_check check(radius_meters between 25 and 1000);
grant update(retired) on public.cc_sites to authenticated;
grant update(active) on public.cc_assignments to authenticated;
create policy site_retire on public.cc_sites for update to authenticated
 using(cc_private.is_owner(company_id)) with check(cc_private.is_owner(company_id));
create policy assignment_retire on public.cc_assignments for update to authenticated
 using(cc_private.is_owner(company_id)) with check(cc_private.is_owner(company_id));
-- Historical names remain readable by the employee assigned at capture time.
alter policy site_read on public.cc_sites using(cc_private.is_owner(company_id) or id in (
 select site_id from public.cc_assignments where user_id=(select auth.uid())));
-- Assignment creation keeps the existing owner-only policy. A site-read lookup
-- here would recurse through site_read -> cc_assignments policies.
alter policy assignment_create on public.cc_assignments with check(cc_private.is_owner(company_id));

create function public.cc_manage_site(target uuid, new_name text default null, new_radius integer default null, remove_site boolean default false)
returns uuid language plpgsql security invoker set search_path='' as $$
declare old public.cc_sites%rowtype; saved uuid; a public.cc_assignments%rowtype;
begin
 select * into old from public.cc_sites where id=target for update;
 if old.id is null or not cc_private.is_owner(old.company_id) then
  raise exception 'Owner access required' using errcode='42501'; end if;
 if old.retired then raise exception 'Job already changed. Refresh Jobs before trying again.' using errcode='40001'; end if;
 if remove_site is null then raise exception 'Choose edit or delete' using errcode='22023'; end if;
 if not remove_site then
  if new_name is null or length(trim(new_name)) not between 1 and 160 or new_radius is null or new_radius not between 25 and 1000 then
   raise exception 'Enter a name and radius from 25 to 1000 meters' using errcode='22023'; end if;
  insert into public.cc_sites(company_id,name,address,lat,lng,radius_meters)
   values(old.company_id,trim(new_name),old.address,old.lat,old.lng,new_radius) returning id into saved;
 end if;
 for a in select * from public.cc_assignments where site_id=target and active for update loop
  update public.cc_assignments set active=false where id=a.id;
  if not remove_site then
   insert into public.cc_assignments(company_id,site_id,user_id,version)
    values(a.company_id,saved,a.user_id,a.version+1);
  end if;
 end loop;
 update public.cc_sites set retired=true where id=target;
 return saved;
end $$;
revoke all on function public.cc_manage_site(uuid,text,integer,boolean) from public,anon;
grant execute on function public.cc_manage_site(uuid,text,integer,boolean) to authenticated;
notify pgrst,'reload schema';
commit;
