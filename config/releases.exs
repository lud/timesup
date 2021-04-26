# In this file, we load production configuration and secrets
# from environment variables. You can also hardcode secrets,
# although such is generally not recommended and you have to
# remember to add this file to your .gitignore.
import Config

database_url =
  System.get_env("DATABASE_URL") ||
    raise """
    environment variable DATABASE_URL is missing.
    For example: ecto://USER:PASS@HOST/DATABASE
    """

config :timesup, Timesup.Repo,
  ssl: false,
  url: database_url,
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "2")

secret_key_base =
  System.get_env("SECRET_KEY_BASE") ||
    raise """
    environment variable SECRET_KEY_BASE is missing.
    You can generate one by calling: mix phx.gen.secret
    """

signing_salt =
  System.get_env("SIGNING_SALT") ||
    raise """
    environment variable SIGNING_SALT is missing.
    You can generate one by calling: mix phx.gen.secret
    """

config :timesup, TimesupWeb.Endpoint,
  http: [:inet6, port: String.to_integer(System.get_env("PORT") || "4000")],
  secret_key_base: Map.fetch!(System.get_env(), "SECRET_KEY_BASE"),
  live_view: [
    signing_salt: Map.fetch!(System.get_env(), "SIGNING_SALT")
  ]

# Using releases
config :timesup, TimesupWeb.Endpoint, server: true
