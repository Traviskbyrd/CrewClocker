begin;
-- Operational records are private. The API exposes only scoped state-machine RPCs.
alter table public.cc_sites add column job_key uuid not null default gen_random_uuid();
create index cc_sites_job_key_idx on public.cc_sites(job_key);
create table cc_private.crews(id uuid primary key default gen_random_uuid(), company_id uuid not null references public.cc_companies(id), name text not null check(length(trim(name)) between 1 and 160), kind text not null check(kind in ('employee','sub')), lead_id uuid references auth.users(id), supervisor_id uuid references auth.users(id));
create table cc_private.people(company_id uuid not null references public.cc_companies(id), user_id uuid not null references auth.users(id), name text not null, role text not null check(role in ('employee','supervisor','sub_lead','sub_rep')), crew_id uuid references cc_private.crews(id), active boolean not null default true, primary key(company_id,user_id));
insert into cc_private.people(company_id,user_id,name,role) select m.company_id,m.user_id,m.display_name,'employee' from public.cc_memberships m join public.cc_companies c on c.id=m.company_id where m.user_id<>c.owner_id;
create table cc_private.invites(id uuid primary key default gen_random_uuid(), company_id uuid not null references public.cc_companies(id), contact text not null, role text not null check(role in ('employee','supervisor','sub_lead','sub_rep')), crew_id uuid references cc_private.crews(id), token_hash text not null unique, expires_at timestamptz not null default now()+interval '7 days', used_by uuid references auth.users(id), revoked boolean not null default false);
create table cc_private.crew_sites(crew_id uuid not null references cc_private.crews(id), job_key uuid not null, primary key(crew_id,job_key));
create table cc_private.schedules(id uuid primary key default gen_random_uuid(), company_id uuid not null references public.cc_companies(id), crew_id uuid not null references cc_private.crews(id), site_id uuid not null references public.cc_sites(id), window_start timestamptz not null, window_end timestamptz not null, notes text not null default '', cancelled boolean not null default false, check(window_end>=window_start and window_end<=window_start+interval '24 hours'));
create table cc_private.reports(id uuid primary key default gen_random_uuid(), schedule_id uuid not null references cc_private.schedules(id), reporter_id uuid not null references auth.users(id), reporter_name text not null, kind text not null check(kind in ('confirm','arrival','departure','delay','crew_remaining')), headcount integer check(headcount between 1 and 100), note text not null default '', reported_at timestamptz not null default now());
create table cc_private.cards(id uuid primary key default gen_random_uuid(), company_id uuid not null references public.cc_companies(id), user_id uuid not null references auth.users(id), site_id uuid not null references public.cc_sites(id), started_at timestamptz not null, ended_at timestamptz, break_seconds integer not null default 0 check(break_seconds>=0), break_started timestamptz, status text not null default 'draft' check(status in ('draft','submitted','approved','changes_requested','void')), note text not null default '', source_key text unique, revision integer not null default 1, check(ended_at is null or ended_at>started_at));
create unique index cards_one_open on cc_private.cards(user_id) where ended_at is null and status<>'void';
create index cards_user_time on cc_private.cards(user_id,started_at);
create table cc_private.card_audit(id bigint generated always as identity primary key, card_id uuid not null references cc_private.cards(id), actor_id uuid not null references auth.users(id), action text not null, reason text not null default '', recorded_at timestamptz not null default now(), before_data jsonb, after_data jsonb);
-- Defense in depth; clients have no table privileges in this schema.
alter table cc_private.crews enable row level security;
revoke all on cc_private.crews from public,anon,authenticated;
alter table cc_private.people enable row level security;
revoke all on cc_private.people from public,anon,authenticated;
alter table cc_private.invites enable row level security;
revoke all on cc_private.invites from public,anon,authenticated;
alter table cc_private.crew_sites enable row level security;
revoke all on cc_private.crew_sites from public,anon,authenticated;
alter table cc_private.schedules enable row level security;
revoke all on cc_private.schedules from public,anon,authenticated;
alter table cc_private.reports enable row level security;
revoke all on cc_private.reports from public,anon,authenticated;
alter table cc_private.cards enable row level security;
revoke all on cc_private.cards from public,anon,authenticated;
alter table cc_private.card_audit enable row level security;
revoke all on cc_private.card_audit from public,anon,authenticated;

create function cc_private.actor_role(c uuid) returns text language sql stable security definer set search_path='' as $$
 select case when exists(select 1 from public.cc_companies where id=c and owner_id=auth.uid()) then 'owner'
 else (select role from cc_private.people where company_id=c and user_id=auth.uid() and active) end where auth.uid() is not null
$$;
create function cc_private.crew_access(c uuid, cr uuid) returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from cc_private.crews g where g.company_id=c and g.id=cr and (
 cc_private.actor_role(c)='owner' or (cc_private.actor_role(c)='supervisor' and g.supervisor_id=auth.uid()) or (cc_private.actor_role(c)='sub_lead' and g.lead_id=auth.uid()) or exists(select 1 from cc_private.people p where p.company_id=c and p.user_id=auth.uid() and p.crew_id=g.id and p.active)))
$$;
create function cc_private.review_access(c uuid, worker uuid) returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and worker<>auth.uid() and (cc_private.actor_role(c)='owner' or (cc_private.actor_role(c)='supervisor' and exists(select 1 from cc_private.people p join cc_private.crews g on g.id=p.crew_id where p.company_id=c and p.user_id=worker and g.supervisor_id=auth.uid() and g.kind='employee')))
$$;
revoke all on function cc_private.actor_role(uuid),cc_private.crew_access(uuid,uuid),cc_private.review_access(uuid,uuid) from public,anon,authenticated;

-- All mutations authenticate the caller and check company, role, and row scope.
-- Private definer is intentional: clients cannot bypass invitation acceptance,
-- timecard transitions or audit insertion through direct table writes.
create function cc_private.operations(c uuid, op text, d jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); r text; cr cc_private.crews%rowtype; inv cc_private.invites%rowtype;
 p cc_private.people%rowtype; s public.cc_sites%rowtype; sched cc_private.schedules%rowtype;
 card cc_private.cards%rowtype; before_card jsonb; result jsonb; token text; role_value text;
 target uuid; crew uuid; worker uuid; v_start timestamptz; v_end timestamptz; breaks integer;
 event record; opening record; open_id uuid; open_time timestamptz; aid uuid; imported integer:=0; conflicts integer:=0;
 reason text:=coalesce(d->>'note','');
begin
 if uid is null then raise exception 'Sign in first' using errcode='42501'; end if;
 if length(reason)>2000 then raise exception 'Note is too long' using errcode='22023'; end if;
 if op='pending_invites' then
  return coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'company_name',co.name,'role',i.role)) from cc_private.invites i join public.cc_companies co on co.id=i.company_id join auth.users u on u.id=uid
   where not i.revoked and i.used_by is null and i.expires_at>now() and ((lower(u.email)=i.contact and u.email_confirmed_at is not null) or ('+'||ltrim(u.phone,'+')=i.contact and u.phone_confirmed_at is not null))),'[]'::jsonb);
 end if;
 if op='accept_invite' then
  select * into inv from cc_private.invites where (id=nullif(d->>'id','')::uuid or token_hash=encode(sha256(convert_to(trim(d->>'token'),'UTF8')),'hex')) for update;
  if inv.id is null or inv.revoked or inv.expires_at<now() then raise exception 'Invitation is invalid or expired' using errcode='22023'; end if;
  if not exists(select 1 from auth.users where id=uid and ((lower(email)=inv.contact and email_confirmed_at is not null) or ('+'||ltrim(phone,'+')=inv.contact and phone_confirmed_at is not null))) then raise exception 'Sign in with the verified phone number or email on this invitation' using errcode='42501'; end if;
  if inv.used_by=uid then return jsonb_build_object('company_id',inv.company_id); end if;
  if inv.used_by is not null then raise exception 'Invitation already used' using errcode='22023'; end if;
  if cc_private.actor_role(inv.company_id) is not null then raise exception 'Already a member. Ask the owner to change your access.' using errcode='22023'; end if;
  if length(trim(coalesce(d->>'name',''))) not between 1 and 120 then raise exception 'Enter your name' using errcode='22023'; end if;
  insert into public.cc_memberships(company_id,user_id,display_name) values(inv.company_id,uid,trim(d->>'name')) on conflict(company_id,user_id) do nothing;
  insert into cc_private.people(company_id,user_id,name,role,crew_id) values(inv.company_id,uid,trim(d->>'name'),inv.role,inv.crew_id)
   on conflict(company_id,user_id) do update set name=excluded.name,role=excluded.role,crew_id=excluded.crew_id,active=true;
  update cc_private.invites set used_by=uid where id=inv.id;
  if inv.crew_id is not null then
   insert into public.cc_assignments(company_id,site_id,user_id)
    select inv.company_id,st.id,uid from cc_private.crew_sites cs join public.cc_sites st on st.job_key=cs.job_key and not st.retired where cs.crew_id=inv.crew_id
    on conflict(site_id,user_id) do update set active=true;
  end if;
  return jsonb_build_object('company_id',inv.company_id);
 end if;
 r:=cc_private.actor_role(c);
 if r is null then raise exception 'Active company membership required' using errcode='42501'; end if;
 if op='state' then
  return jsonb_build_object('role',r,
   'people',coalesce((select jsonb_agg(to_jsonb(x)) from (
    select p.* from cc_private.people p where p.company_id=c and (r='owner' or p.user_id=uid or (p.crew_id is not null and cc_private.crew_access(c,p.crew_id) and r in ('supervisor','sub_lead')))
    union all select c,co.owner_id,co.name||' (owner)','owner',null,true from public.cc_companies co where co.id=c and r='owner'
   ) x),'[]'::jsonb),
   'crews',coalesce((select jsonb_agg(to_jsonb(g) order by g.name) from cc_private.crews g where g.company_id=c and cc_private.crew_access(c,g.id)),'[]'::jsonb),
   'jobs',coalesce((select jsonb_agg(to_jsonb(st) order by st.name) from public.cc_sites st where st.company_id=c and not st.retired and (r='owner' or exists(select 1 from public.cc_assignments a where a.site_id=st.id and a.user_id=uid and a.active) or exists(select 1 from cc_private.crew_sites cs where cs.job_key=st.job_key and cc_private.crew_access(c,cs.crew_id)))),'[]'::jsonb),
   'invites',case when r='owner' then coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'contact',i.contact,'role',i.role,'expires_at',i.expires_at,'used',i.used_by is not null,'revoked',i.revoked)) from cc_private.invites i where i.company_id=c),'[]'::jsonb) else '[]'::jsonb end,
   'schedules',coalesce((select jsonb_agg(to_jsonb(x) order by x.window_start) from (
     select sc.*,st.name as site_name,g.name as crew_name,g.kind as crew_kind,
       coalesce((select jsonb_agg(to_jsonb(rr) order by rr.reported_at) from cc_private.reports rr where rr.schedule_id=sc.id),'[]'::jsonb) as reports,
       coalesce((select jsonb_agg(jsonb_build_object('person',pe.name,'transition',o.transition,'observed_at',o.observed_at,'received_at',o.received_at) order by o.observed_at)
         from public.cc_observations o join public.cc_assignments a on a.id=o.assignment_id join public.cc_sites os on os.id=a.site_id join cc_private.people pe on pe.company_id=c and pe.user_id=o.employee_id
         where os.job_key=st.job_key and pe.crew_id=sc.crew_id and o.observed_at between sc.window_start-interval '2 hours' and sc.window_start+interval '24 hours'),'[]'::jsonb) as detected
     from cc_private.schedules sc join public.cc_sites st on st.id=sc.site_id join cc_private.crews g on g.id=sc.crew_id
     where sc.company_id=c and cc_private.crew_access(c,sc.crew_id) and sc.window_start between now()-interval '30 days' and now()+interval '90 days'
   ) x),'[]'::jsonb),
   'cards',case when r in ('sub_lead','sub_rep') then '[]'::jsonb else coalesce((select jsonb_agg(to_jsonb(x) order by x.started_at desc) from (
      select tc.*,st.name as site_name,coalesce(pe.name,'Owner') as person_name,
       coalesce((select jsonb_agg(jsonb_build_object('action',au.action,'reason',au.reason,'recorded_at',au.recorded_at,'actor_id',au.actor_id) order by au.id) from cc_private.card_audit au where au.card_id=tc.id),'[]'::jsonb) as history
      from cc_private.cards tc join public.cc_sites st on st.id=tc.site_id left join cc_private.people pe on pe.company_id=c and pe.user_id=tc.user_id
      where tc.company_id=c and (tc.user_id=uid or cc_private.review_access(c,tc.user_id)) order by tc.started_at desc limit 300
   ) x),'[]'::jsonb) end,'server_time',now());
 end if;
 if op in ('invite','revoke_invite','create_crew','configure_crew','set_person') then
  if r<>'owner' then raise exception 'Owner access required' using errcode='42501'; end if;
  if op='create_crew' then
   insert into cc_private.crews(company_id,name,kind) values(c,trim(d->>'name'),d->>'kind') returning id into target;
   return jsonb_build_object('id',target);
  elsif op='invite' then
   role_value:=d->>'role'; crew:=nullif(d->>'crew_id','')::uuid;
   if role_value not in ('employee','supervisor','sub_lead','sub_rep') or role_value is null then raise exception 'Invalid role' using errcode='22023'; end if;
   if coalesce(d->>'contact','') !~ '^[^ @]+@[^ @]+\.[^ @]+$' and coalesce(d->>'contact','') !~ '^\+[1-9][0-9]{7,14}$' then raise exception 'Enter a phone number with country code or an email address' using errcode='22023'; end if;
   if crew is not null then
    select * into cr from cc_private.crews where id=crew and company_id=c;
    if cr.id is null or (role_value in ('employee','supervisor') and cr.kind<>'employee') or (role_value in ('sub_lead','sub_rep') and cr.kind<>'sub') then raise exception 'Choose a matching crew' using errcode='22023'; end if;
   end if;
   if role_value='sub_rep' and crew is null then raise exception 'Choose a subcontractor crew' using errcode='22023'; end if;
   token:=replace(gen_random_uuid()::text||gen_random_uuid()::text,'-','');
   insert into cc_private.invites(company_id,contact,role,crew_id,token_hash) values(c,lower(trim(d->>'contact')),role_value,crew,encode(sha256(convert_to(token,'UTF8')),'hex'));
   return jsonb_build_object('token',token,'contact',lower(trim(d->>'contact')));
  elsif op='revoke_invite' then
   update cc_private.invites set revoked=true where id=(d->>'id')::uuid and company_id=c;
  elsif op='configure_crew' then
   select * into cr from cc_private.crews where id=(d->>'id')::uuid and company_id=c for update;
   if cr.id is null then raise exception 'Crew unavailable' using errcode='42501'; end if;
   target:=nullif(d->>'lead_id','')::uuid; worker:=nullif(d->>'supervisor_id','')::uuid;
   if target is not null and not exists(select 1 from cc_private.people where company_id=c and user_id=target and active and role=case when cr.kind='sub' then 'sub_lead' else 'supervisor' end) then raise exception 'Invalid lead' using errcode='22023'; end if;
   if worker is not null and not exists(select 1 from cc_private.people where company_id=c and user_id=worker and role='supervisor' and active) then raise exception 'Invalid supervisor' using errcode='22023'; end if;
   update cc_private.crews set lead_id=target,supervisor_id=worker where id=cr.id;
  elsif op='set_person' then
   worker:=(d->>'user_id')::uuid; crew:=nullif(d->>'crew_id','')::uuid; role_value:=d->>'role';
   if role_value not in ('employee','supervisor','sub_lead','sub_rep') or role_value is null then raise exception 'Invalid role' using errcode='22023'; end if;
   select * into p from cc_private.people where company_id=c and user_id=worker for update;
   if p.user_id is null then raise exception 'Person unavailable' using errcode='42501'; end if;
   if exists(select 1 from cc_private.cards where company_id=c and user_id=worker and ended_at is null and status<>'void') then raise exception 'Close the active timecard before changing access' using errcode='22023'; end if;
   if crew is not null then
    select * into cr from cc_private.crews where id=crew and company_id=c;
    if cr.id is null or (role_value in ('employee','supervisor') and cr.kind<>'employee') or (role_value in ('sub_lead','sub_rep') and cr.kind<>'sub') then raise exception 'Choose a matching crew' using errcode='22023'; end if;
   end if;
   update cc_private.people set role=role_value,crew_id=crew,active=coalesce((d->>'active')::boolean,true) where company_id=c and user_id=worker;
   update public.cc_assignments set active=false where company_id=c and user_id=worker;
   update cc_private.crews set lead_id=null where company_id=c and lead_id=worker;
   update cc_private.crews set supervisor_id=null where company_id=c and supervisor_id=worker;
   if crew is not null and coalesce((d->>'active')::boolean,true) then
    insert into public.cc_assignments(company_id,site_id,user_id) select c,st.id,worker from cc_private.crew_sites cs join public.cc_sites st on st.job_key=cs.job_key and not st.retired where cs.crew_id=crew
     on conflict(site_id,user_id) do update set active=true;
   end if;
  end if;
  return '{}'::jsonb;
 end if;
 if op in ('schedule','cancel_schedule','report','assign_crew') then
  if op in ('schedule','assign_crew') then
   select * into cr from cc_private.crews where id=(d->>'crew_id')::uuid and company_id=c;
   select * into s from public.cc_sites where id=(d->>'site_id')::uuid and company_id=c and not retired;
   if cr.id is null or s.id is null or r not in ('owner','supervisor') or not cc_private.crew_access(c,cr.id) then raise exception 'Assigned supervisor or owner required' using errcode='42501'; end if;
   insert into cc_private.crew_sites(crew_id,job_key) values(cr.id,s.job_key) on conflict do nothing;
   insert into public.cc_assignments(company_id,site_id,user_id) select c,s.id,pe.user_id from cc_private.people pe where pe.company_id=c and pe.crew_id=cr.id and pe.active
    on conflict(site_id,user_id) do update set active=true;
   if op='schedule' then
    insert into cc_private.schedules(company_id,crew_id,site_id,window_start,window_end,notes)
    values(c,cr.id,s.id,(d->>'start')::timestamptz,(d->>'end')::timestamptz,reason) returning id into target;
    return jsonb_build_object('id',target);
   end if;
  else
   select * into sched from cc_private.schedules where id=(d->>'schedule_id')::uuid and company_id=c for update;
   if sched.id is null or not cc_private.crew_access(c,sched.crew_id) then raise exception 'Schedule unavailable' using errcode='42501'; end if;
   if op='cancel_schedule' then
    if r not in ('owner','supervisor') then raise exception 'Supervisor or owner required' using errcode='42501'; end if;
    update cc_private.schedules set cancelled=true where id=sched.id;
   else
    if sched.cancelled then raise exception 'Schedule cancelled' using errcode='22023'; end if;
    if d->>'kind' in ('arrival','crew_remaining') and nullif(d->>'headcount','') is null then raise exception 'Enter the reported crew count' using errcode='22023'; end if;
    insert into cc_private.reports(schedule_id,reporter_id,reporter_name,kind,headcount,note)
    values(sched.id,uid,coalesce((select name from cc_private.people where company_id=c and user_id=uid),'Owner'),d->>'kind',nullif(d->>'headcount','')::integer,reason);
   end if;
  end if;
  return '{}'::jsonb;
 end if;
 -- Employee timecards are unavailable to subcontractor roles.
 if r not in ('owner','employee','supervisor') then raise exception 'Employee timecards only' using errcode='42501'; end if;
 perform pg_advisory_xact_lock(hashtextextended(uid::text,0));
 if op='import_visits' then
  for aid in select a.id from public.cc_assignments a where a.company_id=c and a.user_id=uid loop
   open_id:=null; open_time:=null;
   for event in select o.*,a.site_id from public.cc_observations o join public.cc_assignments a on a.id=o.assignment_id where o.assignment_id=aid and o.observed_at>=now()-interval '30 days' order by o.observed_at,o.event_id loop
    if event.transition='enter' and open_id is null then open_id:=event.event_id; open_time:=event.observed_at;
    elsif event.transition='exit' and open_id is not null then
     if event.observed_at>open_time and event.observed_at<=open_time+interval '24 hours' and not exists(select 1 from cc_private.cards where source_key=open_id::text||':'||event.event_id::text) then
      if exists(select 1 from cc_private.cards where user_id=uid and status<>'void' and started_at<event.observed_at and coalesce(ended_at,'infinity'::timestamptz)>open_time) then conflicts:=conflicts+1;
      else
       insert into cc_private.cards(company_id,user_id,site_id,started_at,ended_at,note,source_key) values(c,uid,event.site_id,open_time,event.observed_at,'Detected visit: review job, times and breaks before submitting.',open_id::text||':'||event.event_id::text) returning id into target;
       insert into cc_private.card_audit(card_id,actor_id,action) values(target,uid,'import_detected_visit'); imported:=imported+1;
      end if;
     end if;
     open_id:=null; open_time:=null;
    end if;
   end loop;
  end loop;
  return jsonb_build_object('imported',imported,'overlaps',conflicts);
 end if;
 if op in ('clock_in','save_card') then
  target:=nullif(d->>'id','')::uuid;
  if target is not null then
   select * into card from cc_private.cards where id=target and company_id=c and user_id=uid for update;
   if card.id is null or card.status not in ('draft','changes_requested') or card.ended_at is null then raise exception 'This timecard cannot be edited' using errcode='42501'; end if;
   if card.revision is distinct from (d->>'revision')::integer then raise exception 'Timecard changed. Refresh first.' using errcode='40001'; end if;
   if length(trim(reason))=0 then raise exception 'Explain the correction' using errcode='22023'; end if;
   before_card:=to_jsonb(card);
  end if;
  select * into s from public.cc_sites where id=(d->>'site_id')::uuid and company_id=c;
  if s.id is null or (r<>'owner' and not exists(select 1 from public.cc_assignments where site_id=s.id and user_id=uid and (active or target is not null))) then raise exception 'Assigned job required' using errcode='42501'; end if;
  if s.retired and target is null then raise exception 'Choose an active job' using errcode='22023'; end if;
  v_start:=case when op='clock_in' then now() else (d->>'start')::timestamptz end;
  v_end:=case when op='clock_in' then null else (d->>'end')::timestamptz end;
  breaks:=case when op='clock_in' then 0 else coalesce((d->>'break_minutes')::integer,0)*60 end;
  if v_start is null or v_start>now()+interval '1 minute' or (op='save_card' and (v_end is null or v_end<=v_start or v_end>now()+interval '1 minute' or v_end>v_start+interval '24 hours' or breaks<0 or breaks>=extract(epoch from(v_end-v_start)))) then raise exception 'Check start, end and break duration (maximum 24 hours)' using errcode='22023'; end if;
  if exists(select 1 from cc_private.cards where user_id=uid and status<>'void' and id is distinct from target and started_at<coalesce(v_end,'infinity'::timestamptz) and coalesce(ended_at,'infinity'::timestamptz)>v_start) then raise exception 'This time overlaps another timecard' using errcode='22023'; end if;
  if target is null then
   insert into cc_private.cards(company_id,user_id,site_id,started_at,ended_at,break_seconds,note) values(c,uid,s.id,v_start,v_end,breaks,reason) returning * into card;
  else
   update cc_private.cards set site_id=s.id,started_at=v_start,ended_at=v_end,break_seconds=breaks,note=reason,status='draft',revision=revision+1 where id=target returning * into card;
  end if;
  insert into cc_private.card_audit(card_id,actor_id,action,reason,before_data,after_data) values(card.id,uid,op,reason,before_card,to_jsonb(card));
  return to_jsonb(card);
 end if;
 select * into card from cc_private.cards where id=(d->>'id')::uuid and company_id=c for update;
 if card.id is null then raise exception 'Timecard unavailable' using errcode='42501'; end if;
 before_card:=to_jsonb(card);
 if op in ('approve','request_changes') then
  if not cc_private.review_access(c,card.user_id) or card.status<>'submitted' then raise exception 'Assigned reviewer required; self-approval is not allowed' using errcode='42501'; end if;
  if op='request_changes' and length(trim(reason))=0 then raise exception 'Explain the requested change' using errcode='22023'; end if;
  update cc_private.cards set status=case when op='approve' then 'approved' else 'changes_requested' end,revision=revision+1 where id=card.id returning * into card;
 else
  if card.user_id<>uid then raise exception 'Own timecard required' using errcode='42501'; end if;
  if op in ('break','resume','clock_out') then
   if card.status<>'draft' or card.ended_at is not null then raise exception 'No active timecard' using errcode='22023'; end if;
   if op='break' then
    if card.break_started is not null then return to_jsonb(card); end if;
    update cc_private.cards set break_started=now(),revision=revision+1 where id=card.id returning * into card;
   else
    update cc_private.cards set break_seconds=break_seconds+case when break_started is null then 0 else greatest(0,extract(epoch from(now()-break_started))::integer) end,break_started=null,ended_at=case when op='clock_out' then now() else null end,revision=revision+1 where id=card.id returning * into card;
   end if;
  elsif op='submit' then
   if card.status not in ('draft','changes_requested') or card.ended_at is null or card.ended_at>card.started_at+interval '24 hours' then raise exception 'Review a closed timecard of at most 24 hours first' using errcode='22023'; end if;
   update cc_private.cards set status='submitted',revision=revision+1 where id=card.id returning * into card;
  elsif op='void' then
   if card.status not in ('draft','changes_requested') or length(trim(reason))=0 then raise exception 'Only drafts can be removed; give a reason' using errcode='22023'; end if;
   update cc_private.cards set status='void',revision=revision+1 where id=card.id returning * into card;
  else raise exception 'Unknown operation' using errcode='22023'; end if;
 end if;
 insert into cc_private.card_audit(card_id,actor_id,action,reason,before_data,after_data) values(card.id,uid,op,reason,before_card,to_jsonb(card));
 return to_jsonb(card);
end $$;
revoke all on function cc_private.operations(uuid,text,jsonb) from public,anon;
grant execute on function cc_private.operations(uuid,text,jsonb) to authenticated;
create function public.cc_operations(company uuid, action text, data jsonb default '{}'::jsonb) returns jsonb
language sql security invoker set search_path='' as $$ select cc_private.operations(company,action,data) $$;
revoke all on function public.cc_operations(uuid,text,jsonb) from public,anon;
grant execute on function public.cc_operations(uuid,text,jsonb) to authenticated;
create or replace function public.cc_manage_site(target uuid, new_name text default null, new_radius integer default null, remove_site boolean default false)
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
  insert into public.cc_sites(company_id,name,address,lat,lng,radius_meters,job_key)
   values(old.company_id,trim(new_name),old.address,old.lat,old.lng,new_radius,old.job_key) returning id into saved;
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

notify pgrst,'reload schema';
commit;
