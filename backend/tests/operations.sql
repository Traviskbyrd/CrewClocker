begin;
do $$
declare own uuid:=gen_random_uuid(); emp uuid:=gen_random_uuid(); sup uuid:=gen_random_uuid(); sub uuid:=gen_random_uuid(); stranger uuid:=gen_random_uuid(); co uuid; job uuid; other_job uuid; crew uuid; subcrew uuid; schedule uuid; card uuid; invite jsonb; st jsonb; a uuid; other_a uuid; active_card uuid; dv uuid:=gen_random_uuid();
begin
 insert into auth.users(id,instance_id,aud,role,email,email_confirmed_at,phone,phone_confirmed_at,created_at,updated_at)
 select x,'00000000-0000-0000-0000-000000000000'::uuid,'authenticated','authenticated',x::text||'@example.invalid',now(),case when x=emp then '15550009991' else null end,case when x=emp then now() else null end,now(),now() from unnest(array[own,emp,sup,sub,stranger]) x;
 perform set_config('request.jwt.claim.sub',own::text,true); perform set_config('role','authenticated',true);
 co:=public.cc_create_company('Operations test','Owner');
 job:=public.cc_create_site(co,'{"name":"Job","lat":30.5,"lng":-97.5,"radius_meters":100}',own);
 other_job:=public.cc_create_site(co,'{"name":"Other","lat":31,"lng":-97.5,"radius_meters":100}',own);
 crew:=(public.cc_operations(co,'create_crew','{"name":"Employees","kind":"employee"}')->>'id')::uuid;
 subcrew:=(public.cc_operations(co,'create_crew','{"name":"Subs","kind":"sub"}')->>'id')::uuid;
 invite:=public.cc_operations(co,'invite',jsonb_build_object('contact','+15550009991','role','employee','crew_id',crew));
 perform set_config('request.jwt.claim.sub',stranger::text,true);
 begin perform public.cc_operations(null,'accept_invite',jsonb_build_object('token',invite->>'token','name','Wrong')); raise exception 'Wrong contact accepted'; exception when insufficient_privilege then null; end;
 perform set_config('request.jwt.claim.sub',emp::text,true);
 if jsonb_array_length(public.cc_operations(null,'pending_invites','{}'))<>1 then raise exception 'Phone invite not found'; end if;
 perform public.cc_operations(null,'accept_invite',jsonb_build_object('token',invite->>'token','name','Employee'));
 perform public.cc_operations(null,'accept_invite',jsonb_build_object('token',invite->>'token','name','Employee'));
 begin perform public.cc_operations(co,'create_crew','{"name":"Attack","kind":"sub"}'); raise exception 'Employee created crew'; exception when insufficient_privilege then null; end;
 begin execute 'select * from cc_private.cards'; raise exception 'Direct private access allowed'; exception when insufficient_privilege then null; end;
 perform set_config('request.jwt.claim.sub',own::text,true);
 invite:=public.cc_operations(co,'invite',jsonb_build_object('contact',sup::text||'@example.invalid','role','supervisor'));
 perform set_config('request.jwt.claim.sub',sup::text,true);
 perform public.cc_operations(null,'accept_invite',jsonb_build_object('token',invite->>'token','name','Supervisor'));
 perform set_config('request.jwt.claim.sub',own::text,true);
 invite:=public.cc_operations(co,'invite',jsonb_build_object('contact',sub::text||'@example.invalid','role','sub_lead','crew_id',subcrew));
 perform set_config('request.jwt.claim.sub',sub::text,true);
 perform public.cc_operations(null,'accept_invite',jsonb_build_object('token',invite->>'token','name','Sub lead'));
 begin perform public.cc_operations(co,'clock_in',jsonb_build_object('site_id',job)); raise exception 'Sub clocked in'; exception when insufficient_privilege then null; end;
 if public.cc_operations(co,'state','{}')->'cards'<>'[]'::jsonb then raise exception 'Sub sees payroll'; end if;
 perform set_config('request.jwt.claim.sub',own::text,true);
 perform public.cc_operations(co,'configure_crew',jsonb_build_object('id',crew,'supervisor_id',sup));
 perform public.cc_operations(co,'assign_crew',jsonb_build_object('crew_id',crew,'site_id',job));
 schedule:=(public.cc_operations(co,'schedule',jsonb_build_object('crew_id',subcrew,'site_id',job,'start',now(),'end',now()+interval '1 hour'))->>'id')::uuid;
 perform set_config('request.jwt.claim.sub',sup::text,true);
 begin perform public.cc_operations(co,'assign_crew',jsonb_build_object('crew_id',crew,'site_id',other_job)); raise exception 'Supervisor assigned unscoped job'; exception when insufficient_privilege then null; end;
 perform public.cc_operations(co,'schedule',jsonb_build_object('crew_id',crew,'site_id',job,'start',now(),'end',now()+interval '1 hour'));
 perform set_config('request.jwt.claim.sub',sub::text,true);
 perform public.cc_operations(co,'report',jsonb_build_object('schedule_id',schedule,'kind','crew_remaining','headcount',3,'note','Lead away; crew working'));
 perform set_config('request.jwt.claim.sub',emp::text,true);
 card:=(public.cc_operations(co,'save_card',jsonb_build_object('site_id',job,'start',now()-interval '3 hours','end',now()-interval '1 hour','break_minutes',30))->>'id')::uuid;
 begin perform public.cc_operations(co,'save_card',jsonb_build_object('site_id',job,'start',now()-interval '2 hours','end',now()-interval '1 hour')); raise exception 'Overlapping card accepted'; exception when invalid_parameter_value then null; end;
 begin perform public.cc_operations(co,'submit',jsonb_build_object('id',card,'revision',0)); raise exception 'Stale submit accepted'; exception when serialization_failure then null; end;
 perform public.cc_operations(co,'submit',jsonb_build_object('id',card,'revision',1));
 begin perform public.cc_operations(co,'approve',jsonb_build_object('id',card,'revision',2)); raise exception 'Self approved'; exception when insufficient_privilege then null; end;
 perform set_config('request.jwt.claim.sub',sup::text,true);
 perform public.cc_operations(co,'request_changes',jsonb_build_object('id',card,'revision',2,'note','Correct break'));
 perform set_config('request.jwt.claim.sub',emp::text,true);
 perform public.cc_operations(co,'save_card',jsonb_build_object('id',card,'revision',3,'site_id',job,'start',now()-interval '3 hours','end',now()-interval '1 hour','break_minutes',20,'note','Corrected break'));
 perform public.cc_operations(co,'submit',jsonb_build_object('id',card,'revision',4));
 perform set_config('request.jwt.claim.sub',sup::text,true);
 begin perform public.cc_operations(co,'approve',jsonb_build_object('id',card,'revision',2)); raise exception 'Stale approval accepted'; exception when serialization_failure then null; end;
 perform public.cc_operations(co,'approve',jsonb_build_object('id',card,'revision',5));
 perform set_config('request.jwt.claim.sub',stranger::text,true);
 begin perform public.cc_operations(co,'state','{}'); raise exception 'Outside company visible'; exception when insufficient_privilege then null; end;
 perform set_config('request.jwt.claim.sub',emp::text,true);
 select id into a from public.cc_assignments where site_id=job and user_id=emp;
 perform public.cc_ingest_observations(jsonb_build_array(jsonb_build_object('event_id',gen_random_uuid(),'assignment_id',a,'employee_id',emp,'device_id',dv,'assignment_version',1,'transition','enter','observed_at',now()-interval '2 days'),jsonb_build_object('event_id',gen_random_uuid(),'assignment_id',a,'employee_id',emp,'device_id',dv,'assignment_version',1,'transition','exit','observed_at',now()-interval '2 days'+interval '1 hour')));
 st:=public.cc_operations(co,'import_visits','{}');
 if (st->>'imported')::integer<>1 then raise exception 'Visit import failed: %',st; end if;
 if (public.cc_operations(co,'import_visits','{}')->>'imported')::integer<>0 then raise exception 'Duplicate import'; end if;
 -- Ambiguous simultaneous job visits must both remain unimported.
 perform set_config('request.jwt.claim.sub',own::text,true);
 perform public.cc_operations(co,'assign_crew',jsonb_build_object('crew_id',crew,'site_id',other_job));
 perform set_config('request.jwt.claim.sub',emp::text,true);
 select id into other_a from public.cc_assignments where site_id=other_job and user_id=emp;
 perform public.cc_ingest_observations(jsonb_build_array(
 jsonb_build_object('event_id',gen_random_uuid(),'assignment_id',a,'employee_id',emp,'device_id',dv,'assignment_version',1,'transition','enter','observed_at',now()-interval '4 days'),
 jsonb_build_object('event_id',gen_random_uuid(),'assignment_id',a,'employee_id',emp,'device_id',dv,'assignment_version',1,'transition','exit','observed_at',now()-interval '4 days'+interval '2 hours'),
 jsonb_build_object('event_id',gen_random_uuid(),'assignment_id',other_a,'employee_id',emp,'device_id',dv,'assignment_version',1,'transition','enter','observed_at',now()-interval '4 days'+interval '20 minutes'),
 jsonb_build_object('event_id',gen_random_uuid(),'assignment_id',other_a,'employee_id',emp,'device_id',dv,'assignment_version',1,'transition','exit','observed_at',now()-interval '4 days'+interval '3 hours')));
 st:=public.cc_operations(co,'import_visits','{}');
 if (st->>'imported')::integer<>0 or (st->>'overlaps')::integer<>2 then raise exception 'Ambiguous overlap imported: %',st; end if;
 active_card:=(public.cc_operations(co,'clock_in',jsonb_build_object('site_id',job))->>'id')::uuid;
 begin perform public.cc_operations(co,'clock_in',jsonb_build_object('site_id',job)); raise exception 'Second open clock allowed'; exception when invalid_parameter_value then null; end;
 perform public.cc_operations(co,'break',jsonb_build_object('id',active_card));
 perform set_config('role','postgres',true);
 -- Simulate elapsed time within this rollback transaction (now() is transaction-stable).
 update cc_private.cards set started_at=now()-interval '1 hour',break_started=now()-interval '10 minutes' where id=active_card;
 perform set_config('role','authenticated',true);
 st:=public.cc_operations(co,'clock_out',jsonb_build_object('id',active_card));
 if (st->>'break_seconds')::integer<>600 or st->>'break_started' is not null or st->>'ended_at' is null then raise exception 'Clock-out did not finish break'; end if;
 perform set_config('request.jwt.claim.sub',own::text,true);
 st:=public.cc_operations(co,'state','{}');
 if st->>'role'<>'owner' or jsonb_array_length(st->'cards')<>3 then raise exception 'Owner state failed: %',st->>'role'; end if;
 perform set_config('role','postgres',true);
 if (select count(*) from cc_private.card_audit where card_id=card)<>6 then raise exception 'Audit missing'; end if;
 if not exists(select 1 from cc_private.schedule_people where schedule_id=schedule and user_id=sub) then raise exception 'Schedule roster not snapshotted'; end if;
 perform set_config('role','anon',true);
 begin perform public.cc_operations(co,'state','{}'); raise exception 'Anonymous access'; exception when insufficient_privilege then null; end;
 perform set_config('role','postgres',true);
end $$;
select 'PASS: verified phone invitation, wrong-contact denial, idempotent join, role and tenant boundaries, private-table denial, supervisor job scope, sub attendance without payroll, timecard overlap, correction audit, stale review, visit import idempotency, ambiguous visit rejection, active breaks and double clocks, owner state, frozen schedule roster and anonymous denial; rolled back' as result;
rollback;
