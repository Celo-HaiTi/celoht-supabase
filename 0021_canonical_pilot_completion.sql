-- Complete pilot education, verified-wallet, and planting-evidence workflows.
-- Existing transaction, donation, and impact ledgers remain separate.

-- =========================================================
-- VERIFIED WALLET OWNERSHIP
-- =========================================================
do $$
begin
  if exists (
    select 1 from public.wallet_identities
    where is_primary and verified_at is null
  ) then
    raise exception 'preflight required: primary wallet identities must be verified before migration 0021';
  end if;

  if exists (
    select 1
    from public.agent_profiles a
    left join public.wallet_identities wi on wi.id = a.wallet_identity_id
    where wi.id is null or wi.profile_id <> a.profile_id or wi.verified_at is null
  ) then
    raise exception 'preflight required: existing agent profiles must reference their owner''s verified wallet';
  end if;
end;
$$;

alter table public.wallet_identities
  add constraint wallet_identities_primary_requires_verification
  check (not is_primary or verified_at is not null);

revoke insert, update, delete on public.wallet_identities from anon, authenticated;
grant select on public.wallet_identities to authenticated;
grant insert (profile_id, address, chain_id) on public.wallet_identities to authenticated;

create or replace function public.require_verified_agent_wallet()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if not exists (
    select 1
    from public.wallet_identities wi
    where wi.id = new.wallet_identity_id
      and wi.profile_id = new.profile_id
      and wi.verified_at is not null
  ) then
    raise exception 'agent application requires the applicant''s verified wallet'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger trg_agent_profiles_require_verified_wallet
  before insert or update of profile_id, wallet_identity_id on public.agent_profiles
  for each row execute function public.require_verified_agent_wallet();

revoke execute on function public.require_verified_agent_wallet() from public, anon, authenticated;

-- =========================================================
-- EDUCATION QUIZZES
-- =========================================================
create table public.quizzes (
  id            uuid primary key default gen_random_uuid(),
  lesson_id     uuid not null references public.lessons(id) on delete cascade,
  title         text not null check (length(btrim(title)) between 1 and 200),
  status        text not null default 'draft' check (status in ('draft','published','archived')),
  passing_score numeric(5,2) not null default 70 check (passing_score between 0 and 100),
  created_by    uuid references public.profiles(id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create table public.quiz_questions (
  id           uuid primary key default gen_random_uuid(),
  quiz_id      uuid not null references public.quizzes(id) on delete cascade,
  prompt       text not null check (length(btrim(prompt)) between 1 and 10000),
  order_index  integer not null check (order_index >= 0),
  created_at   timestamptz not null default now(),
  constraint quiz_questions_id_quiz_unique unique (id, quiz_id),
  constraint quiz_questions_order_unique unique (quiz_id, order_index)
);

create table public.quiz_options (
  id           uuid primary key default gen_random_uuid(),
  question_id  uuid not null references public.quiz_questions(id) on delete cascade,
  option_text  text not null check (length(btrim(option_text)) between 1 and 2000),
  order_index  integer not null check (order_index >= 0),
  created_at   timestamptz not null default now(),
  constraint quiz_options_id_question_unique unique (id, question_id),
  constraint quiz_options_order_unique unique (question_id, order_index)
);

create table public.quiz_answer_keys (
  question_id        uuid primary key references public.quiz_questions(id) on delete cascade,
  correct_option_id  uuid not null,
  created_at         timestamptz not null default now(),
  constraint quiz_answer_keys_option_question_fk
    foreign key (correct_option_id, question_id)
    references public.quiz_options(id, question_id) on delete cascade
);

create table public.quiz_attempts (
  id            uuid primary key default gen_random_uuid(),
  quiz_id       uuid not null references public.quizzes(id) on delete restrict,
  profile_id    uuid not null references public.profiles(id) on delete cascade,
  started_at    timestamptz not null default now(),
  submitted_at  timestamptz,
  score         numeric(5,2),
  passed        boolean,
  graded_at     timestamptz,
  constraint quiz_attempts_id_quiz_unique unique (id, quiz_id),
  constraint quiz_attempts_score_range check (score is null or score between 0 and 100),
  constraint quiz_attempts_grade_consistency check (
    (graded_at is null and score is null and passed is null)
    or (graded_at is not null and submitted_at is not null and score is not null and passed is not null)
  ),
  constraint quiz_attempts_submission_order check (submitted_at is null or submitted_at >= started_at),
  constraint quiz_attempts_grading_order check (graded_at is null or graded_at >= submitted_at)
);

create table public.quiz_responses (
  attempt_id          uuid not null,
  quiz_id             uuid not null,
  question_id         uuid not null,
  selected_option_id  uuid not null,
  answered_at         timestamptz not null default now(),
  primary key (attempt_id, question_id),
  constraint quiz_responses_attempt_fk
    foreign key (attempt_id, quiz_id)
    references public.quiz_attempts(id, quiz_id) on delete cascade,
  constraint quiz_responses_question_fk
    foreign key (question_id, quiz_id)
    references public.quiz_questions(id, quiz_id) on delete restrict,
  constraint quiz_responses_option_fk
    foreign key (selected_option_id, question_id)
    references public.quiz_options(id, question_id) on delete restrict
);

create index quiz_questions_quiz_order_idx on public.quiz_questions (quiz_id, order_index);
create index quiz_attempts_profile_quiz_idx on public.quiz_attempts (profile_id, quiz_id, started_at desc);
create index quiz_responses_attempt_idx on public.quiz_responses (attempt_id);

drop trigger if exists trg_quizzes_updated_at on public.quizzes;
create trigger trg_quizzes_updated_at
  before update on public.quizzes
  for each row execute function public.set_updated_at();

alter table public.quizzes enable row level security;
alter table public.quiz_questions enable row level security;
alter table public.quiz_options enable row level security;
alter table public.quiz_answer_keys enable row level security;
alter table public.quiz_attempts enable row level security;
alter table public.quiz_responses enable row level security;

revoke all on public.quizzes, public.quiz_questions, public.quiz_options,
  public.quiz_answer_keys, public.quiz_attempts, public.quiz_responses
  from anon, authenticated;
grant select on public.quizzes, public.quiz_questions, public.quiz_options,
  public.quiz_attempts, public.quiz_responses to authenticated;
grant insert (quiz_id, profile_id) on public.quiz_attempts to authenticated;
grant insert (attempt_id, quiz_id, question_id, selected_option_id),
  update (selected_option_id) on public.quiz_responses to authenticated;

create policy quizzes_select_published on public.quizzes for select
  using (status = 'published' or public.has_permission('education.manage'));
create policy quizzes_manage on public.quizzes for all
  using (public.has_permission('education.manage'))
  with check (public.has_permission('education.manage'));

create policy quiz_questions_select_published on public.quiz_questions for select
  using (exists (
    select 1 from public.quizzes q
    where q.id = quiz_id and q.status = 'published'
  ) or public.has_permission('education.manage'));
create policy quiz_questions_manage on public.quiz_questions for all
  using (public.has_permission('education.manage'))
  with check (public.has_permission('education.manage'));

create policy quiz_options_select_published on public.quiz_options for select
  using (exists (
    select 1
    from public.quiz_questions qq
    join public.quizzes q on q.id = qq.quiz_id
    where qq.id = question_id and q.status = 'published'
  ) or public.has_permission('education.manage'));
create policy quiz_options_manage on public.quiz_options for all
  using (public.has_permission('education.manage'))
  with check (public.has_permission('education.manage'));

create policy quiz_attempts_select_own on public.quiz_attempts for select
  using (profile_id = auth.uid() or public.has_permission('education.manage'));
create policy quiz_attempts_insert_own on public.quiz_attempts for insert
  with check (
    profile_id = auth.uid()
    and exists (select 1 from public.quizzes q where q.id = quiz_id and q.status = 'published')
  );

create policy quiz_responses_select_own on public.quiz_responses for select
  using (exists (
    select 1 from public.quiz_attempts a
    where a.id = attempt_id and a.profile_id = auth.uid()
  ) or public.has_permission('education.manage'));
create policy quiz_responses_insert_own on public.quiz_responses for insert
  with check (exists (
    select 1 from public.quiz_attempts a
    where a.id = attempt_id and a.quiz_id = quiz_id
      and a.profile_id = auth.uid() and a.submitted_at is null
  ));
create policy quiz_responses_update_own on public.quiz_responses for update
  using (exists (
    select 1 from public.quiz_attempts a
    where a.id = attempt_id and a.quiz_id = quiz_id
      and a.profile_id = auth.uid() and a.submitted_at is null
  ))
  with check (exists (
    select 1 from public.quiz_attempts a
    where a.id = attempt_id and a.quiz_id = quiz_id
      and a.profile_id = auth.uid() and a.submitted_at is null
  ));

-- Answer keys and grading fields are exclusively writable/readable by trusted services.
comment on table public.quiz_answer_keys is
  'SERVER ONLY. Correct answers are never exposed to Data API roles.';
comment on table public.quiz_attempts is
  'Users may create and read their own attempts. Submission and grading fields are server-owned.';

-- =========================================================
-- PLANTING EVIDENCE AND REVIEW HISTORY
-- =========================================================
alter table public.reforestation_evidence
  add column submitted_by uuid references public.profiles(id) on delete set null;

create index reforestation_evidence_submitter_idx
  on public.reforestation_evidence (submitted_by, created_at desc)
  where submitted_by is not null;

create table public.reforestation_evidence_reviews (
  id             uuid primary key default gen_random_uuid(),
  evidence_id    uuid not null references public.reforestation_evidence(id) on delete restrict,
  reviewer_id    uuid not null references public.profiles(id) on delete restrict,
  decision       text not null check (decision in ('approved','rejected','changes_requested')),
  trees_verified integer check (trees_verified is null or trees_verified >= 0),
  notes          text,
  reviewed_at    timestamptz not null default now(),
  constraint evidence_reviews_approved_count_check
    check (decision <> 'approved' or trees_verified is not null)
);

alter table public.audit_logs
  drop constraint audit_logs_action_known;
alter table public.audit_logs
  add constraint audit_logs_action_known check (action in (
    'kyc_review',
    'agent_approval',
    'agent_suspension',
    'agent_rejection',
    'evidence_verification',
    'evidence_rejection',
    'evidence_changes_requested',
    'wallet_verification',
    'quiz_grading',
    'course_publication',
    'project_publication',
    'admin_configuration_change'
  ));

create index reforestation_evidence_reviews_evidence_idx
  on public.reforestation_evidence_reviews (evidence_id, reviewed_at desc);
create index reforestation_evidence_reviews_reviewer_idx
  on public.reforestation_evidence_reviews (reviewer_id, reviewed_at desc);

alter table public.reforestation_evidence_reviews enable row level security;

drop policy reforestation_evidence_write_admin on public.reforestation_evidence;
create policy reforestation_evidence_select_submitter
  on public.reforestation_evidence for select
  using (submitted_by = auth.uid());
create policy reforestation_evidence_insert_submitter
  on public.reforestation_evidence for insert
  with check (
    submitted_by = auth.uid()
    and status = 'pending'
    and verified_by is null
    and verified_at is null
    and trees_verified is null
    and exists (
      select 1 from public.reforestation_projects p
      where p.id = project_id and p.status = 'published'
    )
  );

revoke insert, update, delete on public.reforestation_evidence from anon, authenticated;
grant insert (project_id, storage_path, submitted_by)
  on public.reforestation_evidence to authenticated;

create policy evidence_reviews_select_owner_or_reviewer
  on public.reforestation_evidence_reviews for select
  using (
    public.has_permission('impact.review')
    or exists (
      select 1 from public.reforestation_evidence e
      where e.id = evidence_id and e.submitted_by = auth.uid()
    )
  );
create policy evidence_reviews_insert_reviewer
  on public.reforestation_evidence_reviews for insert
  with check (
    reviewer_id = auth.uid()
    and public.has_permission('impact.review')
    and exists (
      select 1 from public.reforestation_evidence e
      where e.id = evidence_id and e.submitted_by is distinct from auth.uid()
    )
  );

revoke all on public.reforestation_evidence_reviews from anon, authenticated;
grant select, insert on public.reforestation_evidence_reviews to authenticated;

create or replace function public.apply_reforestation_evidence_review()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.reforestation_evidence
  set status = case new.decision
        when 'approved' then 'verified'
        when 'rejected' then 'rejected'
        else 'pending'
      end,
      trees_verified = case when new.decision = 'approved' then new.trees_verified else null end,
      verified_by = case when new.decision = 'approved' then new.reviewer_id else null end,
      verified_at = case when new.decision = 'approved' then new.reviewed_at else null end
  where id = new.evidence_id;

  insert into public.audit_logs (actor_id, action, target_table, target_id, metadata)
  values (
    new.reviewer_id,
    case new.decision
      when 'approved' then 'evidence_verification'
      when 'rejected' then 'evidence_rejection'
      else 'evidence_changes_requested'
    end,
    'reforestation_evidence',
    new.evidence_id,
    jsonb_build_object(
      'review_id', new.id,
      'decision', new.decision,
      'trees_verified', new.trees_verified
    )
  );

  return new;
end;
$$;

create trigger trg_apply_reforestation_evidence_review
  after insert on public.reforestation_evidence_reviews
  for each row execute function public.apply_reforestation_evidence_review();

revoke execute on function public.apply_reforestation_evidence_review() from public, anon, authenticated;

create trigger trg_reforestation_evidence_reviews_append_only
  before update or delete on public.reforestation_evidence_reviews
  for each row execute function public.reject_audit_mutation();

comment on table public.reforestation_evidence_reviews is
  'Append-only reviewer decisions. Approved evidence alone updates the verified planting summary; donations are never proof of planting.';

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    grant all on public.quizzes, public.quiz_questions, public.quiz_options,
      public.quiz_answer_keys, public.quiz_attempts, public.quiz_responses,
      public.reforestation_evidence_reviews to service_role;
    grant update (verified_at, is_primary) on public.wallet_identities to service_role;
  end if;
end;
$$;