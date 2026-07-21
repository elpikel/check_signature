# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :check_signature,
  ecto_repos: [CheckSignature.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configure the endpoint
config :check_signature, CheckSignatureWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: CheckSignatureWeb.ErrorHTML, json: CheckSignatureWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: CheckSignature.PubSub,
  live_view: [signing_salt: "EoUkph/O"]

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :check_signature, CheckSignature.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  check_signature: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  check_signature: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Signature verification: which Sources we fan out to, how we cache, and the
# guardrails that keep us from abusing the scraped portals. See docs/adr/.
# Verification is answered solely from the harvested `rulings` index — no live
# per-request scraping. This key now only tunes the background harvesters' HTTP
# timeout (a harvest fetch slower than this is abandoned for that run).
config :check_signature, CheckSignature.Verification, source_timeout_ms: 8_000

config :check_signature, CheckSignature.Signatures,
  # Never process more extracted Signatures than this per Document.
  max_signatures: 50

# Oban: background harvesting of court Rulings into the local `rulings` index.
# Browser-driven harvests (common courts) get their own single-slot queue so a
# heavy Chromium job never crowds out the light HTTP harvests or the default queue.
config :check_signature, Oban,
  repo: CheckSignature.Repo,
  queues: [default: 10, harvest_http: 2, harvest_browser: 1],
  plugins: [
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7},
    # All three Sources harvest on the hour: SN and CBOSA scrape their official
    # portals; common courts is harvested from SAOS (the official portal is behind
    # a browser-only bot wall). Each is a separate cron so a slow/blocked Source
    # never stalls the others.
    {Oban.Plugins.Cron,
     crontab: [
       # Incremental sync — page newest-first, stop on the first fully-known page.
       {"0 * * * *", CheckSignature.Verification.HarvestWorker,
        args: %{"source" => "supreme_court"}},
       {"15 * * * *", CheckSignature.Verification.HarvestWorker,
        args: %{"source" => "administrative_courts"}},
       {"30 * * * *", CheckSignature.Verification.HarvestWorker,
        args: %{"source" => "common_courts"}}
     ]}
  ]

config :check_signature, CheckSignatureWeb.CheckController,
  # Reject Documents larger than this before extraction (bytes).
  max_document_bytes: 100_000,
  # Per-IP rate limit: at most this many checks per window.
  rate_limit_max: 10,
  rate_limit_window_ms: 60_000

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
