-- CargoDek social marketplace + reusable company asset verification
create table if not exists public.cd_company_assets (
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null references public.companies(id) on delete cascade,
 owner_user_id uuid not null references auth.users(id) on delete restrict,
 asset_type text not null check (asset_type in ('truck','trailer','truck_trailer_combination','equipment','recovery_vehicle','other')),
 subtype text,
 registration_number text,
 make_model text,
 year integer,
 capacity text,
 condition text,
 description text,
 location text,
 country text,
 active boolean not null default true,
 verification_status public.verification_status not null default 'pending',
 verified_at timestamptz,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create table if not exists public.cd_asset_documents (
 id uuid primary key default gen_random_uuid(),
 asset_id uuid not null references public.cd_company_assets(id) on delete cascade,
 company_id uuid not null references public.companies(id) on delete cascade,
 uploaded_by uuid not null references auth.users(id) on delete restrict,
 document_type text not null,
 storage_path text not null,
 status public.verification_status not null default 'pending',
 reviewer_notes text,
 submitted_at timestamptz not null default now(),
 reviewed_at timestamptz
);
create table if not exists public.cd_social_posts (
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null references public.companies(id) on delete cascade,
 author_user_id uuid not null references auth.users(id) on delete restrict,
 body text not null check (length(trim(body)) between 1 and 5000),
 media_url text,
 post_type text not null default 'business' check (post_type in ('business','announcement','opportunity','article','image','video')),
 repost_of_id uuid references public.cd_social_posts(id) on delete set null,
 is_promoted boolean not null default false,
 promotion_status text not null default 'none' check (promotion_status in ('none','pending','active','paused','completed')),
 promotion_start timestamptz,
 promotion_end timestamptz,
 promotion_budget numeric check (promotion_budget is null or promotion_budget >= 0),
 status text not null default 'published' check (status in ('draft','published','hidden','removed')),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create table if not exists public.cd_social_comments (
 id uuid primary key default gen_random_uuid(),
 post_id uuid not null references public.cd_social_posts(id) on delete cascade,
 company_id uuid not null references public.companies(id) on delete cascade,
 author_user_id uuid not null references auth.users(id) on delete restrict,
 body text not null check (length(trim(body)) between 1 and 2000),
 created_at timestamptz not null default now()
);
create table if not exists public.cd_social_likes (
 post_id uuid not null references public.cd_social_posts(id) on delete cascade,
 company_id uuid not null references public.companies(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 created_at timestamptz not null default now(),
 primary key(post_id,user_id)
);
create table if not exists public.cd_social_reposts (
 post_id uuid not null references public.cd_social_posts(id) on delete cascade,
 company_id uuid not null references public.companies(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 created_at timestamptz not null default now(),
 primary key(post_id,user_id)
);
alter table public.cd_company_assets enable row level security;
alter table public.cd_asset_documents enable row level security;
alter table public.cd_social_posts enable row level security;
alter table public.cd_social_comments enable row level security;
alter table public.cd_social_likes enable row level security;
alter table public.cd_social_reposts enable row level security;
grant select on public.cd_company_assets, public.cd_asset_documents, public.cd_social_posts, public.cd_social_comments, public.cd_social_likes, public.cd_social_reposts to authenticated;
grant insert,update,delete on public.cd_company_assets, public.cd_asset_documents, public.cd_social_posts, public.cd_social_comments, public.cd_social_likes, public.cd_social_reposts to authenticated;

create index if not exists idx_cd_assets_owner on public.cd_company_assets(owner_user_id);
create index if not exists idx_cd_asset_docs_company on public.cd_asset_documents(company_id);
create index if not exists idx_cd_asset_docs_uploader on public.cd_asset_documents(uploaded_by);
create index if not exists idx_cd_social_posts_company on public.cd_social_posts(company_id);
create index if not exists idx_cd_social_posts_author on public.cd_social_posts(author_user_id);
create index if not exists idx_cd_social_posts_repost on public.cd_social_posts(repost_of_id);
create index if not exists idx_cd_social_comments_company on public.cd_social_comments(company_id);
create index if not exists idx_cd_social_comments_author on public.cd_social_comments(author_user_id);
create index if not exists idx_cd_social_likes_company on public.cd_social_likes(company_id);
create index if not exists idx_cd_social_likes_user on public.cd_social_likes(user_id);
create index if not exists idx_cd_social_reposts_company on public.cd_social_reposts(company_id);
create index if not exists idx_cd_social_reposts_user on public.cd_social_reposts(user_id);
drop policy if exists "assets select own or verified active" on public.cd_company_assets;
create policy "assets select own or verified active" on public.cd_company_assets for select to authenticated
using ((active=true and verification_status='verified') or company_id in (select company_id from public.company_members where user_id=(select auth.uid()) and status='active'));
