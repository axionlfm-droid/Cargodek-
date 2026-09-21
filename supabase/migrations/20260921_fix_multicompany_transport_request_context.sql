-- CargoDek multi-company transport request hardening
-- Derive the transporter company from the selected truck instead of
-- arbitrarily selecting the user's first active transporter company.

create or replace function public.cd_send_connection_request(
  p_load_id uuid,
  p_truck_id uuid default null,
  p_message text default null
)
returns public.connection_requests
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_user_id uuid := auth.uid();
  v_company_id uuid;
  v_load public.loads%rowtype;
  v_request public.connection_requests%rowtype;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  select * into v_load
  from public.loads
  where id = p_load_id
  for update;

  if not found then
    raise exception 'Load not found';
  end if;

  if v_load.status <> 'open'::public.load_status then
    raise exception 'Only open loads can receive transport requests';
  end if;

  if p_truck_id is null then
    raise exception 'A truck is required for a transport request';
  end if;

  select tt.company_id
    into v_company_id
  from public.transporter_trucks tt
  join public.company_members cm
    on cm.company_id = tt.company_id
   and cm.user_id = v_user_id
   and cm.status = 'active'
  join public.company_roles cr
    on cr.company_id = tt.company_id
   and cr.role = 'transporter'::public.business_role
   and cr.active = true
  where tt.id = p_truck_id
    and tt.owner_user_id = v_user_id
    and tt.active = true
  limit 1;

  if v_company_id is null then
    raise exception 'Selected truck is invalid, inactive, or not assigned to you';
  end if;

  if v_load.company_id = v_company_id then
    raise exception 'A company cannot request its own load';
  end if;

  insert into public.connection_requests(
    load_id, transporter_company_id, transporter_user_id,
    truck_id, message, status
  )
  values(
    p_load_id, v_company_id, v_user_id,
    p_truck_id, nullif(trim(p_message), ''),
    'pending'::public.request_status
  )
  on conflict(load_id,transporter_company_id)
  do update set
    transporter_user_id=excluded.transporter_user_id,
    truck_id=excluded.truck_id,
    message=excluded.message,
    status='pending'::public.request_status,
    rejected_at=null,
    updated_at=now()
  returning * into v_request;

  return v_request;
end;
$function$;

revoke execute on function public.cd_send_connection_request(uuid,uuid,text) from public, anon;
grant execute on function public.cd_send_connection_request(uuid,uuid,text) to authenticated;
