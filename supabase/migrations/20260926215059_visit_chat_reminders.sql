-- The "calm clinic" features:
--  1. Video preference (doctor's camera on/off) and "doctor joined" for the
--     waiting room.
--  2. Visit summary the doctor writes for the patient (shareable card).
--  3. Free 24-hour chat after each consultation, with visit context.
--  4. Medicine reminders created from prescriptions (pushed by cron).
--  5. Doctor cockpit: "your usual" prescriptions and today's numbers.
--  6. Voice notes attached to the intake (private storage).

------------------------------------------------------------------
-- 1. Consultation columns
------------------------------------------------------------------
alter table public.consultations
  add column if not exists doctor_video_preferred boolean not null default true,
  add column if not exists doctor_joined_at timestamptz,
  add column if not exists summary_for_patient text
    check (summary_for_patient is null or length(summary_for_patient) <= 2000),
  add column if not exists red_flags text
    check (red_flags is null or length(red_flags) <= 1000),
  add column if not exists follow_up_on date,
  add column if not exists chat_closes_at timestamptz;

alter table public.intake_forms
  add column if not exists voice_note_path text;

-- The patient chooses whether they'd like the doctor's camera on.
create or replace function public.set_video_preference(p_consultation_id uuid, p_doctor_video boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.consultations set doctor_video_preferred = p_doctor_video
  where id = p_consultation_id and patient_id = auth.uid()
    and status in ('awaiting_payment', 'matched', 'in_progress', 'scheduled');
  if not found then raise exception 'not your consultation'; end if;
end $$;

-- The doctor opened the call screen: ends the patient's waiting room.
create or replace function public.mark_doctor_joined(p_consultation_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.consultations set doctor_joined_at = coalesce(doctor_joined_at, now())
  where id = p_consultation_id and doctor_id = auth.uid() and status = 'in_progress';
end $$;

------------------------------------------------------------------
-- 2. Visit summary
------------------------------------------------------------------
create or replace function public.save_visit_summary(
  p_consultation_id uuid, p_summary text, p_red_flags text, p_follow_up_on date
) returns void language plpgsql security definer set search_path = public as $$
declare v_c record;
begin
  select * into v_c from public.consultations where id = p_consultation_id;
  if v_c.id is null or v_c.doctor_id is distinct from auth.uid() then
    raise exception 'not your consultation';
  end if;
  if not (v_c.status in ('matched', 'in_progress')
          or (v_c.status = 'completed' and v_c.ended_at > now() - interval '24 hours')) then
    raise exception 'consultation_not_active';
  end if;
  update public.consultations
  set summary_for_patient = nullif(btrim(coalesce(p_summary, '')), ''),
      red_flags = nullif(btrim(coalesce(p_red_flags, '')), ''),
      follow_up_on = p_follow_up_on
  where id = p_consultation_id;
end $$;

------------------------------------------------------------------
-- 3. Free 24-hour chat after the consultation
------------------------------------------------------------------
-- Opening the window when a consultation completes.
create or replace function public.consultation_chat_window() returns trigger
language plpgsql as $$
begin
  if new.status = 'completed' and old.status is distinct from 'completed' then
    new.chat_closes_at := coalesce(new.ended_at, now()) + interval '24 hours';
  end if;
  return new;
end $$;

drop trigger if exists consultations_chat_window on public.consultations;
create trigger consultations_chat_window
  before update of status on public.consultations
  for each row execute function public.consultation_chat_window();

-- Consultations that already finished recently get their window too.
update public.consultations
set chat_closes_at = coalesce(ended_at, updated_at) + interval '24 hours'
where status = 'completed' and chat_closes_at is null;

create table if not exists public.consultation_messages (
  id uuid primary key default gen_random_uuid(),
  consultation_id uuid not null references public.consultations (id) on delete cascade,
  sender_id uuid references public.users (id) on delete set null,
  kind text not null default 'text' check (kind in ('text', 'system')),
  body text not null check (length(body) between 1 and 2000),
  created_at timestamptz not null default now()
);
create index if not exists consultation_messages_consultation_idx
  on public.consultation_messages (consultation_id, created_at);

alter table public.consultation_messages enable row level security;
create policy consultation_messages_read on public.consultation_messages
  for select to authenticated using (
    exists (select 1 from public.consultations c
            where c.id = consultation_id and auth.uid() in (c.patient_id, c.doctor_id))
  );

do $$ begin
  alter publication supabase_realtime add table public.consultation_messages;
exception when duplicate_object then null; end $$;

-- Who has read up to when (for unread counts).
create table if not exists public.chat_reads (
  consultation_id uuid not null references public.consultations (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  last_read_at timestamptz not null default now(),
  primary key (consultation_id, user_id)
);
alter table public.chat_reads enable row level security;
create policy chat_reads_owner on public.chat_reads
  for select to authenticated using (user_id = auth.uid());

create or replace function public.send_chat_message(p_consultation_id uuid, p_body text)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_c record; v_id uuid; v_body text := btrim(coalesce(p_body, ''));
begin
  select * into v_c from public.consultations where id = p_consultation_id;
  if v_c.id is null or auth.uid() not in (v_c.patient_id, v_c.doctor_id) then
    raise exception 'not your consultation';
  end if;
  if v_c.chat_closes_at is null or v_c.chat_closes_at < now() then
    raise exception 'chat_closed';
  end if;
  if length(v_body) = 0 then raise exception 'empty message'; end if;
  insert into public.consultation_messages (consultation_id, sender_id, body)
  values (p_consultation_id, auth.uid(), left(v_body, 2000))
  returning id into v_id;
  insert into public.chat_reads (consultation_id, user_id, last_read_at)
  values (p_consultation_id, auth.uid(), now())
  on conflict (consultation_id, user_id) do update set last_read_at = now();
  return v_id;
end $$;

create or replace function public.mark_chat_read(p_consultation_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from public.consultations
                 where id = p_consultation_id and auth.uid() in (patient_id, doctor_id)) then
    raise exception 'not your consultation';
  end if;
  insert into public.chat_reads (consultation_id, user_id, last_read_at)
  values (p_consultation_id, auth.uid(), now())
  on conflict (consultation_id, user_id) do update set last_read_at = now();
end $$;

-- My chats: the other person, last message, unread count, window.
create or replace function public.my_chats()
returns table (
  consultation_id uuid, other_id uuid, other_name text, other_avatar text,
  other_role text, specialty text, symptoms text, consulted_at timestamptz,
  closes_at timestamptz, is_open boolean, last_body text, last_at timestamptz,
  last_from_me boolean, unread bigint
) language sql stable security definer set search_path = public as $$
  select c.id,
         other.id,
         public.display_name(other.id),
         other.avatar_url,
         other.role::text,
         c.specialty_requested,
         c.symptom_summary,
         coalesce(c.started_at, c.created_at),
         c.chat_closes_at,
         c.chat_closes_at > now(),
         m.body,
         coalesce(m.created_at, c.ended_at),
         m.sender_id = auth.uid(),
         (select count(*) from public.consultation_messages x
          where x.consultation_id = c.id
            and x.sender_id is distinct from auth.uid()
            and x.created_at > coalesce((select r.last_read_at from public.chat_reads r
                                         where r.consultation_id = c.id and r.user_id = auth.uid()),
                                        '-infinity'))
  from public.consultations c
  join public.users other
    on other.id = case when c.patient_id = auth.uid() then c.doctor_id else c.patient_id end
  left join lateral (
    select body, created_at, sender_id from public.consultation_messages
    where consultation_id = c.id order by created_at desc limit 1
  ) m on true
  where auth.uid() in (c.patient_id, c.doctor_id)
    and c.chat_closes_at is not null
  order by coalesce(m.created_at, c.ended_at, c.created_at) desc
  limit 100;
$$;

-- New message -> tell the other person (system messages have their own alerts).
create or replace function public.chat_message_notifications() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_c record; v_to uuid;
begin
  if new.kind <> 'text' then return new; end if;
  select patient_id, doctor_id into v_c from public.consultations where id = new.consultation_id;
  v_to := case when new.sender_id = v_c.patient_id then v_c.doctor_id else v_c.patient_id end;
  if v_to is null then return new; end if;
  perform public.notify(v_to, 'chat_message', public.display_name(new.sender_id),
    left(new.body, 140), jsonb_build_object('consultation_id', new.consultation_id));
  return new;
end $$;

drop trigger if exists consultation_messages_notify on public.consultation_messages;
create trigger consultation_messages_notify
  after insert on public.consultation_messages
  for each row execute function public.chat_message_notifications();

-- The "consultation finished" message now mentions the free chat.
create or replace function public.consultation_notifications() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_doctor text := case when new.doctor_id is null then 'Your doctor'
                        else public.display_name(new.doctor_id) end;
  v_data jsonb := jsonb_build_object('consultation_id', new.id, 'mode', new.mode);
begin
  if new.status is not distinct from old.status then return new; end if;

  if new.status = 'in_progress' and old.status = 'scheduled' then
    if auth.uid() is not distinct from new.patient_id then
      perform public.notify(new.doctor_id, 'patient_waiting',
        public.display_name(new.patient_id) || ' is waiting',
        'Your appointment has started. Tap to join the video call.', v_data);
    else
      perform public.notify(new.patient_id, 'doctor_ready', v_doctor || ' is ready for you',
        'Your appointment has started. Tap to join the video call.', v_data);
    end if;
  end if;

  if new.status = 'completed' then
    perform public.notify(new.patient_id, 'consultation_completed', 'Consultation finished',
      'Your visit summary is ready. You can message ' || v_doctor
        || ' free for 24 hours, e.g. if a medicine isn''t available.', v_data);
  end if;
  return new;
end $$;

-- Doctors may send a new prescription for up to 24 hours after the call
-- (matches the chat window); it also appears in the chat.
create or replace function public.issue_prescription(
  p_consultation_id uuid,
  p_items jsonb,
  p_valid_days int default 30
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_c record;
  v_id uuid;
  v_item jsonb;
  v_drug uuid;
  v_text text;
  v_doctor_name text;
begin
  select id, patient_id, doctor_id, status, ended_at into v_c
  from public.consultations
  where id = p_consultation_id;

  if v_c.id is null or v_c.doctor_id is distinct from auth.uid() then
    raise exception 'not your consultation';
  end if;
  if not (
    v_c.status in ('matched', 'in_progress')
    or (v_c.status = 'completed' and v_c.ended_at > now() - interval '24 hours')
  ) then
    raise exception 'consultation_not_active';
  end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array'
     or jsonb_array_length(p_items) = 0 then
    raise exception 'prescription_empty';
  end if;
  if jsonb_array_length(p_items) > 20 then
    raise exception 'prescription_too_long';
  end if;

  insert into public.prescriptions (consultation_id, patient_id, doctor_id, source, valid_until)
  values (v_c.id, v_c.patient_id, auth.uid(), 'app',
          current_date + greatest(1, least(coalesce(p_valid_days, 30), 90)))
  returning id into v_id;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_drug := nullif(v_item ->> 'drug_id', '')::uuid;
    v_text := nullif(btrim(coalesce(v_item ->> 'free_text_name', '')), '');
    if v_drug is null and v_text is null then
      raise exception 'prescription_item_invalid';
    end if;
    insert into public.prescription_items (
      prescription_id, drug_id, free_text_name, dosage, quantity, instructions
    ) values (
      v_id, v_drug,
      case when v_drug is null then left(v_text, 200) end,
      left(nullif(btrim(coalesce(v_item ->> 'dosage', '')), ''), 200),
      greatest(1, least(coalesce((v_item ->> 'quantity')::int, 1), 1000)),
      left(nullif(btrim(coalesce(v_item ->> 'instructions', '')), ''), 500)
    );
  end loop;

  select nullif(name, '') into v_doctor_name from public.doctor_profiles where user_id = auth.uid();

  if v_c.status = 'completed' then
    insert into public.consultation_messages (consultation_id, sender_id, kind, body)
    values (v_c.id, auth.uid(), 'system',
            coalesce(v_doctor_name, 'Your doctor') || ' sent a new prescription.');
  end if;

  perform public.notify(
    v_c.patient_id, 'prescription_issued', 'Your prescription is ready',
    coalesce(v_doctor_name, 'Your doctor')
      || ' sent you a prescription. You can order the medicines now.',
    jsonb_build_object('prescription_id', v_id, 'consultation_id', v_c.id)
  );
  return v_id;
end $$;

------------------------------------------------------------------
-- 4. Medicine reminders
------------------------------------------------------------------
create table if not exists public.medication_schedules (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null default auth.uid() references public.users (id) on delete cascade,
  prescription_item_id uuid references public.prescription_items (id) on delete set null,
  drug_name text not null check (length(drug_name) between 1 and 200),
  dosage text check (dosage is null or length(dosage) <= 200),
  times text[] not null check (cardinality(times) between 1 and 6),  -- 'HH:MI', Nairobi time
  start_on date not null default (now() at time zone 'Africa/Nairobi')::date,
  end_on date not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint medication_schedules_dates check (end_on >= start_on and end_on <= start_on + 365)
);
create index if not exists medication_schedules_patient_idx on public.medication_schedules (patient_id);

create table if not exists public.dose_logs (
  id uuid primary key default gen_random_uuid(),
  schedule_id uuid not null references public.medication_schedules (id) on delete cascade,
  due_at timestamptz not null,
  status text not null default 'due' check (status in ('due', 'taken', 'skipped')),
  taken_at timestamptz,
  constraint dose_logs_unique unique (schedule_id, due_at)
);

alter table public.medication_schedules enable row level security;
alter table public.dose_logs enable row level security;
create policy medication_schedules_owner on public.medication_schedules
  for all to authenticated using (patient_id = auth.uid()) with check (patient_id = auth.uid());
create policy dose_logs_owner on public.dose_logs
  for all to authenticated
  using (exists (select 1 from public.medication_schedules s
                 where s.id = schedule_id and s.patient_id = auth.uid()))
  with check (exists (select 1 from public.medication_schedules s
                      where s.id = schedule_id and s.patient_id = auth.uid()));

-- Every 5 minutes: remind about doses that just came due (within 30 min).
create or replace function public.send_dose_reminders()
returns void language plpgsql security definer set search_path = public as $$
declare
  rec record;
  v_today date := (now() at time zone 'Africa/Nairobi')::date;
  v_due timestamptz;
  v_log uuid;
  t text;
begin
  for rec in
    select * from public.medication_schedules
    where active and v_today between start_on and end_on
  loop
    foreach t in array rec.times loop
      v_due := (v_today + t::time) at time zone 'Africa/Nairobi';
      if v_due <= now() and v_due > now() - interval '30 minutes' then
        insert into public.dose_logs (schedule_id, due_at)
        values (rec.id, v_due)
        on conflict (schedule_id, due_at) do nothing
        returning id into v_log;
        if v_log is not null then
          perform public.notify(rec.patient_id, 'dose_due',
            'Time for your ' || rec.drug_name,
            coalesce(rec.dosage, 'Your scheduled dose') || '. Tap when you''ve taken it.',
            jsonb_build_object('schedule_id', rec.id, 'dose_log_id', v_log));
        end if;
      end if;
    end loop;
  end loop;
  -- Finished courses switch themselves off.
  update public.medication_schedules set active = false where active and end_on < v_today;
end $$;

do $$ begin
  perform cron.schedule('send-dose-reminders', '*/5 * * * *', 'select public.send_dose_reminders()');
end $$;

------------------------------------------------------------------
-- 5. Doctor cockpit
------------------------------------------------------------------
-- The doctor's most-used medicines and doses, for one-tap prescribing.
create or replace function public.doctor_usual_prescriptions(p_limit int default 6)
returns table (drug_id uuid, drug_name text, dosage text, quantity int, instructions text, times_used bigint)
language sql stable security definer set search_path = public as $$
  select i.drug_id, d.generic_name, i.dosage,
         mode() within group (order by i.quantity),
         mode() within group (order by i.instructions),
         count(*)
  from public.prescription_items i
  join public.prescriptions p on p.id = i.prescription_id and p.doctor_id = auth.uid()
  join public.drugs d on d.id = i.drug_id
  where i.drug_id is not null
  group by i.drug_id, d.generic_name, i.dosage
  order by count(*) desc, max(p.issued_at) desc
  limit least(greatest(p_limit, 1), 12);
$$;

-- Today's numbers for the doctor's dashboard (Nairobi day).
create or replace function public.doctor_today_stats()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'patients', (select count(*) from public.consultations
                 where doctor_id = auth.uid() and status = 'completed'
                   and (ended_at at time zone 'Africa/Nairobi')::date
                       = (now() at time zone 'Africa/Nairobi')::date),
    'earnings', (select coalesce(sum(p.amount), 0) from public.payments p
                 join public.consultations c on c.id = p.consultation_id
                 where c.doctor_id = auth.uid() and p.status = 'succeeded'
                   and (p.created_at at time zone 'Africa/Nairobi')::date
                       = (now() at time zone 'Africa/Nairobi')::date),
    'rating', (select rating_avg from public.doctor_profiles where user_id = auth.uid()),
    'ratings', (select rating_count from public.doctor_profiles where user_id = auth.uid()),
    'open_chats', (select count(*) from public.consultations
                   where doctor_id = auth.uid() and chat_closes_at > now())
  );
$$;

------------------------------------------------------------------
-- 6. Voice notes (private)
------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('voice-notes', 'voice-notes', false, 5242880,
        array['audio/mp4', 'audio/m4a', 'audio/x-m4a', 'audio/aac', 'audio/webm', 'audio/ogg', 'audio/mpeg', 'audio/wav'])
on conflict (id) do nothing;

drop policy if exists voice_notes_owner_insert on storage.objects;
create policy voice_notes_owner_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'voice-notes' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists voice_notes_owner_read on storage.objects;
create policy voice_notes_owner_read on storage.objects
  for select to authenticated
  using (bucket_id = 'voice-notes' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists voice_notes_doctor_read on storage.objects;
create policy voice_notes_doctor_read on storage.objects
  for select to authenticated
  using (
    bucket_id = 'voice-notes' and exists (
      select 1 from public.intake_forms f
      join public.consultations c on c.id = f.consultation_id
      where f.voice_note_path = objects.name and c.doctor_id = auth.uid()
    )
  );

create or replace function public.attach_voice_note(p_consultation_id uuid, p_path text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if split_part(p_path, '/', 1) <> auth.uid()::text then raise exception 'invalid path'; end if;
  update public.intake_forms f set voice_note_path = p_path
  from public.consultations c
  where f.consultation_id = p_consultation_id and c.id = f.consultation_id
    and c.patient_id = auth.uid();
  if not found then raise exception 'not your consultation'; end if;
end $$;

------------------------------------------------------------------
-- Privileges
------------------------------------------------------------------
revoke all on function
  public.set_video_preference(uuid, boolean),
  public.mark_doctor_joined(uuid),
  public.save_visit_summary(uuid, text, text, date),
  public.consultation_chat_window(),
  public.send_chat_message(uuid, text),
  public.mark_chat_read(uuid),
  public.my_chats(),
  public.chat_message_notifications(),
  public.send_dose_reminders(),
  public.doctor_usual_prescriptions(int),
  public.doctor_today_stats(),
  public.attach_voice_note(uuid, text)
from public, anon, authenticated;
grant execute on function
  public.set_video_preference(uuid, boolean),
  public.mark_doctor_joined(uuid),
  public.save_visit_summary(uuid, text, text, date),
  public.send_chat_message(uuid, text),
  public.mark_chat_read(uuid),
  public.my_chats(),
  public.doctor_usual_prescriptions(int),
  public.doctor_today_stats(),
  public.attach_voice_note(uuid, text)
to authenticated;
