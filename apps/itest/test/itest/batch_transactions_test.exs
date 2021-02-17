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

defmodule BatchTransactionsTests do
  use Cabbage.Feature, async: true, file: "batch_transactions.feature"
  @moduletag :transactions

  require Logger

  alias ExPlasma.Transaction.Payment
  alias Itest.Account
  alias ChildChainAPI.Model.TransactionBatchSubmitBodySchema
  alias Itest.Transactions.Encoding
  alias ChildChainAPI.Api.Transaction
  alias ChildChainAPI.Connection, as: ChildChain
  alias Itest.Client
  alias Itest.Fee
  alias Itest.Transactions.Currency

  import Itest.Poller,
    only: [
      pull_for_utxo_until_recognized_deposit: 4,
      pull_balance_until_amount: 2,
      pull_api_until_successful: 4,
      wait_on_receipt_confirmed: 1,
      all_events_in_status?: 1
    ]

  setup do
    {:ok, _} = DebugEvents.start_link()

    [{alice_address, alice_pkey}, {bob_address, bob_pkey}] = Account.take_accounts(2)

    eth_fee =
      Currency.ether()
      |> Encoding.to_hex()
      |> Fee.get_for_currency()
      |> Map.get("amount")

    %{
      "fee" => eth_fee,
      "Alice" => %{
        address: alice_address,
        pkey: "0x" <> alice_pkey,
        gas: 0,
        ethereum_balance: 0,
        ethereum_initial_balance: 0,
        child_chain_balance: 0,
        utxos: [],
        exit_data: nil,
        transaction_submit: nil,
        receipt_hashes: [],
        in_flight_exit_id: nil,
        in_flight_exit: nil
      },
      "Bob" => %{
        address: bob_address,
        pkey: "0x" <> bob_pkey,
        gas: 0,
        ethereum_balance: 0,
        ethereum_initial_balance: 0,
        child_chain_balance: 0,
        utxos: [],
        exit_data: nil,
        transaction_submit: nil,
        receipt_hashes: [],
        in_flight_exit_id: nil,
        in_flight_exit: nil
      }
    }
  end

  defwhen ~r/^Alice deposits "(?<amount>[^"]+)" ETH to the root chain$/,
          %{amount: amount},
          state do
    entity = "Alice"
    %{address: address} = entity_state = state[entity]
    initial_balance = Itest.Poller.root_chain_get_balance(address)

    {:ok, receipt_hash} =
      amount
      |> Currency.to_wei()
      |> Client.deposit(address, Itest.PlasmaFramework.vault(Currency.ether()))

    geth_block_every = 1

    {:ok, response} =
      WatcherSecurityCriticalAPI.Api.Configuration.configuration_get(WatcherSecurityCriticalAPI.Connection.new())

    watcher_security_critical_config =
      WatcherSecurityCriticalConfiguration.to_struct(Jason.decode!(response.body)["data"])

    finality_margin_blocks = watcher_security_critical_config.deposit_finality_margin
    to_miliseconds = 1000

    finality_margin_blocks
    |> Kernel.*(geth_block_every)
    |> Kernel.*(to_miliseconds)
    |> Kernel.round()
    |> Process.sleep()

    balance_after_deposit = Itest.Poller.root_chain_get_balance(address)
    deposited_amount = initial_balance - balance_after_deposit

    entity_state =
      entity_state
      |> Map.put(:ethereum_balance, balance_after_deposit)
      |> Map.put(:ethereum_initial_balance, initial_balance)
      |> Map.put(:last_deposited_amount, deposited_amount)
      |> Map.put(:receipt_hashes, [receipt_hash | entity_state.receipt_hashes])

    {:ok, Map.put(state, entity, entity_state)}
  end

  defthen ~r/^Alice should have "(?<amount>[^"]+)" ETH on the child chain after finality margin$/,
          %{amount: amount},
          state do
    entity = "Alice"
    %{address: address} = entity_state = state[entity]
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
      pull_for_utxo_until_recognized_deposit(
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

    {:ok, Map.put(state, entity, entity_state)}
  end

  defwhen ~r/^Alice sends Bob "(?<times>[^"]+)" batch transactions for "(?<amount>[^"]+)" ETH on the child chain$/,
          %{times: times, amount: amount},
          state do

    %{address: address, utxos: utxos} = entity_state = state["Alice"]

    utxo = hd(utxos)
    batch =
      1..String.to_integer(times)
      |> Enum.map(fn _ ->
        amount = 1

        alice_input = %ExPlasma.Utxo{
          blknum: utxo.blknum,
          currency: Currency.ether(),
          oindex: 0,
          txindex: utxo.txindex,
          output_type: 1,
          owner: address
        }

        bob_output = %ExPlasma.Utxo{
          currency: Currency.ether(),
          owner: alice_address,
          amount: bob_child_chain_balance - amount - state.fee
        }

        transaction = %Payment{inputs: [bob_input], outputs: [alice_output, bob_output]}

        submitted_tx =
          ExPlasma.Transaction.sign(transaction,
            keys: [bob_pkey]
          )

        ExPlasma.Transaction.encode(submitted_tx)
      end)

    send_transactions(batch)
    {:ok, state}
  end

  defthen ~r/^"(?<entity>[^"]+)" should have "(?<amount>[^"]+)" ETH on the child chain$/,
          %{entity: entity, amount: amount},
          state do
    expecting_amount = Currency.to_wei(amount)
    balance = Client.get_exact_balance(alice_account, expecting_amount)
    balance = balance["amount"]

    assert_equal(Currency.to_wei(amount), balance, "For #{alice_account} #{index}.")
  end

  # defthen ~r/^others should have "(?<amount>[^"]+)" ETH on the child chain$/,
  #         %{amount: amount},
  #         %{bobs: bobs} = state do
  #   bobs
  #   |> Enum.with_index()
  #   |> Task.async_stream(
  #     fn {{bob_account, _}, index} ->
  #       expecting_amount = Currency.to_wei(amount)

  #       balance = Client.get_exact_balance(bob_account, expecting_amount)
  #       balance = balance["amount"]

  #       assert_equal(expecting_amount, balance, "For #{bob_account} #{index}.")
  #     end,
  #     timeout: 240_000,
  #     on_timeout: :kill_task,
  #     max_concurrency: @num_accounts
  #   )
  #   |> Enum.map(fn {:ok, result} -> result end)

  #   {:ok, state}
  # end

  defp assert_equal(left, right, message) do
    assert(left == right, "Expected #{left}, but have #{right}." <> message)
  end

  # alice_output = %ExPlasma.Utxo{
  #   currency: Currency.ether(),
  #   owner: alice_address,
  #   amount: amount
  # }

  # bob_output = %ExPlasma.Utxo{
  #   currency: Currency.ether(),
  #   owner: bob_address,
  #   amount: bob_child_chain_balance - amount - state["fee"]
  # }

  # transaction = %Payment{inputs: [bob_input], outputs: [alice_output, bob_output]}

  # submitted_tx =
  #   ExPlasma.Transaction.sign(transaction,
  #     keys: [bob_pkey]
  #   )

  # txbytes = ExPlasma.Transaction.encode(submitted_tx)

  # _submit_transaction_response = send_transaction(txbytes)

  defp send_transactions(transactions_bytes) do
    transactions_bytes = Enum.map(transactions_bytes, &Encoding.to_hex/1)
    batch_transaction_submit_body_schema = %TransactionBatchSubmitBodySchema{transactions: transactions_bytes}
    {:ok, response} = Transaction.submit(ChildChain.new(), batch_transaction_submit_body_schema)

    response
    |> Map.get(:body)
    |> Jason.decode!()
    |> Map.get("data")
    |> IO.inspect(label: "TransactionBatchSubmit")

    # |> SubmitTransactionResponse.to_struct()
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
