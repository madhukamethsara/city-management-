begin;

create table civic_private.announcements (
  id text primary key,
  authority_id text not null references civic_private.authorities(id),
  created_by uuid not null references civic_private.profiles(id),
  revision integer not null default 1,
  data jsonb not null,
  initial_payload jsonb not null,
  created_at timestamptz not null default now()
);
create index announcements_authority on civic_private.announcements(authority_id, created_at desc, id);
create table civic_private.announcement_deliveries (
  announcement_id text not null references civic_private.announcements(id) on delete cascade,
  recipient_id uuid not null references civic_private.profiles(id) on delete cascade,
  primary key(announcement_id,recipient_id)
);
alter table civic_private.announcement_deliveries enable row level security;
revoke all on civic_private.announcement_deliveries from public, anon, authenticated;
create table civic_private.feed_preferences (
  announcement_id text not null references civic_private.announcements(id) on delete cascade,
  user_id uuid not null references civic_private.profiles(id) on delete cascade,
  reacted boolean not null default false,
  saved boolean not null default false,
  primary key(announcement_id, user_id)
);
create table civic_private.feed_comments (
  id text primary key,
  announcement_id text not null references civic_private.announcements(id) on delete cascade,
  author_id uuid not null references civic_private.profiles(id) on delete cascade,
  message text not null check(length(message) between 1 and 2000),
  created_at timestamptz not null default now()
);
create index feed_comments_announcement on civic_private.feed_comments(announcement_id, created_at, id);
alter table civic_private.announcements enable row level security;
alter table civic_private.feed_preferences enable row level security;
alter table civic_private.feed_comments enable row level security;
revoke all on civic_private.announcements, civic_private.feed_preferences, civic_private.feed_comments
  from public, anon, authenticated;

create function civic_private.announcement_targets(a civic_private.announcements, p civic_private.profiles)
returns boolean language sql stable set search_path = '' as $$
  select p.active and p.authority_id=a.authority_id
    and (a.data->>'targetWard'='' or a.data->>'targetWard'=p.data->>'ward')
    and (a.data->>'targetDivision'='' or a.data->>'targetDivision'=p.data->>'gnDivision');
$$;
create function civic_private.announcement_visible(a civic_private.announcements, p civic_private.profiles)
returns boolean language sql stable set search_path = '' as $$
  select p.active and p.authority_id=a.authority_id and
    (civic_private.is_officer(p) or
      ((a.data->>'isPublished')::boolean and civic_private.announcement_targets(a,p)));
$$;
create function civic_private.announcement_json(a civic_private.announcements, me civic_private.profiles)
returns jsonb language sql stable set search_path = '' as $$
  select a.data || jsonb_build_object(
    'id',a.id,'authorityId',a.authority_id,'revision',a.revision,
    'reactionCount',(select count(*) from civic_private.feed_preferences where announcement_id=a.id and reacted),
    'commentCount',(select count(*) from civic_private.feed_comments where announcement_id=a.id),
    'reactedUserIds',case when exists(select 1 from civic_private.feed_preferences
      where announcement_id=a.id and user_id=me.id and reacted) then jsonb_build_array(me.id) else '[]'::jsonb end,
    'savedUserIds',case when exists(select 1 from civic_private.feed_preferences
      where announcement_id=a.id and user_id=me.id and saved) then jsonb_build_array(me.id) else '[]'::jsonb end,
    'comments',coalesce((select jsonb_agg(jsonb_build_object(
      'id',c.id,'author',coalesce(p.data->>'fullName','Resident'),'message',c.message,
      'createdAt',c.created_at,'isVerified',p.role in ('verifiedResident','officer','departmentAdmin','localAuthorityAdmin','platformAdmin')
    ) order by c.created_at,c.id) from (
      select * from civic_private.feed_comments where announcement_id=a.id order by created_at desc,id desc limit 50
    ) c join civic_private.profiles p on p.id=c.author_id),'[]'::jsonb)
  );
$$;

create function public.civic_list_announcements(page_offset integer default 0, page_size integer default 25)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare me civic_private.profiles; records jsonb; total integer;
begin
  if auth.uid() is null then return jsonb_build_object('announcements','[]'::jsonb,'total',0); end if;
  select * into me from civic_private.profiles where id=auth.uid();
  if me.id is null or not me.active then raise exception 'Not authorised' using errcode='42501'; end if;
  if page_offset is null or page_offset<0 or page_size is null or page_size not between 1 and 100 then
    raise exception 'Invalid page' using errcode='22023'; end if;
  select count(*) into total from civic_private.announcements a where civic_private.announcement_visible(a,me);
  select coalesce(jsonb_agg(civic_private.announcement_json(a,me) order by created_at desc,id),'[]'::jsonb)
    into records from (select * from civic_private.announcements a where civic_private.announcement_visible(a,me)
      order by created_at desc,id limit page_size offset page_offset) a;
  return jsonb_build_object('announcements',records,'total',total);
end;
$$;

create function public.civic_get_announcement(announcement_id text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare me civic_private.profiles; a civic_private.announcements;
begin
  select * into me from civic_private.profiles where id=auth.uid();
  if me.id is null or not me.active then raise exception 'Not authorised' using errcode='42501'; end if;
  select * into a from civic_private.announcements where id=announcement_id;
  if a.id is null or not civic_private.announcement_visible(a,me) then
    raise exception 'Announcement unavailable' using errcode='42501'; end if;
  return civic_private.announcement_json(a,me);
end;
$$;

create function public.civic_save_announcement(payload jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare me civic_private.profiles; a civic_private.announcements; next_data jsonb;
  event_time text := to_char(clock_timestamp() at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"');
begin
  select * into me from civic_private.profiles where id=auth.uid();
  if me.id is null or not civic_private.is_officer(me) or me.authority_id is null
    or coalesce(me.data->>'onboardingComplete','false')<>'true' then
    raise exception 'Officer required' using errcode='42501'; end if;
  if jsonb_typeof(payload) is distinct from 'object'
    or coalesce(payload->>'id','') !~ '^a-[a-zA-Z0-9-]{1,100}$'
    or payload->>'authorityId' is distinct from me.authority_id then
    raise exception 'Invalid authority' using errcode='42501'; end if;
  perform pg_advisory_xact_lock(hashtextextended(payload->>'id',0));
  select * into a from civic_private.announcements where id=payload->>'id' for update;
  if a.id is not null and a.authority_id<>me.authority_id then
    raise exception 'Announcement unavailable' using errcode='42501'; end if;
  if a.id is not null and payload->>'revision'='0' and a.created_by=me.id and a.initial_payload=payload then
    return civic_private.announcement_json(a,me); end if;
  if jsonb_typeof(payload->'revision') is distinct from 'number'
    or coalesce(payload->>'revision','') !~ '^[0-9]{1,9}$' then
    raise exception 'Invalid revision' using errcode='22023'; end if;
  if (a.id is null and (payload->>'revision')::integer<>0)
    or (a.id is not null and (payload->>'revision')::integer<>a.revision) then
    raise exception 'Announcement changed' using errcode='40001'; end if;
  if exists(select 1 from unnest(array['title','body','type','department','targetWard','targetDivision']) key
      where jsonb_typeof(payload->key) is distinct from 'string')
    or exists(select 1 from unnest(array['isPinned','isPublished']) key
      where jsonb_typeof(payload->key) is distinct from 'boolean') then
    raise exception 'Invalid fields' using errcode='22023'; end if;
  if length(trim(payload->>'title')) not between 8 and 130
    or length(trim(payload->>'body')) not between 20 and 10000
    or payload->>'type' not in ('normal','serviceInterruption','roadClosure','emergency','wasteCollection','publicHealth','event')
    or length(payload->>'targetWard')>120 or length(payload->>'targetDivision')>120
    or (payload->>'department'<>'Administration' and not exists(
      select 1 from civic_private.departments where authority_id=me.authority_id and data->>'name'=payload->>'department')) then
    raise exception 'Invalid announcement' using errcode='22023'; end if;
  -- Audience labels are derived from the actual targeting fields, never trusted from the client.
  next_data := jsonb_build_object('title',trim(payload->>'title'),'body',trim(payload->>'body'),
    'type',payload->>'type','department',payload->>'department',
    'targetWard',trim(payload->>'targetWard'),'targetDivision',trim(payload->>'targetDivision'),
    'targetLabel',coalesce(nullif(concat_ws(' / ',nullif(trim(payload->>'targetWard'),''),
      nullif(trim(payload->>'targetDivision'),'')),''),'All wards'),
    'isPinned',payload->'isPinned','isPublished',payload->'isPublished',
    'publishedAt',case when a.id is null or
      (a.data->>'isPublished'='false' and payload->>'isPublished'='true') then event_time else a.data->>'publishedAt' end);
  if a.id is null then
    insert into civic_private.announcements(id,authority_id,created_by,data,initial_payload)
      values(payload->>'id',me.authority_id,me.id,next_data,payload) returning * into a;
  elsif a.data=next_data then
    return civic_private.announcement_json(a,me);
  else
    update civic_private.announcements set data=next_data,revision=revision+1 where id=a.id returning * into a;
  end if;
  if a.data->>'isPublished'='true' then
    -- Once per announcement and recipient, even after unpublishing/retrying/re-targeting.
    with recipients as (
      insert into civic_private.announcement_deliveries
        select a.id,p.id from civic_private.profiles p where civic_private.announcement_targets(a,p)
          and coalesce(p.data->>'onboardingComplete','false')='true'
        on conflict do nothing returning recipient_id
    )
    insert into civic_private.notifications(id,recipient_id,data)
      select 'n-announcement-'||a.id||'-'||p.id,p.id,
        jsonb_build_object('title','New local announcement','message',a.data->>'title',
          'category','Announcement','createdAt',event_time,'route','/announcements/'||a.id)
      from civic_private.profiles p join recipients r on r.recipient_id=p.id
      on conflict(id) do nothing;
  end if;
  -- Remove stale content/links from audiences who can no longer open the notice.
  delete from civic_private.notifications n using civic_private.profiles p
    where n.recipient_id=p.id and n.id='n-announcement-'||a.id||'-'||p.id
      and (a.data->>'isPublished'<>'true' or not civic_private.announcement_targets(a,p));
  return civic_private.announcement_json(a,me);
end;
$$;

create function public.civic_set_feed_preference(announcement_id text, reacted boolean default null, saved boolean default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare me civic_private.profiles; a civic_private.announcements;
begin
  select * into me from civic_private.profiles where id=auth.uid();
  if me.id is null or not me.active or coalesce(me.data->>'onboardingComplete','false')<>'true' then
    raise exception 'Sign in to participate' using errcode='42501'; end if;
  select * into a from civic_private.announcements where id=announcement_id for share;
  if a.id is null or not civic_private.announcement_visible(a,me) or a.data->>'isPublished'<>'true' then
    raise exception 'Announcement unavailable' using errcode='42501'; end if;
  if reacted is null and saved is null then raise exception 'Missing preference' using errcode='22023'; end if;
  insert into civic_private.feed_preferences as existing values(a.id,me.id,coalesce(reacted,false),coalesce(saved,false))
    on conflict on constraint feed_preferences_pkey do update
      set reacted=coalesce(civic_set_feed_preference.reacted,existing.reacted),
          saved=coalesce(civic_set_feed_preference.saved,existing.saved);
  return civic_private.announcement_json(a,me);
end;
$$;

create function public.civic_add_feed_comment(announcement_id text, comment_id text, message text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare me civic_private.profiles; a civic_private.announcements; c civic_private.feed_comments;
begin
  select * into me from civic_private.profiles where id=auth.uid();
  if me.id is null or not me.active or coalesce(me.data->>'onboardingComplete','false')<>'true' then
    raise exception 'Sign in to comment' using errcode='42501'; end if;
  select * into a from civic_private.announcements where id=announcement_id for share;
  if a.id is null or not civic_private.announcement_visible(a,me) or a.data->>'isPublished'<>'true' then
    raise exception 'Announcement unavailable' using errcode='42501'; end if;
  if coalesce(comment_id,'') !~ '^c-[a-zA-Z0-9-]{1,100}$' or length(trim(coalesce(message,''))) not between 1 and 2000 then
    raise exception 'Invalid comment' using errcode='22023'; end if;
  perform pg_advisory_xact_lock(hashtextextended(comment_id,1));
  select * into c from civic_private.feed_comments where id=comment_id;
  if c.id is not null then
    if c.author_id<>me.id or c.announcement_id<>a.id or c.message<>trim(message) then
      raise exception 'Comment retry changed' using errcode='40001'; end if;
  else
    insert into civic_private.feed_comments(id,announcement_id,author_id,message)
      values(comment_id,a.id,me.id,trim(message));
  end if;
  return civic_private.announcement_json(a,me);
end;
$$;

revoke all on function civic_private.announcement_targets(civic_private.announcements,civic_private.profiles),
  civic_private.announcement_visible(civic_private.announcements,civic_private.profiles),
  civic_private.announcement_json(civic_private.announcements,civic_private.profiles) from public, anon, authenticated;
revoke all on function public.civic_list_announcements(integer,integer),
  public.civic_get_announcement(text), public.civic_save_announcement(jsonb),
  public.civic_set_feed_preference(text,boolean,boolean),public.civic_add_feed_comment(text,text,text) from public, anon;
grant execute on function public.civic_list_announcements(integer,integer) to anon, authenticated;
grant execute on function public.civic_get_announcement(text),public.civic_save_announcement(jsonb),
  public.civic_set_feed_preference(text,boolean,boolean),public.civic_add_feed_comment(text,text,text) to authenticated;
commit;
