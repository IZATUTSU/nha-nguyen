-- =====================================================================
-- Nhà Nguyện Ánh Nến: kiểm duyệt, báo cáo và quản trị
-- Chạy SAU schema.sql. Chạy lại nhiều lần cũng không sao.
-- =====================================================================

-- ---------- 1. Danh sách từ cấm (viết thường, giữ dấu; so khớp nguyên từ) ----------
create table if not exists public.tu_cam (tu text primary key);
alter table public.tu_cam enable row level security;   -- không ai đọc trực tiếp; chỉ hàm kiểm duyệt dùng
insert into public.tu_cam (tu) values
  ('đụ'),('địt'),('đéo'),('lồn'),('buồi'),('cặc'),('đĩ'),('cave'),('đần độn'),('óc chó'),('chó đẻ'),('mẹ mày'),('bố mày'),
  ('đm'),('dm'),('đmm'),('dmm'),('đcm'),('dcm'),('vcl'),('vkl'),('vl'),('clm'),('cmm'),('cc'),('cl'),('loz'),('dit'),('djt'),('đjt'),
  ('súc vật'),('thằng chó'),('con đĩ'),('fuck'),('fck'),('shit'),('bitch'),('dick'),('porn'),('sex'),('xxx'),('cá độ'),('nổ hũ'),('tài xỉu')
on conflict do nothing;

-- ---------- 2. Hàm kiểm tra nội dung: trả về lý do vi phạm, hoặc null nếu hợp lệ ----------
create or replace function public.noi_dung_vi_pham(t text)
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  n text;
  w text;
begin
  if t is null or btrim(t) = '' then return null; end if;
  n := ' ' || regexp_replace(lower(t), '[[:space:][:punct:]]+', ' ', 'g') || ' ';
  for w in select tu from public.tu_cam loop
    if position(' ' || w || ' ' in n) > 0 then return 'từ ngữ không phù hợp'; end if;
  end loop;
  if t ~ '([0-9][ .\-]?){8,}[0-9]' then return 'số điện thoại'; end if;
  if lower(t) ~ '(https?://|www\.|t\.me/|zalo\.me|fb\.com|bit\.ly|[a-z0-9-]+\.(com|vn|net|org|xyz|me|io|info|top|link|site|online|shop|store|club|app|ly|gg|biz|tk)([^a-z]|$))' then
    return 'đường link';
  end if;
  if lower(t) ~ '[a-z0-9._%+-]+@[a-z0-9-]+\.[a-z]' then return 'địa chỉ email'; end if;
  return null;
end;
$$;

create or replace function public.kiem_duyet()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  r text;
begin
  r := coalesce(public.noi_dung_vi_pham(new.name), public.noi_dung_vi_pham(to_jsonb(new)->>'text'));
  if r is not null then
    raise exception 'Nội dung có %, không thể đăng.', r using errcode = 'P0001';
  end if;
  return new;
end;
$$;

drop trigger if exists kiem_duyet_nen on public.candles;
create trigger kiem_duyet_nen before insert on public.candles
  for each row execute function public.kiem_duyet();

drop trigger if exists kiem_duyet_y_nguyen on public.intentions;
create trigger kiem_duyet_y_nguyen before insert on public.intentions
  for each row execute function public.kiem_duyet();

-- ---------- 3. Báo cáo: 3 người khác nhau báo cáo thì ý nguyện tự ẩn ----------
create table if not exists public.reports (
  intention_id uuid not null references public.intentions(id) on delete cascade,
  reporter     text not null check (char_length(reporter) between 8 and 64),
  created_at   timestamptz not null default now(),
  primary key (intention_id, reporter)
);
alter table public.reports enable row level security;   -- chỉ thao tác qua hàm bên dưới

create or replace function public.report_intention(p_id uuid, p_reporter text)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  n integer;
  recent integer;
begin
  select count(*) into recent from public.reports where created_at > now() - interval '10 minutes';
  if recent >= 60 then raise exception 'Quá nhiều báo cáo, hãy thử lại sau' using errcode = 'P0001'; end if;
  if not exists (select 1 from public.intentions where id = p_id and not hidden) then return 0; end if;
  insert into public.reports (intention_id, reporter) values (p_id, p_reporter) on conflict do nothing;
  select count(*) into n from public.reports where intention_id = p_id;
  if n >= 3 then update public.intentions set hidden = true where id = p_id; end if;
  return n;
end;
$$;
revoke all on function public.report_intention(uuid, text) from public;
grant execute on function public.report_intention(uuid, text) to anon, authenticated;

-- ---------- 4. Quản trị viên (đăng nhập bằng email trên trang quan-tri.html) ----------
create table if not exists public.admins (email text primary key);
alter table public.admins enable row level security;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.admins where lower(email) = lower(coalesce(auth.jwt() ->> 'email', '')));
$$;

create or replace function public.admin_list()
returns table (id uuid, name text, noi_dung text, prayed integer, hidden boolean, created_at timestamptz, so_bao_cao bigint)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then raise exception 'Chỉ quản trị viên được xem' using errcode = 'P0001'; end if;
  return query
    select i.id, i.name, i.text, i.prayed, i.hidden, i.created_at,
           (select count(*) from public.reports r where r.intention_id = i.id)
      from public.intentions i
     order by i.created_at desc
     limit 300;
end;
$$;

create or replace function public.admin_set_hidden(p_id uuid, p_hidden boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then raise exception 'Chỉ quản trị viên được thao tác' using errcode = 'P0001'; end if;
  update public.intentions set hidden = p_hidden where id = p_id;
  if not p_hidden then delete from public.reports where intention_id = p_id; end if;   -- hiện lại thì xoá các báo cáo cũ
end;
$$;

revoke all on function public.is_admin(), public.admin_list(), public.admin_set_hidden(uuid, boolean) from public, anon;
grant execute on function public.is_admin(), public.admin_list(), public.admin_set_hidden(uuid, boolean) to authenticated;
revoke all on function public.noi_dung_vi_pham(text) from public, anon, authenticated;

-- ---------- 5. Thêm quản trị viên: thay email rồi chạy dòng dưới ----------
-- insert into public.admins (email) values ('email-cua-ban@gmail.com') on conflict do nothing;
