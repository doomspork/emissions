import Config

config :emissions,
  adapters: [{Emissions.Testing.TestAdapter, []}],
  handlers: []
