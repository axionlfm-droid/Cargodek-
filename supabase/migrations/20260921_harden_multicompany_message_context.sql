-- CargoDek multi-company messaging hardening.
-- Explicit company context prevents ambiguous sender/recipient company selection.

drop function if exists public.cd_send_message(uuid,text,uuid);

create or replace function public.cd_send_message(
  p_recipient_user_id uuid,
  p_body text,
  p_load_id uuid default null,
  p_sender_company_id uuid default null,
  p_recipient_company_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_user uuid := auth.uid();
  v_message_id uuid;
  v_sender_company_id uuid := p_sender_company_id;
  v_recipient_company_id uuid := p_recipient_company_id;
  v_sender_company_count integer;
  v_recipient_company_count integer;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if p_recipient_user_id is null then raise exception 'Message recipient is required'; end if;
  if p_recipient_user_id = v_user then raise exception 'You cannot message yourself'; end if;
  if nullif(trim(p_body), '') is null then raise exception 'Message cannot be empty'; end if;

  if v_sender_company_id is null then
    select count(*) into v_sender_company_count
    from public.company_members cm
    where cm.user_id = v_user and cm.status = 'active';

    if v_sender_company_count = 0 then
      raise exception 'You must belong to an active company';
    elsif v_sender_company_count > 1 then
      raise exception 'Sender company context is required for multi-company users';
    end if;

    select cm.company_id into v_sender_company_id
    from public.company_members cm
    where cm.user_id = v_user and cm.status = 'active'
    limit 1;
  end if;

  if not exists (
    select 1 from public.company_members cm
    where cm.company_id = v_sender_company_id
      and cm.user_id = v_user
      and cm.status = 'active'
  ) then
    raise exception 'You are not an active member of the selected sender company';
  end if;

  if v_recipient_company_id is null then
    select count(*) into v_recipient_company_count
    from public.company_members cm
    where cm.user_id = p_recipient_user_id and cm.status = 'active';

    if v_recipient_company_count = 0 then
      raise exception 'Recipient does not belong to an active company';
    elsif v_recipient_company_count > 1 then
      raise exception 'Recipient company context is required for multi-company users';
    end if;

    select cm.company_id into v_recipient_company_id
    from public.company_members cm
    where cm.user_id = p_recipient_user_id and cm.status = 'active'
    limit 1;
  end if;

  if not exists (
    select 1 from public.company_members cm
    where cm.company_id = v_recipient_company_id
      and cm.user_id = p_recipient_user_id
      and cm.status = 'active'
  ) then
    raise exception 'Recipient is not an active member of the selected company';
  end if;

  if p_load_id is not null then
    if not exists (
      select 1
      from public.loads l
      join public.connection_requests cr on cr.load_id = l.id
      where l.id = p_load_id
        and (
          (l.company_id = v_sender_company_id and cr.transporter_company_id = v_recipient_company_id)
          or
          (l.company_id = v_recipient_company_id and cr.transporter_company_id = v_sender_company_id)
        )
    ) then
      raise exception 'The selected load is not associated with these companies';
    end if;
  end if;

  insert into public.messages(
    sender_user_id,sender_company_id,
    recipient_user_id,recipient_company_id,
    load_id,body
  )
  values(
    v_user,v_sender_company_id,
    p_recipient_user_id,v_recipient_company_id,
    p_load_id,trim(p_body)
  )
  returning id into v_message_id;

  return v_message_id;
end;
$function$;

revoke execute on function public.cd_send_message(uuid,text,uuid,uuid,uuid) from public, anon;
grant execute on function public.cd_send_message(uuid,text,uuid,uuid,uuid) to authenticated;
