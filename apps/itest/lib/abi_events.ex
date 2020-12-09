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
defmodule AbiEvents do
  @moduledoc """
  Extract ABI event definitions from contract ABIs
  """
  require Logger

  def get(abi_path) do
    abi_path
    |> File.ls!()
    |> Enum.map(fn file ->
      try do
        [abi_path, file]
        |> Path.join()
        |> File.read!()
        |> Jason.decode!()
        |> Map.fetch!("abi")
        |> ABI.parse_specification(include_events?: true)
      rescue
        x in [MatchError, RuntimeError] ->
          _ = Logger.warn("couldn't parse! #{file} because of #{inspect(x)}")
          []
      end
    end)
    |> List.flatten()
    |> Enum.filter(fn fs -> fs.type == :event end)
  end
end