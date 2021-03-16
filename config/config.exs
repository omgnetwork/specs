use Mix.Config

config :ethereumex,
  url: System.get_env("ETHEREUM_RPC_URL", "http://localhost:8545"),
  http_options: [timeout: 60_000, recv_timeout: 60_000]

config :itest,
  ethereum_rpc_url: System.get_env("ETHEREUM_RPC_URL", "http://localhost:8545"),
  ethereum_ws_url: System.get_env("ETHEREUM_WS_URL", "ws://127.0.0.1:8546"),
  child_chain_url: System.get_env("CHILD_CHAIN_URL"),
  watcher_info_url: System.get_env("WATCHER_INFO_URL", "http://localhost:7534"),
  watcher_url: System.get_env("WATCHER_URL", "http://localhost:7434"),
  fee_claimer_address: System.get_env("FEE_CLAIMER_ADDRESS"),
  exit_id_size: String.to_integer(System.get_env("EXIT_ID_SIZE") || "160"), # 168 contracts v2
  reorg: System.get_env("REORG"),
  localchain_contract_env_path:
    System.get_env("LOCALCHAIN_CONTRACT_ADDRESSES") || "./../../localchain_contract_addresses.env"

config :ex_plasma,
  exit_id_size: String.to_integer(System.get_env("EXIT_ID_SIZE") || "160") # 168 contracts v2

config :tesla, adapter: Tesla.Adapter.Hackney

config :logger, level: :info
