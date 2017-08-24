use Mix.Config


dev_secret = "8C6FsJwjV11d+1WPUIbkEH6gB/VavJrcXWoPLujgpclfxjkLkoNFSjVU9XfeNm6s"

# General config
config :captain_fact, frontend_url: "http://localhost:3333"

# For development, we disable any cache and enable
# debugging and code reloading.
config :captain_fact, CaptainFactWeb.Endpoint,
  secret_key_base: dev_secret,
  debug_errors: false,
  code_reloader: true,
  check_origin: false,
  http: [port: 4000],
  force_ssl: false,
  https: [
    port: 4001,
    otp_app: :captain_fact,
    keyfile: "priv/keys/privkey.pem",
    certfile: "priv/keys/cert.pem"
  ]

# Watch static and templates for browser reloading.
config :captain_fact, CaptainFactWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r{priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$},
      ~r{priv/gettext/.*(po)$},
      ~r{lib/captain_fact/web/views/.*(ex)$},
      ~r{lib/captain_fact/web/templates/.*(eex)$}
    ]
  ]

# Guardian + Ueberauth

config :guardian, Guardian,
  secret_key: dev_secret

config :ueberauth, Ueberauth.Strategy.Facebook.OAuth,
  client_id: "506726596325615",
  client_secret: "4b320056746b8e57144c889f3baf0424"

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Configure your database
config :captain_fact, CaptainFact.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "captain_fact_dev",
  hostname: "localhost",
  pool_size: 10

# Mails
config :captain_fact, CaptainFact.Mailer, adapter: Bamboo.LocalAdapter