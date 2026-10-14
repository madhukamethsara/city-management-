begin;

alter table civic_private.proposals
  add column project_id text unique references civic_private.projects(id),
  add column conversion_payload jsonb;

-- Keep the project link server-owned and available to resident detail views.
create or replace function civic_private.proposal_json(p civic_private.proposals, me civic_private.profiles)
returns jsonb language sql stable set search_path='' as $$
  select p.data || jsonb_build_object('id',p.id,'status',p.status,'revision',p.revision,
    'projectId',p.project_id,
    'createdAt',p.created_at,'author',coalesce((select data->>'fullName' from civic_private.profiles where id=p.owner_id),'Resident'),
    'supportCount',(select count(*) from civic_private.proposal_preferences where proposal_id=p.id and supported),
    'supporterIds',case when exists(select 1 from civic_private.proposal_preferences where proposal_id=p.id and user_id=me.id and supported)
      then jsonb_build_array(me.id) else '[]'::jsonb end,
    'followerIds',case when exists(select 1 from civic_private.proposal_preferences where proposal_id=p.id and user_id=me.id and following)
      then jsonb_build_array(me.id) else '[]'::jsonb end,
    'comments',coalesce((select jsonb_agg(jsonb_build_object('id',c.id,'author',coalesce(u.data->>'fullName','Resident'),
      'message',c.message,'createdAt',c.created_at,'isVerified',u.role<>'citizen') order by c.created_at,c.id)
      from civic_private.proposal_comments c join civic_private.profiles u on u.id=c.author_id
      where c.proposal_id=p.id),'[]'::jsonb));
$$;

create function public.civic_convert_proposal(proposal_id text, expected_revision integer, payload jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  me civic_private.profiles := civic_private.participant();
  p civic_private.proposals;
  project civic_private.projects;
  saved jsonb;
begin
  if not civic_private.is_officer(me) then
    raise exception 'Officer required' using errcode='42501';
  end if;
  select * into p from civic_private.proposals where id=proposal_id for update;
  if p.id is null or p.authority_id<>me.authority_id then
    raise exception 'Unavailable' using errcode='42501';
  end if;
  if p.project_id is not null then
    if payload is distinct from p.conversion_payload or
       expected_revision is distinct from p.revision-1 then
      raise exception 'Already converted' using errcode='40001';
    end if;
    select * into project from civic_private.projects where id=p.project_id;
    return jsonb_build_object('proposal',civic_private.proposal_json(p,me),
      'project',civic_private.project_json(project,me));
  end if;
  if expected_revision is distinct from p.revision then
    raise exception 'Changed' using errcode='40001';
  end if;
  if p.status<>'approved' or jsonb_typeof(payload) is distinct from 'object'
     or payload->>'revision' is distinct from '0'
     or coalesce(payload->>'id','') !~ '^p-[a-zA-Z0-9-]{1,100}$' then
    raise exception 'Approved proposal and new project required' using errcode='22023';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(payload->>'id',0));
  if exists(select 1 from civic_private.projects where id=payload->>'id') then
    raise exception 'Project already exists' using errcode='40001';
  end if;
  -- Reuse project validation, authority checks and audit triggers. Any error
  -- rolls back project creation, the proposal link and notifications together.
  saved := public.civic_save_project(payload);
  update civic_private.proposals set project_id=payload->>'id',
    conversion_payload=payload,status='convertedToProject',revision=revision+1
    where id=p.id returning * into p;
  insert into civic_private.notifications(id,recipient_id,data)
    select 'n-proposal-converted-'||p.id||'-'||u.id,u.id,
      jsonb_build_object('title','Proposal became a project','message',p.data->>'title',
        'category','Project','route','/projects/'||p.project_id)
    from civic_private.profiles u where u.active and u.authority_id=p.authority_id
      and (u.id=p.owner_id or exists(select 1 from civic_private.proposal_preferences pref
        where pref.proposal_id=p.id and pref.user_id=u.id and pref.following));
  return jsonb_build_object('proposal',civic_private.proposal_json(p,me),'project',saved);
end; $$;

create or replace function public.civic_review_proposal(proposal_id text, next_status text, expected_revision integer) returns jsonb
language plpgsql security definer set search_path='' as $$
declare me civic_private.profiles := civic_private.participant(); p civic_private.proposals;
begin
  if not civic_private.is_officer(me) then raise exception 'Officer required' using errcode='42501'; end if;
  select * into p from civic_private.proposals where id=proposal_id for update;
  if p.id is null or p.authority_id<>me.authority_id then raise exception 'Unavailable' using errcode='42501'; end if;
  if expected_revision is distinct from p.revision then raise exception 'Changed' using errcode='40001'; end if;
  if p.project_id is not null or next_status is null or next_status not in ('submitted','communityReview','technicalReview','approved','rejected') then
    raise exception 'Invalid status' using errcode='22023'; end if;
  update civic_private.proposals set status=next_status,revision=revision+1 where id=p.id returning * into p;
  insert into civic_private.notifications(id,recipient_id,data)
    select 'n-proposal-'||p.id||'-'||p.revision||'-'||pref.user_id,pref.user_id,
      jsonb_build_object('title','Proposal review updated','message',p.data->>'title','category','Proposal','route','/proposals/'||p.id)
    from civic_private.proposal_preferences pref join civic_private.profiles u on u.id=pref.user_id
    where pref.proposal_id=p.id and pref.following and u.active and u.authority_id=p.authority_id;
  return civic_private.proposal_json(p,me);
end; $$;

revoke all on function public.civic_convert_proposal(text,integer,jsonb) from public,anon,authenticated;
grant execute on function public.civic_convert_proposal(text,integer,jsonb) to authenticated;
commit;
