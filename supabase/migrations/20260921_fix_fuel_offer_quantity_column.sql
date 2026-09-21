-- Fix fuel offer acceptance to use the actual fuel_enquiries.quantity column.
create or replace function public.cd_accept_fuel_offer(p_offer_id uuid)
returns uuid
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_offer public.fuel_offers%rowtype;
  v_enquiry public.fuel_enquiries%rowtype;
  v_listing public.fuel_listings%rowtype;
begin
  if (select auth.uid()) is null then raise exception 'Authentication required'; end if;
  select * into v_offer from public.fuel_offers where id=p_offer_id for update;
  if not found then raise exception 'Fuel offer does not exist'; end if;
  select * into v_enquiry from public.fuel_enquiries where id=v_offer.enquiry_id for update;
  if not found then raise exception 'Fuel enquiry does not exist'; end if;
  select * into v_listing from public.fuel_listings where id=v_enquiry.listing_id for update;
  if not found then raise exception 'Fuel listing does not exist'; end if;
  if not public.cd_is_member(v_enquiry.buyer_company_id) then raise exception 'Buyer company membership required'; end if;
  if not public.cd_has_role(v_enquiry.buyer_company_id,'fuel_buyer'::public.business_role) then raise exception 'Fuel buyer role is not active'; end if;
  if not exists(select 1 from public.fuel_buyer_kyc k where k.company_id=v_enquiry.buyer_company_id and k.status='verified'::public.kyc_status) then raise exception 'Verified fuel buyer KYC is required before accepting a fuel offer'; end if;
  if v_enquiry.status<>'pending' then raise exception 'Fuel enquiry is not pending'; end if;
  if v_offer.status<>'pending' then raise exception 'Fuel offer is not pending'; end if;
  if v_offer.quantity<=0 or v_offer.quantity>v_enquiry.quantity then raise exception 'Offer quantity is invalid'; end if;
  if v_offer.quantity>v_listing.quantity then raise exception 'Insufficient fuel quantity remains on listing'; end if;
  update public.fuel_offers set status='accepted',updated_at=now() where id=v_offer.id;
  update public.fuel_offers set status='rejected',updated_at=now() where enquiry_id=v_enquiry.id and id<>v_offer.id and status='pending';
  update public.fuel_enquiries set status='accepted',updated_at=now() where id=v_enquiry.id;
  perform set_config('cargodek.controlled_fuel_update','true',true);
  update public.fuel_listings set quantity=quantity-v_offer.quantity,status=case when quantity-v_offer.quantity<=0 then 'reserved' else status end,updated_at=now() where id=v_listing.id;
  perform set_config('cargodek.controlled_fuel_update','false',true);
  return v_offer.id;
end;
$function$;