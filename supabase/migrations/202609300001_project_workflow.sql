begin;

create table civic_private.projects (
  id text primary key,
  authority_id text not null references civic_private.authorities(id),
  created_by uuid not null references civic_private.profiles(id),
  revision integer not null default 1,
  data jsonb not null,
  initial_payload jsonb not null,
  created_at timestamptz not null default now()
);
create index projects_authority on civic_private.projects(authority_id, id);
create table civic_private.project_subscriptions (
  project_id text not null references civic_private.projects(id) on delete cascade,
  user_id uuid not null references civic_private.profiles(id) on delete cascade,
  primary key(project_id, user_id)
);
alter table civic_private.projects enable row level security;
alter table civic_private.project_subscriptions enable row level security;
revoke all on civic_private.projects, civic_private.project_subscriptions from public, anon, authenticated;

create function civic_private.project_json(p civic_private.projects, me civic_private.profiles)
returns jsonb language sql stable set search_path = '' as $$
  select p.data || jsonb_build_object(
    'id',p.id,'authorityId',p.authority_id,'revision',p.revision,
    'budget',case when civic_private.is_officer(me) or (p.data->>'isBudgetPublic')::boolean
      then p.data->'budget' else '0'::jsonb end,
    'spent',case when civic_private.is_officer(me) or (p.data->>'isBudgetPublic')::boolean
      then p.data->'spent' else '0'::jsonb end,
    'updates',coalesce((select jsonb_agg(u order by n) from jsonb_array_elements(p.data->'updates')
      with ordinality as entries(u,n) where civic_private.is_officer(me) or (u->>'isPublic')::boolean),'[]'::jsonb),
    'followerIds',case when exists(select 1 from civic_private.project_subscriptions
      where project_id=p.id and user_id=me.id) then jsonb_build_array(me.id) else '[]'::jsonb end
  );
$$;

create function public.civic_list_projects(
  search_text text default '', status_filter text default null,
  sort_order text default 'Latest', page_offset integer default 0, page_size integer default 25)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare me civic_private.profiles; result jsonb; total integer;
begin
  if auth.uid() is null then return jsonb_build_object('projects','[]'::jsonb,'total',0); end if;
  select * into me from civic_private.profiles where id=auth.uid();
  if me.id is null or not me.active then raise exception 'Not authorised' using errcode='42501'; end if;
  if page_offset is null or page_offset < 0 or page_size is null or page_size not between 1 and 100
    or search_text is null or length(search_text)>200
    or sort_order is null or sort_order not in ('Latest','A-Z','Most progress','Completion date')
    or (status_filter is not null and status_filter not in
      ('proposed','underReview','planned','funded','tendering','inProgress','paused','delayed','completed','cancelled')) then
    raise exception 'Invalid query' using errcode='22023';
  end if;
  select count(*) into total from civic_private.projects p where p.authority_id=me.authority_id
    and (status_filter is null or p.data->>'status'=status_filter)
    and (search_text='' or strpos(lower(concat_ws(' ',p.data->>'title',p.data->>'description',
      p.data->>'category',p.data->>'locationLabel')),lower(search_text))>0);
  select coalesce(jsonb_agg(civic_private.project_json(p,me) order by position),'[]'::jsonb) into result from (
    select p, row_number() over (order by
      case when sort_order='A-Z' then lower(p.data->>'title') end asc,
      case when sort_order='Most progress' then (p.data->>'progress')::integer end desc,
      case when sort_order='Completion date' then (p.data->>'expectedCompletion')::timestamptz end asc,
      case when sort_order='Latest' then (p.data->>'startDate')::timestamptz end desc, p.id) as position
    from civic_private.projects p where p.authority_id=me.authority_id
      and (status_filter is null or p.data->>'status'=status_filter)
      and (search_text='' or strpos(lower(concat_ws(' ',p.data->>'title',p.data->>'description',
        p.data->>'category',p.data->>'locationLabel')),lower(search_text))>0)
    order by position limit page_size offset page_offset
  ) page;
  return jsonb_build_object('projects',result,'total',total);
end;
$$;

create function public.civic_get_project(project_id text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare me civic_private.profiles; p civic_private.projects;
begin
  select * into me from civic_private.profiles where id=auth.uid();
  if me.id is null or not me.active then raise exception 'Not authorised' using errcode='42501'; end if;
  select * into p from civic_private.projects where id=project_id and authority_id=me.authority_id;
  if p.id is null then raise exception 'Project unavailable' using errcode='42501'; end if;
  return civic_private.project_json(p,me);
end;
$$;

create function public.civic_follow_project(project_id text, following boolean)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare me civic_private.profiles; p civic_private.projects;
begin
  select * into me from civic_private.profiles where id=auth.uid();
  if me.id is null or not me.active or coalesce(me.data->>'onboardingComplete','false')<>'true' then
    raise exception 'Not authorised' using errcode='42501'; end if;
  select * into p from civic_private.projects where id=project_id and authority_id=me.authority_id for share;
  if p.id is null then raise exception 'Project unavailable' using errcode='42501'; end if;
  if following is null then raise exception 'Invalid preference' using errcode='22023'; end if;
  if following then
    insert into civic_private.project_subscriptions values(p.id,me.id) on conflict do nothing;
  else
    delete from civic_private.project_subscriptions s where s.project_id=p.id and s.user_id=me.id;
  end if;
  return civic_private.project_json(p,me);
end;
$$;

create function public.civic_save_project(payload jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  me civic_private.profiles;
  p civic_private.projects;
  next_data jsonb;
  old_public jsonb;
  new_public jsonb;
  item jsonb;
  event_time text := to_char(clock_timestamp() at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"');
begin
  select * into me from civic_private.profiles where id=auth.uid();
  if me.id is null or not civic_private.is_officer(me) or me.authority_id is null
    or coalesce(me.data->>'onboardingComplete','false')<>'true' then
    raise exception 'Officer required' using errcode='42501'; end if;
  if jsonb_typeof(payload) is distinct from 'object'
    or coalesce(payload->>'id','') !~ '^p-[a-zA-Z0-9-]{1,100}$'
    or payload->>'authorityId' is distinct from me.authority_id then
    raise exception 'Invalid project authority' using errcode='42501'; end if;
  -- Serialize creation retries and edits of the same project, including absent rows.
  perform pg_advisory_xact_lock(hashtextextended(payload->>'id',0));
  select * into p from civic_private.projects where id=payload->>'id' for update;
  if p.id is not null and p.authority_id<>me.authority_id then
    raise exception 'Project unavailable' using errcode='42501'; end if;
  if p.id is not null and payload->>'revision'='0' and p.created_by=me.id and p.initial_payload=payload then
    return civic_private.project_json(p,me);
  end if;
  if coalesce(payload->>'revision','') !~ '^[0-9]{1,9}$' then
    raise exception 'Invalid revision' using errcode='22023'; end if;
  if (p.id is null and (payload->>'revision')::integer<>0)
    or (p.id is not null and (payload->>'revision')::integer<>p.revision) then
    raise exception 'Project changed' using errcode='40001'; end if;
  if exists(select 1 from unnest(array['title','description','category','locationLabel','status',
      'startDate','expectedCompletion','department']) key where jsonb_typeof(payload->key) is distinct from 'string')
    or exists(select 1 from unnest(array['progress','budget','spent']) key
      where jsonb_typeof(payload->key) is distinct from 'number')
    or exists(select 1 from unnest(array['contractor','projectManager']) key
      where payload ? key and jsonb_typeof(payload->key) not in ('string','null')) then
    raise exception 'Invalid project field types' using errcode='22023'; end if;
  if length(trim(coalesce(payload->>'title',''))) not between 8 and 100
    or length(trim(coalesce(payload->>'description',''))) not between 20 and 10000
    or length(trim(coalesce(payload->>'category',''))) not between 1 and 120
    or length(trim(coalesce(payload->>'locationLabel',''))) not between 1 and 200
    or coalesce(payload->>'status','') not in ('proposed','underReview','planned','funded','tendering',
      'inProgress','paused','delayed','completed','cancelled')
    or coalesce(payload->>'progress','') !~ '^[0-9]{1,3}$'
    or coalesce(payload->>'budget','') !~ '^[0-9]{1,15}$'
    or coalesce(payload->>'spent','') !~ '^[0-9]{1,15}$'
    or jsonb_typeof(payload->'isBudgetPublic') is distinct from 'boolean'
    or jsonb_typeof(payload->'location'->'latitude') is distinct from 'number'
    or jsonb_typeof(payload->'location'->'longitude') is distinct from 'number'
    or nullif(payload->>'startDate','') is null or nullif(payload->>'expectedCompletion','') is null
    or not exists(select 1 from civic_private.departments d where d.authority_id=me.authority_id
      and d.data->>'name'=payload->>'department')
    or length(coalesce(payload->>'contractor',''))>200
    or length(coalesce(payload->>'projectManager',''))>200 then
    raise exception 'Invalid project fields' using errcode='22023'; end if;
  if (payload->>'progress')::integer>100
    or (payload->'location'->>'latitude')::numeric not between -90 and 90
    or (payload->'location'->>'longitude')::numeric not between -180 and 180
    or not isfinite((payload->>'startDate')::timestamptz)
    or not isfinite((payload->>'expectedCompletion')::timestamptz)
    or (payload->>'expectedCompletion')::timestamptz<(payload->>'startDate')::timestamptz then
    raise exception 'Invalid project range' using errcode='22023'; end if;
  if jsonb_typeof(payload->'milestones') is distinct from 'array'
    or jsonb_typeof(payload->'updates') is distinct from 'array'
    or jsonb_typeof(payload->'documents') is distinct from 'array' then
    raise exception 'Invalid project collections' using errcode='22023'; end if;
  if jsonb_array_length(payload->'milestones')>100 or jsonb_array_length(payload->'updates')>200
    or jsonb_array_length(payload->'documents')>20 then
    raise exception 'Too many project entries' using errcode='22023'; end if;
  for item in select value from jsonb_array_elements(payload->'milestones') loop
    if jsonb_typeof(item) is distinct from 'object'
      or jsonb_typeof(item->'title') is distinct from 'string'
      or jsonb_typeof(item->'percentage') is distinct from 'number'
      or jsonb_typeof(item->'expectedDate') is distinct from 'string'
      or (item->>'completedDate' is not null and jsonb_typeof(item->'completedDate') is distinct from 'string')
      or length(trim(coalesce(item->>'title',''))) not between 1 and 200
      or length(coalesce(item->>'description',''))>2000
      or coalesce(item->>'percentage','') !~ '^[0-9]{1,3}$'
      or jsonb_typeof(item->'isComplete') is distinct from 'boolean'
      or nullif(item->>'expectedDate','') is null then
      raise exception 'Invalid milestone' using errcode='22023'; end if;
    if (item->>'percentage')::integer>100 or not isfinite((item->>'expectedDate')::timestamptz)
      or ((item->>'isComplete')::boolean and nullif(item->>'completedDate','') is null)
      or (item->>'completedDate' is not null and not isfinite((item->>'completedDate')::timestamptz)) then
      raise exception 'Invalid milestone range' using errcode='22023'; end if;
  end loop;
  for item in select value from jsonb_array_elements(payload->'updates') loop
    if jsonb_typeof(item) is distinct from 'object'
      or jsonb_typeof(item->'title') is distinct from 'string'
      or jsonb_typeof(item->'message') is distinct from 'string'
      or jsonb_typeof(item->'date') is distinct from 'string'
      or length(trim(coalesce(item->>'title',''))) not between 1 and 200
      or length(trim(coalesce(item->>'message',''))) not between 1 and 4000
      or jsonb_typeof(item->'isPublic') is distinct from 'boolean'
      or nullif(item->>'date','') is null then
      raise exception 'Invalid update' using errcode='22023'; end if;
    if not isfinite((item->>'date')::timestamptz) then raise exception 'Invalid date' using errcode='22023'; end if;
  end loop;
  for item in select value from jsonb_array_elements(payload->'documents') loop
    if jsonb_typeof(item) is distinct from 'object'
      or jsonb_typeof(item->'name') is distinct from 'string'
      or jsonb_typeof(item->'url') is distinct from 'string'
      or length(trim(coalesce(item->>'name',''))) not between 1 and 200
      or length(coalesce(item->>'url',''))>2048
      or coalesce(item->>'url','') !~ '^https://[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?(:[0-9]{1,5})?(/[^[:space:]]*)?$'
      or length(coalesce(item->>'kind',''))>40 or length(coalesce(item->>'sizeLabel',''))>80 then
      raise exception 'Use an HTTPS document link' using errcode='22023'; end if;
  end loop;
  -- Persist only known fields, so arbitrary client metadata cannot leak.
  select jsonb_object_agg(key,value) into next_data from jsonb_each(payload)
    where key=any(array['title','description','category','locationLabel','status','progress',
      'startDate','expectedCompletion','department','budget','spent','isBudgetPublic','contractor','projectManager']);
  next_data := next_data || jsonb_build_object(
    'location',jsonb_build_object('latitude',payload->'location'->'latitude','longitude',payload->'location'->'longitude'),
    'imageLabels','[]'::jsonb,
    'milestones',coalesce((select jsonb_agg(jsonb_build_object('title',v->'title','description',coalesce(v->>'description',''),
      'percentage',v->'percentage','expectedDate',v->'expectedDate','completedDate',v->'completedDate','isComplete',v->'isComplete'))
      from jsonb_array_elements(payload->'milestones') v),'[]'::jsonb),
    'updates',coalesce((select jsonb_agg(jsonb_build_object('title',v->'title','message',v->'message','date',v->'date','isPublic',v->'isPublic'))
      from jsonb_array_elements(payload->'updates') v),'[]'::jsonb),
    'documents',coalesce((select jsonb_agg(jsonb_build_object('name',v->'name','kind',coalesce(v->>'kind','Link'),
      'sizeLabel',coalesce(v->>'sizeLabel','Public document'),'url',v->'url')) from jsonb_array_elements(payload->'documents') v),'[]'::jsonb)
  );
  if p.id is null then
    insert into civic_private.projects(id,authority_id,created_by,data,initial_payload)
      values(payload->>'id',me.authority_id,me.id,next_data,payload) returning * into p;
  else
    select coalesce(jsonb_agg(v),'[]'::jsonb) into old_public from jsonb_array_elements(p.data->'updates') v where (v->>'isPublic')::boolean;
    select coalesce(jsonb_agg(v),'[]'::jsonb) into new_public from jsonb_array_elements(next_data->'updates') v where (v->>'isPublic')::boolean;
    if p.data=next_data then return civic_private.project_json(p,me); end if;
    if old_public is distinct from new_public or p.data->'status' is distinct from next_data->'status'
      or p.data->'progress' is distinct from next_data->'progress' then
      insert into civic_private.notifications(id,recipient_id,data)
        select 'project-'||p.id||'-'||(p.revision+1)||'-'||s.user_id,s.user_id,
          jsonb_build_object('title','Project updated','message',next_data->>'title',
            'category','project','createdAt',event_time,'route','/projects/'||p.id)
        from civic_private.project_subscriptions s join civic_private.profiles u on u.id=s.user_id
        where s.project_id=p.id and u.active and u.authority_id=p.authority_id;
    end if;
    update civic_private.projects set data=next_data,revision=revision+1 where id=p.id returning * into p;
  end if;
  return civic_private.project_json(p,me);
exception when invalid_text_representation or datetime_field_overflow or invalid_datetime_format then
  raise exception 'Invalid project value' using errcode='22023';
end;
$$;

revoke all on function civic_private.project_json(civic_private.projects,civic_private.profiles) from public, anon, authenticated;
revoke all on function public.civic_list_projects(text,text,text,integer,integer),
  public.civic_get_project(text), public.civic_follow_project(text,boolean), public.civic_save_project(jsonb) from public, anon, authenticated;
grant execute on function public.civic_list_projects(text,text,text,integer,integer) to anon, authenticated;
grant execute on function public.civic_get_project(text), public.civic_follow_project(text,boolean), public.civic_save_project(jsonb) to authenticated;
commit;
