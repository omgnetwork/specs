# Copyright 2019-2021 OMG Network Pte Ltd
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

defmodule Itest.Configuration do
  @moduledoc false

  def ethereum_ws_url() do
    Application.get_env(:itest, :ethereum_ws_url)
  end

  def child_chain_url() do
    Application.get_env(:itest, :child_chain_url)
  end

  def watcher_info_url() do
    Application.get_env(:itest, :watcher_info_url)
  end

  def watcher_url() do
    Application.get_env(:itest, :watcher_url)
  end

  def fee_claimer_address() do
    Application.fetch!(:itest, :fee_claimer_address)
  end

  def exit_id_size() do
    Application.get_env(:itest, :exit_id_size)
  end

  def exit_id_type() do
    case exit_id_size() do
      168 -> :uint168
      160 -> :uint160
    end
  end
end
