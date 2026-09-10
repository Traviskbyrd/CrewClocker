begin; alter policy assignment_create on public.cc_assignments with check(cc_private.is_owner(company_id)); notify pgrst,'reload schema'; commit;
