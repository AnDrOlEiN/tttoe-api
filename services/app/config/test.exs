use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :tictactoe, TictactoeWeb.Endpoint,
  http: [port: 4001],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

# Short TTL so room-sweep tests don't have to wait; the sweep itself
# only runs when triggered explicitly (or after the 5-minute interval).
config :tictactoe, room_ttl: 50
