begin;

-- Retain the original request separately so a lost creation response can be retried.
alter table civic_private.departments add column initial_payload jsonb;

create function public.civic_create_department(payload jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  me civic_private.profiles;
  target civic_private.departments;
  cleaned jsonb;
begin
  select * into me from civic_private.profiles where id = auth.uid() for update;
  if me.id is null or not me.active or me.authority_id is null
    or me.role not in ('localAuthorityAdmin','platformAdmin') then
    raise exception 'Authority administrator required' using errcode = '42501';
  end if;
  if jsonb_typeof(payload) is distinct from 'object'
    or jsonb_typeof(payload->'id') is distinct from 'string'
    or coalesce(payload->>'id','') !~ '^[A-Za-z0-9_-]{1,120}$'
    or jsonb_typeof(payload->'name') is distinct from 'string'
    or length(trim(coalesce(payload->>'name',''))) not between 1 and 120
    or jsonb_typeof(payload->'headName') is distinct from 'string'
    or length(trim(coalesce(payload->>'headName',''))) not between 1 and 120
    or jsonb_typeof(payload->'officerCount') is distinct from 'number'
    or coalesce(payload->>'officerCount','') !~ '^[0-9]{1,6}$'
    or jsonb_typeof(payload->'categories') is distinct from 'array' then
    raise exception 'Invalid department' using errcode = '22023';
  end if;
  if jsonb_array_length(payload->'categories') not between 1 and 100
    or exists(select 1 from jsonb_array_elements(payload->'categories') c
      where jsonb_typeof(c) <> 'string' or length(trim(c #>> '{}')) not between 1 and 120) then
    raise exception 'Invalid categories' using errcode = '22023';
  end if;
  cleaned := jsonb_build_object('name',trim(payload->>'name'),
    'headName',trim(payload->>'headName'),'officerCount',(payload->>'officerCount')::integer,
    'categories',payload->'categories');
  -- Serialize name checks and insertion, including administrators in different sessions.
  lock table civic_private.departments in share row exclusive mode;
  select * into target from civic_private.departments where id = payload->>'id';
  if target.id is not null then
    if target.authority_id is distinct from me.authority_id then
      raise exception 'Department not accessible' using errcode = '42501';
    end if;
    if target.initial_payload is distinct from cleaned then
      raise exception 'Creation request changed' using errcode = '40001';
    end if;
    return target.data || jsonb_build_object('id',target.id);
  end if;
  if exists(select 1 from civic_private.departments
    where authority_id = me.authority_id and lower(trim(data->>'name')) = lower(cleaned->>'name')) then
    raise exception 'Department name already exists' using errcode = '23505';
  end if;
  insert into civic_private.departments(id,authority_id,data,initial_payload)
    values(payload->>'id',me.authority_id,cleaned,cleaned) returning * into target;
  return target.data || jsonb_build_object('id',target.id);
end;
$$;

create function public.civic_remove_department(payload jsonb)
returns void language plpgsql security definer set search_path = '' as $$
declare
  me civic_private.profiles;
  target civic_private.departments;
begin
  select * into me from civic_private.profiles where id = auth.uid() for update;
  if me.id is null or not me.active or me.authority_id is null
    or me.role not in ('localAuthorityAdmin','platformAdmin') then
    raise exception 'Authority administrator required' using errcode = '42501';
  end if;
  -- Block concurrent reference writes until the check and removal commit together.
  lock table civic_private.reports, civic_private.projects, civic_private.announcements
    in share row exclusive mode;
  select * into target from civic_private.departments where id = payload->>'id' for update;
  if target.id is null then return; end if; -- retry after a lost success response
  if target.authority_id is distinct from me.authority_id then
    raise exception 'Department not accessible' using errcode = '42501';
  end if;
  if (target.data || jsonb_build_object('id',target.id)) is distinct from payload then
    raise exception 'Department changed' using errcode = '40001';
  end if;
  if exists(select 1 from civic_private.reports where authority_id = me.authority_id
      and data->>'department' = target.data->>'name')
    or exists(select 1 from civic_private.projects where authority_id = me.authority_id
      and data->>'department' = target.data->>'name')
    or exists(select 1 from civic_private.announcements where authority_id = me.authority_id
      and data->>'department' = target.data->>'name') then
    raise exception 'Department still owns civic records' using errcode = '23503';
  end if;
  delete from civic_private.departments where id = target.id;
end;
$$;

revoke all on function public.civic_create_department(jsonb) from public, anon;
revoke all on function public.civic_remove_department(jsonb) from public, anon;
grant execute on function public.civic_create_department(jsonb) to authenticated;
grant execute on function public.civic_remove_department(jsonb) to authenticated;

commit;
