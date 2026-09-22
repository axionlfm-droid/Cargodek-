-- CargoDek service coverage metadata
alter table public.cd_service_listings
  add column if not exists service_area text,
  add column if not exists coverage_radius_km numeric(8,2);

update public.cd_service_listings
set service_area=coalesce(service_area, city || ' area'),
    coverage_radius_km=coalesce(coverage_radius_km,100)
where status='active';

update public.cd_service_listings
set service_area='Johannesburg and Gauteng freight corridors', coverage_radius_km=100
where id='15f0c8c1-6416-4692-897a-ab11cad899a5';

update public.cd_service_listings
set service_area='Durban and KwaZulu-Natal freight corridors', coverage_radius_km=100
where id='4605355b-6a47-477c-b407-e6085089e954';

update public.cd_service_listings
set service_area='Gaborone and Botswana', coverage_radius_km=150
where id in ('b1efac6e-7d6b-4d67-94d0-7fb98e5c5e18','ef79eed4-316e-4eb8-8ac4-efe26de13d61');

update public.cd_service_listings
set service_area='Harare and Zimbabwe', coverage_radius_km=150
where id in ('7f17cd92-6892-46ee-99d9-966e2e29726b','a3f25a41-136f-4b58-87bd-facd3d276ae1');
