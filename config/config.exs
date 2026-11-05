
import Config

config :libremarket, Libremarket.Repo,
  hostname: System.get_env("DB_HOST"),
  port: String.to_integer(System.get_env("DB_PORT", "5432")),
  database: System.get_env("DB_NAME"),
  username: System.get_env("DB_USER"),
  password: System.get_env("DB_PASSWORD"),
  pool_size: 5
