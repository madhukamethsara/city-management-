begin;

-- Preserve existing bootstrap behavior; expose resident profiles only to admins.
alter function public.civic_bootstrap() set schema civic_private;
revoke all on function civic_private.civic_bootstrap() from public, anon, authenticated;

create function public.civic_bootstrap()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  result jsonb;
  me civic_private.profiles;
begin
  result := civic_private.civic_bootstrap();
  select * into me from civic_private.profiles where id = auth.uid();
  if me.active and me.role in ('localAuthorityAdmin','platformAdmin') then
    result := result || jsonb_build_object('users', coalesce((
      select jsonb_agg(civic_private.profile_json(p) order by p.id)
      from civic_private.profiles p where p.authority_id = me.authority_id
    ), '[]'::jsonb));
  end if;
  return result;
end;
$$;

create function public.civic_manage_user(payload jsonb, expected_role text, expected_active boolean)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  me civic_private.profiles;
  target civic_private.profiles;
  next_role text := payload->>'role';
  next_active boolean;
begin
  select * into me from civic_private.profiles where id = auth.uid() for update;
  if me.id is null or not me.active or me.authority_id is null
    or me.role not in ('localAuthorityAdmin','platformAdmin') then
    raise exception 'Administrator required' using errcode = '42501';
  end if;
  select * into target from civic_private.profiles where id::text = payload->>'id' for update;
  if target.id is null or target.id = me.id or target.authority_id is distinct from me.authority_id
    or (me.role <> 'platformAdmin' and (target.role = 'platformAdmin' or next_role = 'platformAdmin')) then
    raise exception 'Account not accessible' using errcode = '42501';
  end if;
  if next_role is null or next_role not in
    ('citizen','verifiedResident','officer','departmentAdmin','localAuthorityAdmin','platformAdmin')
    or jsonb_typeof(payload->'isActive') is distinct from 'boolean' then
    raise exception 'Invalid role or active state' using errcode = '22023';
  end if;
  if target.role is distinct from expected_role or target.active is distinct from expected_active then
    raise exception 'Account changed' using errcode = '40001';
  end if;
  next_active := (payload->>'isActive')::boolean;
  -- Only privilege fields are writable here; profile and authority stay intact.
  update civic_private.profiles set role = next_role, active = next_active
    where id = target.id returning * into target;
  return civic_private.profile_json(target);
end;
$$;

create function public.civic_save_department(payload jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  me civic_private.profiles;
  target civic_private.departments;
begin
  select * into me from civic_private.profiles where id = auth.uid() for update;
  if me.id is null or not me.active or me.authority_id is null
    or me.role not in ('departmentAdmin','localAuthorityAdmin','platformAdmin') then
    raise exception 'Administrator required' using errcode = '42501';
  end if;
  select * into target from civic_private.departments where id = payload->>'id' for update;
  if target.id is null or target.authority_id is distinct from me.authority_id then
    raise exception 'Department not accessible' using errcode = '42501';
  end if;
  if length(trim(coalesce(payload->>'headName',''))) not between 1 and 120
    or jsonb_typeof(payload->'officerCount') is distinct from 'number'
    or coalesce(payload->>'officerCount','') !~ '^[0-9]{1,6}$'
    or jsonb_typeof(payload->'categories') is distinct from 'array' then
    raise exception 'Invalid department' using errcode = '22023';
  end if;
  if jsonb_array_length(payload->'categories') not between 1 and 100 then
    raise exception 'Invalid categories' using errcode = '22023';
  end if;
  if exists(select 1 from jsonb_array_elements(payload->'categories') c
    where jsonb_typeof(c) <> 'string' or length(trim(c #>> '{}')) not between 1 and 120) then
    raise exception 'Invalid category' using errcode = '22023';
  end if;
  update civic_private.departments set data = data || jsonb_build_object(
    'headName', trim(payload->>'headName'),
    'officerCount', (payload->>'officerCount')::integer,
    'categories', payload->'categories'
  ) where id = target.id returning * into target;
  return target.data || jsonb_build_object('id',target.id);
end;
$$;

revoke all on function public.civic_bootstrap() from public;
revoke all on function public.civic_manage_user(jsonb,text,boolean) from public, anon;
revoke all on function public.civic_save_department(jsonb) from public, anon;
grant execute on function public.civic_bootstrap() to anon, authenticated;
grant execute on function public.civic_manage_user(jsonb,text,boolean) to authenticated;
grant execute on function public.civic_save_department(jsonb) to authenticated;

commit;
