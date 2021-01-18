defmodule Itest.Configuration do
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
