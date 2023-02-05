defmodule Explorer.EthRPC.TolarHashnet do
  @moduledoc """
  JsonRPC methods handling for Tolar hashnet
  """
  alias Explorer.Chain
  alias Explorer.Chain.{Block, Hash}

  @type tol_block_response :: %{
          required(:block_hash) => Hash.t(),
          required(:previous_block_hash) => Hash.t(),
          required(:block_index) => EthereumJSONRPC.block_number(),
          required(:confirmation_timestamp) => non_neg_integer(),
          required(:transaction_hashes) => [Hash.t()]
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
end
