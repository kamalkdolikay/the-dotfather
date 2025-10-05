import Config

# Enable the Phoenix endpoint server if PHX_SERVER=true
if System.get_env("PHX_SERVER") do
  config :the_dotfather, TheDotfatherWeb.Endpoint, server: true
end

if config_env() == :prod do
  # ===== No database section =====
  # We skip all Repo configuration entirely.

  # Secret key base for signing/encrypting cookies
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :the_dotfather, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  # Configure the endpoint for production
  config :the_dotfather, TheDotfatherWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Bind on all IPv4 and IPv6 interfaces
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base
end
