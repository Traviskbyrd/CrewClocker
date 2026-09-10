begin;
do $$
declare owner uuid:=gen_random_uuid(); outsider uuid:=gen_random_uuid(); crew uuid:=gen_random_uuid(); company uuid; site uuid; edited uuid; assignment uuid; eid uuid:=gen_random_uuid(); payload jsonb; n integer;
begin
 insert into auth.users(id,instance_id,aud,role,email,created_at,updated_at)
 select x,'00000000-0000-0000-0000-000000000000'::uuid,'authenticated','authenticated',x::text||'@example.invalid',now(),now() from unnest(array[owner,outsider,crew]) x;
 perform set_config('request.jwt.claim.sub',owner::text,true); perform set_config('role','authenticated',true);
 company:=public.cc_create_company('Edit test','Owner');
 insert into public.cc_memberships values(company,crew,'Crew');
 site:=public.cc_create_site(company,'{"name":"Original","lat":30.5,"lng":-97.5,"radius_meters":100}',owner);
 insert into public.cc_assignments(company_id,site_id,user_id) values(company,site,crew);
 select id into assignment from public.cc_assignments where site_id=site and user_id=owner;
 payload:=jsonb_build_array(jsonb_build_object('event_id',eid,'assignment_id',assignment,'employee_id',owner,'device_id',gen_random_uuid(),'assignment_version',1,'transition','enter','observed_at',now()));
 perform public.cc_ingest_observations(payload);
 perform set_config('request.jwt.claim.sub',outsider::text,true);
 begin perform public.cc_manage_site(site,'Attack',50,false); raise exception 'Cross company edit allowed'; exception when insufficient_privilege then null; end;
 begin perform public.cc_manage_site(site,null,null,true); raise exception 'Cross company delete allowed'; exception when insufficient_privilege then null; end;
 perform set_config('request.jwt.claim.sub',crew::text,true);
 begin perform public.cc_manage_site(site,'Attack',50,false); raise exception 'Crew edit allowed'; exception when insufficient_privilege then null; end;
 perform set_config('request.jwt.claim.sub',owner::text,true);
 select count(*) into n from public.cc_sites;
 begin perform public.cc_manage_site(site,'',50,false); raise exception 'Empty name allowed'; exception when invalid_parameter_value then null; end;
 begin perform public.cc_manage_site(site,'Invalid',24,false); raise exception 'Small radius allowed'; exception when invalid_parameter_value then null; end;
 begin perform public.cc_manage_site(site,'Invalid',1001,false); raise exception 'Large radius allowed'; exception when invalid_parameter_value then null; end;
 if (select count(*) from public.cc_sites)<>n or (select retired from public.cc_sites where id=site) then raise exception 'Failed edits changed rows'; end if;
 edited:=public.cc_manage_site(site,'Renamed',50,false);
 if not exists(select 1 from public.cc_sites where id=edited and name='Renamed' and radius_meters=50 and lat=30.5 and lng=-97.5 and not retired) then raise exception 'Edit not saved'; end if;
 if not exists(select 1 from public.cc_sites where id=site and name='Original' and radius_meters=100 and retired) then raise exception 'History overwritten'; end if;
 if exists(select 1 from public.cc_assignments where site_id=site and active) or (select count(*) from public.cc_assignments where site_id=edited and active and version=2)<>2 then raise exception 'Assignment transition failed'; end if;
 begin perform public.cc_manage_site(site,'Stale',75,false); raise exception 'Stale edit accepted'; exception when serialization_failure then null; end;
 if public.cc_ingest_observations(payload)<>jsonb_build_array(eid) then raise exception 'Old event retry failed'; end if;
 -- A delayed native event from the retired immutable assignment still uploads.
 perform public.cc_ingest_observations(jsonb_set(payload,'{0,event_id}',to_jsonb(gen_random_uuid())));
 perform set_config('request.jwt.claim.sub',crew::text,true);
 if not exists(select 1 from public.cc_sites where id=site and name='Original') then raise exception 'Historical site inaccessible'; end if;
 perform set_config('request.jwt.claim.sub',owner::text,true);
 perform public.cc_manage_site(edited,null,null,true);
 if exists(select 1 from public.cc_assignments where site_id=edited and active) or not (select retired from public.cc_sites where id=edited) then raise exception 'Delete did not retire site'; end if;
 if not exists(select 1 from public.cc_observations where event_id=eid) then raise exception 'Delete lost observation'; end if;
 begin delete from public.cc_sites where id=site; raise exception 'Hard delete allowed'; exception when insufficient_privilege then null; end;
 perform set_config('role','anon',true);
 begin perform public.cc_manage_site(edited,null,null,true); raise exception 'Anon RPC allowed'; exception when insufficient_privilege then null; end;
 perform set_config('role','postgres',true);
end $$;
select 'PASS: owner edit/delete, isolation, validation, stale edits, assignment replacement, historical reads, delayed upload and hard-delete denial; fixtures rolled back' as result;
rollback;
