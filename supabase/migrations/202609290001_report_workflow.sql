begin;

-- First connected workflow. Apply to a Supabase staging project before release.
-- All application tables live outside the exposed public schema.
create schema if not exists civic_private;
revoke all on schema civic_private from public, anon, authenticated;

create table civic_private.authorities (
  id text primary key,
  data jsonb not null check (jsonb_typeof(data) = 'object')
);
create table civic_private.departments (
  id text primary key,
  authority_id text not null references civic_private.authorities(id),
  data jsonb not null check (jsonb_typeof(data) = 'object')
);
create table civic_private.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  authority_id text references civic_private.authorities(id),
  role text not null default 'citizen' check (role in
    ('citizen','verifiedResident','officer','departmentAdmin','localAuthorityAdmin','platformAdmin')),
  active boolean not null default true,
  data jsonb not null default '{}'::jsonb
);
create sequence civic_private.case_number_seq;
create table civic_private.reports (
  id text primary key,
  authority_id text not null references civic_private.authorities(id),
  owner_id uuid not null references civic_private.profiles(id),
  case_number text not null unique,
  revision integer not null default 1,
  data jsonb not null,
  internal_notes jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);
create index reports_authority on civic_private.reports(authority_id);
create index reports_owner on civic_private.reports(owner_id);
create table civic_private.notifications (
  id text primary key,
  recipient_id uuid not null references civic_private.profiles(id) on delete cascade,
  data jsonb not null,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);
create index notifications_recipient on civic_private.notifications(recipient_id);
alter table civic_private.authorities enable row level security;
alter table civic_private.departments enable row level security;
alter table civic_private.profiles enable row level security;
alter table civic_private.reports enable row level security;
alter table civic_private.notifications enable row level security;
-- No direct table access, even if this schema is accidentally added to the Data API.
revoke all on all tables in schema civic_private from public, anon, authenticated;
revoke all on all sequences in schema civic_private from public, anon, authenticated;

create function civic_private.is_officer(p civic_private.profiles)
returns boolean language sql immutable set search_path = '' as $$
  select p.active and p.role in ('officer','departmentAdmin','localAuthorityAdmin','platformAdmin');
$$;

create function civic_private.profile_json(p civic_private.profiles)
returns jsonb language sql stable set search_path = '' as $$
  select p.data || jsonb_build_object(
    'id', p.id, 'role', p.role, 'isActive', p.active,
    'localAuthorityId', coalesce(p.authority_id, ''),
    'fullName', coalesce(p.data->>'fullName', 'Resident'),
    'email', coalesce((select email from auth.users where id = p.id), '')
  );
$$;

create function civic_private.report_json(r civic_private.reports, officer boolean)
returns jsonb language sql immutable set search_path = '' as $$
  select r.data || jsonb_build_object(
    'id', r.id, 'caseNumber', r.case_number, 'ownerUserId', r.owner_id,
    'revision', r.revision,
    'internalNotes', case when officer then r.internal_notes else '[]'::jsonb end
  );
$$;

create function public.civic_bootstrap()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  me civic_private.profiles;
  staff boolean := false;
  result jsonb;
begin
  result := jsonb_build_object(
    'authorities', coalesce((select jsonb_agg(data || jsonb_build_object('id', id) order by id)
      from civic_private.authorities), '[]'::jsonb),
    'departments', '[]'::jsonb, 'users', '[]'::jsonb,
    'reports', '[]'::jsonb, 'notifications', '[]'::jsonb
  );
  if auth.uid() is null then return result; end if;
  insert into civic_private.profiles(id, data)
    select id, jsonb_build_object('fullName',
      coalesce(nullif(raw_user_meta_data->>'full_name', ''), 'Resident'))
    from auth.users where id = auth.uid()
    on conflict (id) do nothing;
  select * into strict me from civic_private.profiles where id = auth.uid();
  if not me.active then raise exception 'Account inactive' using errcode = '42501'; end if;
  staff := civic_private.is_officer(me);
  return result || jsonb_build_object(
    'users', jsonb_build_array(civic_private.profile_json(me)) ||
      case when staff then coalesce((select jsonb_agg(jsonb_build_object(
        'id',p.id,'fullName',coalesce(p.data->>'fullName','Officer'),'role',p.role,
        'isActive',p.active,'localAuthorityId',p.authority_id))
        from civic_private.profiles p where p.id<>me.id and p.authority_id=me.authority_id
        and civic_private.is_officer(p)), '[]'::jsonb) else '[]'::jsonb end,
    'departments', coalesce((select jsonb_agg(data || jsonb_build_object('id', id) order by id)
      from civic_private.departments where authority_id = me.authority_id), '[]'::jsonb),
    'reports', coalesce((select jsonb_agg(civic_private.report_json(r, staff) order by r.created_at desc)
      from civic_private.reports r where r.authority_id = me.authority_id
      and (r.owner_id = me.id or staff)), '[]'::jsonb),
    'notifications', coalesce((select jsonb_agg(data || jsonb_build_object('id', id, 'isRead', is_read)
      order by created_at desc) from civic_private.notifications where recipient_id = me.id), '[]'::jsonb)
  );
end;
$$;

create function public.civic_save_profile_notifications(profiles jsonb, read_notifications jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  me civic_private.profiles;
  item jsonb;
  authority text;
  saved_users jsonb := '[]'::jsonb;
  saved_notifications jsonb := '[]'::jsonb;
  n civic_private.notifications;
begin
  select * into me from civic_private.profiles where id = auth.uid() for update;
  if me.id is null or not me.active then raise exception 'Not authorised' using errcode = '42501'; end if;
  if jsonb_typeof(profiles) <> 'array' or jsonb_array_length(profiles) > 1
    or jsonb_typeof(read_notifications) <> 'array' then
    raise exception 'Invalid batch' using errcode = '22023';
  end if;
  for item in select value from jsonb_array_elements(profiles) loop
    if item->>'id' is distinct from me.id::text or item->>'role' is distinct from me.role
      or item->>'isActive' is distinct from 'true' then
      raise exception 'Profile privileges are managed by the authority' using errcode = '42501';
    end if;
    authority := nullif(item->>'localAuthorityId', '');
    if me.authority_id is not null and authority is distinct from me.authority_id then
      raise exception 'Authority transfers require an administrator' using errcode = '42501';
    end if;
    if length(trim(coalesce(item->>'fullName', ''))) not between 2 and 120
      or coalesce(item->>'preferredLanguage','') not in ('en','si','ta')
      or length(coalesce(item->>'phone','')) > 30
      or length(coalesce(item->>'ward','')) > 120
      or length(coalesce(item->>'gnDivision','')) > 120
      or (item->>'onboardingComplete' = 'true' and authority is null)
      or (authority is not null and not exists(select 1 from civic_private.authorities where id=authority)) then
      raise exception 'Invalid profile' using errcode = '22023';
    end if;
    update civic_private.profiles set authority_id = authority,
      data = jsonb_build_object(
        'fullName', trim(item->>'fullName'), 'phone', item->>'phone',
        'ward', item->>'ward', 'gnDivision', item->>'gnDivision',
        'preferredLanguage', item->>'preferredLanguage',
        'onboardingComplete', coalesce((item->>'onboardingComplete')::boolean,false),
        'residentialArea', item->'residentialArea')
      where id = me.id returning * into me;
    saved_users := jsonb_build_array(civic_private.profile_json(me));
  end loop;
  for item in select value from jsonb_array_elements(read_notifications) loop
    update civic_private.notifications set is_read = (item->>'isRead')::boolean
      where id = item->>'id' and recipient_id = me.id returning * into n;
    if not found then raise exception 'Notification not accessible' using errcode = '42501'; end if;
    saved_notifications := saved_notifications || jsonb_build_array(
      n.data || jsonb_build_object('id', n.id, 'isRead', n.is_read));
  end loop;
  return jsonb_build_object('users', saved_users, 'notifications', saved_notifications);
end;
$$;

create function public.civic_save_report(payload jsonb, is_new boolean)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  me civic_private.profiles;
  r civic_private.reports;
  staff boolean;
  next_data jsonb;
  updates jsonb;
  comments jsonb;
  notes jsonb;
  entry jsonb;
  evidence text;
  message text;
  status text;
  changed boolean := false;
  now_value text := to_char(clock_timestamp() at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"');
  mutable text[] := array['revision','status','priority','department','assignedOfficer','attachments',
    'updates','lastUpdated','followerIds','internalNotes','comments'];
begin
  select * into me from civic_private.profiles where id = auth.uid();
  if me.id is null or not me.active or me.authority_id is null
    or coalesce(me.data->>'onboardingComplete','false') <> 'true' then
    raise exception 'Complete your profile first' using errcode = '42501';
  end if;
  staff := civic_private.is_officer(me);
  if coalesce(payload->>'id','') !~ '^r-[a-zA-Z0-9-]{1,100}$'
    or length(trim(coalesce(payload->>'title',''))) not between 6 and 80
    or length(trim(coalesce(payload->>'description',''))) not between 15 and 900
    or length(trim(coalesce(payload->>'locationLabel',''))) not between 4 and 240
    or coalesce(payload->>'priority','') not in ('Normal','High','Urgent')
    or coalesce(payload->>'category','') not in ('Road Damage','Street Light','Garbage','Drainage',
      'Dangerous Tree','Public Property Damage','Environmental Issue','Water Issue','Public Health',
      'Noise/Public Nuisance','Other')
    or coalesce((payload->'location'->>'latitude')::numeric, 999) not between -90 and 90
    or coalesce((payload->'location'->>'longitude')::numeric, 999) not between -180 and 180
    or jsonb_typeof(payload->'attachments') is distinct from 'array'
    or jsonb_array_length(payload->'attachments') > 10
    or jsonb_typeof(payload->'updates') is distinct from 'array'
    or jsonb_typeof(payload->'comments') is distinct from 'array'
    or jsonb_typeof(payload->'internalNotes') is distinct from 'array'
    or jsonb_typeof(payload->'followerIds') is distinct from 'array' then
    raise exception 'Invalid report' using errcode = '22023';
  end if;
  -- Serialise retries for the same client request id, including initial creation.
  perform pg_advisory_xact_lock(hashtextextended(payload->>'id', 0));
  select * into r from civic_private.reports where id = payload->>'id' for update;
  if is_new then
    if r.id is not null then
      if r.owner_id <> me.id or r.authority_id <> me.authority_id then
        raise exception 'Not authorised' using errcode = '42501';
      end if;
      -- A lost response can safely retry without creating a second case.
      if (r.data - mutable - array['caseNumber','submittedAt'])
        is distinct from (payload - mutable - array['caseNumber','submittedAt']) then
        raise exception 'Request id already used' using errcode = '23505';
      end if;
      return civic_private.report_json(r, staff);
    end if;
    if payload->>'ownerUserId' is distinct from me.id::text then
      raise exception 'Invalid owner' using errcode = '42501';
    end if;
    message := 'Your report was received and given a case number.';
    next_data := payload - array['internalNotes','revision'] || jsonb_build_object(
      'caseNumber', 'SS-' || extract(year from now())::text || '-' ||
        lpad(nextval('civic_private.case_number_seq')::text, 8, '0'),
      'status', 'submitted', 'submittedAt', now_value, 'lastUpdated', now_value,
      'assignedOfficer', null, 'comments', '[]'::jsonb,
      'followerIds', jsonb_build_array(me.id::text),
      'department', coalesce((select data->>'name' from civic_private.departments
        where authority_id = me.authority_id and data->'categories' ? (payload->>'category')
        order by id limit 1), 'Administration'),
      'updates', jsonb_build_array(jsonb_build_object(
        'status','submitted','message',message,'date',now_value,'isPublic',true))
    );
    notes := '[]'::jsonb;
    changed := true;
  else
    if r.id is null or r.authority_id <> me.authority_id or (r.owner_id <> me.id and not staff) then
      raise exception 'Report not accessible' using errcode = '42501';
    end if;
    if (payload->>'revision')::integer is distinct from r.revision then
      raise exception 'Report changed' using errcode = '40001';
    end if;
    if (payload - mutable) is distinct from (r.data - mutable) then
      raise exception 'Immutable report fields changed' using errcode = '42501';
    end if;
    next_data := r.data;
    notes := r.internal_notes;
    status := payload->>'status';
    if coalesce(status,'') not in ('submitted','acknowledged','assigned','inProgress','resolved','rejected') then
      raise exception 'Invalid status' using errcode = '22023';
    end if;
    -- A resident can only confirm/reopen their resolved case, follow it, or comment.
    if not staff then
      if (payload - array['revision','status','updates','lastUpdated','followerIds','internalNotes','comments'])
        is distinct from (r.data - array['revision','status','updates','lastUpdated','followerIds','internalNotes','comments'])
        or payload->'internalNotes' <> '[]'::jsonb then
        raise exception 'Officer fields changed' using errcode = '42501';
      end if;
      if payload->'updates' is distinct from r.data->'updates' then
        if r.data->>'status' <> 'resolved' or status not in ('resolved','inProgress') then
          raise exception 'Only resolved cases can be confirmed' using errcode = '42501';
        end if;
        message := case when status = 'resolved'
          then 'The resident confirmed that this issue is resolved.'
          else 'The resident reported that the issue still needs attention.' end;
        changed := true;
      elsif status is distinct from r.data->>'status' then
        raise exception 'Invalid status change' using errcode = '42501';
      end if;
    else
      if payload->'updates' is distinct from r.data->'updates' then
        updates := payload->'updates';
        if jsonb_array_length(updates) <> jsonb_array_length(r.data->'updates') + 1
          or (updates - (jsonb_array_length(updates)-1)) <> r.data->'updates' then
          raise exception 'Timeline is append only' using errcode = '22023';
        end if;
        message := updates->-1->>'message';
        if length(trim(coalesce(message,''))) not between 1 and 2000 then
          raise exception 'A public update is required' using errcode = '22023';
        end if;
        changed := true;
      elsif (payload->>'status',payload->>'priority',payload->>'department',payload->>'assignedOfficer',payload->'attachments')
        is distinct from (r.data->>'status',r.data->>'priority',r.data->>'department',r.data->>'assignedOfficer',r.data->'attachments') then
        raise exception 'A public update is required' using errcode = '22023';
      end if;
      if payload->>'department' <> 'Administration' and not exists (
        select 1 from civic_private.departments where authority_id = me.authority_id
        and data->>'name' = payload->>'department') then
        raise exception 'Invalid department' using errcode = '22023';
      end if;
      if nullif(payload->>'assignedOfficer','') is not null and not exists (
        select 1 from civic_private.profiles p where p.authority_id=me.authority_id
        and civic_private.is_officer(p) and p.data->>'fullName'=payload->>'assignedOfficer') then
        raise exception 'Invalid officer' using errcode = '22023';
      end if;
      notes := payload->'internalNotes';
      if jsonb_array_length(notes) < jsonb_array_length(r.internal_notes)
        or jsonb_array_length(notes) > jsonb_array_length(r.internal_notes)+1
        or (select coalesce(jsonb_agg(value order by ord),'[]'::jsonb)
            from jsonb_array_elements(notes) with ordinality n(value,ord)
            where ord <= jsonb_array_length(r.internal_notes)) <> r.internal_notes then
        raise exception 'Internal notes are append only' using errcode = '22023';
      end if;
      if notes <> r.internal_notes and length(coalesce(notes->>-1,'')) not between 1 and 2000 then
        raise exception 'Invalid note' using errcode = '22023';
      end if;
      next_data := next_data || jsonb_build_object(
        'priority',payload->'priority','department',payload->'department',
        'assignedOfficer',payload->'assignedOfficer','attachments',payload->'attachments');
    end if;
    -- Followers are private to this release: only the current actor can toggle their own id.
    if (select coalesce(jsonb_agg(value order by value),'[]'::jsonb)
        from jsonb_array_elements(payload->'followerIds') where value <> to_jsonb(me.id::text))
      <> (select coalesce(jsonb_agg(value order by value),'[]'::jsonb)
        from jsonb_array_elements(r.data->'followerIds') where value <> to_jsonb(me.id::text))
      or jsonb_array_length(payload->'followerIds') > jsonb_array_length(r.data->'followerIds')+1 then
      raise exception 'Invalid followers' using errcode = '42501';
    end if;
    next_data := next_data || jsonb_build_object('followerIds', payload->'followerIds');
    comments := payload->'comments';
    if comments is distinct from r.data->'comments' then
      if jsonb_array_length(comments) <> jsonb_array_length(r.data->'comments')+1
        or (comments - (jsonb_array_length(comments)-1)) <> r.data->'comments' then
        raise exception 'Comments are append only' using errcode = '22023';
      end if;
      entry := comments->-1;
      if length(trim(coalesce(entry->>'message',''))) not between 1 and 2000 then
        raise exception 'Invalid comment' using errcode = '22023';
      end if;
      entry := jsonb_build_object('id',gen_random_uuid()::text,
        'author',case when staff then 'Authority officer' else 'Resident' end,
        'message',trim(entry->>'message'),'createdAt',now_value,
        'isVerified',staff or me.role='verifiedResident');
      next_data := next_data || jsonb_build_object('comments',r.data->'comments' || jsonb_build_array(entry));
    end if;
    if changed then
      next_data := next_data || jsonb_build_object('status',status,'lastUpdated',now_value,
        'updates',r.data->'updates' || jsonb_build_array(jsonb_build_object(
          'status',status,'message',message,'date',now_value,'isPublic',true)));
    end if;
  end if;
  -- New evidence must be an existing private upload owned by the caller.
  for evidence in select jsonb_array_elements_text(next_data->'attachments') loop
    if not is_new and r.data->'attachments' ? evidence then continue; end if;
    if split_part(evidence,'/',1) <> me.id::text or not exists (
      select 1 from storage.objects where bucket_id='report-evidence' and name=evidence
    ) then raise exception 'Invalid evidence' using errcode = '42501'; end if;
  end loop;
  if is_new then
    insert into civic_private.reports(id, authority_id, owner_id, case_number, data, internal_notes)
      values(payload->>'id', me.authority_id, me.id, next_data->>'caseNumber', next_data, notes)
      returning * into r;
  else
    update civic_private.reports set data=next_data, internal_notes=notes, revision=revision+1
      where id=r.id returning * into r;
  end if;
  if changed then
    insert into civic_private.notifications(id,recipient_id,data)
    values(r.id || '-' || r.revision::text, r.owner_id, jsonb_build_object(
      'title',case when is_new then 'Your report was submitted' else 'Your report has an update' end,
      'message',r.case_number || ': ' || message,'category','Report update',
      'createdAt',now_value,'route','/reports/' || r.id));
  end if;
  return civic_private.report_json(r, staff);
end;
$$;

-- Storage authorisation reads the same live profile and report membership as RPCs.
create function public.civic_can_read_evidence(object_name text)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from civic_private.profiles p where p.id=auth.uid() and p.active and (
    split_part(object_name,'/',1)=p.id::text or exists (
      select 1 from civic_private.reports r where r.authority_id=p.authority_id
      and (r.owner_id=p.id or civic_private.is_officer(p)) and r.data->'attachments' ? object_name)));
$$;
create function public.civic_can_upload_evidence(object_name text)
returns boolean language sql stable security definer set search_path = '' as $$
  select split_part(object_name,'/',1)=auth.uid()::text and exists(
    select 1 from civic_private.profiles where id=auth.uid() and active
    and authority_id is not null and data->>'onboardingComplete'='true');
$$;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('report-evidence','report-evidence',false,5242880,array['image/jpeg','image/png','image/webp']);
create policy report_evidence_insert on storage.objects for insert to authenticated
  with check(bucket_id='report-evidence' and public.civic_can_upload_evidence(name));
create policy report_evidence_read on storage.objects for select to authenticated
  using(bucket_id='report-evidence' and public.civic_can_read_evidence(name));
-- No overwrite/delete policy: attached evidence remains stable.

revoke all on all functions in schema civic_private from public, anon, authenticated;
revoke all on function public.civic_bootstrap() from public, anon, authenticated;
revoke all on function public.civic_save_profile_notifications(jsonb,jsonb) from public, anon, authenticated;
revoke all on function public.civic_save_report(jsonb,boolean) from public, anon, authenticated;
revoke all on function public.civic_can_read_evidence(text) from public, anon, authenticated;
revoke all on function public.civic_can_upload_evidence(text) from public, anon, authenticated;
grant execute on function public.civic_bootstrap() to anon, authenticated;
grant execute on function public.civic_save_profile_notifications(jsonb,jsonb) to authenticated;
grant execute on function public.civic_save_report(jsonb,boolean) to authenticated;
grant execute on function public.civic_can_read_evidence(text) to authenticated;
grant execute on function public.civic_can_upload_evidence(text) to authenticated;

commit;
