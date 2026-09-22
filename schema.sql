-- Run once in Supabase SQL Editor on a NEW project.
create table public.poll_options (
 id bigint generated always as identity primary key,
 label text not null check (char_length(btrim(label)) between 1 and 80),
 creator uuid not null references auth.users(id),
 created_at timestamptz not null default now()
);
create table public.poll_submissions (
 user_id uuid primary key references auth.users(id),
 submitted_at timestamptz not null default now()
);
create table public.poll_votes (
 user_id uuid not null references public.poll_submissions(user_id),
 option_id bigint not null references public.poll_options(id),
 primary key (user_id, option_id)
);
create index poll_options_creator_idx on public.poll_options(creator);
create index poll_votes_option_idx on public.poll_votes(option_id);

alter table public.poll_options enable row level security;
alter table public.poll_submissions enable row level security;
alter table public.poll_votes enable row level security;
create policy "Signed-in users see options" on public.poll_options for select to authenticated using (true);
create policy "Users see their submission" on public.poll_submissions for select to authenticated using (user_id = (select auth.uid()));
-- Votes are intentionally not directly readable: only aggregated counts are exposed by RPC.
revoke all on public.poll_options, public.poll_submissions, public.poll_votes from anon, authenticated;
grant select on public.poll_options, public.poll_submissions to authenticated;

create or replace function public.poll_deadline() returns timestamptz
language sql stable set search_path = '' as $$select '2026-10-11 06:59:00+00'::timestamptz$$;

create or replace function public.add_poll_option(p_label text)
returns bigint language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_id bigint; v_label text := btrim(p_label);
begin
 if v_uid is null then raise exception '请先登录'; end if;
 -- Serialize all operations for this user, even when there is no existing row to lock.
 perform pg_advisory_xact_lock(hashtextextended(v_uid::text, 0));
 if now() >= public.poll_deadline() then raise exception '投票已截止'; end if;
 if exists(select 1 from public.poll_submissions where user_id=v_uid) then raise exception '已提交，无法再添加选项'; end if;
 if v_label is null or char_length(v_label) not between 1 and 80 then raise exception '选项长度须为 1–80 字'; end if;
 if (select count(*) from public.poll_options where creator=v_uid) >= 3 then raise exception '每人最多提出 3 个选项'; end if;
 insert into public.poll_options(label, creator) values(v_label,v_uid) returning id into v_id;
 return v_id;
end $$;

create or replace function public.submit_poll(p_option_ids bigint[])
returns void language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_own int; v_selected int; v_valid int;
begin
 if v_uid is null then raise exception '请先登录'; end if;
 perform pg_advisory_xact_lock(hashtextextended(v_uid::text, 0));
 if now() >= public.poll_deadline() then raise exception '投票已截止'; end if;
 if exists(select 1 from public.poll_submissions where user_id=v_uid) then raise exception '已提交，不能重复投票'; end if;
 if p_option_ids is null then raise exception '请选择有效选项'; end if;
 select count(*) into v_own from public.poll_options where creator=v_uid;
 select count(distinct x) into v_selected from unnest(p_option_ids) x;
 if coalesce(array_length(p_option_ids,1),0) <> v_selected then raise exception '选项不能重复'; end if;
 if v_own + v_selected < 1 or v_own + v_selected > 3 then raise exception '提出选项与投票合计须为 1–3 次'; end if;
 select count(*) into v_valid from public.poll_options where id = any(p_option_ids) and creator <> v_uid;
 if v_valid <> v_selected then raise exception '只能选择其他人创建的有效选项'; end if;
 insert into public.poll_submissions(user_id) values(v_uid);
 -- Newly created options automatically count as one vote for their creator on submission.
 insert into public.poll_votes(user_id,option_id)
 select v_uid,id from public.poll_options where creator=v_uid;
 insert into public.poll_votes(user_id,option_id)
 select v_uid,unnest(p_option_ids);
end $$;

create or replace function public.poll_results()
returns table(option_id bigint, votes bigint) language sql stable security definer set search_path = '' as $$
 select o.id, count(v.option_id)::bigint from public.poll_options o
 left join public.poll_votes v on v.option_id=o.id
 where auth.uid() is not null
 group by o.id order by o.id;
$$;

revoke all on function public.poll_deadline(), public.add_poll_option(text), public.submit_poll(bigint[]), public.poll_results() from public, anon;
grant execute on function public.poll_deadline(), public.add_poll_option(text), public.submit_poll(bigint[]), public.poll_results() to authenticated;
-- Options are public to logged-in participants only. Enable option updates via Realtime if desired:
-- alter publication supabase_realtime add table public.poll_options;
