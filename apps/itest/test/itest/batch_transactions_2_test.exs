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

defmodule BatchTransactions2Tests do
  use Cabbage.Feature, async: true, file: "batch_transactions_2.feature"
  @moduletag :transactions

  require Logger

  alias ExPlasma.Transaction.Payment
  alias Itest.Account
  alias Itest.ApiModel.WatcherSecurityCriticalConfiguration
  alias Itest.Client
  alias Itest.Fee
  alias Itest.Poller
  alias Itest.Transactions.Currency
  alias Itest.Transactions.Encoding
  alias WatcherSecurityCriticalAPI.Api.Transaction
  alias WatcherSecurityCriticalAPI.Connection, as: Watcher
  alias WatcherSecurityCriticalAPI.Model.TransactionBatchSubmitBodySchema

  setup do
    {:ok, _} = DebugEvents.start_link()

    accounts = Account.take_accounts(3)

    eth_fee =
      Currency.ether()
      |> Encoding.to_hex()
      |> Fee.get_for_currency()
      |> Map.get("amount")

    ["Alice", "Bob", "Eve"]
    |> Enum.zip(accounts)
    |> Enum.reduce(%{}, fn {name, {address, pkey}}, map_acc ->
      Map.merge(map_acc, %{
        name => %{
          address: address,
          pkey: "0x" <> pkey,
          gas: 0,
          ethereum_balance: 0,
          ethereum_initial_balance: 0,
          child_chain_balance: 0,
          utxos: [],
          transaction_submit: nil,
          receipt_hashes: []
        }
      })
    end)
    |> Map.merge(%{"fee" => eth_fee})
  end

  defwhen ~r/^they deposit "(?<amount>[^"]+)" ETH to the root chain$/,
          %{amount: amount},
          state do
    entity_1 = "Alice"
    entity_2 = "Bob"
    entity_3 = "Eve"

    receipts =
      Enum.map([entity_1, entity_2, entity_3], fn entity ->
        %{address: address} = state[entity]

        {:ok, receipt_hash} =
          amount
          |> Currency.to_wei()
          |> Client.deposit(address, Itest.PlasmaFramework.vault(Currency.ether()))

        receipt_hash
      end)

    # lets wait for the three deposits to be recognized
    geth_block_every_seconds = 1

    {:ok, response} = WatcherSecurityCriticalAPI.Api.Configuration.configuration_get(Watcher.new())

    watcher_security_critical_config =
      WatcherSecurityCriticalConfiguration.to_struct(Jason.decode!(response.body)["data"])

    finality_margin_blocks = watcher_security_critical_config.deposit_finality_margin
    to_miliseconds = 1000

    finality_margin_blocks
    |> Kernel.*(geth_block_every_seconds)
    |> Kernel.*(to_miliseconds)
    # for good measure so that we avoid any kind of race conditions
    # blocks are very fast locally (1second)
    |> Kernel.+(10_000)
    |> Kernel.round()
    |> Process.sleep()

    new_state =
      [entity_1, entity_2, entity_3]
      |> Enum.zip(receipts)
      |> Enum.reduce(state, fn {entity, receipt_hash}, state_acc ->
        %{address: address} = entity_state = state_acc[entity]
        initial_balance = Itest.Poller.root_chain_get_balance(address)
        balance_after_deposit = Itest.Poller.root_chain_get_balance(address)
        deposited_amount = initial_balance - balance_after_deposit

        entity_state =
          entity_state
          |> Map.put(:ethereum_balance, balance_after_deposit)
          |> Map.put(:ethereum_initial_balance, initial_balance)
          |> Map.put(:last_deposited_amount, deposited_amount)
          |> Map.put(:receipt_hashes, [receipt_hash | entity_state.receipt_hashes])

        Map.put(state_acc, entity, entity_state)
      end)

    {:ok, new_state}
  end

  defthen ~r/^they should have "(?<amount>[^"]+)" ETH on the child chain after finality margin$/,
          %{amount: amount},
          state do
    entity_1 = "Alice"
    entity_2 = "Bob"
    entity_3 = "Eve"

    new_state =
      Enum.reduce([entity_1, entity_2, entity_3], state, fn entity, state_acc ->
        %{address: address} = entity_state = state_acc[entity]
        _ = Logger.info("#{entity} should have #{amount} ETH on the child chain after finality margin")

        child_chain_balance =
          case amount do
            "0" ->
              assert Client.get_exact_balance(address, Currency.to_wei(amount)) == []
              0

            _ ->
              %{"amount" => network_amount} = Client.get_exact_balance(address, Currency.to_wei(amount))
              assert network_amount == Currency.to_wei(amount)
              network_amount
          end

        blknum = capture_blknum_from_event(address, amount)

        all_utxos =
          Poller.pull_for_utxo_until_recognized_deposit(
            address,
            Currency.to_wei(amount),
            Encoding.to_hex(Currency.ether()),
            blknum
          )

        balance = Itest.Poller.root_chain_get_balance(address)

        entity_state =
          entity_state
          |> Map.put(:ethereum_balance, balance)
          |> Map.put(:utxos, all_utxos["data"])
          |> Map.put(:child_chain_balance, child_chain_balance)

        Map.put(state_acc, entity, entity_state)
      end)

    {:ok, new_state}
  end

  defwhen ~r/^Alice and Eve start a batch transactions for "(?<amount>[^"]+)" WEI to Bob on the child chain$/,
          %{amount: amount},
          state do
    entity_1 = "Alice"
    entity_3 = "Eve"

    batch =
      Enum.reduce([entity_1, entity_3], [], fn entity, acc_batch ->
        %{
          address: entity_address,
          pkey: entity_pkey,
          utxos: [utxo | _],
          child_chain_balance: entity_child_chain_balance
        } = state[entity]

        amount = String.to_integer(amount)

        %{address: bob_address} = state["Bob"]

        entity_input = %ExPlasma.Utxo{
          blknum: utxo["blknum"],
          currency: Currency.ether(),
          oindex: 0,
          txindex: utxo["txindex"],
          output_type: 1
        }

        bob_output = %ExPlasma.Utxo{
          currency: Currency.ether(),
          owner: bob_address,
          amount: amount
        }

        entity_output = %ExPlasma.Utxo{
          currency: Currency.ether(),
          owner: entity_address,
          amount: entity_child_chain_balance - 1 - state["fee"]
        }

        transaction = %Payment{inputs: [entity_input], outputs: [bob_output, entity_output]}

        submitted_tx = ExPlasma.Transaction.sign(transaction, keys: [entity_pkey])

        [ExPlasma.Transaction.encode(submitted_tx) | acc_batch]
      end)

    {:ok, Map.put(state, "batch", Enum.reverse(batch))}
  end

  defwhen ~r/^Bob adds a transactions for "(?<amount>[^"]+)" WEI that uses a non existing UTXO on the child chain$/,
          %{amount: amount},
          state do
    entity_2 = "Bob"

    batch =
      Enum.reduce([entity_2], [], fn entity, acc_batch ->
        %{
          address: entity_address,
          pkey: entity_pkey,
          utxos: [utxo | _],
          child_chain_balance: entity_child_chain_balance
        } = state[entity]

        amount = String.to_integer(amount)

        %{address: bob_address} = state["Bob"]
        # we're trying to spend a UTXO that doesn't exist! on purpose!
        non_existent_utxo = utxo["blknum"] + 1

        entity_input = %ExPlasma.Utxo{
          blknum: non_existent_utxo,
          currency: Currency.ether(),
          oindex: 0,
          txindex: utxo["txindex"],
          output_type: 1
        }

        bob_output = %ExPlasma.Utxo{
          currency: Currency.ether(),
          owner: bob_address,
          amount: amount
        }

        entity_output = %ExPlasma.Utxo{
          currency: Currency.ether(),
          owner: entity_address,
          amount: entity_child_chain_balance - 1 - state["fee"]
        }

        transaction = %Payment{inputs: [entity_input], outputs: [bob_output, entity_output]}

        submitted_tx = ExPlasma.Transaction.sign(transaction, keys: [entity_pkey])

        [ExPlasma.Transaction.encode(submitted_tx) | acc_batch]
      end)

    old_batch = state["batch"]

    {:ok,
     state
     |> Map.put("batch", old_batch ++ batch)
     |> Map.put("send_transactions", send_transactions(old_batch ++ batch))}
  end

  defthen ~r/^"(?<entity>[^"]+)" should have "(?<amount>[^"]+)" WEI on the child chain$/,
          %{entity: entity, amount: amount},
          state do
    %{address: bob_address} = state[entity]
    # bob has 10ETH
    # gets 1 wei from alice
    # gets 1 wei from eve
    # send 1 transaction and pays 1 wei fee
    expecting_amount = String.to_integer(amount)

    balance = Client.get_exact_balance(bob_address, expecting_amount)
    balance = balance["amount"]

    assert_equal(expecting_amount, balance, "For #{bob_address}.")
  end

  defthen ~r/^the batch transaction response should have a error on the third index$/, _vars, state do
    data = state["send_transactions"]

    [
      %{
        "txindex" => 0
      },
      %{
        "txindex" => 1
      },
      %{"error" => "utxo_not_found"}
    ] = data
  end

  defp assert_equal(left, right, message) do
    assert(left == right, "Expected #{left}, but have #{right}." <> message)
  end

  defp send_transactions(transactions_bytes) do
    transactions_bytes = Enum.map(transactions_bytes, &Encoding.to_hex/1)
    batch_transaction_submit_body_schema = %TransactionBatchSubmitBodySchema{transactions: transactions_bytes}
    {:ok, response} = Transaction.batch_submit(Watcher.new(), batch_transaction_submit_body_schema)

    data =
      response
      |> Map.get(:body)
      |> Jason.decode!()
      |> Map.get("data")

    Logger.info("#{inspect(data)}")

    [%{"txindex" => 0}, %{"txindex" => 1}, %{"error" => "utxo_not_found"}] = data
  end

  defp capture_blknum_from_event(address, amount) do
    receive do
      {:event,
       {%ABI.FunctionSelector{},
        [
          {"depositor", "address", true, event_account},
          {"blknum", "uint256", true, event_blknum},
          {"token", "address", true, event_token},
          {"amount", "uint256", false, event_amount}
        ]}} = message ->
        # is this really our deposit?
        # let's double check with what we know
        case {Encoding.to_hex(event_account) == address, Currency.ether() == event_token,
              Currency.to_wei(amount) == event_amount} do
          {true, true, true} ->
            event_blknum

          _ ->
            # listen to some more, maybe we captured some other accounts deposit
            # return the message in the mailbox
            send(self(), message)
            capture_blknum_from_event(event_account, amount)
        end
    after
      5_000 ->
        throw(:deposit_event_didnt_arrive)
    end
  end
end
