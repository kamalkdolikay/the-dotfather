import {Socket} from "phoenix"

const DOT_MAX = 250
const LONG_MIN = 3000
const STORAGE_KEYS = {
  player: "dotfather:player",
  highScore: "dotfather:high-score",
  match: "dotfather:active-match"
}

let listenersRegistered = false
const pointerStarts = new Map()
const keyStarts = new Map()
let channelSocket = null

function dispatchSymbol(symbol) {
  if (!symbol) return
  window.dispatchEvent(new CustomEvent("morse-input", {detail: {symbol}}))
}

function classify(duration) {
  if (duration >= LONG_MIN) return "long_dash"
  if (duration >= DOT_MAX) return "dash"
  return "dot"
}

function pointerDown(event) {
  if (event.isPrimary === false) return
  pointerStarts.set(event.pointerId, performance.now())
}

function pointerEnd(event) {
  if (!pointerStarts.has(event.pointerId)) return
  const start = pointerStarts.get(event.pointerId)
  pointerStarts.delete(event.pointerId)
  const symbol = classify(performance.now() - start)
  dispatchSymbol(symbol)
}

function keyDown(event) {
  if (event.repeat) return
  if (shouldIgnoreTarget(event.target)) return
  keyStarts.set(event.code, performance.now())
}

function keyUp(event) {
  if (!keyStarts.has(event.code)) return
  const start = keyStarts.get(event.code)
  keyStarts.delete(event.code)
  const symbol = classify(performance.now() - start)
  dispatchSymbol(symbol)
}

function shouldIgnoreTarget(target) {
  if (!target) return false
  const tag = target.tagName
  return tag === "INPUT" || tag === "TEXTAREA" || target.isContentEditable
}

export function initMorseInput() {
  if (listenersRegistered) return
  listenersRegistered = true

  window.addEventListener("pointerdown", pointerDown)
  window.addEventListener("pointerup", pointerEnd)
  window.addEventListener("pointercancel", pointerEnd)
  window.addEventListener("keydown", keyDown)
  window.addEventListener("keyup", keyUp)
}

function ensureChannelSocket(identity) {
  if (!channelSocket) {
    channelSocket = new Socket("/socket", {params: identity})
    channelSocket.connect()
  }
  return channelSocket
}

function loadIdentity() {
  try {
    const stored = JSON.parse(localStorage.getItem(STORAGE_KEYS.player) || "null")
    if (stored?.user_id && stored?.nickname) {
      return stored
    }
  } catch (_err) {
    // ignore corrupted storage
  }

  const userId = crypto.randomUUID()
  const nickname = `Player_${userId.slice(0, 5).toUpperCase()}`
  const identity = {user_id: userId, nickname: nickname}

  try {
    localStorage.setItem(STORAGE_KEYS.player, JSON.stringify(identity))
  } catch (_err) {
    // ignore storage errors
  }

  return identity
}

function loadHighScore() {
  const stored = localStorage.getItem(STORAGE_KEYS.highScore)
  return stored ? parseInt(stored, 10) || 0 : 0
}

function saveHighScore(score) {
  try {
    localStorage.setItem(STORAGE_KEYS.highScore, String(score))
  } catch (_err) {}
}

function storeActiveMatch(matchId) {
  try {
    if (matchId) {
      localStorage.setItem(STORAGE_KEYS.match, matchId)
    } else {
      localStorage.removeItem(STORAGE_KEYS.match)
    }
  } catch (_err) {}
}

function loadActiveMatch() {
  const stored = localStorage.getItem(STORAGE_KEYS.match)
  return stored && stored.length > 0 ? stored : null
}

function formatSymbols(symbols) {
  return symbols.map(symbol => (symbol === "dot" ? "." : symbol === "dash" ? "-" : "")).join("")
}

function normalizeSymbol(input) {
  switch (input) {
    case "dot":
    case "dash":
    case "long_dash":
      return input
    case "long-dash":
      return "long_dash"
    default:
      return input
  }
}

export const Hooks = {
  MorseInput: {
    mounted() {
      initMorseInput()
      this.handler = event => {
        const symbol = normalizeSymbol(event.detail.symbol)
        this.pushEvent("morse_input", {symbol})
      }
      window.addEventListener("morse-input", this.handler)
    },

    destroyed() {
      window.removeEventListener("morse-input", this.handler)
    }
  },

  Competition: {
    mounted() {
      initMorseInput()
      this.identity = loadIdentity()
      this.highScore = loadHighScore()
      this.activeMatchId = loadActiveMatch()
      this.pendingMatchId = null
      this.clockOffsetMs = 0
      this.answerSymbols = []
      this.idleTimeout = null
      this.countdownHandle = null
      this.deadline = null
      this.mode = "idle"
      this.currentPatternHint = null

      this.cacheElements()
      this.updateHighScore()
      this.bindHandlers()
      this.establishChannels()
    },

    destroyed() {
      window.removeEventListener("morse-input", this.onMorseInput)
      this.clearIdleTimer()
      this.clearCountdown()
      if (this.gameChannel) {
        this.gameChannel.leave()
        this.gameChannel = null
      }
      if (this.lobbyChannel) {
        this.lobbyChannel.leave()
        this.lobbyChannel = null
      }
    },

    cacheElements() {
      this.highScoreEl = document.getElementById("highest-score")
      this.queuePromptEl = document.getElementById("queue-prompt")
      this.statusButton = document.getElementById("matchmaking-status")
      this.questionPromptEl = document.getElementById("question-prompt")
      this.questionTypeEl = document.getElementById("question-type")
      this.questionCounterEl = document.getElementById("question-counter")
      this.timerEl = document.getElementById("question-timer")
      this.inputEl = document.getElementById("player-input")
      this.feedbackEl = document.getElementById("answer-feedback")
      this.scoreboardEl = document.getElementById("scoreboard")
      this.matchSummaryEl = document.getElementById("match-summary")
    },

    bindHandlers() {
      this.onMorseInput = event => {
        const symbol = normalizeSymbol(event.detail.symbol)
        this.handleSymbol(symbol)
      }
      window.addEventListener("morse-input", this.onMorseInput)
    },

    establishChannels() {
      const socket = ensureChannelSocket(this.identity)

      this.lobbyChannel = socket.channel("lobby", {})
      this.lobbyChannel.on("queued", () => this.updateQueueStatus("Queued... waiting for an opponent"))
      this.lobbyChannel.on("queue_canceled", () => this.updateQueueStatus("Matchmaking canceled"))
      this.lobbyChannel.on("match_found", payload => this.joinMatch(payload.match_id))

      this.lobbyChannel
        .join()
        .receive("ok", () => {
          if (this.activeMatchId) {
            this.joinMatch(this.activeMatchId)
          }
        })
    },

    joinMatch(matchId) {
      if (!matchId) return
      if (this.pendingMatchId === matchId || this.activeMatchId === matchId) return

      this.pendingMatchId = matchId
      this.mode = "matched"
      this.updateQueueStatus("Opponent found! Preparing match...")

      if (this.gameChannel) {
        this.gameChannel.leave()
        this.gameChannel = null
      }

      const socket = ensureChannelSocket(this.identity)
      const channel = socket.channel(`game:${matchId}`, {})
      this.gameChannel = channel

      channel.on("round_started", payload => this.handleRoundStarted(payload))
      channel.on("round_result", payload => this.handleRoundResult(payload))
      channel.on("match_over", payload => this.handleMatchOver(payload))
      channel.on("answer_feedback", payload => this.handleAnswerFeedback(payload))

      channel
        .join()
        .receive("ok", snapshot => {
          this.pendingMatchId = null
          this.activeMatchId = matchId
          storeActiveMatch(matchId)
          this.handleSnapshot(snapshot)
        })
        .receive("error", _reason => {
          this.handleFailedMatchJoin(matchId)
        })
    },

    handleFailedMatchJoin(matchId) {
      if (this.gameChannel) {
        this.gameChannel.leave()
        this.gameChannel = null
      }

      if (this.pendingMatchId === matchId) {
        this.pendingMatchId = null
      }
      if (this.activeMatchId === matchId) {
        this.activeMatchId = null
      }

      storeActiveMatch(null)
      this.mode = "idle"
      this.clearCountdown()
      this.answerSymbols = []
      this.renderAnswer()
      this.feedbackEl.textContent = ""
      this.renderScoreboard({})
      this.updateQueueStatus("Press Dash to start matching")
    },

    handleSnapshot(snapshot) {
      const status = snapshot.status || "waiting"
      this.updateClockOffset(snapshot.server_now_ms)
      this.renderScoreboard(snapshot.players || {})
      this.updateScores(snapshot.scores || {})

      if (snapshot.question) {
        const roundMs = snapshot.round_ms || 0
        const targetDeadline = this.resolveDeadline(snapshot.deadline_ms, snapshot.remaining_ms, roundMs)

        this.applyQuestion(
          snapshot.question,
          snapshot.round || 0,
          snapshot.total_rounds || 0,
          targetDeadline,
          roundMs
        )
      }

      if (status === "finished") {
        this.mode = "results"
      } else if (status === "running") {
        this.mode = "answering"
      } else {
        this.mode = "matched"
      }

      if (status === "waiting") {
        this.updateQueueStatus("Waiting for opponent to connect...")
      } else if (status === "running") {
        this.updateQueueStatus("Match in progress")
      }
    },

    handleRoundStarted(payload) {
      this.mode = "answering"
      this.clearIdleTimer()
      this.answerSymbols = []
      this.renderAnswer()
      this.feedbackEl.textContent = ""
      this.updateClockOffset(payload.server_now_ms)
      const roundMs = payload.round_ms || 0
      const targetDeadline = this.resolveDeadline(payload.deadline_ms, null, roundMs)
      this.applyQuestion(payload.question, payload.round, payload.total_rounds, targetDeadline, roundMs)
      this.renderScoreboard(payload.players || {})
      this.updateScores(payload.scores || {})
      this.updateQueueStatus("Match in progress")
    },

    handleRoundResult(payload) {
      this.renderScoreboard(payload.players || {})
      this.updateScores(payload.scores || {})
      this.feedbackEl.textContent = "Round complete"
      this.clearCountdown()
    },

    handleMatchOver(payload) {
      this.mode = "results"
      this.clearCountdown()
      this.renderScoreboard(payload.players || {})
      this.updateScores(payload.scores || {})

      const scores = payload.scores || {}
      const myScore = scores[this.identity.user_id] || 0
      const topScore = Math.max(...Object.values(scores))
      if (Object.keys(scores).length > 0) {
        this.feedbackEl.textContent =
          myScore >= topScore
            ? `Congratulations! You scored ${myScore}! You are the winner!`
            : `You scored ${myScore}. Sorry, you lose the game, try again.`
      }
      this.matchSummaryEl.textContent = "Press Dash to start a new matching or Long-Dash to exit."
      this.updateQueueStatus("Match complete. Press Dash to start matching")
      this.answerSymbols = []
      this.renderAnswer()

      if (myScore > this.highScore) {
        this.highScore = myScore
        saveHighScore(myScore)
        this.updateHighScore()
      }

      storeActiveMatch(null)
      this.activeMatchId = null
      this.pendingMatchId = null
    },

    handleAnswerFeedback(payload) {
      switch (payload.result) {
        case "incorrect":
          this.feedbackEl.textContent = "Sorry, wrong code. Try again"
          this.answerSymbols = []
          this.renderAnswer()
          break
        case "correct":
          this.feedbackEl.textContent = "Correct!"
          this.clearIdleTimer()
          break
        default:
          break
      }
    },

    handleSymbol(symbol) {
      if (symbol === "long_dash") {
        window.location.href = "/"
        return
      }

      if (this.mode === "idle") {
        if (symbol === "dash") {
          this.startMatching()
        }
        return
      }

      if (this.mode === "results") {
        if (symbol === "dash") {
          this.startMatching()
        }
        return
      }

      if (this.mode === "queued") {
        if (symbol === "long_dash") {
          this.cancelMatching()
        }
        return
      }

      if (this.mode === "answering") {
        this.answerSymbols.push(symbol)
        this.renderAnswer()
        this.restartIdleTimer()
        this.maybeSubmitAnswer()
      }
    },

    startMatching() {
      if (!this.lobbyChannel) return
      this.lobbyChannel.push("find_game", {})
      this.mode = "queued"
      this.updateQueueStatus("Searching for an opponent...")
    },

    cancelMatching() {
      if (this.lobbyChannel) {
        this.lobbyChannel.push("cancel_find", {})
      }
      this.mode = "idle"
      this.updateQueueStatus("Matchmaking canceled. Press Dash to start matching")
    },

    restartIdleTimer() {
      this.clearIdleTimer()
      this.idleTimeout = setTimeout(() => {
        if (this.mode === "answering") {
          this.feedbackEl.textContent = "Sorry, wrong code. Try again"
          this.answerSymbols = []
          this.renderAnswer()
        }
      }, 2000)
    },

    clearIdleTimer() {
      if (this.idleTimeout) {
        clearTimeout(this.idleTimeout)
        this.idleTimeout = null
      }
    },

    applyQuestion(question, round, totalRounds, deadlineMs, roundMs) {
      if (!question) return
      this.currentPatternHint = question.pattern_hint || ""
      this.questionPromptEl.textContent = question.prompt
      this.questionTypeEl.textContent = question.type === "word" ? "Word challenge" : "Letter challenge"
      this.questionCounterEl.textContent = totalRounds > 0 ? `${round} / ${totalRounds}` : "--"
      this.answerSymbols = []
      this.renderAnswer()
      this.feedbackEl.textContent = ""
      const targetDeadline = this.resolveDeadline(deadlineMs, null, roundMs)
      this.startCountdown(targetDeadline)
    },

    renderAnswer() {
      if (!this.inputEl) return
      const glyphs = formatSymbols(this.answerSymbols)
      this.inputEl.textContent = glyphs.length > 0 ? glyphs : ""
    },

    renderScoreboard(players) {
      if (!this.scoreboardEl) return
      const entries = Object.entries(players)
      if (entries.length === 0) {
        this.scoreboardEl.innerHTML = `<div class="rounded-2xl border border-slate-800/60 bg-slate-950/80 px-4 py-3 text-slate-500">Waiting for players¡­</div>`
        return
      }

      this.scoreboardEl.innerHTML = entries
        .map(([id, data]) => {
          const isSelf = id === this.identity.user_id
          const accent = isSelf ? "border-emerald-400/70 bg-emerald-500/10" : "border-slate-800/60 bg-slate-950/80"
          return `<div class="rounded-2xl border ${accent} px-4 py-3">
            <div class="flex items-center justify-between">
              <div>
                <p class="text-xs uppercase tracking-widest text-slate-500">${isSelf ? "You" : "Opponent"}</p>
                <p class="text-lg font-semibold text-slate-100">${data.nickname}</p>
              </div>
              <p class="text-2xl font-semibold text-emerald-300" data-score-for="${id}">${data.score ?? 0}</p>
            </div>
          </div>`
        })
        .join("")
    },

    updateScores(scores) {
      if (!scores || !this.scoreboardEl) return
      Object.entries(scores).forEach(([uid, score]) => {
        const el = this.scoreboardEl.querySelector(`[data-score-for="${uid}"]`)
        if (el) {
          el.textContent = score
        }
      })
    },

    updateQueueStatus(message) {
      if (this.queuePromptEl) {
        this.queuePromptEl.textContent = message
      }
    },

    updateHighScore() {
      if (this.highScoreEl) {
        this.highScoreEl.textContent = String(this.highScore)
      }
    },

    resolveDeadline(deadlineMs, remainingMs, roundMs) {
      if (typeof deadlineMs === "number" && Number.isFinite(deadlineMs)) {
        return deadlineMs + (this.clockOffsetMs || 0)
      }
      if (typeof remainingMs === "number" && Number.isFinite(remainingMs)) {
        return Date.now() + remainingMs
      }
      if (typeof roundMs === "number" && Number.isFinite(roundMs) && roundMs > 0) {
        return Date.now() + roundMs
      }
      return null
    },

    updateClockOffset(serverNowMs) {
      if (typeof serverNowMs === "number" && Number.isFinite(serverNowMs)) {
        this.clockOffsetMs = Date.now() - serverNowMs
      }
    },

    startCountdown(targetTimestamp) {
      this.clearCountdown()

      if (typeof targetTimestamp !== "number" || Number.isNaN(targetTimestamp)) {
        this.deadline = null
        if (this.timerEl) this.timerEl.textContent = "--"
        return
      }

      this.deadline = targetTimestamp

      const tick = () => {
        if (this.deadline == null) return
        const remaining = Math.max(this.deadline - Date.now(), 0)
        if (this.timerEl) {
          this.timerEl.textContent = `${(remaining / 1000).toFixed(1)}s`
        }
        if (remaining > 0) {
          this.countdownHandle = requestAnimationFrame(tick)
        } else {
          this.countdownHandle = null
        }
      }

      tick()
    },

    clearCountdown() {
      if (this.countdownHandle) {
        cancelAnimationFrame(this.countdownHandle)
        this.countdownHandle = null
      }
      this.deadline = null
      if (this.timerEl) this.timerEl.textContent = "--"
    },

    maybeSubmitAnswer() {
      if (!this.gameChannel || this.answerSymbols.length === 0) return
      if (!this.currentPatternHint) return

      const expectedLength = this.currentPatternHint.replace(/\s+/g, "").length
      const currentLength = formatSymbols(this.answerSymbols).length

      if (currentLength >= expectedLength && expectedLength > 0) {
        this.gameChannel.push("answer", {morse: formatSymbols(this.answerSymbols)})
      }
    }
  }
}



