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

defmodule FeeClaimingTests do
  use Cabbage.Feature, async: false, file: "fee_claiming.feature"
  @moduletag :fee

  require Logger

  alias Itest.Account
  alias Itest.Client
  alias Itest.Configuration
  alias Itest.Transactions.Currency
  alias Itest.Transactions.Encoding

  @fee_currency <<0::160>>
  @payment_tx_type "1"

  setup do
    {:ok, _} = DebugEvents.start_link()
    [{alice_address, alice_pkey}, {bob_address, bob_pkey}] = Account.take_accounts(2)
    fee_claimer_address = Configuration.fee_claimer_address()

    initial_balance =
      fee_claimer_address
      |> Client.get_balance!(@fee_currency)
      |> fix_balance_response()

    %{
      "Alice" => %{
        address: alice_address,
        pkey: alice_pkey
      },
      "Bob" => %{
        address: bob_address,
        pkey: bob_pkey
      },
      "FeeClaimer" => %{address: fee_claimer_address},
      fees_initial_balance: initial_balance,
      gas: 0
    }
  end

  defwhen ~r/^"(?<entity>[^"]+)" deposits "(?<amount>[^"]+)" ETH to the root chain$/,
          %{entity: entity, amount: amount},
          state do
    entity_address = state[entity].address

    {:ok, receipt_hash} =
      amount
      |> Currency.to_wei()
      |> Client.deposit(entity_address, Itest.PlasmaFramework.vault(Currency.ether()))

    gas_used = Client.get_gas_used(receipt_hash)

    {_, new_state} =
      Map.get_and_update!(state, :gas, fn current_gas ->
        {current_gas, current_gas + gas_used}
      end)

    {:ok, new_state}
  end

  defwhen ~r/^"(?<sender>[^"]+)" sends "(?<receiver>[^"]+)" "(?<amount>[^"]+)" ETH on the child chain$/,
          %{sender: sender, receiver: receiver, amount: amount},
          state do
    sender = state[sender]
    receiver = state[receiver]

    {:ok, [sign_hash, typed_data, _txbytes]} =
      Client.create_transaction(
        Currency.to_wei(amount),
        sender.address,
        receiver.address
      )

    _ = Client.submit_transaction(typed_data, sign_hash, [sender.pkey])

    {:ok, state}
  end

  defthen ~r/^"(?<entity>[^"]+)" should have "(?<amount>[^"]+)" ETH on the child chain$/,
          %{entity: entity, amount: amount},
          state do
    entity_address = state[entity].address
    expecting_amount = Currency.to_wei(amount)

    balance =
      entity_address
      |> Client.get_exact_balance(expecting_amount)
      |> fix_balance_response()

    balance = balance["amount"]
    assert_equal(expecting_amount, balance, "For #{entity}")
    {:ok, state}
  end

  defthen ~r/^Operator has claimed the fees$/, _, %{fees_initial_balance: initial_balance} do
    # fee_claimer_address needs to match the address in docker-compose
    actual_balance =
      Configuration.fee_claimer_address()
      |> Client.get_balance!(@fee_currency)
      |> fix_balance_response()

    assert_equal(
      initial_balance["amount"] + get_fee_amount(),
      actual_balance["amount"],
      "amount of fees claimed"
    )

    assert_equal(Encoding.to_hex(@fee_currency), actual_balance["currency"], "currency of fees claimed")
  end

  defp assert_equal(left, right, message) do
    assert(left == right, "Expected #{left}, but have #{right}." <> message)
  end

  defp get_fee_amount() do
    {:ok, response} = Client.get_fees()

    fee =
      Enum.find(
        response[@payment_tx_type],
        :fee_for_currency_not_found,
        fn fee_data ->
          fee_data["currency"] == Encoding.to_hex(@fee_currency)
        end
      )

    fee["amount"]
  end

  # TODO: Remove when fixed. See issue: omisego/elixir-omg/issues/1293
  defp fix_balance_response(response) when is_map(response), do: response
  defp fix_balance_response([response]), do: fix_balance_response(response)
  defp fix_balance_response([]), do: %{"amount" => 0}
end
