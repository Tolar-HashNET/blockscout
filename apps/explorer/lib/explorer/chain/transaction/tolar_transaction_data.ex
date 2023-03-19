defmodule Explorer.Chain.Transaction.TolarTransactionData do
  @moduledoc """
  Holds additional transaction information, specific to Tolar Hashnet network
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias TolarTransactionData

  alias Explorer.Chain.{Data, Transaction, Hash}

  @optional_attrs ~w(gas_refunded)a
  @required_attrs ~w(network_id output hash)a
  @allowed_attrs @optional_attrs ++ @required_attrs

  @typedoc """
   * `hash` - hash of contents of this transaction
   * `transaction` - transaction that additional data belongs to.
   * `gas_refunded` - how much gas refunded (if any).
   * `network_id` - Identifier of the network.
   * `output` - the `output` of the transaction.
  """
  @type t :: %__MODULE__{
    hash: Hash.t(),
    transaction: %Ecto.Association.NotLoaded{} | Transaction.t(),
    gas_refunded: Decimal.t() | nil,
    network_id: non_neg_integer(),
    output: Data.t()
  }

  @primary_key false
  schema "tolar_transaction_data" do
    belongs_to(:transaction, Transaction, foreign_key: :hash, references: :hash, type: Hash.Full)

    field :gas_refunded, :decimal
    field :network_id, :integer
    field :output, Data

    timestamps()
  end

  @doc """
  All fields are required for tolar transaction data

      iex> changeset = TolarTransactionData.changeset(
      ...>   %TolarTransactionData{},
      ...>   %{
      ...>     hash: "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6",
      ...>     gas_refunded: 2300000,
      ...>     network_id: 1,
      ...>     output: "0x"
      ...>   }
      ...> )
      iex> changeset.valid?
      true

  """
  def changeset(%__MODULE__{} = tolar_transaction_data, attrs \\ %{}) do
    tolar_transaction_data
    |> cast(attrs, @allowed_attrs)
    |> validate_required(@required_attrs)
    |> assoc_constraint(:transaction)
  end
end
