defmodule Explorer.Chain.Import.Runner.Transaction.TolarTransactionData do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Transaction.TolarTransactionData.t/0`.
  """

  require Ecto.Query

  import Ecto.Query, only: [from: 2]

  alias Ecto.{Multi, Repo}
  alias Explorer.Chain.{Hash, Import, Transaction}

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [
          %{required(:hash) => Hash.Full.t()}
        ]

  @impl Import.Runner
  def ecto_schema_module, do: Transaction.TolarTransactionData

  @impl Import.Runner
  def option_key, do: :transactions

  @impl Import.Runner
  def imported_table_row do
    %{
      value_type: "[%{hash: Explorer.Chain.Hash.t()}]",
      value_description: "List of maps of the `t:#{ecto_schema_module()}.t/0` `hash` "
    }
  end

  @impl Import.Runner
  def run(multi, changes_list, %{timestamps: timestamps} = options) do
    insert_options =
      options
      |> Map.get(option_key(), %{})
      |> Map.take(~w(on_conflict timeout)a)
      |> Map.put_new(:timeout, @timeout)
      |> Map.put(:timestamps, timestamps)

    Multi.run(multi, :tolar_transaction_data, fn repo, _ ->
      insert(repo, changes_list, insert_options)
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{
          optional(:on_conflict) => Import.Runner.on_conflict(),
          required(:timeout) => timeout,
          required(:timestamps) => Import.timestamps()
        }) :: {:ok, [%{hash: Hash.t()}]}
  defp insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    Import.insert_changes_list(
      repo,
      changes_list,
      conflict_target: :hash,
      on_conflict: on_conflict,
      for: Transaction.TolarTransactionData,
      returning: [:hash],
      timeout: timeout,
      timestamps: timestamps
    )
  end

  defp default_on_conflict do
    from(
      tolar_tx_data in Transaction.TolarTransactionData,
      update: [
        set: [
          gas_refunded: fragment("EXCLUDED.gas_refunded"),
          network_id: fragment("EXCLUDED.network_id"),
          output: fragment("EXCLUDED.output")
        ]
      ],
      where: fragment("EXCLUDED.hash <> ?", tolar_tx_data.hash)
    )
  end
end
