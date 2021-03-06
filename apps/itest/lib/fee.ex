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
defmodule Itest.Fee do
  @moduledoc """
  Functions to pull fees
  """

  alias Itest.Client

  @doc """
  get all supported fees for payment transactions
  """
  def get_fees() do
    payment_v1 = ExPlasma.payment_v1() |> :binary.decode_unsigned() |> to_string()
    {:ok, %{^payment_v1 => fees}} = Client.get_fees()
    fees
  end

  @doc """
  get the fee for a specific currency
  """
  def get_for_currency(currency) do
    fees = get_fees()
    Enum.find(fees, &(&1["currency"] == currency))
  end
end
