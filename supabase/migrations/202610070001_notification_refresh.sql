-- Fetch recipient updates without reloading civic records or local drafts.
create function public.civic_notifications()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  me civic_private.profiles;
begin
  select * into me from civic_private.profiles where id = auth.uid();
  if me.id is null or not me.active then
    raise exception 'Active account required' using errcode = '42501';
  end if;
  return coalesce((select jsonb_agg(
    data || jsonb_build_object('id', id, 'isRead', is_read)
    order by created_at desc, id
  ) from civic_private.notifications where recipient_id = me.id), '[]'::jsonb);
end;
$$;

revoke all on function public.civic_notifications() from public, anon, authenticated;
grant execute on function public.civic_notifications() to authenticated;
