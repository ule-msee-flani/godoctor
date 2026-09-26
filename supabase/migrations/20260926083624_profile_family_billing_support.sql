-- Profile hub: profile photos for everyone, richer patient details, place
-- names for locations, family members + family sessions (listen in on a
-- consultation), billing methods/preferences, and support & feedback.

------------------------------------------------------------------
-- 1. Account-wide fields on public.users
------------------------------------------------------------------
alter table public.users
  add column if not exists avatar_url text,        -- path in the `avatars` bucket
  add column if not exists contact_phone text,     -- reachable number (not the login)
  add column if not exists last_seen_at timestamptz;

-- Doctors already had a public avatar; carry it over.
update public.users u
set avatar_url = dp.avatar_url
from public.doctor_profiles dp
where dp.user_id = u.id and dp.avatar_url is not null and u.avatar_url is null;

-- Keep the doctor directory's copy in sync when a doctor changes photo.
create or replace function public.sync_doctor_avatar() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.role = 'doctor' and new.avatar_url is distinct from old.avatar_url then
    update public.doctor_profiles set avatar_url = new.avatar_url where user_id = new.id;
  end if;
  return new;
end $$;
drop trigger if exists users_sync_doctor_avatar on public.users;
create trigger users_sync_doctor_avatar
  after update of avatar_url on public.users
  for each row execute function public.sync_doctor_avatar();

-- Users may only change their own photo and contact number (never their
-- role, status, email or login phone).
revoke update on public.users from authenticated, anon;
grant update (avatar_url, contact_phone) on public.users to authenticated;

-- "Online" for family sessions: the app pings this about once a minute.
create or replace function public.touch_presence() returns void
language sql security definer set search_path = public as $$
  update public.users set last_seen_at = now() where id = auth.uid();
$$;

------------------------------------------------------------------
-- 2. Patient details
------------------------------------------------------------------
alter table public.patient_profiles
  add column if not exists location_name text,       -- e.g. "Ruiru, Kiambu, Kenya"
  add column if not exists location_details text,    -- landmark / house, for delivery
  add column if not exists blood_group text
    check (blood_group is null or blood_group in ('A+','A-','B+','B-','AB+','AB-','O+','O-')),
  add column if not exists height_cm numeric(5,1) check (height_cm is null or height_cm between 30 and 260),
  add column if not exists weight_kg numeric(5,1) check (weight_kg is null or weight_kg between 1 and 400),
  add column if not exists emergency_contact_name text,
  add column if not exists emergency_contact_phone text;

alter table public.chemist_profiles
  add column if not exists location_name text;

------------------------------------------------------------------
-- 3. Family members (two GoDoctor accounts linked by invitation)
------------------------------------------------------------------
create table if not exists public.family_links (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.users (id) on delete cascade,
  member_id uuid not null references public.users (id) on delete cascade,
  relationship text not null default 'Family' check (length(relationship) between 1 and 40),
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  constraint family_links_not_self check (requester_id <> member_id),
  constraint family_links_unique unique (requester_id, member_id)
);
create index if not exists family_links_member_idx on public.family_links (member_id);

alter table public.family_links enable row level security;
-- Reads and removal by either side; creating and answering go through RPCs.
create policy family_links_read on public.family_links
  for select to authenticated
  using (auth.uid() in (requester_id, member_id));
create policy family_links_delete on public.family_links
  for delete to authenticated
  using (auth.uid() in (requester_id, member_id));

create or replace function public.are_family(a uuid, b uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.family_links
    where status = 'accepted'
      and ((requester_id = a and member_id = b) or (requester_id = b and member_id = a))
  );
$$;

create or replace function public.display_name(p_user uuid) returns text
language sql stable security definer set search_path = public as $$
  select coalesce(
    nullif((select name from public.patient_profiles where user_id = p_user), ''),
    nullif((select name from public.doctor_profiles where user_id = p_user), ''),
    nullif((select business_name from public.chemist_profiles where user_id = p_user), ''),
    'GoDoctor user'
  );
$$;

-- Invite an existing GoDoctor patient by email or phone.
create or replace function public.invite_family_member(p_contact text, p_relationship text)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_contact text := lower(btrim(coalesce(p_contact, '')));
  v_phone text := regexp_replace(v_contact, '[^0-9]', '', 'g');
  v_member uuid;
  v_id uuid;
begin
  if not public.current_role_is('patient') then raise exception 'patients_only'; end if;
  if v_contact = '' then raise exception 'family_member_not_found'; end if;

  -- Kenyan numbers: 07.. / 01.. -> 2547.. / 2541..
  if v_phone ~ '^0[17][0-9]{8}$' then v_phone := '254' || substr(v_phone, 2); end if;

  select id into v_member from public.users
  where role = 'patient'
    and (lower(email) = v_contact
         or (v_phone <> '' and (regexp_replace(coalesce(phone, ''), '[^0-9]', '', 'g') = v_phone
                               or regexp_replace(coalesce(contact_phone, ''), '[^0-9]', '', 'g') = v_phone)))
  limit 1;

  if v_member is null then raise exception 'family_member_not_found'; end if;
  if v_member = auth.uid() then raise exception 'family_member_is_self'; end if;
  if exists (select 1 from public.family_links
             where (requester_id = auth.uid() and member_id = v_member)
                or (requester_id = v_member and member_id = auth.uid())) then
    raise exception 'family_link_exists';
  end if;
  if (select count(*) from public.family_links where requester_id = auth.uid()) >= 20 then
    raise exception 'family_limit_reached';
  end if;

  insert into public.family_links (requester_id, member_id, relationship)
  values (auth.uid(), v_member, left(coalesce(nullif(btrim(p_relationship), ''), 'Family'), 40))
  returning id into v_id;

  perform public.notify(
    v_member, 'family_invite', 'Family invitation',
    public.display_name(auth.uid()) || ' wants to add you as family on GoDoctor.',
    jsonb_build_object('family_link_id', v_id)
  );
  return v_id;
end $$;

create or replace function public.respond_family_invite(p_link_id uuid, p_accept boolean)
returns void language plpgsql security definer set search_path = public as $$
declare v_link record;
begin
  select * into v_link from public.family_links where id = p_link_id for update;
  if v_link.id is null or v_link.member_id <> auth.uid() then raise exception 'not your invitation'; end if;
  if v_link.status <> 'pending' then raise exception 'family_invite_answered'; end if;

  update public.family_links
  set status = case when p_accept then 'accepted' else 'declined' end, responded_at = now()
  where id = p_link_id;

  if p_accept then
    perform public.notify(
      v_link.requester_id, 'family_accepted', 'Family member added',
      public.display_name(auth.uid()) || ' accepted your family invitation.',
      jsonb_build_object('family_link_id', p_link_id)
    );
  end if;
end $$;

-- Everyone linked to me (either direction), with name, photo and presence.
create or replace function public.my_family()
returns table (
  link_id uuid, user_id uuid, name text, avatar_url text, relationship text,
  status text, invited_by_me boolean, online boolean, created_at timestamptz
) language sql stable security definer set search_path = public as $$
  select f.id,
         other.id,
         public.display_name(other.id),
         other.avatar_url,
         f.relationship,
         f.status,
         f.requester_id = auth.uid(),
         coalesce(other.last_seen_at > now() - interval '2 minutes', false),
         f.created_at
  from public.family_links f
  join public.users other
    on other.id = case when f.requester_id = auth.uid() then f.member_id else f.requester_id end
  where auth.uid() in (f.requester_id, f.member_id)
    and not (f.status = 'declined' and f.member_id = auth.uid())
  order by (f.status = 'pending' and f.member_id = auth.uid()) desc, f.created_at desc;
$$;

------------------------------------------------------------------
-- 4. Family sessions: family members listening in on a consultation
------------------------------------------------------------------
create table if not exists public.consultation_participants (
  id uuid primary key default gen_random_uuid(),
  consultation_id uuid not null references public.consultations (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  invited_by uuid not null references public.users (id) on delete cascade,
  status text not null default 'invited' check (status in ('invited', 'joined', 'left', 'declined')),
  invited_at timestamptz not null default now(),
  joined_at timestamptz,
  left_at timestamptz,
  constraint consultation_participants_unique unique (consultation_id, user_id)
);
create index if not exists consultation_participants_user_idx
  on public.consultation_participants (user_id);

alter table public.consultation_participants enable row level security;
create policy consultation_participants_read on public.consultation_participants
  for select to authenticated
  using (
    user_id = auth.uid()
    or exists (select 1 from public.consultations c
               where c.id = consultation_id and auth.uid() in (c.patient_id, c.doctor_id))
  );

do $$ begin
  alter publication supabase_realtime add table public.consultation_participants;
exception when duplicate_object then null; end $$;

create or replace function public.invite_to_consultation(p_consultation_id uuid, p_member_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_c record;
begin
  select * into v_c from public.consultations where id = p_consultation_id;
  if v_c.id is null or v_c.patient_id <> auth.uid() then raise exception 'not your consultation'; end if;
  if v_c.status not in ('scheduled', 'awaiting_payment', 'matched', 'in_progress') then
    raise exception 'consultation_not_active';
  end if;
  if not public.are_family(auth.uid(), p_member_id) then raise exception 'not_family'; end if;
  if (select count(*) from public.consultation_participants
      where consultation_id = p_consultation_id and status in ('invited', 'joined')) >= 3 then
    raise exception 'family_session_full';
  end if;

  insert into public.consultation_participants (consultation_id, user_id, invited_by)
  values (p_consultation_id, p_member_id, auth.uid())
  on conflict (consultation_id, user_id)
  do update set status = 'invited', invited_at = now(), joined_at = null, left_at = null;

  perform public.notify(
    p_member_id, 'family_session_invite', 'Join a family consultation',
    public.display_name(auth.uid()) || ' invited you to listen in on their consultation.',
    jsonb_build_object('consultation_id', p_consultation_id)
  );
end $$;

create or replace function public.respond_consultation_invite(p_consultation_id uuid, p_join boolean)
returns void language plpgsql security definer set search_path = public as $$
declare v_p record; v_c record;
begin
  select * into v_p from public.consultation_participants
  where consultation_id = p_consultation_id and user_id = auth.uid() for update;
  if v_p.id is null then raise exception 'not invited'; end if;
  select * into v_c from public.consultations where id = p_consultation_id;

  if p_join then
    if v_c.status <> 'in_progress' then raise exception 'consultation_not_started'; end if;
    update public.consultation_participants
    set status = 'joined', joined_at = now(), left_at = null where id = v_p.id;
    perform public.notify(
      v_c.patient_id, 'family_joined', 'Family member joined',
      public.display_name(auth.uid()) || ' joined your consultation.',
      jsonb_build_object('consultation_id', p_consultation_id)
    );
  else
    update public.consultation_participants
    set status = case when v_p.status = 'joined' then 'left' else 'declined' end,
        left_at = case when v_p.status = 'joined' then now() else left_at end
    where id = v_p.id;
  end if;
end $$;

-- The patient removes someone they invited.
create or replace function public.remove_consultation_participant(p_consultation_id uuid, p_user_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from public.consultations
                 where id = p_consultation_id and patient_id = auth.uid()) then
    raise exception 'not your consultation';
  end if;
  delete from public.consultation_participants
  where consultation_id = p_consultation_id and user_id = p_user_id;
end $$;

-- Who is in the session (for the patient, the doctor and the participants).
create or replace function public.consultation_people(p_consultation_id uuid)
returns table (user_id uuid, name text, avatar_url text, role text, status text)
language plpgsql stable security definer set search_path = public as $$
declare v_c record;
begin
  select * into v_c from public.consultations where id = p_consultation_id;
  if v_c.id is null then return; end if;
  if auth.uid() is distinct from v_c.patient_id
     and auth.uid() is distinct from v_c.doctor_id
     and not exists (select 1 from public.consultation_participants cp
                     where cp.consultation_id = p_consultation_id and cp.user_id = auth.uid()) then
    raise exception 'not your consultation';
  end if;

  return query
    select v_c.patient_id, public.display_name(v_c.patient_id),
           (select u.avatar_url from public.users u where u.id = v_c.patient_id),
           'patient'::text, 'joined'::text
    union all
    select v_c.doctor_id, public.display_name(v_c.doctor_id),
           (select u.avatar_url from public.users u where u.id = v_c.doctor_id),
           'doctor'::text, 'joined'::text
    where v_c.doctor_id is not null
    union all
    select p.user_id, public.display_name(p.user_id), u.avatar_url, 'family'::text, p.status
    from public.consultation_participants p
    join public.users u on u.id = p.user_id
    where p.consultation_id = p_consultation_id;
end $$;

-- What an invited family member may see about the consultation: who, which
-- specialty and its status -- never symptoms, notes or prescriptions.
create or replace function public.family_session_info(p_consultation_id uuid)
returns table (
  consultation_id uuid, patient_name text, doctor_name text, specialty text,
  status text, started_at timestamptz, my_status text
) language sql stable security definer set search_path = public as $$
  select c.id,
         public.display_name(c.patient_id),
         case when c.doctor_id is null then null else public.display_name(c.doctor_id) end,
         c.specialty_requested,
         c.status::text,
         c.started_at,
         p.status
  from public.consultations c
  join public.consultation_participants p
    on p.consultation_id = c.id and p.user_id = auth.uid()
  where c.id = p_consultation_id;
$$;

------------------------------------------------------------------
-- 5. Billing: saved payment methods and preferences
--    Cards are stored for display only (brand, last 4, expiry). Full card
--    numbers and CVVs never reach this database; charging a card will go
--    through the payment provider's own tokenisation.
------------------------------------------------------------------
create table if not exists public.payment_methods (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references public.users (id) on delete cascade,
  kind text not null check (kind in ('mpesa', 'card')),
  label text check (label is null or length(label) <= 40),
  mpesa_phone text check (mpesa_phone is null or mpesa_phone ~ '^254[17][0-9]{8}$'),
  card_brand text check (card_brand is null or card_brand in ('visa', 'mastercard', 'amex', 'other')),
  card_last4 text check (card_last4 is null or card_last4 ~ '^[0-9]{4}$'),
  card_exp_month int check (card_exp_month is null or card_exp_month between 1 and 12),
  card_exp_year int check (card_exp_year is null or card_exp_year between 2024 and 2100),
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  constraint payment_methods_shape check (
    (kind = 'mpesa' and mpesa_phone is not null and card_last4 is null)
    or (kind = 'card' and card_last4 is not null and card_brand is not null
        and card_exp_month is not null and card_exp_year is not null and mpesa_phone is null)
  )
);
create index if not exists payment_methods_user_idx on public.payment_methods (user_id);

alter table public.payment_methods enable row level security;
create policy payment_methods_owner on public.payment_methods
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- One default per user; the first method added becomes the default.
create or replace function public.payment_methods_single_default() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' and not exists (
    select 1 from public.payment_methods where user_id = new.user_id
  ) then
    new.is_default := true;
  end if;
  if new.is_default then
    update public.payment_methods set is_default = false
    where user_id = new.user_id and id <> new.id and is_default;
  end if;
  return new;
end $$;
drop trigger if exists payment_methods_default on public.payment_methods;
create trigger payment_methods_default
  before insert or update of is_default on public.payment_methods
  for each row execute function public.payment_methods_single_default();

create table if not exists public.user_settings (
  user_id uuid primary key default auth.uid() references public.users (id) on delete cascade,
  pay_with_default boolean not null default true,   -- skip the method picker at checkout
  email_receipts boolean not null default true,
  updated_at timestamptz not null default now()
);
alter table public.user_settings enable row level security;
create policy user_settings_owner on public.user_settings
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

------------------------------------------------------------------
-- 6. Support & feedback
------------------------------------------------------------------
create table if not exists public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references public.users (id) on delete cascade,
  kind text not null check (kind in ('support', 'complaint', 'feedback', 'account_deletion')),
  subject text not null check (length(subject) between 1 and 120),
  status text not null default 'open' check (status in ('open', 'answered', 'closed')),
  related_consultation_id uuid references public.consultations (id) on delete set null,
  related_order_id uuid references public.orders (id) on delete set null,
  created_at timestamptz not null default now(),
  last_message_at timestamptz not null default now()
);
create index if not exists support_tickets_user_idx on public.support_tickets (user_id);

create table if not exists public.support_messages (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.support_tickets (id) on delete cascade,
  sender_id uuid not null default auth.uid() references public.users (id) on delete cascade,
  from_staff boolean not null default false,
  body text not null check (length(body) between 1 and 4000),
  created_at timestamptz not null default now()
);
create index if not exists support_messages_ticket_idx on public.support_messages (ticket_id);

alter table public.support_tickets enable row level security;
alter table public.support_messages enable row level security;

create policy support_tickets_owner_read on public.support_tickets
  for select to authenticated using (user_id = auth.uid() or public.current_role_is('admin'));
create policy support_tickets_owner_insert on public.support_tickets
  for insert to authenticated with check (user_id = auth.uid() and status = 'open');
create policy support_tickets_admin_update on public.support_tickets
  for update to authenticated using (public.current_role_is('admin'));
-- Owners may close their own ticket.
create policy support_tickets_owner_close on public.support_tickets
  for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid() and status = 'closed');

create policy support_messages_read on public.support_messages
  for select to authenticated using (
    public.current_role_is('admin')
    or exists (select 1 from public.support_tickets t
               where t.id = ticket_id and t.user_id = auth.uid())
  );
create policy support_messages_insert on public.support_messages
  for insert to authenticated with check (
    sender_id = auth.uid() and (
      (from_staff and public.current_role_is('admin'))
      or (not from_staff and exists (select 1 from public.support_tickets t
                                     where t.id = ticket_id and t.user_id = auth.uid()
                                       and t.status <> 'closed'))
    )
  );

-- New message: bump the ticket; staff replies mark it answered and notify.
create or replace function public.support_message_after_insert() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_ticket record;
begin
  select * into v_ticket from public.support_tickets where id = new.ticket_id;
  update public.support_tickets
  set last_message_at = new.created_at,
      status = case when new.from_staff then 'answered' else 'open' end
  where id = new.ticket_id;
  if new.from_staff then
    perform public.notify(
      v_ticket.user_id, 'support_reply', 'GoDoctor support replied',
      left(new.body, 140),
      jsonb_build_object('ticket_id', new.ticket_id)
    );
  end if;
  return new;
end $$;
drop trigger if exists support_messages_after_insert on public.support_messages;
create trigger support_messages_after_insert
  after insert on public.support_messages
  for each row execute function public.support_message_after_insert();

do $$ begin
  alter publication supabase_realtime add table public.support_messages;
exception when duplicate_object then null; end $$;

create table if not exists public.app_ratings (
  user_id uuid primary key default auth.uid() references public.users (id) on delete cascade,
  stars int not null check (stars between 1 and 5),
  comment text check (comment is null or length(comment) <= 1000),
  updated_at timestamptz not null default now()
);
alter table public.app_ratings enable row level security;
create policy app_ratings_owner on public.app_ratings
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy app_ratings_admin_read on public.app_ratings
  for select to authenticated using (public.current_role_is('admin'));

------------------------------------------------------------------
-- 7. Function privileges: signed-in users only
------------------------------------------------------------------
revoke all on function
  public.touch_presence(),
  public.are_family(uuid, uuid),
  public.display_name(uuid),
  public.invite_family_member(text, text),
  public.respond_family_invite(uuid, boolean),
  public.my_family(),
  public.invite_to_consultation(uuid, uuid),
  public.respond_consultation_invite(uuid, boolean),
  public.remove_consultation_participant(uuid, uuid),
  public.consultation_people(uuid),
  public.family_session_info(uuid),
  public.sync_doctor_avatar(),
  public.payment_methods_single_default(),
  public.support_message_after_insert()
from public, anon;
grant execute on function
  public.touch_presence(),
  public.invite_family_member(text, text),
  public.respond_family_invite(uuid, boolean),
  public.my_family(),
  public.invite_to_consultation(uuid, uuid),
  public.respond_consultation_invite(uuid, boolean),
  public.remove_consultation_participant(uuid, uuid),
  public.consultation_people(uuid),
  public.family_session_info(uuid)
to authenticated;
