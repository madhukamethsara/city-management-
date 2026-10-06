begin;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('project-public','project-public',true,10485760,array['image/jpeg','image/png','image/webp','application/pdf']);
create function civic_private.can_upload_project_asset(object_name text) returns boolean
language sql stable security definer set search_path='' as $$
  select split_part(object_name,'/',1)=auth.uid()::text
  and exists(select 1 from civic_private.profiles p where p.id=auth.uid()
    and civic_private.is_officer(p) and p.authority_id=split_part(object_name,'/',2)
    and coalesce(p.data->>'onboardingComplete','false')='true')
  and split_part(object_name,'/',3) ~ '^p-[a-zA-Z0-9-]{1,100}$'
  and array_length(string_to_array(object_name,'/'),1)=4
  and split_part(object_name,'/',4) ~ '^[a-zA-Z0-9][a-zA-Z0-9._-]{0,220}$'
  and object_name ~ '\.(jpg|jpeg|png|webp|pdf)$';
$$;
revoke all on function civic_private.can_upload_project_asset(text) from public,anon,authenticated;
grant execute on function civic_private.can_upload_project_asset(text) to authenticated;
create policy project_asset_upload on storage.objects for insert to authenticated with check (
  bucket_id='project-public' and civic_private.can_upload_project_asset(name)
);
-- Uploaded public assets are immutable through client APIs.
alter function public.civic_save_project(jsonb) rename to civic_save_project_core;
revoke all on function public.civic_save_project_core(jsonb) from public,anon,authenticated;
create function public.civic_save_project(payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare me civic_private.profiles := civic_private.participant(); images jsonb := coalesce(payload->'imageLabels','[]'::jsonb);
  image jsonb; p civic_private.projects;
begin
  if not civic_private.is_officer(me) then raise exception 'Officer required' using errcode='42501'; end if;
  if jsonb_typeof(images) is distinct from 'array' then raise exception 'Invalid images' using errcode='22023'; end if;
  if jsonb_array_length(images)>10 then raise exception 'Too many images' using errcode='22023'; end if;
  for image in select value from jsonb_array_elements(images) loop
    if jsonb_typeof(image) is distinct from 'string' then raise exception 'Invalid image' using errcode='22023'; end if;
    if split_part(image#>>'{}','/',2) is distinct from me.authority_id
      or split_part(image#>>'{}','/',3) is distinct from payload->>'id'
      or image#>>'{}' !~ '\.(jpg|jpeg|png|webp)$'
      or not exists(select 1 from storage.objects where bucket_id='project-public' and name=image#>>'{}') then
      raise exception 'Image unavailable' using errcode='22023'; end if;
  end loop;
  perform public.civic_save_project_core(payload);
  update civic_private.projects set data=data||jsonb_build_object('imageLabels',images)
    where id=payload->>'id' and authority_id=me.authority_id returning * into p;
  return civic_private.project_json(p,me);
end; $$;
revoke all on function public.civic_save_project(jsonb) from public,anon,authenticated;
grant execute on function public.civic_save_project(jsonb) to authenticated;
commit;
