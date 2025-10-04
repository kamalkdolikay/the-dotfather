# The Dotfather

The Dotfather is a Phoenix 1.8 application that teaches Morse code through an interactive tutorial and a head-to-head competition mode.

## Prerequisites

- Elixir 1.15+
- Erlang/OTP 26+
- Node.js 18+ (for JS tooling)

## Initial Setup

```bash
mix deps.get
mix assets.setup
mix assets.build
```

The project does not require a database by default, so you can skip `mix ecto.setup`.

## Running the Server

```bash
mix phx.server
```

Visit [http://localhost:4000](http://localhost:4000) to use the app. Global input uses press duration:

- **Dot** 每 press or click < 250?ms
- **Dash** 每 press or click ≡ 250?ms and < 3?s
- **Long-Dash** 每 press or click ≡ 3?s (acts as exit/back)

## Modes

### Tutorial

Dot on the landing page enters the tutorial. Learn Morse basics, step through configurable letter drills, and use dot/dash/long-dash to advance, revisit, or exit.

### Competition

Dash on the landing page enters matchmaking. Use long-dash to back out. After pairing, each duel consists of 5 rounds (3 letters, 2 words) drawn from the tutorial letters. Answers earn base points plus time bonuses, and the scoreboard updates live.

Highest score persists locally per browser.

## Front-End Development

The global input logic and competition client live in `assets/js/morse_input.js`. Rebuild assets when you change JS or CSS:

```bash
mix assets.build
```

## Tests

Tests are optional and currently skip database setup. Run them with:

```bash
mix test
```

(You can remove the generated controller tests or reconfigure `TheDotfather.Repo` if you need database-backed tests.)

## Repository Layout

- `lib/the_dotfather/` 每 Morse helpers, tutorial config, matchmaking, and game server
- `lib/the_dotfather_web/live/` 每 LiveViews for main, tutorial, and competition pages
- `assets/js/morse_input.js` 每 Press detection, channel wiring, competition logic
- `priv/static/images/` 每 Placeholder artwork for tutorial and landing pages

Enjoy mastering Morse!
