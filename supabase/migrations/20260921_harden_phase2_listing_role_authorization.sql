-- CargoDek Phase 2 listing authorization hardening
-- Require the active business role that owns each listing type.
-- Prevent non-admin creators from inserting already-public/verified records.

drop policy if exists "cd_service_owner_insert" on public.cd_service_listings;
create policy "cd_service_owner_insert"
on public.cd_service_listings
for insert
to authenticated
with check (
  created_by = (select auth.uid())
  and cd_has_role(company_id, service_type)
  and status = 'pending'
);

drop policy if exists "cd_fuel_station_insert" on public.cd_fuel_stations;
create policy "cd_fuel_station_insert"
on public.cd_fuel_stations
for insert
to authenticated
with check (
  created_by = (select auth.uid())
  and cd_has_role(company_id, 'retail_fuel_supplier'::public.business_role)
  and status = 'pending'
  and verified = false
);

drop policy if exists "cd_truck_stop_insert" on public.cd_truck_stops;
create policy "cd_truck_stop_insert"
on public.cd_truck_stops
for insert
to authenticated
with check (
  created_by = (select auth.uid())
  and cd_has_role(company_id, 'truck_stop'::public.business_role)
  and status = 'pending'
);
