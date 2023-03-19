defmodule Explorer.Chain.Transaction.TolarTransactionDataTest do
  use Explorer.DataCase

  alias Ecto.Changeset
  alias Explorer.Chain.Transaction.TolarTransactionData

  doctest TolarTransactionData

  test "a tolar_transaction_data cannot be inserted if the corresponding transaction does not exist" do
    assert %Changeset{valid?: true} = changeset = TolarTransactionData.changeset(%TolarTransactionData{}, params_for(:tolar_transaction_data))

    assert {:error, %Changeset{errors: [transaction: {"does not exist", _}]}} = Repo.insert(changeset)
  end
end
