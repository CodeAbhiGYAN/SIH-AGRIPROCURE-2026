
-- ============================================================
-- SECTION 1: smart_procurement_supabase_initial.sql
-- ============================================================
-- Smart Procurement - Initial Supabase/PostgreSQL schema
-- Demo scope: 12 permanent farmers, 4 centres, initially unprocessed.
-- Demo allocation rule: every farmer who becomes eligible is assigned Centre A.
-- Do not store passwords or Supabase secret/service-role keys in this project.

begin;

-- =========================
-- ENUM TYPES
-- =========================

drop type if exists public.farmer_workflow_state cascade;
create type public.farmer_workflow_state as enum (
  'unprocessed',
  'verified',
  'assigned',
  'travelling',
  'arrived',
  'waiting',
  'processing',
  'completed',
  'cancelled',
  'rescheduled'
);

drop type if exists public.centre_status cascade;
create type public.centre_status as enum (
  'normal',
  'busy',
  'highLoad',
  'delayed',
  'degraded',
  'unavailable'
);

drop type if exists public.verification_status cascade;
create type public.verification_status as enum (
  'pending',
  'verified',
  'actionRequired',
  'underReview'
);

-- =========================
-- UPDATED_AT HELPER
-- =========================

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- =========================
-- CENTRES
-- =========================

create table public.centres (
  centre_id text primary key,
  name text not null unique,
  address text not null,
  lat double precision not null,
  lng double precision not null,
  capacity numeric(10,2) not null default 100,
  current_load numeric(10,2) not null default 0,
  processing_rate numeric(10,2) not null default 0,
  queue_count integer not null default 0,
  active_staff integer not null default 0,
  staff_total integer not null default 0,
  weighbridges_working integer not null default 0,
  weighbridges_total integer not null default 0,
  status public.centre_status not null default 'normal',
  quality_testing_ok boolean not null default true,
  storage_ok boolean not null default true,
  transport_ok boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (capacity >= 0),
  check (current_load >= 0),
  check (queue_count >= 0),
  check (active_staff >= 0 and active_staff <= staff_total),
  check (weighbridges_working >= 0 and weighbridges_working <= weighbridges_total)
);

create trigger centres_updated_at
before update on public.centres
for each row execute function public.set_updated_at();

insert into public.centres (
  centre_id, name, address, lat, lng, capacity, current_load,
  processing_rate, queue_count, active_staff, staff_total,
  weighbridges_working, weighbridges_total, status,
  quality_testing_ok, storage_ok, transport_ok
) values
  ('A', 'Centre A', 'Main Procurement Yard', 28.61, 77.10, 100, 0, 8, 0, 4, 6, 1, 2, 'highLoad', true, true, true),
  ('B', 'Centre B', 'North Village Procurement Yard', 28.64, 77.13, 100, 0, 12, 0, 6, 7, 2, 2, 'normal', true, true, true),
  ('C', 'Centre C', 'Canal Road Procurement Yard', 28.58, 77.16, 100, 0, 10, 0, 5, 6, 2, 2, 'busy', true, true, true),
  ('D', 'Centre D', 'East Block Procurement Yard', 28.62, 77.20, 100, 0, 11, 0, 5, 6, 2, 2, 'normal', true, true, true);

-- =========================
-- FARMERS: ONLY THE 12 DEMO FARMERS
-- =========================

create table public.farmers (
  farmer_id text primary key,
  name text not null,
  mobile text not null,
  village text not null,
  crop text not null,
  expected_quantity numeric(10,2) not null,
  cultivated_area numeric(10,2) not null,
  priority_score integer not null default 50,
  language text not null default 'English',
  lat double precision not null,
  lng double precision not null,
  workflow_state public.farmer_workflow_state not null default 'unprocessed',
  has_left_home boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (expected_quantity >= 0),
  check (cultivated_area >= 0),
  check (priority_score between 0 and 100),
  check (language in ('English', 'Hindi'))
);

create trigger farmers_updated_at
before update on public.farmers
for each row execute function public.set_updated_at();

insert into public.farmers (
  farmer_id, name, mobile, village, crop, expected_quantity,
  cultivated_area, priority_score, language, lat, lng
) values
  ('F001', 'Raj Kumar',     '98XXXX1001', 'Najafgarh',  'Wheat',   25, 1.2, 55, 'English', 28.570, 77.080),
  ('F002', 'Suresh Yadav',  '98XXXX1002', 'Dhansa',     'Paddy',   30, 1.6, 62, 'English', 28.578, 77.092),
  ('F003', 'Sunita Devi',   '98XXXX1003', 'Kair',       'Mustard', 35, 2.0, 69, 'English', 28.586, 77.104),
  ('F004', 'Mohan Singh',   '98XXXX1004', 'Roshanpura', 'Wheat',   40, 2.4, 76, 'English', 28.594, 77.116),
  ('F005', 'Geeta Sharma',  '98XXXX1005', 'Najafgarh',  'Paddy',   45, 2.8, 83, 'English', 28.602, 77.128),
  ('F006', 'Ramesh Verma',  '98XXXX1006', 'Dhansa',     'Mustard', 50, 1.2, 90, 'English', 28.610, 77.140),
  ('F007', 'Kavita Rani',   '98XXXX1007', 'Kair',       'Wheat',   55, 1.6, 52, 'English', 28.618, 77.152),
  ('F008', 'Anil Chauhan',  '98XXXX1008', 'Roshanpura', 'Paddy',   25, 2.0, 59, 'English', 28.626, 77.164),
  ('F009', 'Pooja Kumari',  '98XXXX1009', 'Najafgarh',  'Mustard', 30, 2.4, 66, 'English', 28.634, 77.176),
  ('F010', 'Mahender Pal',  '98XXXX1010', 'Dhansa',     'Wheat',   35, 2.8, 73, 'English', 28.642, 77.080),
  ('F011', 'Rekha Devi',    '98XXXX1011', 'Kair',       'Paddy',   40, 1.2, 80, 'English', 28.650, 77.092),
  ('F012', 'Vijay Kumar',   '98XXXX1012', 'Roshanpura', 'Mustard', 45, 1.6, 87, 'English', 28.658, 77.104);

-- =========================
-- VERIFICATION
-- =========================

create table public.verification (
  farmer_id text primary key references public.farmers(farmer_id) on delete cascade,
  identity_status public.verification_status not null default 'pending',
  land_status public.verification_status not null default 'pending',
  bank_status public.verification_status not null default 'pending',
  crop_status public.verification_status not null default 'pending',
  eligibility_status public.verification_status not null default 'pending',
  bank_name text,
  bank_account text,
  bank_ifsc text,
  selected_crop text,
  crop_quantity numeric(10,2),
  crop_season text,
  updated_at timestamptz not null default now()
);

create trigger verification_updated_at
before update on public.verification
for each row execute function public.set_updated_at();

insert into public.verification (farmer_id)
select farmer_id from public.farmers;

-- =========================
-- APPOINTMENTS
-- =========================

create table public.appointments (
  appointment_id bigint generated by default as identity primary key,
  farmer_id text not null references public.farmers(farmer_id) on delete cascade,
  centre_id text references public.centres(centre_id),
  procurement_date date,
  window_start time,
  window_end time,
  queue_token integer,
  assigned_at timestamptz,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (farmer_id),
  check (status in ('pending', 'assigned', 'rescheduled', 'cancelled', 'completed')),
  check (queue_token is null or queue_token > 0)
);

create trigger appointments_updated_at
before update on public.appointments
for each row execute function public.set_updated_at();

-- =========================
-- FARMER STATUS
-- =========================

create table public.farmer_status (
  farmer_id text primary key references public.farmers(farmer_id) on delete cascade,
  location_status text not null default 'HOME',
  attendance_status boolean not null default false,
  attendance_at timestamptz,
  updated_at timestamptz not null default now(),
  check (location_status in ('HOME', 'ON_WAY', 'AT_CENTRE'))
);

create trigger farmer_status_updated_at
before update on public.farmer_status
for each row execute function public.set_updated_at();

insert into public.farmer_status (farmer_id)
select farmer_id from public.farmers;

-- =========================
-- QUEUE STATE BY CENTRE
-- =========================

create table public.queue_status (
  centre_id text primary key references public.centres(centre_id) on delete cascade,
  service_date date not null default current_date,
  current_serving integer not null default 0,
  total_waiting integer not null default 0,
  updated_at timestamptz not null default now(),
  check (current_serving >= 0),
  check (total_waiting >= 0)
);

create trigger queue_status_updated_at
before update on public.queue_status
for each row execute function public.set_updated_at();

insert into public.queue_status (centre_id)
select centre_id from public.centres;

-- =========================
-- PROCUREMENT
-- =========================

create table public.procurement (
  farmer_id text primary key references public.farmers(farmer_id) on delete cascade,
  quality_check_status text not null default 'pending',
  procurement_status text not null default 'not_started',
  accepted_quantity numeric(10,2),
  quality_grade text,
  completed_at timestamptz,
  updated_at timestamptz not null default now(),
  check (quality_check_status in ('pending', 'in_progress', 'completed', 'failed')),
  check (procurement_status in ('not_started', 'in_progress', 'completed', 'cancelled')),
  check (accepted_quantity is null or accepted_quantity >= 0)
);

create trigger procurement_updated_at
before update on public.procurement
for each row execute function public.set_updated_at();

insert into public.procurement (farmer_id)
select farmer_id from public.farmers;

-- =========================
-- PAYMENTS
-- =========================

create table public.payments (
  farmer_id text primary key references public.farmers(farmer_id) on delete cascade,
  payment_status text not null default 'pending',
  amount numeric(12,2),
  payment_date timestamptz,
  reference text,
  updated_at timestamptz not null default now(),
  check (payment_status in ('pending', 'processing', 'completed', 'failed')),
  check (amount is null or amount >= 0)
);

create trigger payments_updated_at
before update on public.payments
for each row execute function public.set_updated_at();

insert into public.payments (farmer_id)
select farmer_id from public.farmers;

-- =========================
-- NOTIFICATIONS
-- =========================

create table public.notifications (
  notification_id bigint generated by default as identity primary key,
  farmer_id text not null references public.farmers(farmer_id) on delete cascade,
  title text not null,
  message text not null,
  details text not null default '',
  kind text not null default 'general',
  is_read boolean not null default false,
  created_at timestamptz not null default now(),
  read_at timestamptz,
  check (kind in ('otp', 'appointment', 'reschedule', 'general', 'procurement_status'))
);

create index notifications_farmer_unread_idx
on public.notifications (farmer_id, is_read, created_at desc);

-- =========================
-- ACTIVITY / AUDIT HISTORY
-- =========================

create table public.activity_history (
  activity_id bigint generated by default as identity primary key,
  farmer_id text references public.farmers(farmer_id) on delete cascade,
  action text not null,
  performed_by text not null,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index activity_history_farmer_idx
on public.activity_history (farmer_id, created_at desc);

-- =========================
-- GOVERNMENT USERS / ROLES
-- =========================

create table public.government_users (
  official_id text primary key,
  name text not null,
  centre_id text not null default '*',
  role text not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  check (role in ('centre_manager', 'district_officer', 'admin'))
);

insert into public.government_users (official_id, name, centre_id, role) values
  ('OFF001', 'Centre Manager', 'A', 'centre_manager'),
  ('OFF002', 'Centre Manager 2', 'A', 'centre_manager'),
  ('DIST001', 'District Officer', '*', 'district_officer'),
  ('ADMIN001', 'System Admin', '*', 'admin');

-- =========================
-- DEMO ASSIGNMENT FUNCTION
-- =========================
-- When eligibility becomes verified, assign Centre A for the demo.

create or replace function public.assign_demo_centre_a(p_farmer_id text)
returns public.appointments
language plpgsql
as $$
declare
  v_row public.appointments;
  v_next_token integer;
begin
  if not exists (
    select 1 from public.verification v
    where v.farmer_id = p_farmer_id
      and v.identity_status = 'verified'
      and v.land_status = 'verified'
      and v.bank_status = 'verified'
      and v.crop_status = 'verified'
      and v.eligibility_status = 'verified'
  ) then
    raise exception 'Farmer % is not fully verified/eligible', p_farmer_id;
  end if;

  select coalesce(max(queue_token), 0) + 1
    into v_next_token
  from public.appointments
  where centre_id = 'A'
    and status in ('assigned', 'rescheduled');

  insert into public.appointments (
    farmer_id, centre_id, procurement_date,
    window_start, window_end, queue_token,
    assigned_at, status
  ) values (
    p_farmer_id,
    'A',
    current_date,
    '11:00:00',
    '11:30:00',
    v_next_token,
    now(),
    'assigned'
  )
  on conflict (farmer_id) do update set
    centre_id = excluded.centre_id,
    procurement_date = excluded.procurement_date,
    window_start = excluded.window_start,
    window_end = excluded.window_end,
    queue_token = excluded.queue_token,
    assigned_at = excluded.assigned_at,
    status = excluded.status;

  update public.farmers
  set workflow_state = 'assigned'
  where farmer_id = p_farmer_id;

  select * into v_row
  from public.appointments
  where farmer_id = p_farmer_id;

  insert into public.activity_history (farmer_id, action, performed_by, details)
  values (
    p_farmer_id,
    'centre_assigned',
    'system',
    jsonb_build_object('centre_id', 'A', 'demo_mode', true)
  );

  return v_row;
end;
$$;

-- =========================
-- WORKFLOW VALIDATION
-- =========================

create or replace function public.enforce_procurement_workflow()
returns trigger
language plpgsql
as $$
declare
  v_verified boolean;
  v_attended boolean;
begin
  select (
    identity_status = 'verified'
    and land_status = 'verified'
    and bank_status = 'verified'
    and crop_status = 'verified'
    and eligibility_status = 'verified'
  ) into v_verified
  from public.verification
  where farmer_id = new.farmer_id;

  select attendance_status into v_attended
  from public.farmer_status
  where farmer_id = new.farmer_id;

  if new.procurement_status <> 'not_started' and coalesce(v_verified, false) = false then
    raise exception 'Procurement cannot start before verification/eligibility for %', new.farmer_id;
  end if;

  if new.procurement_status <> 'not_started' and coalesce(v_attended, false) = false then
    raise exception 'Procurement cannot start before attendance for %', new.farmer_id;
  end if;

  return new;
end;
$$;

create trigger procurement_workflow_guard
before insert or update on public.procurement
for each row execute function public.enforce_procurement_workflow();

create or replace function public.enforce_payment_workflow()
returns trigger
language plpgsql
as $$
declare
  v_procurement_completed boolean;
begin
  select procurement_status = 'completed'
    into v_procurement_completed
  from public.procurement
  where farmer_id = new.farmer_id;

  if new.payment_status <> 'pending' and coalesce(v_procurement_completed, false) = false then
    raise exception 'Payment cannot be processed before procurement completes for %', new.farmer_id;
  end if;

  return new;
end;
$$;

create trigger payment_workflow_guard
before insert or update on public.payments
for each row execute function public.enforce_payment_workflow();

-- Attendance guard: only eligible + assigned farmers may be marked attended.
create or replace function public.enforce_attendance_workflow()
returns trigger
language plpgsql
as $$
declare
  v_verified boolean;
  v_assigned boolean;
begin
  if new.attendance_status = true then
    select (
      identity_status = 'verified'
      and land_status = 'verified'
      and bank_status = 'verified'
      and crop_status = 'verified'
      and eligibility_status = 'verified'
    ) into v_verified
    from public.verification
    where farmer_id = new.farmer_id;

    select exists(
      select 1 from public.appointments a
      where a.farmer_id = new.farmer_id
        and a.centre_id is not null
        and a.status in ('assigned', 'rescheduled')
    ) into v_assigned;

    if coalesce(v_verified, false) = false or coalesce(v_assigned, false) = false then
      raise exception 'Attendance cannot be marked before eligible centre appointment for %', new.farmer_id;
    end if;

    if new.attendance_at is null then
      new.attendance_at = now();
    end if;
  end if;

  return new;
end;
$$;

create trigger attendance_workflow_guard
before insert or update on public.farmer_status
for each row execute function public.enforce_attendance_workflow();

-- =========================
-- AUTOMATIC FARMER STATE / NOTIFICATION HELPERS
-- =========================

-- Procurement changes create a generic notification only.
create or replace function public.notify_procurement_status_change()
returns trigger
language plpgsql
as $$
begin
  if (tg_op = 'INSERT') or
     old.procurement_status is distinct from new.procurement_status or
     old.quality_check_status is distinct from new.quality_check_status or
     old.accepted_quantity is distinct from new.accepted_quantity or
     old.quality_grade is distinct from new.quality_grade then
    insert into public.notifications (
      farmer_id, title, message, details, kind
    ) values (
      new.farmer_id,
      'Procurement Status Updated',
      'Your procurement status has been updated.',
      'Open Procurement Status to view the latest update.',
      'procurement_status'
    );
  end if;

  return new;
end;
$$;

create trigger procurement_status_notification
after insert or update on public.procurement
for each row execute function public.notify_procurement_status_change();

-- Appointment/centre changes create a generic appointment notification.
create or replace function public.notify_appointment_change()
returns trigger
language plpgsql
as $$
begin
  if (tg_op = 'INSERT' and new.status = 'assigned') or
     (tg_op = 'UPDATE' and (
       old.centre_id is distinct from new.centre_id or
       old.procurement_date is distinct from new.procurement_date or
       old.window_start is distinct from new.window_start or
       old.window_end is distinct from new.window_end
     )) then
    insert into public.notifications (
      farmer_id, title, message, details, kind
    ) values (
      new.farmer_id,
      'Appointment Updated',
      'Your procurement appointment has been updated.',
      'Open your appointment details to view the latest centre/date/time.',
      case when tg_op = 'UPDATE' then 'reschedule' else 'appointment' end
    );
  end if;

  return new;
end;
$$;

create trigger appointment_change_notification
after insert or update on public.appointments
for each row execute function public.notify_appointment_change();

-- =========================
-- GOVERNMENT FARMERS VIEW
-- Only eligible farmers with a centre assignment appear.
-- =========================

create or replace view public.government_farmers as
select
  f.farmer_id,
  f.name,
  f.mobile,
  f.village,
  f.crop,
  f.expected_quantity,
  f.cultivated_area,
  f.priority_score,
  f.language,
  f.workflow_state,
  f.has_left_home,
  fs.location_status,
  fs.attendance_status,
  a.centre_id,
  c.name as centre_name,
  a.procurement_date,
  a.window_start,
  a.window_end,
  a.queue_token,
  p.quality_check_status,
  p.procurement_status,
  p.accepted_quantity,
  p.quality_grade,
  pay.payment_status,
  pay.amount as payment_amount
from public.farmers f
join public.verification v on v.farmer_id = f.farmer_id
join public.farmer_status fs on fs.farmer_id = f.farmer_id
left join public.appointments a on a.farmer_id = f.farmer_id
left join public.centres c on c.centre_id = a.centre_id
left join public.procurement p on p.farmer_id = f.farmer_id
left join public.payments pay on pay.farmer_id = f.farmer_id
where v.eligibility_status = 'verified'
  and a.centre_id is not null
  and a.status in ('assigned', 'rescheduled');

-- =========================
-- PERFORMANCE INDEXES
-- =========================

create index farmers_workflow_state_idx
on public.farmers (workflow_state);

create index verification_eligibility_idx
on public.verification (eligibility_status);

create index appointments_centre_status_idx
on public.appointments (centre_id, status, procurement_date);

create index farmer_status_location_idx
on public.farmer_status (location_status);

create index procurement_status_idx
on public.procurement (procurement_status);

create index payments_status_idx
on public.payments (payment_status);

-- =========================
-- INITIAL ACTIVITY LOG ENTRY
-- =========================

insert into public.activity_history (farmer_id, action, performed_by, details)
select farmer_id, 'demo_record_created', 'system',
       jsonb_build_object('demo_farmer', true, 'initially_unprocessed', true)
from public.farmers;

-- =========================
-- RLS
-- =========================
-- This first prototype phase does not yet have Supabase Auth wired into the
-- Flutter apps. To keep the two apps connected during the prototype phase,
-- the publishable client is allowed to use the tables. We will tighten this
-- with role-aware RLS after the Flutter apps are connected.

alter table public.centres enable row level security;
alter table public.farmers enable row level security;
alter table public.verification enable row level security;
alter table public.appointments enable row level security;
alter table public.farmer_status enable row level security;
alter table public.queue_status enable row level security;
alter table public.procurement enable row level security;
alter table public.payments enable row level security;
alter table public.notifications enable row level security;
alter table public.activity_history enable row level security;
alter table public.government_users enable row level security;

-- Remove any policies with these names if this script is rerun.
drop policy if exists demo_centres_select on public.centres;
drop policy if exists demo_centres_write on public.centres;
drop policy if exists demo_farmers_select on public.farmers;
drop policy if exists demo_farmers_write on public.farmers;
drop policy if exists demo_verification_rw on public.verification;
drop policy if exists demo_appointments_rw on public.appointments;
drop policy if exists demo_farmer_status_rw on public.farmer_status;
drop policy if exists demo_queue_status_rw on public.queue_status;
drop policy if exists demo_procurement_rw on public.procurement;
drop policy if exists demo_payments_rw on public.payments;
drop policy if exists demo_notifications_rw on public.notifications;
drop policy if exists demo_activity_history_rw on public.activity_history;
drop policy if exists demo_government_users_select on public.government_users;

create policy demo_centres_select on public.centres
for select using (true);

create policy demo_centres_write on public.centres
for all using (true) with check (true);

create policy demo_farmers_select on public.farmers
for select using (true);

create policy demo_farmers_write on public.farmers
for all using (true) with check (true);

create policy demo_verification_rw on public.verification
for all using (true) with check (true);

create policy demo_appointments_rw on public.appointments
for all using (true) with check (true);

create policy demo_farmer_status_rw on public.farmer_status
for all using (true) with check (true);

create policy demo_queue_status_rw on public.queue_status
for all using (true) with check (true);

create policy demo_procurement_rw on public.procurement
for all using (true) with check (true);

create policy demo_payments_rw on public.payments
for all using (true) with check (true);

create policy demo_notifications_rw on public.notifications
for all using (true) with check (true);

create policy demo_activity_history_rw on public.activity_history
for all using (true) with check (true);

create policy demo_government_users_select on public.government_users
for select using (true);

-- =========================
-- REALTIME
-- =========================
-- Idempotently add the tables to the Realtime publication.

do $$
begin
  begin alter publication supabase_realtime add table public.farmers; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.verification; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.appointments; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.farmer_status; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.queue_status; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.procurement; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.payments; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.notifications; exception when duplicate_object then null; end;
end $$;

commit;

-- ================================================================
-- QUICK CHECKS (run separately if you want to verify the setup)
-- ================================================================
-- select farmer_id, name, workflow_state from public.farmers order by farmer_id;
-- select count(*) as demo_farmers from public.farmers;            -- should be 12
-- select count(*) as government_visible from public.government_farmers; -- should be 0 initially
-- select * from public.government_farmers order by farmer_id;

-- ============================================================
-- SECTION 2: smart_procurement_supabase_client_access.sql
-- ============================================================
-- Smart Procurement demo: Data API privileges for the Flutter apps.
-- Run this AFTER the initial Smart Procurement schema has been created.
-- This is intentionally permissive for the SIH prototype. Tighten with RLS
-- policies before using the project beyond the demo.

grant usage on schema public to anon, authenticated;

grant select, insert, update, delete on table
  public.centres,
  public.farmers,
  public.verification,
  public.appointments,
  public.farmer_status,
  public.queue_status,
  public.procurement,
  public.payments,
  public.notifications,
  public.activity_history,
  public.government_users
  to anon, authenticated;

grant usage, select on all sequences in schema public to anon, authenticated;

grant execute on function public.assign_demo_centre_a(text) to anon, authenticated;

-- ============================================================
-- SECTION 3: smart_procurement_supabase_stage_fix.sql
-- ============================================================
-- Smart Procurement: independent procurement-stage persistence + notification fix
-- Run this AFTER the initial Smart Procurement schema has already succeeded.

begin;

alter table public.procurement
  add column if not exists stages jsonb not null default '[]'::jsonb;

-- Backfill the existing current state into the new independent stage list.
update public.procurement p
set stages = (
  select coalesce(jsonb_agg(x.stage order by x.ord), '[]'::jsonb)
  from (
    select 'Quality check'::text as stage, 3 as ord
    where p.quality_check_status = 'completed'
    union all
    select 'Weighing', 4
    where p.procurement_status in ('in_progress', 'completed')
    union all
    select 'Procurement', 5
    where p.procurement_status in ('in_progress', 'completed')
    union all
    select 'Bill', 6
    where p.procurement_status = 'completed'
  ) x
)
where p.stages = '[]'::jsonb;

-- Attendance is stored in farmer_status and intentionally remains there.
-- Arrival is represented by the independent procurement-stage list, rather
-- than being inferred from location_status, so the Farmer UI reflects exactly
-- what Government saved.

create or replace function public.notify_procurement_status_change()
returns trigger
language plpgsql
as $$
begin
  if (tg_op = 'INSERT') or
     old.procurement_status is distinct from new.procurement_status or
     old.quality_check_status is distinct from new.quality_check_status or
     old.accepted_quantity is distinct from new.accepted_quantity or
     old.quality_grade is distinct from new.quality_grade or
     old.stages is distinct from new.stages then
    insert into public.notifications (
      farmer_id, title, message, details, kind
    ) values (
      new.farmer_id,
      'Procurement Status Updated',
      'Your procurement status has been updated.',
      'Open Procurement Status to view the latest update.',
      'procurement_status'
    );
  end if;

  return new;
end;
$$;

-- Keep the trigger attached to the updated function definition.
drop trigger if exists procurement_status_notification on public.procurement;
create trigger procurement_status_notification
after insert or update on public.procurement
for each row execute function public.notify_procurement_status_change();

commit;

-- ============================================================
-- SECTION 4: smart_procurement_supabase_realtime_fixed_v2.sql
-- ============================================================
-- Smart Procurement final backend synchronization fix.
-- Run after the initial schema + prior stage-fix migrations.
-- This migration is idempotent.

begin;

alter table public.procurement
  add column if not exists stages jsonb not null default '[]'::jsonb;

-- Replace the prior trigger-based procurement notification mechanism.
-- Notifications are now created by the atomic RPC below so the notification
-- is guaranteed to correspond to a successful Government save operation.
drop trigger if exists procurement_status_notification on public.procurement;
drop function if exists public.notify_procurement_status_change();

-- ------------------------------------------------------------
-- Farmer attendance: atomic and persistent.
-- Also mirrors Attendance into procurement.stages so both apps
-- observe the same workflow checkpoint after any refresh.
-- ------------------------------------------------------------
create or replace function public.mark_farmer_attendance(
  p_farmer_id text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_verified boolean;
  v_assigned boolean;
  v_old_stages jsonb;
  v_new_stages jsonb;
begin
  select (
    identity_status = 'verified'
    and land_status = 'verified'
    and bank_status = 'verified'
    and crop_status = 'verified'
    and eligibility_status = 'verified'
  )
  into v_verified
  from public.verification
  where farmer_id = p_farmer_id;

  select exists (
    select 1
    from public.appointments
    where farmer_id = p_farmer_id
      and centre_id is not null
      and status in ('assigned', 'rescheduled')
  )
  into v_assigned;

  if not coalesce(v_verified, false) then
    raise exception 'Farmer % is not fully verified/eligible', p_farmer_id;
  end if;

  if not coalesce(v_assigned, false) then
    raise exception 'Farmer % has no active procurement appointment', p_farmer_id;
  end if;

  select coalesce(stages, '[]'::jsonb)
  into v_old_stages
  from public.procurement
  where farmer_id = p_farmer_id
  for update;

  -- Add Attendance while preserving any later Government-confirmed stages.
  select coalesce(jsonb_agg(value order by ord), '[]'::jsonb)
  into v_new_stages
  from (
    select value, min(ord) as ord
    from (
      select value, 0 as ord
      from jsonb_array_elements_text(v_old_stages)
      union all
      select 'Attendance', 0
    ) q
    group by value
  ) ordered;

  update public.farmer_status
  set
    attendance_status = true,
    attendance_at = coalesce(attendance_at, now()),
    location_status = 'AT_CENTRE'
  where farmer_id = p_farmer_id;

  update public.procurement
  set stages = v_new_stages
  where farmer_id = p_farmer_id;

  update public.farmers
  set
    has_left_home = true,
    workflow_state = 'arrived'
  where farmer_id = p_farmer_id;

  insert into public.activity_history (
    farmer_id, action, performed_by, details
  ) values (
    p_farmer_id,
    'attendance_marked',
    'farmer_app',
    jsonb_build_object('source', 'farmer', 'stages', v_new_stages)
  );
end;
$$;

-- ------------------------------------------------------------
-- Government procurement-stage save: atomic source of truth.
-- ------------------------------------------------------------
create or replace function public.save_procurement_stage_update(
  p_farmer_id text,
  p_stages jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_stages text[];
  v_stage text;
  v_index integer;
  v_highest integer := -1;
  v_old_stages jsonb;
  v_new_stages jsonb;
  v_complete boolean := false;
  v_quality text;
  v_procurement_status text;
  v_workflow_state text;
begin
  if not exists (
    select 1 from public.farmers where farmer_id = p_farmer_id
  ) then
    raise exception 'Farmer % does not exist', p_farmer_id;
  end if;

  if jsonb_typeof(p_stages) <> 'array' then
    raise exception 'Procurement stages must be a JSON array';
  end if;

  select coalesce(
    array_agg(trim(value) order by ord),
    '{}'::text[]
  )
  into v_stages
  from (
    select distinct value, ord
    from jsonb_array_elements_text(p_stages) with ordinality as x(value, ord)
    where trim(value) <> ''
  ) q;

  foreach v_stage in array v_stages loop
    v_index := case v_stage
      when 'Attendance' then 0
      when 'Arrival' then 1
      when 'Quality check' then 2
      when 'Weighing' then 3
      when 'Procurement' then 4
      when 'Bill' then 5
      when 'Payment' then 6
      else -1
    end;

    if v_index < 0 then
      raise exception 'Invalid procurement stage: %', v_stage;
    end if;

    if v_index > v_highest then
      v_highest := v_index;
    end if;
  end loop;

  -- Only sequential workflow prefixes are valid.
  if v_highest >= 0 and not ('Attendance' = any(v_stages)) then
    raise exception 'Attendance must be completed before later stages';
  end if;
  if v_highest >= 1 and not ('Arrival' = any(v_stages)) then
    raise exception 'Arrival must be completed before later stages';
  end if;
  if v_highest >= 2 and not ('Quality check' = any(v_stages)) then
    raise exception 'Quality check must be completed before later stages';
  end if;
  if v_highest >= 3 and not ('Weighing' = any(v_stages)) then
    raise exception 'Weighing must be completed before later stages';
  end if;
  if v_highest >= 4 and not ('Procurement' = any(v_stages)) then
    raise exception 'Procurement must be completed before later stages';
  end if;
  if v_highest >= 5 and not ('Bill' = any(v_stages)) then
    raise exception 'Bill must be completed before payment';
  end if;

  if v_highest >= 0 then
    if not exists (
      select 1 from public.verification
      where farmer_id = p_farmer_id
        and identity_status = 'verified'
        and land_status = 'verified'
        and bank_status = 'verified'
        and crop_status = 'verified'
        and eligibility_status = 'verified'
    ) then
      raise exception 'Farmer % is not fully verified/eligible', p_farmer_id;
    end if;

    if not exists (
      select 1 from public.appointments
      where farmer_id = p_farmer_id
        and centre_id is not null
        and status in ('assigned', 'rescheduled')
    ) then
      raise exception 'Farmer % has no active procurement appointment', p_farmer_id;
    end if;
  end if;

  select coalesce(stages, '[]'::jsonb)
  into v_old_stages
  from public.procurement
  where farmer_id = p_farmer_id
  for update;

  v_new_stages := to_jsonb(v_stages);

  -- Never allow Government to erase a checkpoint that has already been
  -- persisted by the Farmer or an earlier Government action.
  if exists (
    select 1
    from jsonb_array_elements_text(v_old_stages) old_stage
    where not (old_stage.value = any(v_stages))
  ) then
    raise exception 'Procurement stages cannot move backwards for %', p_farmer_id;
  end if;

  if 'Attendance' = any(v_stages) then
    update public.farmer_status
    set
      attendance_status = true,
      attendance_at = coalesce(attendance_at, now()),
      location_status = 'AT_CENTRE'
    where farmer_id = p_farmer_id;
  end if;

  v_complete :=
       'Attendance' = any(v_stages)
   and 'Arrival' = any(v_stages)
   and 'Quality check' = any(v_stages)
   and 'Weighing' = any(v_stages)
   and 'Procurement' = any(v_stages)
   and 'Bill' = any(v_stages)
   and 'Payment' = any(v_stages);

  v_quality := case
    when 'Quality check' = any(v_stages) then 'completed'
    else 'pending'
  end;

  v_procurement_status := case
    when v_complete then 'completed'
    when 'Procurement' = any(v_stages) then 'in_progress'
    when 'Weighing' = any(v_stages) then 'in_progress'
    when 'Quality check' = any(v_stages) then 'in_progress'
    else 'not_started'
  end;

  v_workflow_state := case
    when v_complete then 'completed'
    when 'Procurement' = any(v_stages)
      or 'Weighing' = any(v_stages)
      or 'Bill' = any(v_stages) then 'processing'
    when 'Arrival' = any(v_stages)
      or 'Quality check' = any(v_stages) then 'arrived'
    else 'assigned'
  end;

  update public.procurement
  set
    stages = v_new_stages,
    quality_check_status = v_quality,
    procurement_status = v_procurement_status,
    quality_grade = case
      when 'Quality check' = any(v_stages) then 'A'
      else null
    end,
    completed_at = case when v_complete then coalesce(completed_at, now()) else null end
  where farmer_id = p_farmer_id;

  update public.farmers
  set
    -- workflow_state is a PostgreSQL enum (farmer_workflow_state), while
    -- v_workflow_state is intentionally computed as text above. Cast it
    -- explicitly so Supabase/PostgreSQL does not reject the update.
    workflow_state = v_workflow_state::public.farmer_workflow_state,
    has_left_home = (v_highest >= 0)
  where farmer_id = p_farmer_id;

  if 'Payment' = any(v_stages) then
    update public.payments
    set
      payment_status = 'completed',
      payment_date = coalesce(payment_date, now()),
      reference = coalesce(
        reference,
        'DEMO-' || p_farmer_id || '-' || extract(epoch from now())::bigint
      )
    where farmer_id = p_farmer_id;
  end if;

  if v_old_stages is distinct from v_new_stages then
    insert into public.notifications (
      farmer_id, title, message, details, kind
    ) values (
      p_farmer_id,
      'Procurement Status Updated',
      'Your procurement status has been updated.',
      'Open Procurement Status to view the latest update.',
      'procurement_status'
    );
  end if;

  insert into public.activity_history (
    farmer_id, action, performed_by, details
  ) values (
    p_farmer_id,
    'procurement_stage_update',
    'government_app',
    jsonb_build_object('stages', v_new_stages)
  );
end;
$$;

grant execute on function public.mark_farmer_attendance(text) to anon, authenticated;
grant execute on function public.save_procurement_stage_update(text, jsonb) to anon, authenticated;

-- Explicit Realtime publication membership. Safe to re-run.
-- Make row changes fully visible to Realtime so UPDATE/DELETE events have
-- complete old/new records available to the Flutter listeners. Safe to rerun.
alter table public.farmers replica identity full;
alter table public.verification replica identity full;
alter table public.appointments replica identity full;
alter table public.farmer_status replica identity full;
alter table public.procurement replica identity full;
alter table public.payments replica identity full;
alter table public.notifications replica identity full;

do $$
begin
  begin alter publication supabase_realtime add table public.farmers; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.verification; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.appointments; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.farmer_status; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.procurement; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.payments; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.notifications; exception when duplicate_object then null; end;
end $$;

commit;
