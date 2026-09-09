begin;
-- Synthetic users exist only within this rolled-back transaction; no emails sent.
do $$
declare u1 uuid:=gen_random_uuid(); u2 uuid:=gen_random_uuid(); crew uuid:=gen_random_uuid();
 c1 uuid; c2 uuid; s1 uuid; sc uuid; a1 uuid; ac uuid; event uuid:=gen_random_uuid();
 device uuid:=gen_random_uuid(); payload jsonb; accepted jsonb; checks integer:=0;
begin
 insert into auth.users(id,instance_id,aud,role,email,email_confirmed_at,created_at,updated_at)
 select x,'00000000-0000-0000-0000-000000000000'::uuid,'authenticated','authenticated',x::text||'@example.invalid',now(),now(),now()
 from unnest(array[u1,u2,crew]) x;
 insert into public.profiles(id,role) values(u1,'admin');
 perform set_config('request.jwt.claim.sub',u1::text,true);
 perform set_config('role','authenticated',true);
 if not cc_private.prototype_admin() then raise exception 'Prototype admin compatibility'; end if;
 checks:=checks+1;
 begin
  perform public.is_admin(u1);
  raise exception 'Expected public admin helper denial';
 exception when insufficient_privilege then checks:=checks+1; end;
 c1:=public.cc_create_company('Owner A','Owner A');
 if public.cc_create_company('Retry','Retry')<>c1 then raise exception 'Company retry failed'; end if;
 checks:=checks+1;
 insert into public.cc_memberships(company_id,user_id,display_name) values(c1,crew,'Crew');
 s1:=public.cc_create_site(c1,'{"name":"Site A","lat":30.5,"lng":-97.6,"radius_meters":175}'::jsonb,u1);
 sc:=public.cc_create_site(c1,'{"name":"Crew site","lat":30.6,"lng":-97.7,"radius_meters":175}'::jsonb,crew);
 select id into a1 from public.cc_assignments where site_id=s1;
 select id into ac from public.cc_assignments where site_id=sc;
 payload:=jsonb_build_array(jsonb_build_object('event_id',event,'assignment_id',a1,'employee_id',u1,
  'device_id',device,'assignment_version',1,'transition','enter','observed_at','2026-09-09T00:00:00Z'));
 accepted:=public.cc_ingest_observations(payload);
 if accepted<>jsonb_build_array(event) then raise exception 'No acknowledgement'; end if;
 if public.cc_ingest_observations(payload)<>accepted or (select count(*) from public.cc_observations where event_id=event)<>1 then raise exception 'Duplicate handling failed'; end if;
 checks:=checks+2;
 begin
  perform public.cc_ingest_observations(jsonb_set(payload,'{0,transition}','"exit"'));
  raise exception 'Expected payload conflict';
 exception when invalid_parameter_value then checks:=checks+1; end;
 begin
  perform public.cc_create_site(c1,'{"name":"Bad","lat":999,"lng":0,"radius_meters":175}'::jsonb,u1);
  raise exception 'Expected coordinate rejection';
 exception when check_violation then checks:=checks+1; end;
 perform set_config('request.jwt.claim.sub',u2::text,true);
 c2:=public.cc_create_company('Owner B','Owner B');
 if exists(select 1 from public.cc_companies where id=c1) or exists(select 1 from public.cc_sites where id=s1)
  or exists(select 1 from public.cc_observations where event_id=event) then raise exception 'Cross-company read'; end if;
 checks:=checks+1;
 begin
  perform public.cc_create_site(c1,'{"name":"Intruder","lat":30,"lng":-97,"radius_meters":175}'::jsonb,u2);
  raise exception 'Expected cross-company write rejection';
 exception when insufficient_privilege then checks:=checks+1; end;
 begin
  perform public.cc_ingest_observations(payload);
  raise exception 'Expected forged user rejection';
 exception when insufficient_privilege then checks:=checks+1; end;
 begin
  perform public.cc_ingest_observations(jsonb_set(payload,'{0,employee_id}',to_jsonb(u2)));
  raise exception 'Expected foreign assignment rejection';
 exception when insufficient_privilege then checks:=checks+1; end;
 perform set_config('request.jwt.claim.sub',crew::text,true);
 if not exists(select 1 from public.cc_companies where id=c1) or not exists(select 1 from public.cc_sites where id=sc)
  or exists(select 1 from public.cc_sites where id=s1) or exists(select 1 from public.cc_observations where event_id=event)
 then raise exception 'Crew assignment isolation failed'; end if;
 checks:=checks+1;
 begin
  insert into public.cc_memberships(company_id,user_id,display_name) values(c1,u2,'Escalation');
  raise exception 'Expected membership escalation denial';
 exception when insufficient_privilege then checks:=checks+1; end;
 begin
  update public.cc_companies set owner_id=crew where id=c1;
  raise exception 'Expected ownership update denial';
 exception when insufficient_privilege then checks:=checks+1; end;
 begin
  perform public.cc_ingest_observations(jsonb_set(jsonb_set(payload,'{0,employee_id}',to_jsonb(crew)),'{0,assignment_id}',to_jsonb(ac)));
  raise exception 'Expected event ID collision rejection';
 exception when invalid_parameter_value then checks:=checks+1; end;
 perform set_config('role','anon',true);
 begin
  perform public.cc_create_company('Anon','Anon');
  raise exception 'Expected anonymous RPC denial';
 exception when insufficient_privilege then checks:=checks+1; end;
 begin
  perform count(*) from public.cc_observations;
  raise exception 'Expected anonymous table denial';
 exception when insufficient_privilege then checks:=checks+1; end;
 perform set_config('role','postgres',true);
 if checks<>17 then raise exception 'Wrong check count: %',checks; end if;
end $$;
select 'PASS: 17 authorization, validation and idempotency checks; fixtures rolled back' as result;
rollback;
