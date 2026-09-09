begin;
create function cc_private.prototype_admin() returns boolean
language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from public.profiles where id=auth.uid() and role='admin')
$$;
revoke all on function cc_private.prototype_admin() from public,anon;
grant execute on function cc_private.prototype_admin() to authenticated;
alter policy "Admins see all" on public.profiles to authenticated using(cc_private.prototype_admin());
alter policy "Admins see all time" on public.time_entries to authenticated using(cc_private.prototype_admin()) with check(cc_private.prototype_admin());
alter policy "Everyone can view active jobs" on public.jobs to authenticated using(cc_private.prototype_admin());
alter function public.is_admin(uuid) set search_path='';
revoke all on function public.is_admin(uuid) from public,anon,authenticated;
notify pgrst,'reload schema';
commit;
