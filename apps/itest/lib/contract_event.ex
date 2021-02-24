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
defmodule Itest.ContractEvent do
  @moduledoc """
  Listens for contract events passed in as `listen_to`.
  """
  use WebSockex
  alias Itest.Transactions.Encoding

  require Logger

  #
  # Client API
  #

  @doc """
  Starts a GenServer that listens to events.
  """
  @spec start_link(Keyword.t()) :: {:ok, pid()} | no_return()
  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)

    case Process.whereis(name) do
      nil ->
        websockex_start_link(name, opts)

      pid ->
        {:ok, pid}
    end
  end

  #
  # Server API
  #

  @doc false
  @impl true
  def handle_frame({:text, msg}, state) do
    {:ok, decoded} = Jason.decode(msg)

    case decoded["params"]["result"] do
      nil ->
        :ok

      log ->
        abis = Keyword.fetch!(state, :abis)

        topics =
          Enum.map(log["topics"], fn
            nil -> nil
            topic -> Encoding.to_binary(topic)
          end)

        data = Encoding.to_binary(log["data"])

        event =
          ABI.Event.find_and_decode(
            abis,
            Enum.at(topics, 0),
            Enum.at(topics, 1),
            Enum.at(topics, 2),
            Enum.at(topics, 3),
            data
          )

        forward_event(state, event)
    end

    {:ok, state}
  end

  defp forward_event(state, event) do
    {%{function: even_name}, data} = event
    _ = Logger.info("Event #{even_name} detected: #{inspect(data)}")

    case Keyword.get(state, :subscribe, nil) do
      nil ->
        :ok

      to ->
        Kernel.send(to, {:event, event})
    end
  end

  defp websockex_start_link(name, opts) do
    ws_url = Keyword.fetch!(opts, :ws_url)
    abi_path = Keyword.fetch!(opts, :abi_path)

    abis = AbiEvents.get(abi_path)

    case WebSockex.start_link(ws_url, __MODULE__, [{:abis, abis} | opts], name: name) do
      {:error, {:already_started, pid}} ->
        {:ok, pid}

      {:ok, pid} ->
        listen_to = Keyword.fetch!(opts, :listen_to)
        listen(pid, listen_to)

        {:ok, pid}
    end
  end

  defp listen(pid, listen_to) do
    Enum.each(listen_to, fn address ->
      spawn(fn -> send_eth_subscribe(pid, address) end)
    end)
  end

  # >> {"id": 1, "method": "eth_subscribe", "params": ["logs",
  #  {"address": "0x8320fe7702b96808f7bbc0d4a888ed1468216cfd",
  # "topics": ["0xd78a0cb8bb633d06981248b816e7bd33c2a35a6089241d099fa519e361cab902"]}]}
  defp send_eth_subscribe(pid, address) do
    payload = %{
      jsonrpc: "2.0",
      id: Enum.random(1..99_999),
      method: "eth_subscribe",
      params: [
        "logs",
        %{"address" => address}
      ]
    }

    WebSockex.send_frame(pid, {:text, Jason.encode!(payload)})
  end
end
