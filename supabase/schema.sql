-- =====================================================================
-- Nhà Nguyện Ánh Nến: dữ liệu dùng chung cho nến và tường ý nguyện
-- Dán toàn bộ vào Supabase → SQL Editor → New query → Run.
-- Chạy lại nhiều lần cũng không sao (không xoá dữ liệu cũ).
-- =====================================================================

-- ---------- Bảng ----------
create table if not exists public.candles (
  id          uuid primary key default gen_random_uuid(),
  name        text not null default 'Khách hành hương' check (char_length(name) between 1 and 24),
  created_at  timestamptz not null default now()
);

create table if not exists public.intentions (
  id          uuid primary key default gen_random_uuid(),
  name        text not null default 'Khách hành hương' check (char_length(name) between 1 and 24),
  text        text not null check (char_length(btrim(text)) between 1 and 160),
  prayed      integer not null default 0 check (prayed >= 0),
  hidden      boolean not null default false,   -- quản trị viên đặt true để ẩn ý nguyện không phù hợp
  created_at  timestamptz not null default now()
);

create index if not exists candles_created_idx    on public.candles (created_at desc);
create index if not exists intentions_created_idx on public.intentions (created_at desc);

-- ---------- Bảo mật theo dòng (RLS) ----------
alter table public.candles    enable row level security;
alter table public.intentions enable row level security;

-- Nến: ai cũng xem được nến trong 24 giờ qua và thắp được nến mới
drop policy if exists "xem nen 24 gio" on public.candles;
create policy "xem nen 24 gio" on public.candles
  for select to anon, authenticated
  using (created_at > now() - interval '24 hours');

drop policy if exists "thap nen" on public.candles;
create policy "thap nen" on public.candles
  for insert to anon, authenticated
  with check (created_at between now() - interval '1 minute' and now() + interval '1 minute');

-- Ý nguyện: xem được ý nguyện chưa bị ẩn trong 30 ngày qua; ghi mới thì luôn bắt đầu từ 0 lượt cầu nguyện
drop policy if exists "xem y nguyen" on public.intentions;
create policy "xem y nguyen" on public.intentions
  for select to anon, authenticated
  using (not hidden and created_at > now() - interval '30 days');

drop policy if exists "ghi y nguyen" on public.intentions;
create policy "ghi y nguyen" on public.intentions
  for insert to anon, authenticated
  with check (prayed = 0 and hidden = false
              and created_at between now() - interval '1 minute' and now() + interval '1 minute');

-- Người chơi chỉ được xem và thêm, không được sửa hay xoá
revoke update, delete on public.candles, public.intentions from anon, authenticated;
grant select, insert on public.candles, public.intentions to anon, authenticated;

-- ---------- "Cầu nguyện cho ý này": tăng đếm an toàn qua một hàm ----------
create or replace function public.pray_for(intention_id uuid)
returns integer
language sql
security definer
set search_path = public
as $$
  update public.intentions
     set prayed = prayed + 1
   where id = intention_id
     and not hidden
     and created_at > now() - interval '30 days'
  returning prayed;
$$;
revoke all on function public.pray_for(uuid) from public;
grant execute on function public.pray_for(uuid) to anon, authenticated;

-- ---------- Chống spam: giới hạn số lượt trong 10 phút cho cả nhà nguyện ----------
create or replace function public.gioi_han_10_phut()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  n integer;
begin
  execute format('select count(*) from %I.%I where created_at > now() - interval ''10 minutes''',
                 tg_table_schema, tg_table_name)
     into n;
  if n >= tg_argv[0]::integer then
    raise exception 'Quá nhiều lượt trong 10 phút, hãy thử lại sau';
  end if;
  return new;
end;
$$;

drop trigger if exists gioi_han_nen on public.candles;
create trigger gioi_han_nen before insert on public.candles
  for each row execute function public.gioi_han_10_phut('150');

drop trigger if exists gioi_han_y_nguyen on public.intentions;
create trigger gioi_han_y_nguyen before insert on public.intentions
  for each row execute function public.gioi_han_10_phut('40');

-- ---------- Bật Realtime để nến và ý nguyện mới hiện ngay cho mọi người ----------
do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'candles') then
    alter publication supabase_realtime add table public.candles;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'intentions') then
    alter publication supabase_realtime add table public.intentions;
  end if;
end;
$$;
