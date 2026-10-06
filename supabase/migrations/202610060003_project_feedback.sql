begin;
create table civic_private.project_comments (
  id text primary key,
  project_id text not null references civic_private.projects on delete cascade,
  author_id uuid not null references civic_private.profiles,
  message text not null check(length(message) between 1 and 2000),
  created_at timestamptz not null default now()
);
alter table civic_private.project_comments enable row level security;
revoke all on civic_private.project_comments from public,anon,authenticated;
create index project_comments_parent on civic_private.project_comments(project_id,created_at,id);
create or replace function civic_private.project_json(p civic_private.projects, me civic_private.profiles) returns jsonb
language sql stable set search_path='' as $$
  select p.data || jsonb_build_object(
    'id',p.id,'authorityId',p.authority_id,'revision',p.revision,
    'budget',case when civic_private.is_officer(me) or (p.data->>'isBudgetPublic')::boolean then p.data->'budget' else '0'::jsonb end,
    'spent',case when civic_private.is_officer(me) or (p.data->>'isBudgetPublic')::boolean then p.data->'spent' else '0'::jsonb end,
    'updates',coalesce((select jsonb_agg(u order by n) from jsonb_array_elements(p.data->'updates')
      with ordinality as entries(u,n) where civic_private.is_officer(me) or (u->>'isPublic')::boolean),'[]'::jsonb),
    'followerIds',case when exists(select 1 from civic_private.project_subscriptions where project_id=p.id and user_id=me.id)
      then jsonb_build_array(me.id) else '[]'::jsonb end,
    'comments',coalesce((
    select jsonb_agg(jsonb_build_object('id',c.id,'author',coalesce(u.data->>'fullName','Resident'),
      'message',c.message,'createdAt',c.created_at,'isVerified',u.role<>'citizen') order by c.created_at,c.id)
    from civic_private.project_comments c join civic_private.profiles u on u.id=c.author_id
    where c.project_id=p.id),'[]'::jsonb));
$$;
create function public.civic_project_comment(project_id text, comment_id text, message text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare me civic_private.profiles := civic_private.participant(); p civic_private.projects; c civic_private.project_comments;
begin
  select * into p from civic_private.projects where id=project_id;
  if p.id is null or p.authority_id<>me.authority_id then raise exception 'Unavailable' using errcode='42501'; end if;
  if comment_id is null or comment_id !~ '^pjc-[a-zA-Z0-9-]{1,100}$'
    or message is null or length(trim(message)) not between 1 and 2000 then
    raise exception 'Invalid comment' using errcode='22023'; end if;
  perform pg_advisory_xact_lock(hashtextextended(comment_id,0));
  select * into c from civic_private.project_comments where id=comment_id;
  if c.id is not null then
    if c.project_id<>p.id or c.author_id<>me.id then raise exception 'Unavailable' using errcode='42501'; end if;
    if c.message<>trim(message) then raise exception 'Retry changed' using errcode='40001'; end if;
  else insert into civic_private.project_comments(id,project_id,author_id,message) values(comment_id,p.id,me.id,trim(message)); end if;
  return civic_private.project_json(p,me);
end; $$;
revoke all on function civic_private.project_json(civic_private.projects,civic_private.profiles),
  public.civic_project_comment(text,text,text) from public,anon,authenticated;
grant execute on function public.civic_project_comment(text,text,text) to authenticated;
commit;
