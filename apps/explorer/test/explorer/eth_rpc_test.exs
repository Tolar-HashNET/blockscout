defmodule Explorer.EthRPCTest do
  use Explorer.DataCase, async: true

  import Explorer.Factory,
    only: [
      transaction_hash: 0,
      block_hash: 0,
      with_block: 2,
      insert: 1,
      insert: 2,
      insert_list: 2,
      insert_list: 3,
      build: 2
    ]

  alias Explorer.EthRPC

  alias Explorer.Chain.Block
  alias Explorer.Chain.Transaction
  alias Explorer.Chain.Hash

  @json_rpc_2_request %{"jsonrpc" => "2.0", "id" => 1}

  describe "eth_address_to_tolar/1" do
    test "converts eth_address to tolar format correctly" do
      tx_example_hash = "0000000000000000000000000000000000000000"
      {:ok, hash} = Explorer.Chain.Hash.Address.cast("0x" <> tx_example_hash)

      assert Explorer.EthRPC.TolarHashnet.eth_address_to_tolar(hash) ===
               "54000000000000000000000000000000000000000023199e2b"
    end
  end

  describe "tolar_address_to_eth/1" do
    test "converts tolar address to eth format correctly for zero address" do
      tolar_address = "54000000000000000000000000000000000000000023199e2b"

      assert {:ok,
              %Hash{byte_count: 20, bytes: <<0x0000000000000000000000000000000000000000::big-integer-size(20)-unit(8)>>}} ===
               Explorer.EthRPC.TolarHashnet.tolar_address_to_eth(tolar_address)
    end

    test "convers arbitrary tolar address to eth format correctly" do
      tolar_address = "5493b8597964a2a7f0c93c49f9e4c4a170e0c42a5eb3beda0d"

      assert {:ok,
              %Hash{byte_count: 20, bytes: <<0x93B8597964A2A7F0C93C49F9E4C4A170E0C42A5E::big-integer-size(20)-unit(8)>>}} ===
               Explorer.EthRPC.TolarHashnet.tolar_address_to_eth(tolar_address)
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
      request = build_request("tol_getBlockByHash", %{"block_hash" => hash_binary_representation})

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
      request = build_request("tol_getBlockByHash", %{"block_hash" => arbitrary_hash})

      assert [%{id: 1, error: "Block not found"}] = EthRPC.responses([request])
    end

    test "with invalid block_hash" do
      request = build_request("tol_getBlockByHash", %{"block_hash" => 1})

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
      request = build_request("tol_getBlockByIndex", %{"block_index" => block_index})

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
      request = build_request("tol_getBlockByIndex", %{"block_index" => 1})

      assert [%{id: 1, error: "Block not found"}] = EthRPC.responses([request])
    end

    test "with invalid block_hash" do
      request = build_request("tol_getBlockByIndex", %{"block_index" => ""})

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
      request = build_request("tol_getTransaction", %{"transaction_hash" => transaction_hash_binary_representation})

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
                   new_address: "54000000000000000000000000000000000000000023199e2b",
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
      request = build_request("tol_getTransaction", %{"transaction_hash" => tx_hash})

      assert [%{id: 1, error: "Transaction not found"}] == EthRPC.responses([request])
    end

    test "with invalid hash - return a propper error message" do
      request = build_request("tol_getTransaction", %{"transaction_hash" => "cebdae28242fa6953c3699f42b943c008a08e1f4bcfedac357104aa32cbc544d"})

      assert [%{id: 1, error: "Invalid transaction hash"}] == EthRPC.responses([request])
    end
  end

  describe "tol_getTransactionList/3" do
    setup do
      block_hash = block_hash()
      block = insert(:block, hash: block_hash)
      {:ok, from_address_hash} = Explorer.Chain.Hash.Address.cast("0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5")
      {:ok, to_address_hash} = Explorer.Chain.Hash.Address.cast("0x8880bb98e7747f73b52a9cfA34DAb9A4A06afA38")
      from_address = insert(:address, hash: from_address_hash)

      transaction =
        insert(:transaction,
          hash: transaction_hash(),
          from_address: from_address,
          to_address: build(:address, hash: to_address_hash)
        )
        |> with_block(block)

      %{block: block, transaction: transaction, from_address_hash: from_address_hash, from_address: from_address}
    end

    test "without matched tx_hashes return an error" do
      tolar_address = "5493b8597964a2a7f0c93c49f9e4c4a170e0c42a5eb3beda0d"
      request = build_request("tol_getTransactionList", %{"addresses" => [tolar_address], "limit" => 10, "skip" => 0})

      assert [%{id: 1, error: "Transactions not found"}] == EthRPC.responses([request])
    end

    test "without address return all transactions in database", %{
      transaction: transaction,
      block: %Block{hash: block_hash} = block
    } do
      transaction_hash_binary_representation = hash_to_binary(transaction.hash)
      request = build_request("tol_getTransactionList", %{"addresses" => [], "limit" => 10, "skip" => 0})

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
                 result: [
                   %{
                     sender_address: resp_from,
                     receiver_address: resp_to,
                     new_address: "54000000000000000000000000000000000000000023199e2b",
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
                     confirmation_timestamp: ^confirmation_timestamp,
                     network_id: nil,
                     output: nil,
                     gas_refunded: nil
                   }
                 ]
               }
             ] = EthRPC.responses([request])
    end

    test "with existing tx_hashes return matched transactions", %{from_address_hash: from_address_hash} do
      tolar_format_address = Explorer.EthRPC.TolarHashnet.eth_address_to_tolar(from_address_hash)

      request =
        build_request("tol_getTransactionList", %{"addresses" => [tolar_format_address], "limit" => 10, "skip" => 0})

      assert [%{id: 1, result: [%{sender_address: ^tolar_format_address}]}] = EthRPC.responses([request])
    end

    test "limit parameter restrict the number of returned transactions", %{
      from_address_hash: from_address_hash,
      block: block,
      from_address: from_address
    } do
      limit = 4
      tolar_format_address = Explorer.EthRPC.TolarHashnet.eth_address_to_tolar(from_address_hash)

      params = %{"addresses" => [tolar_format_address], "limit" => limit, "skip" => 0}

      request = build_request("tol_getTransactionList", params)
      insert_list(10, :transaction, from_address: from_address) |> Enum.map(&with_block(&1, block))

      [%{id: 1, result: result}] = EthRPC.responses([request])

      assert ^limit = Enum.count(result)
    end

    test "skip parameter skip's n most recent transactions", %{
      from_address_hash: from_address_hash,
      block: block,
      from_address: from_address
    } do
      limit = 10
      skip = 2

      params = %{
        "addresses" => [Explorer.EthRPC.TolarHashnet.eth_address_to_tolar(from_address_hash)],
        "limit" => limit,
        "skip" => skip
      }

      request = build_request("tol_getTransactionList", params)

      [_, _, third_most_recent | _] =
        l =
        insert_list(10, :transaction, from_address: from_address) |> Enum.map(&with_block(&1, block)) |> Enum.reverse()

      [%{id: 1, result: [result_first_transaction | _]}] = EthRPC.responses([request])

      assert third_most_recent.hash === result_first_transaction.transaction_hash
    end
  end

  describe "tol_getTransactionReceipt/1" do
    setup do
      block_hash = block_hash()
      block = insert(:block, hash: block_hash)
      transaction = insert(:transaction, hash: transaction_hash()) |> with_block(block)

      {:ok, from_address_hash} = Explorer.Chain.Hash.Address.cast("0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5")
      {:ok, to_address_hash} = Explorer.Chain.Hash.Address.cast("0x8880bb98e7747f73b52a9cfA34DAb9A4A06afA38")
      from_address = insert(:address, hash: from_address_hash)
      to_address = insert(:address, hash: to_address_hash)

      transaction =
        insert(:transaction,
          hash: transaction_hash(),
          from_address: from_address,
          to_address: to_address
        )
        |> with_block(block)

      log_1 =
        insert(:log,
          block: block,
          transaction: transaction,
          data: "0x010101",
          address: to_address,
          first_topic: "0x00",
          second_topic: "0x01"
        )

      log_2 = insert(:log, block: block, transaction: transaction, data: "0x010102", address: to_address)
      log_3 = insert(:log, block: block, transaction: transaction, data: "0x010103", address: to_address)

      %{block: block, transaction: transaction, logs: [log_1, log_2, log_3]}
    end

    test "returns an error when transaction isn't found in the database", %{transaction: transaction} do
      tx_hash = transaction_hash() |> hash_to_binary()
      request = build_request("tol_getTransactionReceipt", %{"transaction_hash" => tx_hash})

      assert [%{id: 1, error: "Transaction not found"}] == EthRPC.responses([request])
    end

    test "return response with expected structure when transactions is found", %{
      transaction: transaction,
      block: %Block{number: block_num, hash: block_hash} = block,
      logs: [first_log | _]
    } do
      transaction_hash_binary_representation = hash_to_binary(transaction.hash)

      request =
        build_request("tol_getTransactionReceipt", %{"transaction_hash" => transaction_hash_binary_representation})

      %Transaction{
        hash: tx_hash,
        index: tx_index,
        gas_used: gas_used,
        has_error_in_internal_txs: excepted,
        created_contract_address_hash: new_address
      } = transaction

      assert [
               %{
                 id: 1,
                 result: %{
                   block_hash: ^block_hash,
                   hash: ^tx_hash,
                   transaction_index: ^tx_index,
                   sender_address: sender_address,
                   receiver_address: receiver_address,
                   gas_used: ^gas_used,
                   new_address: new_address,
                   excepted: ^excepted,
                   block_number: ^block_num,
                   logs: [log | _]
                 }
               }
             ] = EthRPC.responses([request])

      assert_tol_address(sender_address)
      assert_tol_address(receiver_address)
      assert_tol_address(new_address)

      assert_tol_address(log.address)
      assert log.data == first_log.data |> Explorer.Chain.Data.to_iodata() |> IO.iodata_to_binary()
      assert log.topics == ["0x00", "0x01"]
    end
  end

  describe "tol_getBlockchainInfo/0" do
    test "return info correctly" do
      last_confirmed_block_hash = block_hash()

      confirmed_block =
        insert(:block, hash: last_confirmed_block_hash, consensus: true, number: 1, timestamp: DateTime.utc_now())

      non_confirmed_block = insert(:block, consensus: false, number: 2, timestamp: DateTime.utc_now())

      # Note, that this will be called automatically every time new block is added
      Explorer.Chain.Cache.Block.set_count(1)

      request = build_request("tol_getBlockchainInfo")

      assert [
               %{
                 id: 1,
                 result: %{
                   confirmed_blocks_count: 1,
                   total_blocks_count: 2,
                   last_confirmed_block_hash: ^last_confirmed_block_hash
                 }
               }
             ] = EthRPC.responses([request])
    end
  end

  describe "tol_getPastEvents/2" do
    setup do
      address = insert(:address)
      block = insert(:block, number: 0)
      transaction_hash = transaction_hash()
      transaction = insert(:transaction, hash: transaction_hash) |> with_block(block)

      insert(:log,
        block: transaction.block,
        address: address,
        transaction: transaction,
        data: "0x010101",
        block_hash: block.hash,
        block_number: 0,
        first_topic: "0x01",
        second_topic: "0x02",
        third_topic: "0x03",
        fourth_topic: "0x04"
      )

      insert(:log,
        block: transaction.block,
        address: address,
        transaction: transaction,
        data: "0x010102",
        block_hash: block.hash,
        block_number: 0,
        first_topic: "0x01",
        second_topic: "0x02"
      )

      %{tol_address: Explorer.EthRPC.TolarHashnet.eth_address_to_tolar(address.hash)}
    end

    test "returns all logs without topic provided", %{tol_address: tol_address} do
      request = build_request("tol_getPastEvents", %{"address" => tol_address, "topic" => nil})

      assert [%{id: 1, result: %{past_events: result}}] = EthRPC.responses([request])

      assert Enum.count(result) == 2
    end

    test "filter by topic correctly", %{tol_address: tol_address} do
      request = build_request("tol_getPastEvents", %{"address" => tol_address, "topic" => "0x03"})

      assert [
               %{
                 id: 1,
                 result: %{
                   past_events: [
                     %{
                       address: address,
                       topic: "0x01",
                       topic_arg_0: "0x02",
                       topic_arg_1: "0x03",
                       topic_arg_2: "0x04",
                       block_index: 0
                     }
                   ]
                 }
               }
             ] = EthRPC.responses([request])

      assert_tol_address(address)
    end
  end

  defp assert_tol_address(term) when is_binary(term) do
    assert String.starts_with?(term, "54")
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
