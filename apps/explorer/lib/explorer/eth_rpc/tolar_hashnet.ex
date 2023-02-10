defmodule Explorer.EthRPC.TolarHashnet do
  @moduledoc """
  JsonRPC methods handling for Tolar hashnet
  """
  alias Explorer.Chain
  alias Explorer.Chain.{Address, Block, Data, Hash, Transaction, Wei, Gas}

  @type tol_block_response :: %{
          required(:block_hash) => Hash.t(),
          required(:previous_block_hash) => Hash.t(),
          required(:block_index) => EthereumJSONRPC.block_number(),
          required(:confirmation_timestamp) => non_neg_integer(),
          required(:transaction_hashes) => [Hash.t()]
        }

  @type transaction_response :: %{
          required(:transaction_hash) => Hash.t(),
          required(:block_hash) => Hash.t(),
          required(:transaction_index) => Transaction.transaction_index(),
          required(:sender_address) => Address.t(),
          required(:receiver_address) => Address.t(),
          required(:value) => Wei.t(),
          required(:gas) => Gas.t(),
          required(:gas_price) => Wei.t(),
          required(:nonce) => non_neg_integer(),
          required(:data) => Data.t(),
          required(:gas_used) => Gas.t() | nil,
          required(:confirmation_timestamp) => non_neg_integer(),
          required(:excepted) => boolean(),
          required(:exception) => String.t() | nil,
          network_id: nil,
          output: nil,
          gas_refunded: nil,
          new_address: nil
        }

  @type error :: String.t()

  @spec tol_get_block_by_hash(String.t()) :: {:ok, tol_block_response()} | {:error, error()}
  def tol_get_block_by_hash(block_hash) when is_binary(block_hash) do
    case Chain.fetch_block_by_hash(block_hash, [:transactions]) do
      %Block{} = block ->
        {:ok, build_block_response(block)}

      _ ->
        {:error, "Block not found"}
    end
  end

  @spec tol_get_block_by_index(number()) :: {:ok, tol_block_response()} | {:error, error()}
  def tol_get_block_by_index(block_index) when is_integer(block_index) do
    case Chain.fetch_block_by_index(block_index, [:transactions]) do
      %Block{} = block ->
        {:ok, build_block_response(block)}

      _ ->
        {:error, "Block not found"}
    end
  end

  @spec tol_get_latest_block() :: {:ok, tol_block_response()} | {:error, error()}
  def tol_get_latest_block() do
    case Chain.fetch_latest_block() do
      %Block{} = block ->
        {:ok, build_block_response(block)}

      _ ->
        {:error, "Block not found"}
    end
  end

  @spec tol_get_block_count() :: {:ok, integer()}
  def tol_get_block_count(), do: {:ok, Chain.block_count()}

  @spec tol_get_transaction(String.t()) :: {:ok, transaction_response()} | {:error, error()}
  def tol_get_transaction(transaction_hash) do
    case Chain.fetch_transaction_by_hash(transaction_hash) do
      %Transaction{} = transaction ->
        {:ok, build_transaction_response(transaction)}

      _ ->
        {:error, "Transaction not found"}
    end
  end

  defp build_block_response(block) do
    transaction_hashes = Enum.map(block.transactions, & &1.hash)

    %{
      block_hash: block.hash,
      previous_block_hash: block.parent_hash,
      block_index: block.number,
      confirmation_timestamp: DateTime.to_unix(block.timestamp, :millisecond),
      transaction_hashes: transaction_hashes
    }
  end

  defp build_transaction_response(transaction) do
    %{
      transaction_hash: transaction.hash,
      block_hash: transaction.block_hash,
      transaction_index: transaction.index,
      sender_address: transaction.from_address,
      receiver_address: transaction.to_address,
      value: transaction.value,
      gas: transaction.gas,
      gas_price: transaction.gas_price,
      nonce: transaction.nonce,
      data: transaction.input,
      gas_used: transaction.gas_used,
      exception: transaction.error,
      excepted: transaction.has_error_in_internal_txs,
      new_address: transaction.created_contract_address_hash,
      confirmation_timestamp: DateTime.to_unix(transaction.block.timestamp, :millisecond),
      network_id: nil,
      output: nil,
      gas_refunded: nil
    }
  end
end
