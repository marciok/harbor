import Config

config :gust,
  b64_secrets_cloak_key: Base.encode64(:binary.copy(<<0>>, 32)),
  dag_runner_supervisor: Gust.DAGRunnerSupervisorMock,
  dag_task_runner_supervisor: Gust.DAGTaskRunnerSupervisorMock

test_database =
  System.get_env("PG_DATABASE", "harbor_test#{System.get_env("MIX_TEST_PARTITION")}")

test_repo_options = [
  username: System.get_env("PG_USER", "postgres"),
  password: System.get_env("PG_PASSWORD", "postgres"),
  hostname: System.get_env("PG_HOST", "localhost"),
  database: test_database,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2
]

config :gust, Gust.Repo, test_repo_options

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :harbor, Harbor.Repo, test_repo_options

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :harbor, HarborWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "KtVTgFmND9OvFK0OZOKpwWwTm4bSEZDsu81WPcqNpyIXJhwl4js1aAUT2aSiAaHL",
  server: false

# In test we don't send emails
config :harbor, Harbor.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
