defmodule Electric.Client.Conformance do
  @moduledoc false
  # What the client's conformance suites share: a call that cannot hang or crash the suite, a
  # value shown briefly in a failure, and the suites' answer. Ours, not upstream's.

  @doc false
  @spec call((-> term()), timeout()) :: {:ok, term()} | {:crashed, String.t()}
  def call(fun, timeout) do
    task =
      Task.async(fn ->
        try do
          {:ok, fun.()}
        rescue
          exception -> {:crashed, "raised #{Exception.format_banner(:error, exception)}"}
        catch
          kind, reason -> {:crashed, "#{kind}: #{show(reason)}"}
        end
      end)

    case Task.yield(task, timeout) || Task.shutdown(task, :brutal_kill) do
      {:ok, answer} -> answer
      {:exit, reason} -> {:crashed, "exited: #{show(reason)}"}
      nil -> {:crashed, "did not answer within #{timeout} ms"}
    end
  end

  @doc false
  @spec show(term()) :: String.t()
  def show(value), do: inspect(value, limit: 8, printable_limit: 120)

  @doc false
  @spec result([String.t()]) :: :ok | {:error, [String.t()]}
  def result([]), do: :ok
  def result(failures), do: {:error, failures}

  @doc false
  @spec implements?(module(), module()) :: boolean()
  def implements?(module, behaviour) do
    Code.ensure_loaded?(module) and
      behaviour in (module.module_info(:attributes)
                    |> Keyword.get_values(:behaviour)
                    |> List.flatten())
  end
end
