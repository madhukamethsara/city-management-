begin;
create table civic_private.audit_events (
  id bigint generated always as identity primary key,
  authority_id text not null references civic_private.authorities,
  actor_id uuid,
  entity text not null,
  record_id text not null,
  action text not null,
  changes jsonb not null,
  created_at timestamptz not null default now()
);
alter table civic_private.audit_events enable row level security;
revoke all on civic_private.audit_events from public,anon,authenticated;
revoke all on sequence civic_private.audit_events_id_seq from public,anon,authenticated;
create index audit_events_authority on civic_private.audit_events(authority_id,id desc);
create function civic_private.audit_change() returns trigger
language plpgsql security definer set search_path='' as $$
declare before_row jsonb := '{}'; after_row jsonb := '{}'; authority text;
  details jsonb := '{}'; key text; before_value jsonb; after_value jsonb;
begin
  if TG_OP<>'INSERT' then before_row := to_jsonb(old); end if;
  if TG_OP<>'DELETE' then after_row := to_jsonb(new); end if;
  if before_row=after_row then return null; end if;
  authority := coalesce(after_row->>'authority_id',before_row->>'authority_id');
  if authority is null then return null; end if;
  -- Do not store contact data, answer text, internal notes, evidence, or budgets.
  foreach key in array array['role','active','status','progress','isPublished','department','headName'] loop
    before_value := coalesce(before_row->key,before_row->'data'->key);
    after_value := coalesce(after_row->key,after_row->'data'->key);
    if before_value is distinct from after_value then
      details := details || jsonb_build_object(key,jsonb_build_object('before',before_value,'after',after_value));
    end if;
  end loop;
  insert into civic_private.audit_events(authority_id,actor_id,entity,record_id,action,changes)
    values(authority,auth.uid(),TG_TABLE_NAME,coalesce(after_row->>'id',before_row->>'id'),lower(TG_OP),details);
  return null;
end; $$;
create trigger audit_profiles after insert or update or delete on civic_private.profiles
  for each row execute function civic_private.audit_change();
create trigger audit_departments after insert or update or delete on civic_private.departments
  for each row execute function civic_private.audit_change();
create trigger audit_reports after insert or update or delete on civic_private.reports
  for each row execute function civic_private.audit_change();
create trigger audit_projects after insert or update or delete on civic_private.projects
  for each row execute function civic_private.audit_change();
create trigger audit_announcements after insert or update or delete on civic_private.announcements
  for each row execute function civic_private.audit_change();
create trigger audit_proposals after insert or update or delete on civic_private.proposals
  for each row execute function civic_private.audit_change();
create trigger audit_consultations after insert or update or delete on civic_private.consultations
  for each row execute function civic_private.audit_change();

create function public.civic_audit_events(before_id bigint default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare me civic_private.profiles := civic_private.participant(); result jsonb;
begin
  if me.role not in ('localAuthorityAdmin','platformAdmin') then
    raise exception 'Administrator required' using errcode='42501'; end if;
  select coalesce(jsonb_agg(jsonb_build_object('id',e.id,'entity',e.entity,'recordId',e.record_id,
    'action',e.action,'actorId',e.actor_id,'changes',e.changes,'createdAt',e.created_at) order by e.id desc),'[]'::jsonb)
    into result from (select * from civic_private.audit_events
      where authority_id=me.authority_id and (before_id is null or id<before_id) order by id desc limit 50) e;
  return result;
end; $$;

create function public.civic_analytics() returns jsonb
language plpgsql security definer set search_path='' as $$
declare me civic_private.profiles := civic_private.participant(); result jsonb;
begin
  if not civic_private.is_officer(me) then raise exception 'Officer required' using errcode='42501'; end if;
  select jsonb_build_object('received',count(*),
    'resolved',count(*) filter(where data->>'status'='resolved'),
    'newComplaints',count(*) filter(where data->>'status'='submitted'),
    'assignedComplaints',count(*) filter(where data->>'status'='assigned'),
    'overdueComplaints',count(*) filter(where data->>'priority'='Urgent' and data->>'status'<>'resolved'),
    'averageResolutionDays',coalesce(round(avg(greatest(0,extract(epoch from (
      coalesce((select (u->>'date')::timestamptz from jsonb_array_elements(data->'updates') with ordinality as history(u,n)
        where u->>'status'='resolved' order by n desc limit 1),(data->>'lastUpdated')::timestamptz)
      -(data->>'submittedAt')::timestamptz))/86400)) filter(where data->>'status'='resolved'),1),0))
    into result from civic_private.reports where authority_id=me.authority_id;
  return result || jsonb_build_object(
    'byCategory',coalesce((select jsonb_object_agg(label,total) from (
      select coalesce(data->>'category','Other') label,count(*) total from civic_private.reports where authority_id=me.authority_id group by 1) g),'{}'::jsonb),
    'byWard',coalesce((select jsonb_object_agg(label,total) from (
      select coalesce(substring(data->>'locationLabel' from '(?i)Ward\s+[0-9]+'),'Other') label,count(*) total
      from civic_private.reports where authority_id=me.authority_id group by 1) g),'{}'::jsonb),
    'activeProjects',(select count(*) from civic_private.projects where authority_id=me.authority_id and data->>'status'='inProgress'),
    'delayedProjects',(select count(*) from civic_private.projects where authority_id=me.authority_id and data->>'status'='delayed'),
    'projectProgress',coalesce((select jsonb_agg(jsonb_build_object('id',id,'title',data->>'title','progress',(data->>'progress')::integer) order by id)
      from civic_private.projects where authority_id=me.authority_id),'[]'::jsonb),
    'citizenProposals',(select count(*) from civic_private.proposals where authority_id=me.authority_id),
    'openConsultations',(select count(*) from civic_private.consultations where authority_id=me.authority_id
      and now()>=(data->>'openingDate')::timestamptz and now()<(data->>'closingDate')::timestamptz));
end; $$;
revoke all on function civic_private.audit_change(),public.civic_audit_events(bigint),public.civic_analytics() from public,anon,authenticated;
grant execute on function public.civic_audit_events(bigint),public.civic_analytics() to authenticated;
commit;
