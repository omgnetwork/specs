use Mix.Config

config :ethereumex,
  url: "http://localhost:8545",
  http_options: [timeout: 60_000, recv_timeout: 60_000]

config :itest,
  exit_id_size: String.to_integer(System.get_env("EXIT_ID_SIZE") || "160"), # 168 contracts v2
  reorg: System.get_env("REORG"),
  localchain_contract_env_path:
    System.get_env("LOCALCHAIN_CONTRACT_ADDRESSES") || "./../../localchain_contract_addresses.env"

config :ex_plasma,
  exit_id_size: String.to_integer(System.get_env("EXIT_ID_SIZE") || "160") # 168 contracts v2

config :tesla, adapter: Tesla.Adapter.Hackney

config :logger, level: :info
