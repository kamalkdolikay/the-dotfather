# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :the_dotfather,
  ecto_repos: [TheDotfather.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :the_dotfather, :start_repo?, false

config :the_dotfather, TheDotfatherWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: TheDotfatherWeb.ErrorHTML, json: TheDotfatherWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: TheDotfather.PubSub,
  live_view: [signing_salt: "BIxOZo75"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :the_dotfather, TheDotfather.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  the_dotfather: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.7",
  the_dotfather: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
config :the_dotfather, TheDotfather.Tutorial,
  letters: [
    %{letter: "E", pattern: [:dot], image: "/images/tutorial/e.svg"},
    %{letter: "T", pattern: [:dash], image: "/images/tutorial/t.svg"},
    %{letter: "I", pattern: [:dot, :dot], image: "/images/tutorial/i.svg"},
    %{letter: "M", pattern: [:dash, :dash], image: "/images/tutorial/m.svg"},
    %{letter: "A", pattern: [:dot, :dash], image: "/images/tutorial/a.svg"},
    %{letter: "S", pattern: [:dot, :dot, :dot], image: "/images/tutorial/s.svg"}
  ]

import_config "#{config_env()}.exs"
