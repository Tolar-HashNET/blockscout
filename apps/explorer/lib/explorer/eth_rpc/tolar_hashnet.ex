defmodule Explorer.EthRPC.TolarHashnet do
  @moduledoc """
  JsonRPC methods handling for Tolar hashnet
  """
  alias Explorer.Chain
  alias Explorer.Chain.{Block, Hash}

  @type tol_get_block_by_hash_response :: %{
          required(:block_hash) => Hash.t(),
          required(:previous_block_hash) => Hash.t(),
          required(:block_index) => EthereumJSONRPC.block_number(),
          required(:confirmation_timestamp) => non_neg_integer(),
          required(:transaction_hashes) => [Hash.t()]
        }

  @type error :: String.t()

  @spec tol_get_block_by_hash(String.t()) :: {:ok, tol_get_block_by_hash_response()} | {:error, error()}
  def tol_get_block_by_hash(block_hash) when is_binary(block_hash) do
    case Chain.fetch_block_by_hash(block_hash, [:transactions]) do
      %Block{} = db_block ->
        transaction_hashes = Enum.map(db_block.transactions, & &1.hash)

        {:ok,
         %{
           block_hash: db_block.hash,
           previous_block_hash: db_block.parent_hash,
           block_index: db_block.number,
           confirmation_timestamp: DateTime.to_unix(db_block.timestamp, :millisecond),
           transaction_hashes: transaction_hashes
         }}

      _ ->
        {:error, "Block not found"}
    end
  end
end
