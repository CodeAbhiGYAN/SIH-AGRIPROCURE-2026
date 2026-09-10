begin;

set local lock_timeout = '5s';

-- ============================================================================
-- 1. APPOINTMENT PROCESSING-TIME MODEL
-- ============================================================================

alter table public.appointments
  add column if not exists predicted_processing_minutes numeric(6,2) not null default 7.0;

-- Backfill any existing rows defensively in case the column was created before
-- a default was attached or contains NULLs from an earlier migration.
update public.appointments
set predicted_processing_minutes = 7.0
where predicted_processing_minutes is null
   or predicted_processing_minutes <= 0;

-- Add the constraint only if it does not already exist.
do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.appointments'::regclass
      and conname = 'appointments_predicted_processing_minutes_positive'
  ) then
    alter table public.appointments
      add constraint appointments_predicted_processing_minutes_positive
      check (predicted_processing_minutes > 0);
  end if;
end $$;

-- ============================================================================
-- 2. AUTHORITATIVE SERVER-SIDE QUEUE ENTRY TIME
-- ============================================================================

alter table public.farmer_status
  add column if not exists queue_entered_at timestamptz;

-- Existing attended farmers should keep a sensible historical queue-entry
-- timestamp rather than appearing to have joined the queue just now.
update public.farmer_status
set queue_entered_at = attendance_at
where attendance_status = true
  and queue_entered_at is null
  and attendance_at is not null;

create index if not exists farmer_status_queue_entered_idx
  on public.farmer_status (queue_entered_at);

create index if not exists farmer_status_queue_state_idx
  on public.farmer_status (attendance_status, queue_entered_at, farmer_id);

create index if not exists appointments_queue_lookup_idx
  on public.appointments (
    centre_id,
    procurement_date,
    window_start,
    window_end,
    status,
    farmer_id
  );

-- ============================================================================
-- 3. PERSISTENT CENTRE/DATE UNAVAILABILITY
-- ============================================================================

create table if not exists public.centre_unavailability (
  centre_id text not null references public.centres(centre_id) on delete cascade,
  service_date date not null,
  reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (centre_id, service_date)
);

create index if not exists centre_unavailability_date_idx
  on public.centre_unavailability (service_date, centre_id);

drop trigger if exists centre_unavailability_updated_at on public.centre_unavailability;
create trigger centre_unavailability_updated_at
before update on public.centre_unavailability
for each row execute function public.set_updated_at();

alter table public.centre_unavailability enable row level security;

drop policy if exists demo_centre_unavailability_rw
  on public.centre_unavailability;

create policy demo_centre_unavailability_rw
on public.centre_unavailability
for all
using (true)
with check (true);

grant select, insert, update, delete
on public.centre_unavailability
 to anon, authenticated;

-- ============================================================================
-- 4. SHARED CONSTANTS / CLASSIFICATION
-- ============================================================================

-- Prototype configuration table. This avoids scattering 7 / 10 / 30 through
-- multiple Flutter screens and SQL functions.
create table if not exists public.procurement_config (
  config_key text primary key,
  numeric_value numeric(10,2),
  text_value text,
  updated_at timestamptz not null default now()
);

insert into public.procurement_config (config_key, numeric_value)
values
  ('default_processing_minutes', 7.0),
  ('appointment_slot_minutes', 30.0),
  ('arrival_buffer_minutes', 10.0)
on conflict (config_key) do nothing;

alter table public.procurement_config enable row level security;

drop policy if exists demo_procurement_config_rw
  on public.procurement_config;

create policy demo_procurement_config_rw
on public.procurement_config
for all
using (true)
with check (true);

grant select, insert, update, delete
on public.procurement_config
 to anon, authenticated;

-- ============================================================================
-- 5. SLOT LOAD VIEW
-- ============================================================================
-- One row per centre + date + slot. This is the mathematical source for the
-- agreed load model:
--   workload = SUM(predicted_processing_minutes)
--   overload = (workload - slot_minutes) / slot_minutes * 100
-- ============================================================================

create or replace view public.centre_slot_operational_snapshot as
with slot_rows as (
  select
    a.centre_id,
    a.procurement_date,
    a.window_start,
    a.window_end,
    greatest(
      extract(epoch from (a.window_end - a.window_start)) / 60.0,
      1.0
    ) as slot_minutes,
    count(*) filter (
      where a.status in ('assigned', 'rescheduled')
    )::integer as scheduled_farmers,
    coalesce(
      sum(
        case
          when a.status in ('assigned', 'rescheduled')
            then coalesce(a.predicted_processing_minutes, 7.0)
          else 0
        end
      ),
      0
    )::numeric(10,2) as predicted_workload_minutes
  from public.appointments a
  where a.centre_id is not null
  group by
    a.centre_id,
    a.procurement_date,
    a.window_start,
    a.window_end
),
classified as (
  select
    s.*,
    round(
      ((s.predicted_workload_minutes - s.slot_minutes)
        / s.slot_minutes) * 100.0,
      2
    ) as overload_percent
  from slot_rows s
)
select
  c.centre_id,
  c.name as centre_name,
  c.address,
  c.lat,
  c.lng,
  x.procurement_date as service_date,
  x.window_start,
  x.window_end,
  round(x.slot_minutes, 2) as slot_minutes,
  x.scheduled_farmers,
  x.predicted_workload_minutes,
  x.overload_percent,
  case
    when x.overload_percent <= 0 then 'normal'
    when x.overload_percent <= 25 then 'moderate'
    when x.overload_percent <= 50 then 'high'
    else 'bottleneck'
  end as load_classification,
  exists (
    select 1
    from public.centre_unavailability u
    where u.centre_id = x.centre_id
      and u.service_date = x.procurement_date
  ) as centre_unavailable
from classified x
join public.centres c on c.centre_id = x.centre_id;

-- ============================================================================
-- 6. LIVE QUEUE VIEW
-- ============================================================================
-- Queue position is derived from actual server-side queue entry timestamps.
-- Token remains separate from live queue position.
-- ============================================================================

create or replace view public.farmer_queue_live as
with active_queue as (
  select
    a.appointment_id,
    a.farmer_id,
    a.centre_id,
    a.procurement_date,
    a.window_start,
    a.window_end,
    a.queue_token,
    f.workflow_state,
    fs.location_status,
    fs.attendance_status,
    fs.queue_entered_at,
    row_number() over (
      partition by a.centre_id, a.procurement_date, a.window_start, a.window_end
      order by fs.queue_entered_at, a.farmer_id
    )::integer as queue_position
  from public.appointments a
  join public.farmers f
    on f.farmer_id = a.farmer_id
  join public.farmer_status fs
    on fs.farmer_id = a.farmer_id
  where a.status in ('assigned', 'rescheduled')
    and fs.attendance_status = true
    and fs.queue_entered_at is not null
    and f.workflow_state::text in ('arrived', 'waiting', 'processing')
)
select
  aq.*,
  greatest(aq.queue_position - 1, 0) as farmers_ahead,
  greatest(aq.queue_position - 1, 0) * coalesce(
    (select numeric_value from public.procurement_config
     where config_key = 'default_processing_minutes'),
    7.0
  ) as estimated_wait_minutes
from active_queue aq;

-- ============================================================================
-- 7. FARMER QUEUE SNAPSHOT RPC
-- ============================================================================

create or replace function public.get_farmer_queue_snapshot(
  p_farmer_id text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_appointment public.appointments%rowtype;
  v_status public.farmer_status%rowtype;
  v_position integer := 0;
  v_ahead integer := 0;
  v_wait numeric := 0;
  v_waiting integer := 0;
  v_processing integer := 0;
  v_workload numeric := 0;
  v_slot_minutes numeric := 30;
  v_overload numeric := 0;
  v_load_classification text := 'normal';
  v_default_minutes numeric := 7.0;
  v_queue_state boolean := false;
begin
  select *
  into v_appointment
  from public.appointments a
  where a.farmer_id = p_farmer_id
    and a.status in ('assigned', 'rescheduled')
  order by a.updated_at desc, a.appointment_id desc
  limit 1;

  if not found then
    return jsonb_build_object(
      'queue_token', 0,
      'position', 0,
      'farmers_ahead', 0,
      'estimated_wait_minutes', 0,
      'current_waiting', 0,
      'current_processing', 0,
      'slot_workload_minutes', 0,
      'slot_minutes', 30,
      'overload_percent', 0,
      'load_status', 'normal',
      'queue_entered_at', null,
      'appointment_date', null,
      'window_start', null,
      'window_end', null
    );
  end if;

  select * into v_status
  from public.farmer_status fs
  where fs.farmer_id = p_farmer_id;

  select coalesce(numeric_value, 7.0)
  into v_default_minutes
  from public.procurement_config
  where config_key = 'default_processing_minutes';

  select greatest(
    extract(epoch from (v_appointment.window_end - v_appointment.window_start)) / 60.0,
    1.0
  )
  into v_slot_minutes;

  -- A farmer only gets a live queue position after actually entering the queue.
  v_queue_state :=
    coalesce(v_status.attendance_status, false)
    and v_status.queue_entered_at is not null;

  if v_queue_state then
    select
      count(*)::integer,
      count(*) filter (
        where f.workflow_state::text in ('waiting', 'arrived')
      )::integer,
      count(*) filter (
        where f.workflow_state::text = 'processing'
      )::integer
    into v_ahead, v_waiting, v_processing
    from public.appointments a
    join public.farmers f
      on f.farmer_id = a.farmer_id
    join public.farmer_status fs
      on fs.farmer_id = a.farmer_id
    where a.centre_id = v_appointment.centre_id
      and a.procurement_date = v_appointment.procurement_date
      and a.window_start = v_appointment.window_start
      and a.window_end = v_appointment.window_end
      and a.status in ('assigned', 'rescheduled')
      and fs.attendance_status = true
      and fs.queue_entered_at is not null
      and f.workflow_state::text in ('arrived', 'waiting', 'processing')
      and a.farmer_id <> p_farmer_id
      and (
        fs.queue_entered_at < v_status.queue_entered_at
        or (
          fs.queue_entered_at = v_status.queue_entered_at
          and a.farmer_id < p_farmer_id
        )
      );

    v_position := v_ahead + 1;
    v_wait := case
      when (select f.workflow_state::text from public.farmers f where f.farmer_id = p_farmer_id) = 'processing'
        then 0
      else v_ahead * v_default_minutes
    end;

    select count(*)::integer
    into v_waiting
    from public.appointments a
    join public.farmers f
      on f.farmer_id = a.farmer_id
    join public.farmer_status fs
      on fs.farmer_id = a.farmer_id
    where a.centre_id = v_appointment.centre_id
      and a.procurement_date = v_appointment.procurement_date
      and a.window_start = v_appointment.window_start
      and a.window_end = v_appointment.window_end
      and a.status in ('assigned', 'rescheduled')
      and fs.attendance_status = true
      and fs.queue_entered_at is not null
      and f.workflow_state::text in ('arrived', 'waiting');

    select count(*)::integer
    into v_processing
    from public.appointments a
    join public.farmers f
      on f.farmer_id = a.farmer_id
    join public.farmer_status fs
      on fs.farmer_id = a.farmer_id
    where a.centre_id = v_appointment.centre_id
      and a.procurement_date = v_appointment.procurement_date
      and a.window_start = v_appointment.window_start
      and a.window_end = v_appointment.window_end
      and a.status in ('assigned', 'rescheduled')
      and fs.attendance_status = true
      and fs.queue_entered_at is not null
      and f.workflow_state::text = 'processing';
  else
    v_ahead := 0;
    v_position := 0;
    v_wait := 0;
  end if;

  select coalesce(sum(coalesce(a.predicted_processing_minutes, v_default_minutes)), 0)
  into v_workload
  from public.appointments a
  where a.centre_id = v_appointment.centre_id
    and a.procurement_date = v_appointment.procurement_date
    and a.window_start = v_appointment.window_start
    and a.window_end = v_appointment.window_end
    and a.status in ('assigned', 'rescheduled');

  v_overload := ((v_workload - v_slot_minutes) / v_slot_minutes) * 100.0;

  v_load_classification := case
    when v_overload <= 0 then 'normal'
    when v_overload <= 25 then 'moderate'
    when v_overload <= 50 then 'high'
    else 'bottleneck'
  end;

  return jsonb_build_object(
    'queue_token', coalesce(v_appointment.queue_token, 0),
    'position', v_position,
    'farmers_ahead', v_ahead,
    'estimated_wait_minutes', round(v_wait, 0),
    'current_waiting', v_waiting,
    'current_processing', v_processing,
    'slot_workload_minutes', round(v_workload, 2),
    'slot_minutes', round(v_slot_minutes, 2),
    'overload_percent', round(v_overload, 2),
    'load_status', v_load_classification,
    'queue_entered_at', v_status.queue_entered_at,
    'appointment_date', v_appointment.procurement_date,
    'window_start', v_appointment.window_start,
    'window_end', v_appointment.window_end,
    'centre_id', v_appointment.centre_id
  );
end;
$$;

grant execute on function public.get_farmer_queue_snapshot(text)
  to anon, authenticated;

-- ============================================================================
-- 8. SAFE ASSIGNMENT RPC UPDATE
-- ============================================================================
-- Keeps the existing Centre A demo behavior, but:
--   * respects unavailable dates;
--   * does not impose an arbitrary "4 farmers per slot" limit;
--   * preserves an already-valid appointment instead of allocating another token;
--   * sets the 7-minute prediction fallback.
-- ============================================================================

create or replace function public.assign_demo_centre_a(p_farmer_id text)
returns public.appointments
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.appointments;
  v_existing public.appointments;
  v_next_token integer;
  v_date date := current_date;
  v_slot_start time := '11:00:00';
  v_slot_end time := '11:30:00';
  v_default_minutes numeric := 7.0;
  v_days_checked integer := 0;
begin
  if not exists (
    select 1
    from public.verification v
    where v.farmer_id = p_farmer_id
      and v.identity_status = 'verified'
      and v.land_status = 'verified'
      and v.bank_status = 'verified'
      and v.crop_status = 'verified'
      and v.eligibility_status = 'verified'
  ) then
    raise exception 'Farmer % is not fully verified/eligible', p_farmer_id;
  end if;

  select coalesce(numeric_value, 7.0)
  into v_default_minutes
  from public.procurement_config
  where config_key = 'default_processing_minutes';

  -- If a valid assignment already exists, keep it. This prevents repeated
  -- verification refreshes from silently changing the farmer's token/slot.
  select *
  into v_existing
  from public.appointments a
  where a.farmer_id = p_farmer_id
    and a.status in ('assigned', 'rescheduled')
    and a.centre_id is not null
  order by a.updated_at desc, a.appointment_id desc
  limit 1;

  if found and not exists (
    select 1
    from public.centre_unavailability u
    where u.centre_id = v_existing.centre_id
      and u.service_date = v_existing.procurement_date
  ) then
    return v_existing;
  end if;

  if found then
    v_date := greatest(current_date, coalesce(v_existing.procurement_date, current_date));
  end if;

  -- Find the next available day for the demo slot. No arbitrary farmer-count
  -- cap is used here; overload is calculated from predicted workload later.
  loop
    exit when not exists (
      select 1
      from public.centre_unavailability u
      where u.centre_id = 'A'
        and u.service_date = v_date
    );

    v_date := v_date + 1;
    v_days_checked := v_days_checked + 1;

    if v_days_checked > 90 then
      raise exception 'No available Centre A date found in the next 90 days';
    end if;
  end loop;

  select coalesce(max(queue_token), 0) + 1
  into v_next_token
  from public.appointments
  where centre_id = 'A'
    and procurement_date = v_date
    and window_start = v_slot_start
    and window_end = v_slot_end
    and status in ('assigned', 'rescheduled');

  insert into public.appointments (
    farmer_id,
    centre_id,
    procurement_date,
    window_start,
    window_end,
    queue_token,
    predicted_processing_minutes,
    assigned_at,
    status
  )
  values (
    p_farmer_id,
    'A',
    v_date,
    v_slot_start,
    v_slot_end,
    v_next_token,
    v_default_minutes,
    now(),
    'assigned'
  )
  on conflict (farmer_id) do update set
    centre_id = excluded.centre_id,
    procurement_date = excluded.procurement_date,
    window_start = excluded.window_start,
    window_end = excluded.window_end,
    queue_token = excluded.queue_token,
    predicted_processing_minutes = excluded.predicted_processing_minutes,
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
    jsonb_build_object(
      'centre_id', 'A',
      'demo_mode', true,
      'procurement_date', v_date,
      'slot', '11:00–11:30',
      'predicted_processing_minutes', v_default_minutes
    )
  );

  return v_row;
end;
$$;

grant execute on function public.assign_demo_centre_a(text)
  to anon, authenticated;

-- ============================================================================
-- 9. ATTENDANCE RPC UPDATE
-- ============================================================================
-- Same public signature and same validation as the current working RPC, but
-- additionally records queue_entered_at using the database/server clock.
-- ============================================================================

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
  v_now timestamptz := now();
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

  -- Preserve the existing checkpoints, add Attendance, and normalize the
  -- ordering to the authoritative workflow sequence.
  select coalesce(
    jsonb_agg(stage order by stage_order),
    '[]'::jsonb
  )
  into v_new_stages
  from (
    select distinct value as stage,
      case value
        when 'Attendance' then 0
        when 'Arrival' then 1
        when 'Quality check' then 2
        when 'Weighing' then 3
        when 'Procurement' then 4
        when 'Bill' then 5
        when 'Payment' then 6
        else 99
      end as stage_order
    from (
      select value
      from jsonb_array_elements_text(v_old_stages)
      union all
      select 'Attendance'
    ) q
  ) normalized;

  update public.farmer_status
  set
    attendance_status = true,
    attendance_at = coalesce(attendance_at, v_now),
    queue_entered_at = coalesce(queue_entered_at, v_now),
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
    farmer_id,
    action,
    performed_by,
    details
  )
  values (
    p_farmer_id,
    'attendance_marked',
    'farmer_app',
    jsonb_build_object(
      'source', 'farmer',
      'queue_entered_at', v_now,
      'stages', v_new_stages
    )
  );
end;
$$;

grant execute on function public.mark_farmer_attendance(text)
  to anon, authenticated;

-- ============================================================================
-- 10. CENTRE OPERATIONAL CACHE
-- ============================================================================
-- The existing centres table is retained for backward compatibility. The
-- following function refreshes its cached/legacy summary values from actual
-- appointments + queue state so old UI code does not display contradictory
-- combinations such as queue=0, load=0, status=HIGH LOAD.
--
-- Note: existing centre_status enum cannot represent the richer four-way load
-- classification. We map:
--   normal      -> normal
--   moderate    -> busy
--   high        -> highLoad
--   bottleneck  -> highLoad
-- The exact richer classification remains available in the derived views.
-- ============================================================================

create or replace function public.refresh_centre_operational_cache(
  p_centre_id text,
  p_service_date date default current_date
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_scheduled integer := 0;
  v_queue integer := 0;
  v_workload numeric := 0;
  v_max_overload numeric := -100;
  v_processing_rate numeric := 0;
  v_status public.centre_status := 'normal';
  v_slot_minutes numeric := 30;
  v_default_minutes numeric := 7;
  v_avg_pred numeric;
  v_is_unavailable boolean := false;
begin
  select coalesce(numeric_value, 7.0)
  into v_default_minutes
  from public.procurement_config
  where config_key = 'default_processing_minutes';

  select exists (
    select 1
    from public.centre_unavailability u
    where u.centre_id = p_centre_id
      and u.service_date = p_service_date
  ) into v_is_unavailable;

  select count(*)::integer,
         coalesce(sum(coalesce(a.predicted_processing_minutes, v_default_minutes)), 0)
  into v_scheduled, v_workload
  from public.appointments a
  where a.centre_id = p_centre_id
    and a.procurement_date = p_service_date
    and a.status in ('assigned', 'rescheduled');

  select count(*)::integer
  into v_queue
  from public.appointments a
  join public.farmers f on f.farmer_id = a.farmer_id
  join public.farmer_status fs on fs.farmer_id = a.farmer_id
  where a.centre_id = p_centre_id
    and a.procurement_date = p_service_date
    and a.status in ('assigned', 'rescheduled')
    and fs.attendance_status = true
    and fs.queue_entered_at is not null
    and f.workflow_state::text in ('arrived', 'waiting', 'processing');

  select coalesce(avg(coalesce(a.predicted_processing_minutes, v_default_minutes)), v_default_minutes)
  into v_avg_pred
  from public.appointments a
  where a.centre_id = p_centre_id
    and a.procurement_date = p_service_date
    and a.status in ('assigned', 'rescheduled');

  v_processing_rate := case
    when v_avg_pred > 0 then 60.0 / v_avg_pred
    else 60.0 / v_default_minutes
  end;

  select coalesce(max(
    ((slot.predicted_workload_minutes - slot.slot_minutes) / slot.slot_minutes) * 100.0
  ), -100)
  into v_max_overload
  from (
    select
      a.window_start,
      a.window_end,
      greatest(
        extract(epoch from (a.window_end - a.window_start)) / 60.0,
        1.0
      ) as slot_minutes,
      coalesce(sum(coalesce(a.predicted_processing_minutes, v_default_minutes)), 0)
        as predicted_workload_minutes
    from public.appointments a
    where a.centre_id = p_centre_id
      and a.procurement_date = p_service_date
      and a.status in ('assigned', 'rescheduled')
    group by a.window_start, a.window_end
  ) slot;

  if v_is_unavailable then
    v_status := 'unavailable';
  elsif v_max_overload <= 0 then
    v_status := 'normal';
  elsif v_max_overload <= 25 then
    v_status := 'busy';
  else
    v_status := 'highLoad';
  end if;

  update public.centres
  set
    current_load = v_scheduled,
    queue_count = v_queue,
    processing_rate = round(v_processing_rate, 2),
    status = v_status
  where centre_id = p_centre_id;
end;
$$;

grant execute on function public.refresh_centre_operational_cache(text, date)
  to anon, authenticated;

-- ============================================================================
-- 11. BACKWARD-COMPATIBLE CENTRE SNAPSHOT VIEW
-- ============================================================================
-- Exposes the richer four-way status while retaining the legacy centre fields.
-- ============================================================================

create or replace view public.centre_operational_snapshot as
with scheduled as (
  select
    a.centre_id,
    count(*) filter (where a.status in ('assigned', 'rescheduled'))::integer as scheduled_today,
    coalesce(sum(a.predicted_processing_minutes) filter (where a.status in ('assigned', 'rescheduled')), 0)::numeric(10,2) as workload_today
  from public.appointments a
  where a.procurement_date = current_date
  group by a.centre_id
),
slot_load as (
  select
    x.centre_id,
    coalesce(max(x.overload_percent), -100)::numeric(10,2) as max_overload_today
  from public.centre_slot_operational_snapshot x
  where x.service_date = current_date
  group by x.centre_id
),
queue as (
  select
    a.centre_id,
    count(*) filter (
      where f.workflow_state::text in ('arrived', 'waiting')
        and fs.attendance_status = true
        and fs.queue_entered_at is not null
        and a.status in ('assigned', 'rescheduled')
        and a.procurement_date = current_date
    )::integer as waiting_now,
    count(*) filter (
      where f.workflow_state::text = 'processing'
        and fs.attendance_status = true
        and fs.queue_entered_at is not null
        and a.status in ('assigned', 'rescheduled')
        and a.procurement_date = current_date
    )::integer as processing_now
  from public.appointments a
  join public.farmers f on f.farmer_id = a.farmer_id
  join public.farmer_status fs on fs.farmer_id = a.farmer_id
  group by a.centre_id
)
select
  c.centre_id,
  c.name,
  c.address,
  c.capacity,
  c.active_staff,
  c.staff_total,
  c.weighbridges_working,
  c.weighbridges_total,
  coalesce(s.scheduled_today, 0) as scheduled_today,
  coalesce(s.workload_today, 0)::numeric(10,2) as workload_today,
  coalesce(sl.max_overload_today, -100)::numeric(10,2) as overload_percent,
  coalesce(q.waiting_now, 0) as waiting_now,
  coalesce(q.processing_now, 0) as processing_now,
  coalesce(q.waiting_now, 0) + coalesce(q.processing_now, 0) as physical_load,
  round(
    case when c.capacity > 0
      then coalesce(s.scheduled_today, 0)::numeric / c.capacity * 100
      else 0
    end,
    2
  ) as appointment_capacity_used_percent,
  case
    when exists (
      select 1 from public.centre_unavailability u
      where u.centre_id = c.centre_id
        and u.service_date = current_date
    ) then 'unavailable'
    when coalesce(sl.max_overload_today, -100) <= 0 then 'normal'
    when coalesce(sl.max_overload_today, -100) <= 25 then 'moderate'
    when coalesce(sl.max_overload_today, -100) <= 50 then 'high'
    else 'bottleneck'
  end as load_classification
from public.centres c
left join scheduled s on s.centre_id = c.centre_id
left join slot_load sl on sl.centre_id = c.centre_id
left join queue q on q.centre_id = c.centre_id;

-- ============================================================================
-- 12. REFRESH EXISTING CENTRE CACHE NOW
-- ============================================================================

select public.refresh_centre_operational_cache(c.centre_id, current_date)
from public.centres c;

-- ============================================================================
-- 13. TRIGGERS TO KEEP LEGACY CENTRE CACHE CONSISTENT
-- ============================================================================

create or replace function public.refresh_centre_cache_from_appointment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op in ('UPDATE', 'DELETE') and old.centre_id is not null then
    perform public.refresh_centre_operational_cache(old.centre_id, coalesce(old.procurement_date, current_date));
  end if;

  if tg_op in ('INSERT', 'UPDATE') and new.centre_id is not null then
    perform public.refresh_centre_operational_cache(new.centre_id, coalesce(new.procurement_date, current_date));
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists appointments_refresh_centre_cache
  on public.appointments;

create trigger appointments_refresh_centre_cache
after insert or update or delete on public.appointments
for each row execute function public.refresh_centre_cache_from_appointment();

create or replace function public.refresh_centre_cache_from_farmer_state()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_centre_id text;
  v_date date;
begin
  select a.centre_id, a.procurement_date
  into v_centre_id, v_date
  from public.appointments a
  where a.farmer_id = coalesce(new.farmer_id, old.farmer_id)
    and a.status in ('assigned', 'rescheduled')
  order by a.updated_at desc, a.appointment_id desc
  limit 1;

  if v_centre_id is not null then
    perform public.refresh_centre_operational_cache(v_centre_id, coalesce(v_date, current_date));
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists farmers_refresh_centre_cache
  on public.farmers;

create trigger farmers_refresh_centre_cache
after update on public.farmers
for each row execute function public.refresh_centre_cache_from_farmer_state();

drop trigger if exists farmer_status_refresh_centre_cache
  on public.farmer_status;

create trigger farmer_status_refresh_centre_cache
after insert or update or delete on public.farmer_status
for each row execute function public.refresh_centre_cache_from_farmer_state();

-- ============================================================================
-- 14. REFRESH CENTRE CACHE AFTER AVAILABILITY CHANGES
-- ============================================================================

create or replace function public.refresh_centre_cache_from_availability()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op in ('UPDATE', 'DELETE') and old.centre_id is not null then
    perform public.refresh_centre_operational_cache(old.centre_id, old.service_date);
  end if;

  if tg_op in ('INSERT', 'UPDATE') and new.centre_id is not null then
    perform public.refresh_centre_operational_cache(new.centre_id, new.service_date);
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists centre_unavailability_refresh_cache
  on public.centre_unavailability;

create trigger centre_unavailability_refresh_cache
after insert or update or delete on public.centre_unavailability
for each row execute function public.refresh_centre_cache_from_availability();

-- ============================================================================
-- 15. REALTIME FOR NEW SHARED DATA
-- ============================================================================

alter table public.farmer_status replica identity full;
alter table public.appointments replica identity full;
alter table public.centre_unavailability replica identity full;
alter table public.procurement_config replica identity full;

do $$
begin
  begin
    alter publication supabase_realtime add table public.centre_unavailability;
  exception when duplicate_object then null;
  end;

  begin
    alter publication supabase_realtime add table public.procurement_config;
  exception when duplicate_object then null;
  end;
end $$;

-- ============================================================================
-- 16. READ GRANTS FOR DERIVED OBJECTS
-- ============================================================================

grant select on public.centre_slot_operational_snapshot
  to anon, authenticated;

grant select on public.farmer_queue_live
  to anon, authenticated;

grant select on public.centre_operational_snapshot
  to anon, authenticated;

commit;

-- ============================================================================
-- OPTIONAL VALIDATION QUERIES (run after the migration)
-- ============================================================================
--
-- select farmer_id, attendance_status, attendance_at, queue_entered_at
-- from public.farmer_status
-- order by farmer_id;
--
-- select *
-- from public.farmer_queue_live
-- order by centre_id, procurement_date, window_start, queue_position;
--
-- select *
-- from public.centre_slot_operational_snapshot
-- order by service_date, centre_id, window_start;
--
-- select *
-- from public.centre_operational_snapshot
-- order by centre_id;
--
-- select public.get_farmer_queue_snapshot('F001');
--
-- select *
-- from public.centre_unavailability
-- order by service_date, centre_id;
