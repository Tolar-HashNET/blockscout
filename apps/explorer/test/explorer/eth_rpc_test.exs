defmodule Explorer.EthRPCTest do
  use Explorer.DataCase

  import Explorer.Factory, only: [transaction_hash: 0, block_hash: 0, with_block: 2, insert: 2, insert_list: 2]

  alias Explorer.EthRPC

  alias Explorer.Chain.Block
  alias Explorer.Chain.Transaction

  @json_rpc_2_request %{"jsonrpc" => "2.0", "id" => 1}

  describe "eth_address_to_tolar/1" do
    test "converts eth_address to tolar format correctly" do
      tx_example_hash = "0000000000000000000000000000000000000000"
      {:ok, hash} = Explorer.Chain.Hash.Address.cast("0x" <> tx_example_hash)

      assert Explorer.EthRPC.TolarHashnet.eth_address_to_tolar(hash) ===
               "54000000000000000000000000000000000000000023199e2b"
    end
  end

  describe "tol_getBlockCount" do
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

  describe "tol_getLatestBlock/0" do
    setup do
      perv_block_hash = block_hash()
      previous_block = insert(:block, hash: perv_block_hash, number: 99)
      block_hash = block_hash()
      block = insert(:block, hash: block_hash, parent_hash: perv_block_hash, number: 100)

      _other_block = insert(:block, number: 89)

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
      request = build_request("tol_getLatestBlock")

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
  end

  describe "tol_getBlockCount/0" do
    test "with 5 blocks in database - return 5 as a result" do
      insert_list(5, :block)
      request = build_request("tol_getBlockCount")

      assert [
               %{
                 id: 1,
                 result: 5
               }
             ] = EthRPC.responses([request])
    end

    test "with no blocks - return 0 as a result" do
      request = build_request("tol_getBlockCount")

      assert [
               %{
                 id: 1,
                 result: 0
               }
             ] = EthRPC.responses([request])
    end
  end

  describe "tol_get_transaction/1" do
    setup do
      block_hash = block_hash()
      block = insert(:block, hash: block_hash)
      transaction = insert(:transaction, hash: transaction_hash()) |> with_block(block)

      %{block: block, transaction: transaction}
    end

    test "with existing transaction - return info correctly", %{
      transaction: transaction,
      block: %Block{hash: block_hash} = block
    } do
      transaction_hash_binary_representation = hash_to_binary(transaction.hash)
      request = build_request("tol_getTransaction", [{"transaction_hash", transaction_hash_binary_representation}])

      %Transaction{
        hash: hash,
        index: index,
        value: value,
        gas: gas,
        gas_price: gas_price,
        nonce: nonce,
        input: data,
        gas_used: gas_used,
        error: exception,
        has_error_in_internal_txs: excepted,
        created_contract_address_hash: new_address,
        from_address: from,
        to_address: to
      } = transaction

      confirmation_timestamp = DateTime.to_unix(block.timestamp, :millisecond)

      assert [
               %{
                 id: 1,
                 result: %{
                   sender_address: resp_from,
                   receiver_address: resp_to,
                   transaction_hash: ^hash,
                   transaction_index: ^index,
                   value: ^value,
                   block_hash: ^block_hash,
                   gas: ^gas,
                   gas_price: ^gas_price,
                   nonce: ^nonce,
                   data: ^data,
                   gas_used: ^gas_used,
                   exception: ^exception,
                   excepted: ^excepted,
                   new_address: ^new_address,
                   confirmation_timestamp: ^confirmation_timestamp,
                   network_id: nil,
                   output: nil,
                   gas_refunded: nil
                 }
               }
             ] = EthRPC.responses([request])

      refute from == resp_from
      refute to == resp_to
    end

    test "with not existing transaction - return a propper error message" do
      tx_hash = transaction_hash() |> hash_to_binary()
      request = build_request("tol_getTransaction", [{"transaction_hash", tx_hash}])

      assert [%{id: 1, error: "Transaction not found"}] == EthRPC.responses([request])
    end
  end

  defp build_request(method, params \\ []) do
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
