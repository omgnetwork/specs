# Copyright 2019-2020 OmiseGO Pte Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule DebugEvents do
  @moduledoc """
  Shortcut to events tracking via WS
  """

  alias Itest.Transactions.Currency
  alias Itest.Transactions.Encoding

  def start_link() do
    plasma_framework = Itest.PlasmaFramework.address()
    vault_ether_address = Currency.ether() |> Itest.PlasmaFramework.vault() |> Encoding.to_hex()
    vault_erc20_address = Currency.erc20() |> Itest.PlasmaFramework.vault() |> Encoding.to_hex()
    exit_game_contract_address = Itest.PlasmaFramework.exit_game_contract_address(ExPlasma.payment_v1())
    Process.flag(:trap_exit, true)

    Itest.ContractEvent.start_link(
      ws_url: "ws://127.0.0.1:8546",
      name: :eth_vault,
      listen_to: [plasma_framework, vault_ether_address, vault_erc20_address, exit_game_contract_address],
      abi_path:
        System.get_env("PLASMA_CONTRACTS_DIR") ||
          Path.join([File.cwd!(), "../../../../data/plasma-contracts/contracts/"]),
      subscribe: self()
    )
  end
end
