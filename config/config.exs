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
config :check_signature, CheckSignature.Verification,
  sources: [
    CheckSignature.Verification.Sources.CommonCourts,
    CheckSignature.Verification.Sources.SupremeCourt,
    CheckSignature.Verification.Sources.AdministrativeCourts
  ],
  # A source lookup that takes longer than this is treated as :errored.
  source_timeout_ms: 8_000,
  # Cache a resolved Verdict for this long before re-checking the portals.
  cache_ttl_seconds: 60 * 60 * 24 * 7

config :check_signature, CheckSignature.Signatures,
  # Never process more extracted Signatures than this per Document.
  max_signatures: 50

config :check_signature, CheckSignatureWeb.CheckController,
  # Reject Documents larger than this before extraction (bytes).
  max_document_bytes: 100_000,
  # Per-IP rate limit: at most this many checks per window.
  rate_limit_max: 10,
  rate_limit_window_ms: 60_000

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
