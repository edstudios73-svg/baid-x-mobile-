-- jobs_read checked job_applications, and job_applications_read checked jobs.
-- Postgres raised 42P17 infinite recursion, so authenticated Worker reads failed.
-- These helpers keep the same ownership rules without re-entering those policies.

create or replace function private.worker_has_application(target_job uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.job_applications
    where job_id = target_job
      and worker_profile_id = (select auth.uid())
  );
$$;

create or replace function private.owns_job(target_job uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.jobs
    where id = target_job
      and owner_profile_id = (select auth.uid())
  );
$$;

revoke all on function private.worker_has_application(uuid) from public;
revoke all on function private.owns_job(uuid) from public;
grant execute on function private.worker_has_application(uuid) to anon, authenticated;
grant execute on function private.owns_job(uuid) to authenticated;

drop policy if exists jobs_read on public.jobs;
create policy jobs_read on public.jobs
for select
to anon, authenticated
using (
  (is_public and status = 'open'::public.job_status)
  or owner_profile_id = (select auth.uid())
  or private.worker_has_application(id)
);

drop policy if exists job_applications_read on public.job_applications;
create policy job_applications_read on public.job_applications
for select
to authenticated
using (
  worker_profile_id = (select auth.uid())
  or private.owns_job(job_id)
);
