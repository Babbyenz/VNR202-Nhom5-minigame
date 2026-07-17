import { createClient } from "@supabase/supabase-js";
import "./style.css";

const app = document.querySelector("#app");
const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

const state = {
  supabase: null,
  room: null,
  player: null,
  players: [],
  questionData: null,
  finalResults: null,
  secret: null,
  channel: null,
  timerId: null,
  syncBusy: false,
  submitBusy: false,
  timeoutSubmittedFor: null,
  connected: false,
  notice: null,
};

const escapeHtml = (value = "") =>
  String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");

const sessionKey = (code) => `history-arena-v2:${code.toUpperCase()}`;
const playerList = () => state.players.filter((player) => !player.is_host);
const totalQuestions = () => state.room?.total_questions || 20;
const completedPlayers = () =>
  playerList().filter(
    (player) =>
      player.finished_at || player.current_position >= totalQuestions(),
  );
const formatSeconds = (ms) => `${(Number(ms || 0) / 1000).toFixed(2)} giây`;
const initials = (name = "") => name.trim().slice(0, 2).toUpperCase();

function randomSecret() {
  return (
    crypto.randomUUID?.() ??
    `${Date.now()}-${Math.random().toString(36).slice(2)}-${Math.random().toString(36).slice(2)}`
  );
}

function saveSession(code, playerId, secret) {
  localStorage.setItem(
    sessionKey(code),
    JSON.stringify({ code, playerId, secret }),
  );
}

function readSession(code) {
  try {
    return JSON.parse(localStorage.getItem(sessionKey(code)) || "null");
  } catch {
    return null;
  }
}

function clearSession(code) {
  localStorage.removeItem(sessionKey(code));
}

function setRoomInUrl(code) {
  const url = new URL(window.location.href);
  if (code) url.searchParams.set("room", code);
  else url.searchParams.delete("room");
  history.replaceState({}, "", url);
}

function clearTimer() {
  if (state.timerId) clearInterval(state.timerId);
  state.timerId = null;
}

function setNotice(type, text) {
  state.notice = { type, text };
}

function noticeHtml() {
  if (!state.notice) return "";
  return `<div class="notice ${escapeHtml(state.notice.type)}">${escapeHtml(state.notice.text)}</div>`;
}

function shell(content) {
  return `
    <main class="app-shell">
      <header class="topbar">
        <div class="brand">
          <div class="brand-mark">★</div>
          <div>
            <p class="eyebrow"> VNR202 - MINIGAME</p>
          </div>
        </div>
        <span class="connection-pill ${state.connected ? "online" : "offline"}">
          ${state.connected ? "Đang đồng bộ" : "Chưa kết nối"}
        </span>
      </header>
      ${content}
    </main>
  `;
}

function renderSetupError() {
  app.innerHTML = shell(`
    <section class="center-card">
      <p class="eyebrow">CHƯA CẤU HÌNH SUPABASE</p>
      <h2>Thiếu biến môi trường</h2>
      <p>Tạo file <strong>.env</strong> tại thư mục gốc và thêm:</p>
      <code>VITE_SUPABASE_URL=https://...supabase.co</code>
      <code>VITE_SUPABASE_ANON_KEY=sb_publishable_...</code>
    </section>
  `);
}

function renderLoading(message = "Đang đồng bộ...") {
  clearTimer();
  app.innerHTML = shell(`
    <section class="loading-screen">
      <div class="spinner"></div>
      <p>${escapeHtml(message)}</p>
    </section>
  `);
}

function renderHome() {
  clearTimer();
  const codeFromUrl =
    new URLSearchParams(location.search).get("room")?.toUpperCase() || "";

  app.innerHTML = shell(`
    <section class="hero-layout">
      <article class="hero-card">
        <span class="status-pill">⚡ 20 câu hỏi · Nhanh như chớp đớp quà ngon 🎁 </span>
        <h2> Xây dựng chủ nghĩa xã hội và bảo vệ Tổ quốc 1975 - 1981 </h2>
        <p>Mỗi người nhận 20 câu theo một thứ tự khác nhau và làm theo tốc độ của mình. Chọn đáp án xong sẽ sang ngay câu tiếp theo. Làm xong trước thì chờ những người còn lại. Khi tất cả hoàn thành, game sẽ cộng điểm và xếp hạng.</p>


        <div class="action-grid">
          <article class="action-card">
            <h3>Tạo phòng</h3>
            
            <label>Tên chủ phòng
              <input id="createName" maxlength="24" placeholder="Ví dụ: Nhóm 5" />
            </label>
            <div class="fixed-count"><span>Số câu hỏi</span><strong>20 câu</strong></div>
            <button id="createRoomButton" class="primary-button" type="button">Tạo phòng mới</button>
          </article>

          <article class="action-card">
            <h3>Tham gia</h3>
            <p>Nhập tên của bạn và mã phòng để tham gia.</p>
            <label>Tên người chơi
              <input id="joinName" maxlength="24" placeholder="Ví dụ: Anh Quân" />
            </label>
            <label>Mã phòng
              <input id="joinCode" class="code-input" maxlength="6" value="${escapeHtml(codeFromUrl)}" placeholder="ABC123" />
            </label>
            <button id="joinRoomButton" class="secondary-button" type="button">Vào phòng</button>
          </article>
        </div>
        ${noticeHtml()}
      </article>

      <aside class="side-card">
        <p class="eyebrow">LUẬT TÍNH ĐIỂM</p>
        <h3>Trả lời đúng và nhanh để ghi điểm</h3>
        <div class="score-rules">
          <div><span>Nhanh nhất</span><strong>1.000 điểm</strong></div>
          <div><span>Về thứ hai</span><strong>700 điểm</strong></div>
          <div><span>Về thứ ba</span><strong>500 điểm</strong></div>
          <div><span>Các vị trí còn lại</span><strong>300 điểm</strong></div>
          <div><span>Trả lời sai hoặc hết giờ</span><strong>0 điểm</strong></div>
        </div>
        <p class="muted">Mỗi câu còn có tối đa 200 điểm thưởng theo thời gian trả lời. Sau 20 câu, người có tổng điểm cao nhất sẽ thắng.</p>
      </aside>
    </section>
  `);

  document
    .querySelector("#createRoomButton")
    .addEventListener("click", createRoom);
  document.querySelector("#joinRoomButton").addEventListener("click", joinRoom);
  document.querySelector("#joinCode").addEventListener("input", (event) => {
    event.target.value = event.target.value
      .replace(/[^a-zA-Z0-9]/g, "")
      .toUpperCase();
  });
  document.querySelectorAll("input").forEach((input) => {
    input.addEventListener("keydown", (event) => {
      if (event.key === "Enter") {
        event.preventDefault();
        input.closest(".action-card").querySelector("button").click();
      }
    });
  });
}

async function createRoom() {
  const name = document.querySelector("#createName").value.trim();
  if (name.length < 2) {
    setNotice("error", "Tên chủ phòng cần có ít nhất 2 ký tự.");
    renderHome();
    return;
  }

  renderLoading("Đang tạo phòng...");
  const secret = randomSecret();
  const { data, error } = await state.supabase.rpc("create_room", {
    p_name: name,
    p_secret: secret,
    p_total_questions: 20,
  });

  if (error) {
    setNotice("error", error.message);
    renderHome();
    return;
  }

  saveSession(data.room_code, data.player_id, secret);
  setRoomInUrl(data.room_code);
  await connectToRoom(data.room_code, data.player_id, secret);
}

async function joinRoom() {
  const name = document.querySelector("#joinName").value.trim();
  const code = document.querySelector("#joinCode").value.trim().toUpperCase();

  if (name.length < 2 || code.length !== 6) {
    setNotice("error", "Hãy nhập tên và mã phòng gồm 6 ký tự.");
    renderHome();
    return;
  }

  renderLoading("Đang tham gia phòng...");
  const secret = randomSecret();
  const { data, error } = await state.supabase.rpc("join_room", {
    p_code: code,
    p_name: name,
    p_secret: secret,
  });

  if (error) {
    setNotice("error", error.message);
    renderHome();
    return;
  }

  saveSession(data.room_code, data.player_id, secret);
  setRoomInUrl(data.room_code);
  await connectToRoom(data.room_code, data.player_id, secret);
}

async function connectToRoom(code, playerId, secret) {
  state.secret = secret;
  renderLoading("Đang mở phòng chơi...");

  const { data: session, error } = await state.supabase.rpc("resume_session", {
    p_player_id: playerId,
    p_secret: secret,
  });

  if (error || session.room_code !== code.toUpperCase()) {
    clearSession(code);
    setNotice("error", "Phiên cũ không còn hợp lệ. Hãy tham gia lại.");
    setRoomInUrl("");
    renderHome();
    return;
  }

  state.player = {
    id: session.player_id,
    name: session.player_name,
    is_host: session.is_host,
    room_id: session.room_id,
  };

  await subscribeToRoom(session.room_id);
  await syncRoom(true);
}

async function subscribeToRoom(roomId) {
  if (state.channel) await state.supabase.removeChannel(state.channel);

  state.channel = state.supabase
    .channel(`history-room-${roomId}`)
    .on(
      "postgres_changes",
      {
        event: "*",
        schema: "public",
        table: "rooms",
        filter: `id=eq.${roomId}`,
      },
      () => syncRoom(),
    )
    .on(
      "postgres_changes",
      {
        event: "*",
        schema: "public",
        table: "players",
        filter: `room_id=eq.${roomId}`,
      },
      () => syncRoom(),
    )
    .subscribe((status) => {
      state.connected = status === "SUBSCRIBED";
      const pill = document.querySelector(".connection-pill");
      if (pill) {
        pill.className = `connection-pill ${state.connected ? "online" : "offline"}`;
        pill.textContent = state.connected ? "Đang đồng bộ" : "Đang kết nối";
      }
    });
}

async function syncRoom(force = false) {
  if (state.syncBusy && !force) return;
  if (!state.player?.room_id) return;
  state.syncBusy = true;

  try {
    const [
      { data: room, error: roomError },
      { data: players, error: playersError },
    ] = await Promise.all([
      state.supabase
        .from("rooms")
        .select("*")
        .eq("id", state.player.room_id)
        .single(),
      state.supabase
        .from("players")
        .select("*")
        .eq("room_id", state.player.room_id)
        .order("joined_at"),
    ]);

    if (roomError) throw roomError;
    if (playersError) throw playersError;

    state.room = room;
    state.players = players || [];
    state.player =
      state.players.find((item) => item.id === state.player.id) || state.player;

    if (
      room.status === "playing" &&
      !state.player.is_host &&
      !state.player.finished_at
    ) {
      const { data, error } = await state.supabase.rpc("get_my_question", {
        p_player_id: state.player.id,
        p_secret: state.secret,
      });
      if (error) throw error;
      state.questionData = data;
    } else {
      state.questionData = null;
    }

    if (room.status === "finished") {
      const { data, error } = await state.supabase.rpc("get_final_results", {
        p_room_id: room.id,
      });
      if (!error) state.finalResults = data;
    } else {
      state.finalResults = null;
    }

    renderRoom();
  } catch (error) {
    setNotice("error", error.message || "Không thể đồng bộ phòng.");
    renderHome();
  } finally {
    state.syncBusy = false;
  }
}

function roomHeader(extra = "") {
  return `
    <section class="room-strip">
      <div>
        <span>Mã phòng</span>
        <strong>${escapeHtml(state.room.code)}</strong>
      </div>
      <div>
        <span>Người chơi</span>
        <strong>${playerList().length}</strong>
      </div>
      <div>
        <span>Số câu</span>
        <strong>20</strong>
      </div>
      ${extra}
      <button id="copyCodeButton" class="small-button" type="button">Sao chép mã</button>
      <button id="leaveButton" class="small-button danger" type="button">Rời phòng</button>
    </section>
  `;
}

function attachCommonRoomEvents() {
  document
    .querySelector("#copyCodeButton")
    ?.addEventListener("click", async () => {
      try {
        await navigator.clipboard.writeText(state.room.code);
        const button = document.querySelector("#copyCodeButton");
        button.textContent = "Đã sao chép";
        setTimeout(() => {
          if (button) button.textContent = "Sao chép mã";
        }, 1200);
      } catch {
        alert(`Mã phòng: ${state.room.code}`);
      }
    });

  document
    .querySelector("#leaveButton")
    ?.addEventListener("click", async () => {
      clearSession(state.room.code);
      if (state.channel) await state.supabase.removeChannel(state.channel);
      clearTimer();
      state.room = null;
      state.player = null;
      state.players = [];
      state.questionData = null;
      state.finalResults = null;
      state.secret = null;
      setRoomInUrl("");
      renderHome();
    });
}

function renderRoom() {
  clearTimer();

  if (!state.room) {
    renderLoading();
    return;
  }

  if (state.room.status === "lobby") renderLobby();
  else if (state.room.status === "playing" && state.player.is_host)
    renderHostDashboard();
  else if (state.room.status === "playing" && state.player.finished_at)
    renderWaitingForOthers();
  else if (state.room.status === "playing") renderQuestion();
  else renderFinalLeaderboard();
}

function renderLobby() {
  const players = playerList();
  app.innerHTML = shell(`
    ${roomHeader()}
    <section class="two-column">
      <article class="main-panel">
        <p class="eyebrow">PHÒNG CHỜ</p>
        <h2>${state.player.is_host ? "Bạn là chủ phòng" : "Đang chờ chủ phòng bắt đầu"}</h2>
        <p>${
          state.player.is_host
            ? "Bạn chỉ cần bắt đầu  và xem tiến độ của mọi người, không phải trả lời câu hỏi."
            : "Khi chủ phòng bắt đầu, bạn làm liên tục 20 câu và không cần chờ người khác."
        }</p>

        <div class="player-grid">
          ${
            players.length
              ? players
                  .map(
                    (player, index) => `
            <div class="player-chip">
              <span class="avatar">${escapeHtml(initials(player.name))}</span>
              <div><strong>${escapeHtml(player.name)}</strong><small>Người chơi ${index + 1}</small></div>
            </div>
          `,
                  )
                  .join("")
              : '<div class="empty-state">Chưa có người chơi nào tham gia.</div>'
          }
        </div>

        ${
          state.player.is_host
            ? `
          <button id="startGameButton" class="primary-button wide-button" type="button" ${players.length < 1 ? "disabled" : ""}>
            Bắt đầu 20 câu
          </button>
          <p class="muted">Cần ít nhất 1 người chơi. Có thể tham gia tối đa 30 người.</p>
        `
            : '<div class="waiting-badge"><span class="pulse-dot"></span> Đang chờ chủ phòng bắt đầu...</div>'
        }
        ${noticeHtml()}
      </article>

      <aside class="side-card">
        <p class="eyebrow">LUẬT CHƠI</p>
        <h3>Cách chơi rất đơn giản</h3>
        <ol class="steps">
          <li>Mỗi câu có 20 giây để trả lời.</li>
          <li>Chọn đáp án xong sẽ sang câu tiếp theo.</li>
          <li>Ai làm xong 20 câu trước sẽ vào phòng chờ.</li>
          <li>Khi mọi người làm xong, game sẽ hiện bảng xếp hạng.</li>
        </ol>
      </aside>
    </section>
  `);

  attachCommonRoomEvents();
  document
    .querySelector("#startGameButton")
    ?.addEventListener("click", startGame);
}

async function startGame() {
  const button = document.querySelector("#startGameButton");
  if (button) button.disabled = true;

  const { error } = await state.supabase.rpc("start_game", {
    p_player_id: state.player.id,
    p_secret: state.secret,
  });

  if (error) {
    setNotice("error", error.message);
    await syncRoom(true);
    return;
  }

  await syncRoom(true);
}

function progressBar(position, total) {
  const safe = Math.min(total, Math.max(0, Number(position || 0)));
  const percent = total ? Math.round((safe / total) * 100) : 0;
  return `
    <div class="progress-line">
      <div class="progress-fill" style="width:${percent}%"></div>
    </div>
  `;
}

function renderHostDashboard() {
  const players = playerList();
  const complete = completedPlayers().length;

  app.innerHTML = shell(`
    ${roomHeader(`<div><span>Hoàn thành</span><strong>${complete}/${players.length}</strong></div>`)}
    <section class="host-dashboard">
      <div class="host-heading">
        <div>
          <p class="eyebrow">MÀN HÌNH CHỦ PHÒNG</p>
          <h2>Theo dõi tiến độ người chơi</h2>
          <p>Bạn không cần trả lời câu hỏi. Khi tất cả làm xong 20 câu, bảng kết quả sẽ hiện ra.</p>
        </div>
        <div class="host-icon">🎛️</div>
      </div>

      <div class="progress-list">
        ${players
          .map((player, index) => {
            const done = Boolean(
              player.finished_at || player.current_position >= totalQuestions(),
            );
            return `
            <article class="progress-player ${done ? "done" : ""}">
              <span class="rank-number">${index + 1}</span>
              <span class="avatar">${escapeHtml(initials(player.name))}</span>
              <div class="progress-main">
                <div class="progress-label">
                  <strong>${escapeHtml(player.name)}</strong>
                  <span>${done ? "Đã hoàn thành" : `${player.current_position}/20 câu`}</span>
                </div>
                ${progressBar(player.current_position, 20)}
              </div>
              <strong class="progress-percent">${Math.round((Math.min(player.current_position, 20) / 20) * 100)}%</strong>
            </article>
          `;
          })
          .join("")}
      </div>

      <div class="host-footer">
        <p><strong>${complete}</strong> người đã hoàn thành, còn <strong>${Math.max(0, players.length - complete)}</strong> người đang làm.</p>
        <button id="forceFinishButton" class="danger-button" type="button">Kết thúc và chấm điểm sớm</button>
      </div>
    </section>
  `);

  attachCommonRoomEvents();
  document
    .querySelector("#forceFinishButton")
    .addEventListener("click", async () => {
      const accepted = confirm(
        "Kết thúc sớm sẽ chấm điểm dựa trên các câu đã trả lời. Bạn chắc chắn chứ?",
      );
      if (!accepted) return;

      const { error } = await state.supabase.rpc("host_finish_game", {
        p_player_id: state.player.id,
        p_secret: state.secret,
      });
      if (error) alert(error.message);
      await syncRoom(true);
    });
}

function renderQuestion() {
  const data = state.questionData;
  if (!data?.question) {
    renderLoading("Đang lấy câu hỏi tiếp theo...");
    setTimeout(() => syncRoom(true), 500);
    return;
  }

  const question = data.question;
  const position = Number(data.position || 0);

  app.innerHTML = shell(`
    ${roomHeader(`<div><span>Tiến độ</span><strong>${position + 1}/20</strong></div>`)}
    <section class="question-layout">
      <article class="question-panel">
        <div class="question-top">
          <span class="category-pill">${escapeHtml(question.category)}</span>
          <div class="timer-box"><span>Thời gian</span><strong id="timerValue">20.0</strong></div>
        </div>
        ${progressBar(position, 20)}
        <p class="question-number">Câu ${position + 1} trên 20</p>
        <h2>${escapeHtml(question.prompt)}</h2>
        <div class="answers-grid">
          ${(question.options || [])
            .map(
              (option, index) => `
            <button class="answer-button" type="button" data-index="${index}">
              <span>${String.fromCharCode(65 + index)}</span>
              <strong>${escapeHtml(option)}</strong>
            </button>
          `,
            )
            .join("")}
        </div>
        <p id="answerStatus" class="answer-status">Chọn một đáp án để sang câu tiếp theo.</p>
      </article>

      <aside class="side-card compact-side">
        <p class="eyebrow">ĐANG THI ĐẤU</p>
        <h3>${escapeHtml(state.player.name)}</h3>
        <div class="personal-stat"><span>Đã làm</span><strong>${position}/20</strong></div>
        <div class="personal-stat"><span>Đúng tạm thời</span><strong>${state.player.correct_count || 0}</strong></div>
        <p class="muted">Điểm cuối cùng sẽ được tính sau khi mọi người làm xong.</p>
      </aside>
    </section>
  `);

  attachCommonRoomEvents();
  document.querySelectorAll(".answer-button").forEach((button) => {
    button.addEventListener("click", () =>
      submitAnswer(Number(button.dataset.index)),
    );
  });

  startQuestionTimer(data.started_at, data.duration_seconds, question.id);
}

function startQuestionTimer(startedAt, durationSeconds, questionId) {
  clearTimer();
  const startMs = new Date(startedAt).getTime();
  const durationMs = Number(durationSeconds || 20) * 1000;

  const tick = () => {
    const remaining = Math.max(0, durationMs - (Date.now() - startMs));
    const timer = document.querySelector("#timerValue");
    if (timer) {
      timer.textContent = (remaining / 1000).toFixed(1);
      timer.classList.toggle("warning", remaining <= 5000);
    }

    if (remaining <= 0) {
      clearTimer();
      if (state.timeoutSubmittedFor !== questionId && !state.submitBusy) {
        state.timeoutSubmittedFor = questionId;
        submitAnswer(null, true);
      }
    }
  };

  tick();
  state.timerId = setInterval(tick, 100);
}

async function submitAnswer(selectedIndex, timedOut = false) {
  if (state.submitBusy || !state.questionData?.question) return;
  state.submitBusy = true;
  clearTimer();

  document.querySelectorAll(".answer-button").forEach((button) => {
    button.disabled = true;
    if (
      selectedIndex !== null &&
      Number(button.dataset.index) === selectedIndex
    ) {
      button.classList.add("selected");
    }
  });

  const status = document.querySelector("#answerStatus");
  if (status)
    status.textContent = timedOut
      ? "Hết thời gian — đang chuyển câu..."
      : "Đã ghi nhận — đang chuyển câu...";

  const questionId = state.questionData.question.id;
  const { error } = await state.supabase.rpc("submit_answer", {
    p_player_id: state.player.id,
    p_secret: state.secret,
    p_question_id: questionId,
    p_selected_index: selectedIndex,
  });

  state.submitBusy = false;

  if (error) {
    alert(error.message);
    await syncRoom(true);
    return;
  }

  state.timeoutSubmittedFor = null;
  await syncRoom(true);
}

function renderWaitingForOthers() {
  const players = playerList();
  const complete = completedPlayers().length;
  const remaining = Math.max(0, players.length - complete);

  app.innerHTML = shell(`
    ${roomHeader(`<div><span>Hoàn thành</span><strong>${complete}/${players.length}</strong></div>`)}
    <section class="center-card completion-card">
      <div class="completion-icon">✅</div>
      <p class="eyebrow">BẠN ĐÃ HOÀN THÀNH 20 CÂU</p>
      <h2>Đang chờ ${remaining} người chơi còn lại</h2>
      <p>Bạn đã làm xong. Hãy chờ những người còn lại; bảng xếp hạng sẽ hiện khi tất cả hoàn thành.</p>

      <div class="waiting-progress">
        ${players
          .map(
            (player) => `
          <div class="waiting-person ${player.finished_at ? "done" : ""}">
            <span class="avatar">${escapeHtml(initials(player.name))}</span>
            <div>
              <strong>${escapeHtml(player.name)}</strong>
              <small>${player.finished_at ? "Đã hoàn thành" : `Đang làm câu ${Math.min(player.current_position + 1, 20)}/20`}</small>
            </div>
            <span>${player.finished_at ? "✓" : `${player.current_position}/20`}</span>
          </div>
        `,
          )
          .join("")}
      </div>

      <div class="waiting-badge"><span class="pulse-dot"></span> Đang chờ những người còn lại...</div>
    </section>
  `);

  attachCommonRoomEvents();
}

function renderFinalLeaderboard() {
  const results =
    state.finalResults?.players ||
    playerList()
      .map((player) => ({
        player_id: player.id,
        name: player.name,
        score: player.score,
        correct_count: player.correct_count,
        total_response_ms: player.total_response_ms,
      }))
      .sort(
        (a, b) =>
          b.score - a.score ||
          b.correct_count - a.correct_count ||
          a.total_response_ms - b.total_response_ms,
      );

  const winner = results[0];
  const medal = (index) => ["🥇", "🥈", "🥉"][index] || `${index + 1}`;

  app.innerHTML = shell(`
    ${roomHeader()}
    <section class="final-panel">
      <div class="winner-section">
        <div class="trophy">🏆</div>
        <p class="eyebrow">KẾT QUẢ CHUNG CUỘC</p>
        <h2>${winner ? `${escapeHtml(winner.name)} chiến thắng!` : "Trận đấu đã kết thúc"}</h2>
        ${winner ? `<p>Quán quân đạt <strong>${winner.score.toLocaleString("vi-VN")} điểm</strong>, trả lời đúng ${winner.correct_count}/20 câu.</p>` : ""}
      </div>

      <div class="leaderboard">
        ${results
          .map(
            (player, index) => `
          <article class="leader-row ${index === 0 ? "champion" : ""}">
            <span class="medal">${medal(index)}</span>
            <span class="avatar">${escapeHtml(initials(player.name))}</span>
            <div class="leader-name">
              <strong>${escapeHtml(player.name)}</strong>
              <small>${player.correct_count}/20 câu đúng · Tổng thời gian ${formatSeconds(player.total_response_ms)}</small>
            </div>
            <strong class="leader-score">${Number(player.score || 0).toLocaleString("vi-VN")} điểm</strong>
          </article>
        `,
          )
          .join("")}
      </div>

      ${
        state.player.is_host
          ? `
        <button id="playAgainButton" class="primary-button wide-button" type="button">Chơi trận mới với cùng phòng</button>
      `
          : '<p class="muted center-text">Chủ phòng có thể bắt đầu một trận mới.</p>'
      }
    </section>
  `);

  attachCommonRoomEvents();
  document
    .querySelector("#playAgainButton")
    ?.addEventListener("click", startGame);
}

async function tryResumeFromUrl() {
  const code = new URLSearchParams(location.search).get("room")?.toUpperCase();
  if (!code) {
    renderHome();
    return;
  }

  const saved = readSession(code);
  if (!saved?.playerId || !saved?.secret) {
    renderHome();
    return;
  }

  await connectToRoom(code, saved.playerId, saved.secret);
}

async function init() {
  if (!supabaseUrl || !supabaseAnonKey) {
    renderSetupError();
    return;
  }

  state.supabase = createClient(supabaseUrl, supabaseAnonKey, {
    realtime: { params: { eventsPerSecond: 10 } },
  });

  await tryResumeFromUrl();
}

init();
