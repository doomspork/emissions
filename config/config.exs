import Config

config :emissions,
  adapters: [],
  handlers: []

import_config "#{config_env()}.exs"
