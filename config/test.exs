import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :check_signature, CheckSignature.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "check_signature_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :check_signature, CheckSignatureWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "wf+uDK01MQzDu/PVuVPZ8Y1103gNe+6R2QXyai0lQWoVgGiFvz2xqO006YUieV50",
  server: false

# In test we don't send emails
config :check_signature, CheckSignature.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# In test, fan out to a single Mox-backed Source so we never scrape real portals.
config :check_signature, CheckSignature.Verification,
  sources: [CheckSignature.Verification.MockSource],
  source_timeout_ms: 1_000,
  cache_ttl_seconds: 60

# Make the rate limiter permissive so it doesn't interfere with feature tests.
config :check_signature, CheckSignatureWeb.CheckController,
  max_document_bytes: 100_000,
  rate_limit_max: 1_000,
  rate_limit_window_ms: 60_000

# Route the analytics proxy's outbound Req calls to a Req.Test stub (no retries in tests)
config :check_signature, :analytics_req_options,
  plug: {Req.Test, CheckSignatureWeb.AnalyticsController},
  retry: false
