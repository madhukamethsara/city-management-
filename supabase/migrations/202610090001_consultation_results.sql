begin;

-- Only onboarded, active officers of the owning authority may see aggregates.
-- Written answers and respondent identifiers never leave this function.
create function public.civic_consultation_results(consultation_id text) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare
  me civic_private.profiles := civic_private.participant();
  c civic_private.consultations;
  q jsonb;
  results jsonb := '[]'::jsonb;
  option_counts jsonb;
  answered bigint;
begin
  if not civic_private.is_officer(me) then
    raise exception 'Officer required' using errcode='42501';
  end if;
  select * into c from civic_private.consultations where id=consultation_id;
  if c.id is null or c.authority_id<>me.authority_id then
    raise exception 'Unavailable' using errcode='42501';
  end if;
  for q in select value from jsonb_array_elements(c.data->'questions') loop
    select count(*) into answered from civic_private.consultation_answers a
      where a.consultation_id=c.id and a.answers ? (q->>'id');
    option_counts := '[]'::jsonb;
    if (q->>'allowsLongText')::boolean=false then
      select coalesce(jsonb_agg(jsonb_build_object('label',o.value,'count',
        (select count(*) from civic_private.consultation_answers a
          where a.consultation_id=c.id and a.answers->>(q->>'id')=o.value))
        order by o.ordinality),'[]'::jsonb)
      into option_counts
      from jsonb_array_elements_text(q->'options') with ordinality o(value,ordinality);
    end if;
    results := results || jsonb_build_array(jsonb_build_object(
      'id',q->>'id','question',q->>'question',
      'allowsLongText',(q->>'allowsLongText')::boolean,
      'responseCount',answered,'options',option_counts));
  end loop;
  return jsonb_build_object('consultationId',c.id,
    'totalResponses',(select count(*) from civic_private.consultation_answers a where a.consultation_id=c.id),
    'questions',results);
end; $$;

revoke all on function public.civic_consultation_results(text) from public,anon,authenticated;
grant execute on function public.civic_consultation_results(text) to authenticated;
commit;
