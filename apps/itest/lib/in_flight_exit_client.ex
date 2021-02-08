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

defmodule Itest.InFlightExitClient do
  @moduledoc """
    Implements in-flight exit related actions.
  """
  alias Itest.Transactions.Encoding

  import Itest.Poller, only: [wait_on_receipt_confirmed: 1]

  require Logger

  @gas 540_000

  def delete_in_flight_exit(owner, exit_game_contract_address, exit_id) do
    _ = Logger.info("Deleting in-flight exit.")

    data = ABI.encode("deleteNonPiggybackedInFlightExit(#{Itest.Configuration.exit_id_type()})", [exit_id])

    tx = %{
      from: owner,
      to: exit_game_contract_address,
      data: Encoding.to_hex(data),
      gas: Encoding.to_hex(@gas)
    }

    {:ok, receipt_hash} = Ethereumex.HttpClient.eth_send_transaction(tx)
    wait_on_receipt_confirmed(receipt_hash)
    :ok
  end
end
