defmodule Explorer.EthRPCTest do
  use Explorer.DataCase

  import Explorer.Factory, only: [transaction_hash: 0, block_hash: 0, with_block: 2, insert: 2]

  alias Explorer.EthRPC

  alias Explorer.Chain.Block
  alias Explorer.Chain.Transaction

  @json_rpc_2_request %{"jsonrpc" => "2.0", "id" => 1}

  describe "tol_getBlockByHash" do
    setup do
      perv_block_hash = block_hash()
      previous_block = insert(:block, hash: perv_block_hash, number: 99)
      block_hash = block_hash()
      block = insert(:block, hash: block_hash, parent_hash: perv_block_hash)

      transaction_1 = insert(:transaction, hash: transaction_hash()) |> with_block(block)
      transaction_2 = insert(:transaction, hash: transaction_hash()) |> with_block(block)

      hash_binary_representation = hash_to_binary(block_hash)

      %{
        prev_block: previous_block,
        block: block,
        transactions: [transaction_1, transaction_2],
        hash_binary: hash_binary_representation
      }
    end

    test "with valid params returns valid structure", %{
      block: %Block{hash: block_hash, number: number} = block,
      prev_block: %Block{hash: prev_block_hash},
      transactions: transactions,
      hash_binary: hash_binary_representation
    } do
      request = build_request("tol_getBlockByHash", [{"block_hash", hash_binary_representation}])

      transaction_hashes = Enum.map(transactions, & &1.hash)
      confirmation_timestamp = DateTime.to_unix(block.timestamp, :millisecond)

      assert [
               %{
                 id: 1,
                 result: %{
                   block_index: ^number,
                   block_hash: ^block_hash,
                   confirmation_timestamp: ^confirmation_timestamp,
                   previous_block_hash: ^prev_block_hash,
                   transaction_hashes: ^transaction_hashes
                 }
               }
             ] = EthRPC.responses([request])
    end

    test "with no data - return error", %{block: block} do
      arbitrary_hash = block_hash() |> hash_to_binary()
      request = build_request("tol_getBlockByHash", [{"block_hash", arbitrary_hash}])

      assert [%{id: 1, error: "Block not found"}] = EthRPC.responses([request])
    end

    test "with invalid block_hash" do
      request = build_request("tol_getBlockByHash", [{"block_hash", 1}])

      assert_raise(FunctionClauseError, fn ->
        EthRPC.responses([request])
      end)
    end
  end

  describe "tol_get_block_by_index/1" do
    setup do
      perv_block_hash = block_hash()
      previous_block = insert(:block, hash: perv_block_hash, number: 99)
      block_hash = block_hash()
      block = insert(:block, hash: block_hash, parent_hash: perv_block_hash, number: 100)

      transaction_1 = insert(:transaction, hash: transaction_hash()) |> with_block(block)
      transaction_2 = insert(:transaction, hash: transaction_hash()) |> with_block(block)

      hash_binary_representation = hash_to_binary(block_hash)

      %{
        prev_block: previous_block,
        block: block,
        transactions: [transaction_1, transaction_2],
        hash_binary: hash_binary_representation
      }
    end

    test "with valid params returns valid structure", %{
      block: %Block{hash: block_hash, number: block_index} = block,
      prev_block: %Block{hash: prev_block_hash},
      transactions: transactions,
      hash_binary: hash_binary_representation
    } do
      request = build_request("tol_getBlockByIndex", [{"block_index", block_index}])

      transaction_hashes = Enum.map(transactions, & &1.hash)
      confirmation_timestamp = DateTime.to_unix(block.timestamp, :millisecond)

      assert [
               %{
                 id: 1,
                 result: %{
                   block_index: ^block_index,
                   block_hash: ^block_hash,
                   confirmation_timestamp: ^confirmation_timestamp,
                   previous_block_hash: ^prev_block_hash,
                   transaction_hashes: ^transaction_hashes
                 }
               }
             ] = EthRPC.responses([request])
    end

    test "with no data - return error", %{block: block} do
      request = build_request("tol_getBlockByIndex", [{"block_index", 1}])

      assert [%{id: 1, error: "Block not found"}] = EthRPC.responses([request])
    end

    test "with invalid block_hash" do
      request = build_request("tol_getBlockByIndex", [{"block_index", ""}])

      assert_raise(FunctionClauseError, fn ->
        EthRPC.responses([request])
      end)
    end
  end

  defp build_request(method, params) do
    Map.merge(@json_rpc_2_request, %{
      "method" => method,
      "params" => params
    })
  end

  defp hash_to_binary(hash) do
    hash
    |> Explorer.Chain.Hash.to_iodata()
    |> IO.iodata_to_binary()
  end
end
