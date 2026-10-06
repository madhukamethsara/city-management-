begin;
create table civic_private.proposals (
  id text primary key, authority_id text not null references civic_private.authorities,
  owner_id uuid not null references civic_private.profiles,
  data jsonb not null, initial_payload jsonb not null,
  status text not null default 'submitted', revision integer not null default 1,
  created_at timestamptz not null default now()
);
create table civic_private.proposal_preferences (
  proposal_id text not null references civic_private.proposals on delete cascade,
  user_id uuid not null references civic_private.profiles on delete cascade,
  supported boolean not null default false, following boolean not null default false,
  primary key(proposal_id,user_id)
);
create table civic_private.proposal_comments (
  id text primary key, proposal_id text not null references civic_private.proposals on delete cascade,
  author_id uuid not null references civic_private.profiles,
  message text not null, created_at timestamptz not null default now()
);
create table civic_private.consultations (
  id text primary key, authority_id text not null references civic_private.authorities,
  owner_id uuid not null references civic_private.profiles, data jsonb not null,
  created_at timestamptz not null default now()
);
create table civic_private.consultation_answers (
  consultation_id text not null references civic_private.consultations on delete cascade,
  user_id uuid not null references civic_private.profiles on delete cascade,
  answers jsonb not null, created_at timestamptz not null default now(),
  primary key(consultation_id,user_id)
);
alter table civic_private.proposals enable row level security;
alter table civic_private.proposal_preferences enable row level security;
alter table civic_private.proposal_comments enable row level security;
alter table civic_private.consultations enable row level security;
alter table civic_private.consultation_answers enable row level security;
revoke all on civic_private.proposals,civic_private.proposal_preferences,
  civic_private.proposal_comments,civic_private.consultations,civic_private.consultation_answers
  from public,anon,authenticated;
create index proposals_authority on civic_private.proposals(authority_id,created_at desc,id);
create index consultations_authority on civic_private.consultations(authority_id,created_at desc,id);
create index proposal_comments_parent on civic_private.proposal_comments(proposal_id,created_at,id);

create function civic_private.protect_consultation_department() returns trigger
language plpgsql set search_path='' as $$
begin
  if exists(select 1 from civic_private.consultations where authority_id=old.authority_id and data->>'department'=old.data->>'name') then
    raise exception 'Department owns consultations' using errcode='23503'; end if;
  return old;
end; $$;
create trigger protect_consultation_department before delete on civic_private.departments
  for each row execute function civic_private.protect_consultation_department();

create function civic_private.participant() returns civic_private.profiles
language plpgsql stable set search_path='' as $$
declare me civic_private.profiles;
begin
  select * into me from civic_private.profiles where id=auth.uid();
  if me.id is null or not me.active or me.authority_id is null
    or coalesce(me.data->>'onboardingComplete','false')<>'true' then
    raise exception 'Active onboarded account required' using errcode='42501'; end if;
  return me;
end; $$;

create function civic_private.proposal_json(p civic_private.proposals, me civic_private.profiles)
returns jsonb language sql stable set search_path='' as $$
  select p.data || jsonb_build_object('id',p.id,'status',p.status,'revision',p.revision,
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
create function civic_private.consultation_json(c civic_private.consultations, me civic_private.profiles)
returns jsonb language sql stable set search_path='' as $$
  select c.data || jsonb_build_object('id',c.id,
    'responseCount',(select count(*) from civic_private.consultation_answers where consultation_id=c.id),
    'respondedUserIds',case when exists(select 1 from civic_private.consultation_answers where consultation_id=c.id and user_id=me.id)
      then jsonb_build_array(me.id) else '[]'::jsonb end,
    'answers',coalesce((select jsonb_build_object(me.id::text,answers) from civic_private.consultation_answers
      where consultation_id=c.id and user_id=me.id),'{}'::jsonb));
$$;
create function public.civic_participation() returns jsonb
language plpgsql security definer set search_path='' as $$
declare me civic_private.profiles;
begin
  if auth.uid() is null then return jsonb_build_object('proposals','[]'::jsonb,'consultations','[]'::jsonb); end if;
  select * into me from civic_private.profiles where id=auth.uid();
  if me.id is null or not me.active then raise exception 'Not authorised' using errcode='42501'; end if;
  return jsonb_build_object(
    'proposals',coalesce((select jsonb_agg(civic_private.proposal_json(p,me) order by p.created_at desc,p.id)
      from civic_private.proposals p where p.authority_id=me.authority_id),'[]'::jsonb),
    'consultations',coalesce((select jsonb_agg(civic_private.consultation_json(c,me) order by c.created_at desc,c.id)
      from civic_private.consultations c where c.authority_id=me.authority_id),'[]'::jsonb));
end; $$;

create function public.civic_create_proposal(payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare me civic_private.profiles := civic_private.participant(); p civic_private.proposals;
begin
  if jsonb_typeof(payload) is distinct from 'object' or coalesce(payload->>'id','') !~ '^pr-[a-zA-Z0-9-]{1,100}$'
    or exists(select 1 from unnest(array['title','description','category','locationLabel','expectedBenefit']) k
      where jsonb_typeof(payload->k) is distinct from 'string')
    or length(trim(payload->>'title')) not between 8 and 130
    or length(trim(payload->>'description')) not between 30 and 10000
    or length(trim(payload->>'category')) not between 1 and 120
    or length(trim(payload->>'locationLabel')) not between 4 and 250
    or length(trim(payload->>'expectedBenefit')) not between 20 and 700
    or payload->'attachments' is distinct from '[]'::jsonb then
    raise exception 'Invalid proposal' using errcode='22023'; end if;
  perform pg_advisory_xact_lock(hashtextextended(payload->>'id',0));
  select * into p from civic_private.proposals where id=payload->>'id';
  if p.id is not null then
    if p.owner_id<>me.id or p.authority_id<>me.authority_id then raise exception 'Unavailable' using errcode='42501'; end if;
    if p.initial_payload<>payload then raise exception 'Retry payload changed' using errcode='40001'; end if;
    return civic_private.proposal_json(p,me);
  end if;
  insert into civic_private.proposals(id,authority_id,owner_id,data,initial_payload)
    values(payload->>'id',me.authority_id,me.id,payload-'id',payload) returning * into p;
  insert into civic_private.proposal_preferences values(p.id,me.id,true,true);
  return civic_private.proposal_json(p,me);
end; $$;
create function public.civic_proposal_preference(proposal_id text, supported boolean default null, following boolean default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare me civic_private.profiles := civic_private.participant(); p civic_private.proposals;
begin
  select * into p from civic_private.proposals where id=proposal_id;
  if p.id is null or p.authority_id<>me.authority_id then raise exception 'Unavailable' using errcode='42501'; end if;
  insert into civic_private.proposal_preferences as pref values(p.id,me.id,coalesce(supported,false),coalesce(following,false))
    on conflict on constraint proposal_preferences_pkey do update set supported=coalesce(civic_proposal_preference.supported,pref.supported),
    following=coalesce(civic_proposal_preference.following,pref.following);
  return civic_private.proposal_json(p,me);
end; $$;
create function public.civic_proposal_comment(proposal_id text, comment_id text, message text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare me civic_private.profiles := civic_private.participant(); p civic_private.proposals; c civic_private.proposal_comments;
begin
  select * into p from civic_private.proposals where id=proposal_id;
  if p.id is null or p.authority_id<>me.authority_id then raise exception 'Unavailable' using errcode='42501'; end if;
  if comment_id is null or comment_id !~ '^pc-[a-zA-Z0-9-]{1,100}$' or message is null or length(trim(message)) not between 1 and 2000 then
    raise exception 'Invalid comment' using errcode='22023'; end if;
  perform pg_advisory_xact_lock(hashtextextended(comment_id,0));
  select * into c from civic_private.proposal_comments where id=comment_id;
  if c.id is not null then
    if c.author_id<>me.id or c.proposal_id<>p.id then raise exception 'Unavailable' using errcode='42501'; end if;
    if c.message<>trim(message) then raise exception 'Retry changed' using errcode='40001'; end if;
  else insert into civic_private.proposal_comments(id,proposal_id,author_id,message) values(comment_id,p.id,me.id,trim(message)); end if;
  return civic_private.proposal_json(p,me);
end; $$;
create function public.civic_review_proposal(proposal_id text, next_status text, expected_revision integer) returns jsonb
language plpgsql security definer set search_path='' as $$
declare me civic_private.profiles := civic_private.participant(); p civic_private.proposals;
begin
  if not civic_private.is_officer(me) then raise exception 'Officer required' using errcode='42501'; end if;
  select * into p from civic_private.proposals where id=proposal_id for update;
  if p.id is null or p.authority_id<>me.authority_id then raise exception 'Unavailable' using errcode='42501'; end if;
  if expected_revision is distinct from p.revision then raise exception 'Changed' using errcode='40001'; end if;
  if next_status is null or next_status not in ('submitted','communityReview','technicalReview','approved','rejected') then
    raise exception 'Invalid status' using errcode='22023'; end if;
  update civic_private.proposals set status=next_status,revision=revision+1 where id=p.id returning * into p;
  insert into civic_private.notifications(id,recipient_id,data)
    select 'n-proposal-'||p.id||'-'||p.revision||'-'||pref.user_id,pref.user_id,
      jsonb_build_object('title','Proposal review updated','message',p.data->>'title','category','Proposal','route','/proposals/'||p.id)
    from civic_private.proposal_preferences pref join civic_private.profiles u on u.id=pref.user_id
    where pref.proposal_id=p.id and pref.following and u.active and u.authority_id=p.authority_id;
  return civic_private.proposal_json(p,me);
end; $$;
create function public.civic_create_consultation(payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare me civic_private.profiles := civic_private.participant(); c civic_private.consultations; q jsonb;
begin
  if not civic_private.is_officer(me) then raise exception 'Officer required' using errcode='42501'; end if;
  if jsonb_typeof(payload) is distinct from 'object' or coalesce(payload->>'id','') !~ '^con-[a-zA-Z0-9-]{1,100}$'
    or exists(select 1 from unnest(array['title','description','department','openingDate','closingDate']) k
      where jsonb_typeof(payload->k) is distinct from 'string')
    or length(trim(payload->>'title')) not between 8 and 130 or length(trim(payload->>'description')) not between 20 and 10000
    or jsonb_typeof(payload->'questions') is distinct from 'array' then
    raise exception 'Invalid consultation' using errcode='22023'; end if;
  perform 1 from civic_private.departments where authority_id=me.authority_id and data->>'name'=payload->>'department' for key share;
  if (payload->>'openingDate')::timestamptz >= (payload->>'closingDate')::timestamptz
    or not exists(select 1 from civic_private.departments where authority_id=me.authority_id and data->>'name'=payload->>'department')
    or jsonb_array_length(payload->'questions') not between 1 and 20 then
    raise exception 'Invalid consultation' using errcode='22023'; end if;
  for q in select value from jsonb_array_elements(payload->'questions') loop
    if jsonb_typeof(q) is distinct from 'object' or jsonb_typeof(q->'id') is distinct from 'string'
      or length(q->>'id') not between 1 and 100 or jsonb_typeof(q->'question') is distinct from 'string'
      or length(trim(q->>'question')) not between 4 and 500
      or jsonb_typeof(q->'allowsLongText') is distinct from 'boolean'
      or jsonb_typeof(q->'options') is distinct from 'array' then
      raise exception 'Invalid question' using errcode='22023'; end if;
    if jsonb_array_length(q->'options')>20 or exists(select 1 from jsonb_array_elements(q->'options') o
        where jsonb_typeof(o) is distinct from 'string' or length(trim(o#>>'{}')) not between 1 and 200)
      or ((q->>'allowsLongText')::boolean=false and jsonb_array_length(q->'options')<2) then
      raise exception 'Invalid options' using errcode='22023'; end if;
  end loop;
  if (select count(distinct value->>'id') from jsonb_array_elements(payload->'questions'))<>jsonb_array_length(payload->'questions') then
    raise exception 'Duplicate questions' using errcode='22023'; end if;
  perform pg_advisory_xact_lock(hashtextextended(payload->>'id',0));
  select * into c from civic_private.consultations where id=payload->>'id';
  if c.id is not null then
    if c.owner_id<>me.id or c.authority_id<>me.authority_id then raise exception 'Unavailable' using errcode='42501'; end if;
    if c.data<>payload-'id' then raise exception 'Retry changed' using errcode='40001'; end if;
  else insert into civic_private.consultations(id,authority_id,owner_id,data)
    values(payload->>'id',me.authority_id,me.id,payload-'id') returning * into c; end if;
  return civic_private.consultation_json(c,me);
end; $$;
create function public.civic_answer_consultation(consultation_id text, answers jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare me civic_private.profiles := civic_private.participant(); c civic_private.consultations; q jsonb; existing jsonb;
begin
  select * into c from civic_private.consultations where id=consultation_id;
  if c.id is null or c.authority_id<>me.authority_id then raise exception 'Unavailable' using errcode='42501'; end if;
  perform pg_advisory_xact_lock(hashtextextended(c.id||me.id,0));
  select a.answers into existing from civic_private.consultation_answers a where a.consultation_id=c.id and user_id=me.id;
  if existing is not null then
    if existing<>answers then raise exception 'Already answered' using errcode='40001'; end if;
    return civic_private.consultation_json(c,me);
  end if;
  if now()<(c.data->>'openingDate')::timestamptz or now()>=(c.data->>'closingDate')::timestamptz
    or jsonb_typeof(answers) is distinct from 'object' then raise exception 'Not accepting answers' using errcode='22023'; end if;
  if (select count(*) from jsonb_object_keys(answers))<>jsonb_array_length(c.data->'questions') then
    raise exception 'Answer every question' using errcode='22023'; end if;
  for q in select value from jsonb_array_elements(c.data->'questions') loop
    if jsonb_typeof(answers->(q->>'id')) is distinct from 'string'
      or length(trim(answers->>(q->>'id'))) not between 1 and 4000
      or ((q->>'allowsLongText')::boolean=false and not (q->'options' ? (answers->>(q->>'id')))) then
      raise exception 'Invalid answer' using errcode='22023'; end if;
  end loop;
  insert into civic_private.consultation_answers values(c.id,me.id,answers,now());
  return civic_private.consultation_json(c,me);
end; $$;

revoke all on function civic_private.participant(),civic_private.proposal_json(civic_private.proposals,civic_private.profiles),
  civic_private.consultation_json(civic_private.consultations,civic_private.profiles),
  civic_private.protect_consultation_department() from public,anon,authenticated;
revoke all on function public.civic_participation(),public.civic_create_proposal(jsonb),
  public.civic_proposal_preference(text,boolean,boolean),public.civic_proposal_comment(text,text,text),
  public.civic_review_proposal(text,text,integer),public.civic_create_consultation(jsonb),
  public.civic_answer_consultation(text,jsonb) from public,anon,authenticated;
grant execute on function public.civic_participation() to anon,authenticated;
grant execute on function public.civic_create_proposal(jsonb),public.civic_proposal_preference(text,boolean,boolean),
  public.civic_proposal_comment(text,text,text),public.civic_review_proposal(text,text,integer),
  public.civic_create_consultation(jsonb),public.civic_answer_consultation(text,jsonb) to authenticated;
commit;
