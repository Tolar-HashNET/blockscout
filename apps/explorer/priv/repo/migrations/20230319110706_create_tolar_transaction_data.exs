defmodule Explorer.Repo.Migrations.CreateTolarTransactionData do
  use Ecto.Migration

  def change do
    create table(:tolar_transaction_data, primary_key: false) do
      add(:hash, references(:transactions, column: :hash, on_delete: :delete_all, type: :bytea), null: false)

      add(:gas_refunded, :numeric, precision: 100, null: true)

      add(:network_id, :integer, null: false)
      add(:output, :bytea, null: false)

      timestamps(null: false, type: :utc_datetime_usec)
    end

    create unique_index(:tolar_transaction_data, :hash)
  end
end
