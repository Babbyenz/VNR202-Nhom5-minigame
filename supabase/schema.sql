-- ================================================================
-- GAME LỊCH SỬ VIỆT NAM 1975–1981 - MULTIPLAYER REALTIME
-- Chạy toàn bộ file này trong Supabase > SQL Editor > New query.
-- ================================================================

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.questions (
  id integer primary key,
  category text not null,
  prompt text not null,
  options jsonb not null check (jsonb_typeof(options) = 'array'),
  correct_index smallint not null check (correct_index between 0 and 3),
  explanation text not null
);

create table if not exists public.rooms (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[A-Z0-9]{6}$'),
  status text not null default 'lobby' check (status in ('lobby', 'playing', 'finished')),
  phase text not null default 'question' check (phase in ('question', 'results')),
  host_player_id uuid,
  question_order integer[] not null default '{}',
  current_position integer not null default -1,
  question_started_at timestamptz,
  results_started_at timestamptz,
  question_duration_seconds integer not null default 20 check (question_duration_seconds between 5 and 60),
  total_questions integer not null default 10 check (total_questions between 5 and 15),
  answers_received integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.players (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 2 and 24),
  score integer not null default 0 check (score >= 0),
  is_host boolean not null default false,
  joined_at timestamptz not null default now()
);

create unique index if not exists players_room_name_unique
  on public.players (room_id, lower(name));

create table if not exists public.player_sessions (
  player_id uuid primary key references public.players(id) on delete cascade,
  secret_hash text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.answers (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete cascade,
  question_id integer not null references public.questions(id),
  selected_index smallint not null check (selected_index between 0 and 3),
  is_correct boolean not null,
  response_ms integer not null check (response_ms >= 0),
  correct_rank integer,
  points integer not null default 0 check (points >= 0),
  answered_at timestamptz not null default clock_timestamp(),
  unique (room_id, player_id, question_id)
);

-- Thêm khóa ngoại sau để tránh vòng tham chiếu khi tạo bảng.
do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'rooms_host_player_id_fkey'
  ) then
    alter table public.rooms
      add constraint rooms_host_player_id_fkey
      foreign key (host_player_id) references public.players(id) on delete set null;
  end if;
end $$;

-- Dữ liệu câu hỏi.
insert into public.questions (id, category, prompt, options, correct_index, explanation) values
(1, 'Bối cảnh sau chiến tranh', 'Sau thắng lợi năm 1975, Việt Nam bước sang thời kỳ lịch sử mới nào?',
 '["Hòa bình, độc lập và thống nhất", "Chia cắt lâu dài giữa hai miền", "Tạm ngừng xây dựng đất nước", "Chỉ tập trung phát triển công nghiệp"]', 0,
 'Sau năm 1975, Việt Nam bước vào thời kỳ hòa bình, độc lập và thống nhất, đồng thời bắt đầu khắc phục hậu quả chiến tranh.'),
(2, 'Thống nhất đất nước', 'Yêu cầu cấp thiết sau khi miền Nam được giải phóng hoàn toàn là gì?',
 '["Thống nhất đất nước về mặt nhà nước và hệ thống chính trị", "Tách riêng bộ máy quản lý của hai miền", "Chỉ khôi phục giao thông ở miền Bắc", "Dừng hoạt động của Quốc hội"]', 0,
 'Thống nhất về mặt nhà nước là cơ sở để xây dựng một quốc gia có bộ máy quản lý tập trung và đồng bộ.'),
(3, 'Hiệp thương chính trị', 'Hội nghị Hiệp thương chính trị giữa đại biểu hai miền bắt đầu từ thời điểm nào?',
 '["Tháng 11 năm 1975", "Tháng 4 năm 1976", "Tháng 12 năm 1976", "Tháng 1 năm 1981"]', 0,
 'Từ tháng 11 năm 1975 đến đầu năm 1976, đại biểu hai miền hiệp thương về việc thống nhất đất nước.'),
(4, 'Quốc hội khóa VI', 'Cuộc tổng tuyển cử bầu Quốc hội khóa VI diễn ra vào ngày nào?',
 '["25 tháng 4 năm 1976", "30 tháng 4 năm 1975", "24 tháng 6 năm 1976", "20 tháng 12 năm 1976"]', 0,
 'Ngày 25/4/1976, cuộc tổng tuyển cử được tiến hành trên toàn quốc để bầu Quốc hội chung.'),
(5, 'Quốc hội khóa VI', 'Kỳ họp thứ nhất của Quốc hội khóa VI diễn ra trong khoảng thời gian nào?',
 '["Từ 24/6 đến 3/7/1976", "Từ 14/12 đến 20/12/1976", "Từ 1/1 đến 10/1/1977", "Từ 25/4 đến 30/4/1976"]', 0,
 'Kỳ họp thứ nhất Quốc hội khóa VI diễn ra tại Hà Nội từ ngày 24/6 đến ngày 3/7/1976.'),
(6, 'Quốc hội khóa VI', 'Quốc hội khóa VI quyết định tên nước là gì?',
 '["Cộng hòa xã hội chủ nghĩa Việt Nam", "Việt Nam Dân chủ Cộng hòa", "Liên bang Việt Nam", "Cộng hòa Việt Nam thống nhất"]', 0,
 'Quốc hội khóa VI quyết định tên nước là Cộng hòa xã hội chủ nghĩa Việt Nam.'),
(7, 'Quốc hội khóa VI', 'Thành phố Sài Gòn – Gia Định được đổi tên thành gì?',
 '["Thành phố Hồ Chí Minh", "Thành phố Thống Nhất", "Thành phố Gia Định", "Thành phố Sài Gòn mới"]', 0,
 'Quốc hội khóa VI đổi tên Sài Gòn – Gia Định thành Thành phố Hồ Chí Minh.'),
(8, 'Đại hội IV', 'Đại hội đại biểu toàn quốc lần thứ IV của Đảng diễn ra khi nào?',
 '["Từ 14 đến 20 tháng 12 năm 1976", "Từ 24 tháng 6 đến 3 tháng 7 năm 1976", "Ngày 25 tháng 4 năm 1976", "Từ 1 đến 7 tháng 5 năm 1975"]', 0,
 'Đại hội IV được tổ chức tại Hà Nội từ ngày 14 đến ngày 20/12/1976.'),
(9, 'Đại hội IV', 'Đại hội IV xác định nhiệm vụ chiến lược của cách mạng Việt Nam là gì?',
 '["Xây dựng chủ nghĩa xã hội và bảo vệ vững chắc Tổ quốc", "Chỉ tập trung vào phát triển thương mại", "Tạm dừng cải tạo kinh tế", "Tách riêng chiến lược của hai miền"]', 0,
 'Nhiệm vụ chiến lược là xây dựng thành công chủ nghĩa xã hội và bảo vệ Tổ quốc xã hội chủ nghĩa.'),
(10, 'Đường lối kinh tế', 'Nhiệm vụ trung tâm được Đại hội IV xác định là gì?',
 '["Công nghiệp hóa xã hội chủ nghĩa", "Tư nhân hóa toàn bộ nền kinh tế", "Ngừng phát triển nông nghiệp", "Chỉ nhập khẩu hàng tiêu dùng"]', 0,
 'Đại hội IV xác định công nghiệp hóa xã hội chủ nghĩa là nhiệm vụ trung tâm.'),
(11, 'Kế hoạch 5 năm', 'Kế hoạch Nhà nước 5 năm lần thứ hai được thực hiện trong giai đoạn nào?',
 '["1976–1980", "1975–1979", "1977–1981", "1981–1985"]', 0,
 'Kế hoạch Nhà nước 5 năm lần thứ hai được triển khai trong giai đoạn 1976–1980.'),
(12, 'Khó khăn kinh tế', 'Hạn chế nổi bật của cơ chế quản lý kinh tế thời kỳ này là gì?',
 '["Tập trung, quan liêu, bao cấp", "Quá phụ thuộc vào thương mại điện tử", "Thiếu vốn đầu tư trực tiếp nước ngoài", "Sản xuất hàng tiêu dùng quá dư thừa"]', 0,
 'Cơ chế quản lý tập trung, quan liêu, bao cấp bộc lộ nhiều hạn chế và làm giảm hiệu quả sản xuất.'),
(13, 'Đời sống xã hội', 'Khó khăn nào phổ biến trong đời sống nhân dân giai đoạn này?',
 '["Thiếu lương thực, thiếu hàng tiêu dùng và lạm phát", "Dư thừa lương thực trên toàn quốc", "Giá cả luôn ổn định tuyệt đối", "Cơ sở hạ tầng hoàn toàn hiện đại"]', 0,
 'Đời sống nhân dân gặp nhiều khó khăn do thiếu lương thực, thiếu hàng tiêu dùng và lạm phát.'),
(14, 'Bảo vệ Tổ quốc', 'Lực lượng nào gây hấn và xâm phạm biên giới Tây Nam Việt Nam?',
 '["Tập đoàn Khmer Đỏ", "Thực dân Pháp", "Phát xít Nhật", "Quân đội Hoa Kỳ"]', 0,
 'Các hành động gây hấn của tập đoàn Khmer Đỏ ảnh hưởng nghiêm trọng đến an ninh biên giới Tây Nam.'),
(15, 'Bảo vệ Tổ quốc', 'Hai nhiệm vụ lớn được thực hiện đồng thời trong giai đoạn 1975–1981 là gì?',
 '["Xây dựng chủ nghĩa xã hội và bảo vệ Tổ quốc", "Mở rộng lãnh thổ và dừng sản xuất", "Chỉ phát triển văn hóa và giáo dục", "Chỉ tập trung vào quốc phòng"]', 0,
 'Việt Nam vừa xây dựng đất nước, vừa củng cố quốc phòng và bảo vệ chủ quyền quốc gia.')
on conflict (id) do update set
  category = excluded.category,
  prompt = excluded.prompt,
  options = excluded.options,
  correct_index = excluded.correct_index,
  explanation = excluded.explanation;

-- View công khai không chứa đáp án đúng.
drop view if exists public.question_public;
create view public.question_public as
select id, category, prompt, options
from public.questions;

-- Chỉ cho phép đọc dữ liệu an toàn. Mọi thao tác ghi đi qua RPC bên dưới.
alter table public.questions enable row level security;
alter table public.rooms enable row level security;
alter table public.players enable row level security;
alter table public.player_sessions enable row level security;
alter table public.answers enable row level security;

revoke all on public.questions from anon, authenticated;
revoke all on public.player_sessions from anon, authenticated;
revoke all on public.answers from anon, authenticated;

drop policy if exists "rooms_public_read" on public.rooms;
create policy "rooms_public_read" on public.rooms
for select to anon, authenticated using (true);

drop policy if exists "players_public_read" on public.players;
create policy "players_public_read" on public.players
for select to anon, authenticated using (true);

grant select on public.rooms, public.players, public.question_public to anon, authenticated;

-- Helper xác minh bí mật của người chơi.
create or replace function public.valid_player(p_player_id uuid, p_secret text)
returns boolean
language sql
stable
security definer
set search_path = public, extensions
as $$
  select exists (
    select 1
    from public.player_sessions s
    where s.player_id = p_player_id
      and s.secret_hash = crypt(p_secret, s.secret_hash)
  );
$$;

create or replace function public.create_room(
  p_name text,
  p_secret text,
  p_total_questions integer default 10
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_room_id uuid;
  v_player_id uuid;
  v_code text;
  v_order integer[];
  v_total integer := greatest(5, least(coalesce(p_total_questions, 10), 15));
begin
  if char_length(trim(p_name)) < 2 or char_length(trim(p_name)) > 24 then
    raise exception 'Tên người chơi phải có từ 2 đến 24 ký tự.';
  end if;
  if p_secret is null or char_length(p_secret) < 12 then
    raise exception 'Mã phiên không hợp lệ.';
  end if;

  loop
    v_code := upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));
    exit when not exists (select 1 from public.rooms where code = v_code);
  end loop;

  select array_agg(id)
  into v_order
  from (
    select id from public.questions order by random() limit v_total
  ) q;

  insert into public.rooms (code, total_questions, question_order)
  values (v_code, v_total, v_order)
  returning id into v_room_id;

  insert into public.players (room_id, name, is_host)
  values (v_room_id, trim(p_name), true)
  returning id into v_player_id;

  insert into public.player_sessions (player_id, secret_hash)
  values (v_player_id, crypt(p_secret, gen_salt('bf')));

  update public.rooms
  set host_player_id = v_player_id, updated_at = now()
  where id = v_room_id;

  return jsonb_build_object(
    'room_id', v_room_id,
    'room_code', v_code,
    'player_id', v_player_id,
    'is_host', true
  );
end;
$$;

create or replace function public.join_room(
  p_code text,
  p_name text,
  p_secret text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_room public.rooms%rowtype;
  v_player_id uuid;
begin
  if char_length(trim(p_name)) < 2 or char_length(trim(p_name)) > 24 then
    raise exception 'Tên người chơi phải có từ 2 đến 24 ký tự.';
  end if;
  if p_secret is null or char_length(p_secret) < 12 then
    raise exception 'Mã phiên không hợp lệ.';
  end if;

  select * into v_room
  from public.rooms
  where code = upper(trim(p_code))
  for update;

  if not found then
    raise exception 'Không tìm thấy phòng.';
  end if;
  if v_room.status = 'playing' then
    raise exception 'Trận đấu đang diễn ra, chưa thể tham gia.';
  end if;
  if (select count(*) from public.players where room_id = v_room.id) >= 30 then
    raise exception 'Phòng đã đủ 30 người.';
  end if;
  if exists (
    select 1 from public.players
    where room_id = v_room.id and lower(name) = lower(trim(p_name))
  ) then
    raise exception 'Tên này đã có trong phòng. Hãy chọn tên khác.';
  end if;

  insert into public.players (room_id, name, is_host)
  values (v_room.id, trim(p_name), false)
  returning id into v_player_id;

  insert into public.player_sessions (player_id, secret_hash)
  values (v_player_id, crypt(p_secret, gen_salt('bf')));

  update public.rooms set updated_at = now() where id = v_room.id;

  return jsonb_build_object(
    'room_id', v_room.id,
    'room_code', v_room.code,
    'player_id', v_player_id,
    'is_host', false
  );
end;
$$;

create or replace function public.resume_session(
  p_player_id uuid,
  p_secret text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_result jsonb;
begin
  if not public.valid_player(p_player_id, p_secret) then
    raise exception 'Phiên người chơi không hợp lệ.';
  end if;

  select jsonb_build_object(
    'room_id', r.id,
    'room_code', r.code,
    'player_id', p.id,
    'player_name', p.name,
    'is_host', p.is_host
  )
  into v_result
  from public.players p
  join public.rooms r on r.id = p.room_id
  where p.id = p_player_id;

  if v_result is null then
    raise exception 'Không tìm thấy người chơi.';
  end if;

  return v_result;
end;
$$;

create or replace function public.start_game(
  p_player_id uuid,
  p_secret text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_room public.rooms%rowtype;
  v_order integer[];
begin
  if not public.valid_player(p_player_id, p_secret) then
    raise exception 'Bạn không có quyền thực hiện thao tác này.';
  end if;

  select r.* into v_room
  from public.rooms r
  join public.players p on p.room_id = r.id
  where p.id = p_player_id
  for update of r;

  if v_room.host_player_id <> p_player_id then
    raise exception 'Chỉ chủ phòng mới có thể bắt đầu.';
  end if;
  if v_room.status not in ('lobby', 'finished') then
    raise exception 'Trận đấu đang diễn ra.';
  end if;
  if (select count(*) from public.players where room_id = v_room.id) < 2 then
    raise exception 'Cần ít nhất 2 người chơi.';
  end if;

  select array_agg(id)
  into v_order
  from (
    select id from public.questions order by random() limit v_room.total_questions
  ) q;

  delete from public.answers where room_id = v_room.id;
  update public.players set score = 0 where room_id = v_room.id;

  update public.rooms
  set status = 'playing',
      phase = 'question',
      question_order = v_order,
      current_position = 0,
      question_started_at = clock_timestamp(),
      results_started_at = null,
      answers_received = 0,
      updated_at = now()
  where id = v_room.id
  returning * into v_room;

  return to_jsonb(v_room);
end;
$$;

create or replace function public.submit_answer(
  p_player_id uuid,
  p_secret text,
  p_question_id integer,
  p_selected_index integer
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_room public.rooms%rowtype;
  v_correct_index integer;
  v_is_correct boolean;
  v_response_ms integer;
  v_rank integer;
  v_base integer;
  v_speed_bonus integer;
  v_points integer;
begin
  if not public.valid_player(p_player_id, p_secret) then
    raise exception 'Phiên người chơi không hợp lệ.';
  end if;
  if p_selected_index not between 0 and 3 then
    raise exception 'Đáp án không hợp lệ.';
  end if;

  select r.* into v_room
  from public.rooms r
  join public.players p on p.room_id = r.id
  where p.id = p_player_id
  for update of r;

  if v_room.status <> 'playing' or v_room.phase <> 'question' then
    raise exception 'Hiện không nhận câu trả lời.';
  end if;
  if v_room.question_order[v_room.current_position + 1] <> p_question_id then
    raise exception 'Câu hỏi không còn hiệu lực.';
  end if;
  if clock_timestamp() > v_room.question_started_at + make_interval(secs => v_room.question_duration_seconds) then
    raise exception 'Đã hết thời gian trả lời.';
  end if;
  if exists (
    select 1 from public.answers
    where room_id = v_room.id and player_id = p_player_id and question_id = p_question_id
  ) then
    raise exception 'Bạn đã trả lời câu này.';
  end if;

  select correct_index into v_correct_index
  from public.questions where id = p_question_id;

  v_response_ms := greatest(
    0,
    floor(extract(epoch from (clock_timestamp() - v_room.question_started_at)) * 1000)::integer
  );
  v_is_correct := p_selected_index = v_correct_index;
  v_rank := null;
  v_points := 0;

  if v_is_correct then
    select count(*) + 1 into v_rank
    from public.answers
    where room_id = v_room.id
      and question_id = p_question_id
      and is_correct = true;

    v_base := case
      when v_rank = 1 then 1000
      when v_rank = 2 then 700
      when v_rank = 3 then 500
      else 300
    end;

    v_speed_bonus := greatest(
      0,
      least(200, floor(((v_room.question_duration_seconds * 1000) - v_response_ms) / 100.0)::integer)
    );
    v_points := v_base + v_speed_bonus;
  end if;

  insert into public.answers (
    room_id, player_id, question_id, selected_index,
    is_correct, response_ms, correct_rank, points
  ) values (
    v_room.id, p_player_id, p_question_id, p_selected_index,
    v_is_correct, v_response_ms, v_rank, v_points
  );

  if v_points > 0 then
    update public.players
    set score = score + v_points
    where id = p_player_id;
  end if;

  update public.rooms
  set answers_received = answers_received + 1,
      updated_at = now()
  where id = v_room.id;

  return jsonb_build_object(
    'is_correct', v_is_correct,
    'response_ms', v_response_ms,
    'rank', v_rank,
    'points', v_points
  );
end;
$$;

create or replace function public.get_my_answer(
  p_player_id uuid,
  p_secret text,
  p_question_id integer
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_result jsonb;
begin
  if not public.valid_player(p_player_id, p_secret) then
    raise exception 'Phiên người chơi không hợp lệ.';
  end if;

  select jsonb_build_object(
    'selected_index', selected_index,
    'is_correct', is_correct,
    'response_ms', response_ms,
    'rank', correct_rank,
    'points', points
  ) into v_result
  from public.answers
  where player_id = p_player_id and question_id = p_question_id;

  return v_result;
end;
$$;

create or replace function public.reveal_results(
  p_player_id uuid,
  p_secret text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_room public.rooms%rowtype;
  v_player_count integer;
begin
  if not public.valid_player(p_player_id, p_secret) then
    raise exception 'Phiên người chơi không hợp lệ.';
  end if;

  select r.* into v_room
  from public.rooms r
  join public.players p on p.room_id = r.id
  where p.id = p_player_id
  for update of r;

  if v_room.status <> 'playing' then
    return to_jsonb(v_room);
  end if;
  if v_room.phase = 'results' then
    return to_jsonb(v_room);
  end if;

  select count(*) into v_player_count
  from public.players where room_id = v_room.id;

  if clock_timestamp() < v_room.question_started_at + make_interval(secs => v_room.question_duration_seconds)
     and v_room.answers_received < v_player_count then
    raise exception 'Câu hỏi vẫn đang diễn ra.';
  end if;

  update public.rooms
  set phase = 'results',
      results_started_at = clock_timestamp(),
      updated_at = now()
  where id = v_room.id
  returning * into v_room;

  return to_jsonb(v_room);
end;
$$;

create or replace function public.get_round_results(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_room public.rooms%rowtype;
  v_question_id integer;
  v_correct_index integer;
  v_explanation text;
  v_answers jsonb;
begin
  select * into v_room from public.rooms where id = p_room_id;
  if not found then
    raise exception 'Không tìm thấy phòng.';
  end if;
  if v_room.phase <> 'results' and v_room.status <> 'finished' then
    raise exception 'Kết quả chưa được công bố.';
  end if;

  v_question_id := v_room.question_order[v_room.current_position + 1];
  select correct_index, explanation
  into v_correct_index, v_explanation
  from public.questions where id = v_question_id;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'player_id', p.id,
        'name', p.name,
        'answered', a.id is not null,
        'selected_index', a.selected_index,
        'is_correct', coalesce(a.is_correct, false),
        'response_ms', a.response_ms,
        'rank', a.correct_rank,
        'points', coalesce(a.points, 0)
      ) order by
        case when a.is_correct then 0 when a.id is not null then 1 else 2 end,
        a.correct_rank nulls last,
        a.response_ms nulls last,
        p.joined_at
    ),
    '[]'::jsonb
  ) into v_answers
  from public.players p
  left join public.answers a
    on a.player_id = p.id
   and a.room_id = p.room_id
   and a.question_id = v_question_id
  where p.room_id = p_room_id;

  return jsonb_build_object(
    'question_id', v_question_id,
    'correct_index', v_correct_index,
    'explanation', v_explanation,
    'answers', v_answers
  );
end;
$$;

create or replace function public.advance_round(
  p_player_id uuid,
  p_secret text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_room public.rooms%rowtype;
begin
  if not public.valid_player(p_player_id, p_secret) then
    raise exception 'Phiên người chơi không hợp lệ.';
  end if;

  select r.* into v_room
  from public.rooms r
  join public.players p on p.room_id = r.id
  where p.id = p_player_id
  for update of r;

  if v_room.status <> 'playing' or v_room.phase <> 'results' then
    return to_jsonb(v_room);
  end if;
  if clock_timestamp() < v_room.results_started_at + interval '6 seconds' then
    raise exception 'Chưa đến thời điểm chuyển câu.';
  end if;

  if v_room.current_position + 1 >= v_room.total_questions then
    update public.rooms
    set status = 'finished',
        updated_at = now()
    where id = v_room.id
    returning * into v_room;
  else
    update public.rooms
    set current_position = current_position + 1,
        phase = 'question',
        question_started_at = clock_timestamp(),
        results_started_at = null,
        answers_received = 0,
        updated_at = now()
    where id = v_room.id
    returning * into v_room;
  end if;

  return to_jsonb(v_room);
end;
$$;

-- Chỉ công khai các RPC cần dùng từ trình duyệt.
revoke all on function public.valid_player(uuid, text) from public, anon, authenticated;

grant execute on function public.create_room(text, text, integer) to anon, authenticated;
grant execute on function public.join_room(text, text, text) to anon, authenticated;
grant execute on function public.resume_session(uuid, text) to anon, authenticated;
grant execute on function public.start_game(uuid, text) to anon, authenticated;
grant execute on function public.submit_answer(uuid, text, integer, integer) to anon, authenticated;
grant execute on function public.get_my_answer(uuid, text, integer) to anon, authenticated;
grant execute on function public.reveal_results(uuid, text) to anon, authenticated;
grant execute on function public.get_round_results(uuid) to anon, authenticated;
grant execute on function public.advance_round(uuid, text) to anon, authenticated;

-- Bật Realtime cho phòng và bảng điểm người chơi.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'rooms'
  ) then
    alter publication supabase_realtime add table public.rooms;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'players'
  ) then
    alter publication supabase_realtime add table public.players;
  end if;
end $$;

-- Đảo vị trí đáp án đúng để tránh quy luật "đáp án A luôn đúng".
update public.questions set options = '["Chia cắt lâu dài giữa hai miền", "Tạm ngừng xây dựng đất nước", "Hòa bình, độc lập và thống nhất", "Chỉ tập trung phát triển công nghiệp"]', correct_index = 2 where id = 1;
update public.questions set options = '["Tách riêng bộ máy quản lý của hai miền", "Thống nhất đất nước về mặt nhà nước và hệ thống chính trị", "Dừng hoạt động của Quốc hội", "Chỉ khôi phục giao thông ở miền Bắc"]', correct_index = 1 where id = 2;
update public.questions set options = '["Tháng 4 năm 1976", "Tháng 12 năm 1976", "Tháng 1 năm 1981", "Tháng 11 năm 1975"]', correct_index = 3 where id = 3;
update public.questions set options = '["30 tháng 4 năm 1975", "24 tháng 6 năm 1976", "25 tháng 4 năm 1976", "20 tháng 12 năm 1976"]', correct_index = 2 where id = 4;
update public.questions set options = '["Từ 14/12 đến 20/12/1976", "Từ 24/6 đến 3/7/1976", "Từ 1/1 đến 10/1/1977", "Từ 25/4 đến 30/4/1976"]', correct_index = 1 where id = 5;
update public.questions set options = '["Việt Nam Dân chủ Cộng hòa", "Liên bang Việt Nam", "Cộng hòa xã hội chủ nghĩa Việt Nam", "Cộng hòa Việt Nam thống nhất"]', correct_index = 2 where id = 6;
update public.questions set options = '["Thành phố Thống Nhất", "Thành phố Gia Định", "Thành phố Sài Gòn mới", "Thành phố Hồ Chí Minh"]', correct_index = 3 where id = 7;
update public.questions set options = '["Từ 24 tháng 6 đến 3 tháng 7 năm 1976", "Từ 14 đến 20 tháng 12 năm 1976", "Ngày 25 tháng 4 năm 1976", "Từ 1 đến 7 tháng 5 năm 1975"]', correct_index = 1 where id = 8;
update public.questions set options = '["Chỉ tập trung vào phát triển thương mại", "Xây dựng chủ nghĩa xã hội và bảo vệ vững chắc Tổ quốc", "Tạm dừng cải tạo kinh tế", "Tách riêng chiến lược của hai miền"]', correct_index = 1 where id = 9;
update public.questions set options = '["Tư nhân hóa toàn bộ nền kinh tế", "Ngừng phát triển nông nghiệp", "Chỉ nhập khẩu hàng tiêu dùng", "Công nghiệp hóa xã hội chủ nghĩa"]', correct_index = 3 where id = 10;
update public.questions set options = '["1975–1979", "1977–1981", "1976–1980", "1981–1985"]', correct_index = 2 where id = 11;
update public.questions set options = '["Thiếu vốn đầu tư trực tiếp nước ngoài", "Tập trung, quan liêu, bao cấp", "Quá phụ thuộc vào thương mại điện tử", "Sản xuất hàng tiêu dùng quá dư thừa"]', correct_index = 1 where id = 12;
update public.questions set options = '["Dư thừa lương thực trên toàn quốc", "Giá cả luôn ổn định tuyệt đối", "Thiếu lương thực, thiếu hàng tiêu dùng và lạm phát", "Cơ sở hạ tầng hoàn toàn hiện đại"]', correct_index = 2 where id = 13;
update public.questions set options = '["Thực dân Pháp", "Phát xít Nhật", "Tập đoàn Khmer Đỏ", "Quân đội Hoa Kỳ"]', correct_index = 2 where id = 14;
update public.questions set options = '["Chỉ phát triển văn hóa và giáo dục", "Xây dựng chủ nghĩa xã hội và bảo vệ Tổ quốc", "Chỉ tập trung vào quốc phòng", "Mở rộng lãnh thổ và dừng sản xuất"]', correct_index = 1 where id = 15;
