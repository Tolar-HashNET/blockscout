defmodule Explorer.EthRPC do
  @moduledoc """
  Ethereum JSON RPC methods logic implementation.
  """

  alias Ecto.Type, as: EctoType
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{Block, Data, Hash, Hash.Address, Wei}
  alias Explorer.Chain.Cache.BlockNumber
  alias Explorer.Etherscan.{Blocks, Logs, RPC}

  alias Explorer.EthRPC.TolarHashnet

  @methods %{
    "eth_blockNumber" => %{
      action: :eth_block_number,
      notes: nil,
      example: """
      {"id": 0, "jsonrpc": "2.0", "method": "eth_blockNumber", "params": []}
      """,
      params: [],
      result: """
      {"id": 0, "jsonrpc": "2.0", "result": "0xb3415c"}
      """
    },
    "eth_getBalance" => %{
      action: :eth_get_balance,
      notes: """
      The `earliest` parameter will not work as expected currently, because genesis block balances
      are not currently imported
      """,
      example: """
      {"id": 0, "jsonrpc": "2.0", "method": "eth_getBalance", "params": ["0x0000000000000000000000000000000000000007", "latest"]}
      """,
      params: [
        %{
          name: "Data",
          description: "20 Bytes - address to check for balance",
          type: "string",
          default: nil,
          required: true
        },
        %{
          name: "Quantity|Tag",
          description: "Integer block number, or the string \"latest\", \"earliest\" or \"pending\"",
          type: "string",
          default: "latest",
          required: true
        }
      ],
      result: """
      {"id": 0, "jsonrpc": "2.0", "result": "0x0234c8a3397aab58"}
      """
    },
    "eth_getLogs" => %{
      action: :eth_get_logs,
      notes: """
      Will never return more than 1000 log entries.\n
      For this reason, you can use pagination options to request the next page. Pagination options params: {"logIndex": "3D", "blockNumber": "6423AC", "transactionIndex": 53} which include parameters from the last log received from the previous request. These three parameters are required for pagination.
      """,
      example: """
      {"id": 0, "jsonrpc": "2.0", "method": "eth_getLogs",
       "params": [
        {"address": "0xc78Be425090Dbd437532594D12267C5934Cc6c6f",
         "paging_options": {"logIndex": "3D", "blockNumber": "6423AC", "transactionIndex": 53},
         "fromBlock": "earliest",
         "toBlock": "latest",
         "topics": ["0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"]}]}
      """,
      params: [
        %{name: "Object", description: "The filter options", type: "json", default: nil, required: true}
      ],
      result: """
      {
        "id":0,
        "jsonrpc":"2.0",
        "result": [{
          "logIndex": "0x1",
          "blockNumber":"0x1b4",
          "blockHash": "0x8216c5785ac562ff41e2dcfdf5785ac562ff41e2dcfdf829c5a142f1fccd7d",
          "transactionHash":  "0xdf829c5a142f1fccd7d8216c5785ac562ff41e2dcfdf5785ac562ff41e2dcf",
          "transactionIndex": "0x0",
          "address": "0x16c5785ac562ff41e2dcfdf829c5a142f1fccd7d",
          "data":"0x0000000000000000000000000000000000000000000000000000000000000000",
          "topics": ["0x59ebeb90bc63057b6515673c3ecf9438e5058bca0f92585014eced636878c9a5"]
          }]
      }
      """
    },
    "tol_getBlockByHash" => %{
      action: :tol_get_block_by_hash,
      notes:
        "Returns block along with it's transactions. This method to be used by mobile clients of Tolar Hashnet exclusively",
      example: """
      {
        "id":1,
        "jsonrpc":"2.0",
        "method":"tol_getBlockByHash",
        "params":{
          "block_hash":"998666a2af4e03f941799a778550d217eb021a0e3daf35eedec5cc2a477a6b3b"
        }
      }
      """,
      result: """
      {
        "id": 1,
        "jsonrpc": "2.0",
        "result": {
          "block_index": 8,
          "block_hash": "998666a2af4e03f941799a778550d217eb021a0e3daf35eedec5cc2a477a6b3b",
          "confirmation_timestamp": 1652192733280,
          "previous_block_hash": "93811a9bdbb846eedfc8f698b141c4de499cfb3d5359a6a1f312c59b21e121c4",
          "transaction_hashes": [
            "5ab70e032db7303b1de31147602970098c21c75904e7281e89cde960d5ede1d1",
            "1c053382aedf362907ea42a6953c8d3684ec9abcb8769439222a4cd3219b678f",
            "fc6c8864f19c47505b8f49702cf051953e06a07096860faa82718ae95ce69b55"
          ]
        }
      }
      """,
      params: [
        %{name: "Block hash", description: "Block hash", type: "string", default: nil, required: true}
      ]
    },
    "tol_getBlockByIndex" => %{
      action: :tol_get_block_by_index,
      notes:
        "Returns block along with it's transactions by block index (called number in blockscout). This method to be used by mobile clients of Tolar Hashnet exclusively",
      example: """
      {
        "id": 1,
        "jsonrpc": "2.0",
        "method": "tol_getBlockByIndex",
        "params":{
          "block_index": 8
        }
      }
      """,
      result: """
      {
        "id": 1,
        "jsonrpc": "2.0",
        "result": {
          "block_index": 8,
          "block_hash": "998666a2af4e03f941799a778550d217eb021a0e3daf35eedec5cc2a477a6b3b",
          "confirmation_timestamp": 1652192733280,
          "previous_block_hash": "93811a9bdbb846eedfc8f698b141c4de499cfb3d5359a6a1f312c59b21e121c4",
          "transaction_hashes": [
            "5ab70e032db7303b1de31147602970098c21c75904e7281e89cde960d5ede1d1",
            "1c053382aedf362907ea42a6953c8d3684ec9abcb8769439222a4cd3219b678f",
            "fc6c8864f19c47505b8f49702cf051953e06a07096860faa82718ae95ce69b55"
          ]
        }
      }
      """,
      params: [
        %{name: "Block index", description: "Block index as integer", type: "integer", default: nil, required: true}
      ]
    },
    "tol_getLatestBlock" => %{
      action: :tol_get_latest_block,
      params: [],
      notes:
        "Returns block with the highest number (index). This method to be used by mobile clients of Tolar Hashnet exclusively",
      example: """
      {
        "id":1,
        "jsonrpc":"2.0",
        "method":"tol_getLatestBlock",
        "params":{
          "block_hash":"998666a2af4e03f941799a778550d217eb021a0e3daf35eedec5cc2a477a6b3b"
        }
      }
      """,
      result: """
      {
        "id": 1,
        "jsonrpc": "2.0",
        "result": {
          "block_index": 8,
          "block_hash": "998666a2af4e03f941799a778550d217eb021a0e3daf35eedec5cc2a477a6b3b",
          "confirmation_timestamp": 1652192733280,
          "previous_block_hash": "93811a9bdbb846eedfc8f698b141c4de499cfb3d5359a6a1f312c59b21e121c4",
          "transaction_hashes": [
            "5ab70e032db7303b1de31147602970098c21c75904e7281e89cde960d5ede1d1",
            "1c053382aedf362907ea42a6953c8d3684ec9abcb8769439222a4cd3219b678f",
            "fc6c8864f19c47505b8f49702cf051953e06a07096860faa82718ae95ce69b55"
          ]
        }
      }
      """
    },
    "tol_getBlockCount" => %{
      action: :tol_get_block_count,
      notes:
        "Returns count of blocks in the database. This method to be used by mobile clients of Tolar Hashnet exclusively",
      params: [],
      example: """
      {
        "id": 1,
        "jsonrpc": "2.0",
        "method": "tol_getBlockCount"
      }
      """,
      result: """
      {
        "id": 1,
        "jsonrpc": "2.0",
        "result": 42
      }
      """
    },
    "tol_getTransaction" => %{
      action: :tol_get_transaction,
      params: [
        %{name: "Transaction Hash", description: "Transaction Hash", type: "string", default: nil, required: true}
      ],
      notes:
        "Returns full info about transaction. This method to be used by mobile clients of Tolar Hashnet exclusively",
      example: """
      {
        "id":1,
        "jsonrpc": "2.0",
        "method": "tol_getTransaction",
        "params": {
          "transaction_hash": "5ab70e032db7303b1de31147602970098c21c75904e7281e89cde960d5ede1d1"
        }
      }
      """,
      result: """
      {
        "id": 1,
        "jsonrpc": "2.0",
        "result": {
          "transaction_hash": "5ab70e032db7303b1de31147602970098c21c75904e7281e89cde960d5ede1d1",
          "block_hash": "998666a2af4e03f941799a778550d217eb021a0e3daf35eedec5cc2a477a6b3b",
          "transaction_index": 1,
          "sender_address": "54d18f8626785dca76b720e5e4426e7d7629fb0c06ab09e65b",
          "receiver_address": "54721c8efe8e860a5b7e5513a13bba982bd000b076239b705d",
          "value": "569000",
          "gas": "21000",
          "gas_price": "1",
          "data": "",
          "nonce": "7",
          "network_id": 1,
          "confirmation_timestamp": 1652192733280,
          "gas_used": "21000",
          "gas_refunded": "0",
          "new_address": "",
          "output": "",
          "excepted": false,
          "exception": 0
        }
      }
      """
    }
  }

  @index_to_word %{
    0 => "first",
    1 => "second",
    2 => "third",
    3 => "fourth"
  }

  def responses(requests) do
    Enum.map(requests, fn request ->
      with {:id, {:ok, id}} <- {:id, Map.fetch(request, "id")},
           {:request, {:ok, result}} <- {:request, do_eth_request(request)} do
        format_success(result, id)
      else
        {:id, :error} -> format_error("id is a required field", 0)
        {:request, {:error, message}} -> format_error(message, Map.get(request, "id"))
      end
    end)
  end

  def eth_block_number do
    max_block_number = BlockNumber.get_max()

    max_block_number_hex =
      max_block_number
      |> encode_quantity()

    {:ok, max_block_number_hex}
  end

  def eth_get_balance(address_param, block_param \\ nil) do
    with {:address, {:ok, address}} <- {:address, Chain.string_to_address_hash(address_param)},
         {:block, {:ok, block}} <- {:block, block_param(block_param)},
         {:balance, {:ok, balance}} <- {:balance, Blocks.get_balance_as_of_block(address, block)} do
      {:ok, Wei.hex_format(balance)}
    else
      {:address, :error} ->
        {:error, "Query parameter 'address' is invalid"}

      {:block, :error} ->
        {:error, "Query parameter 'block' is invalid"}

      {:balance, {:error, :not_found}} ->
        {:error, "Balance not found"}
    end
  end

  def eth_get_logs(filter_options) do
    with {:ok, address_or_topic_params} <- address_or_topic_params(filter_options),
         {:ok, from_block_param, to_block_param} <- logs_blocks_filter(filter_options),
         {:ok, from_block} <- cast_block(from_block_param),
         {:ok, to_block} <- cast_block(to_block_param),
         {:ok, paging_options} <- paging_options(filter_options) do
      filter =
        address_or_topic_params
        |> Map.put(:from_block, from_block)
        |> Map.put(:to_block, to_block)
        |> Map.put(:allow_non_consensus, true)

      logs =
        filter
        |> Logs.list_logs(paging_options)
        |> Enum.map(&render_log/1)

      {:ok, logs}
    else
      {:error, message} when is_bitstring(message) ->
        {:error, message}

      {:error, :empty} ->
        {:ok, []}

      _ ->
        {:error, "Something went wrong."}
    end
  end

  defp render_log(log) do
    topics =
      Enum.reject(
        [log.first_topic, log.second_topic, log.third_topic, log.fourth_topic],
        &is_nil/1
      )

    %{
      "address" => to_string(log.address_hash),
      "blockHash" => to_string(log.block_hash),
      "blockNumber" => Integer.to_string(log.block_number, 16),
      "data" => to_string(log.data),
      "logIndex" => Integer.to_string(log.index, 16),
      "removed" => log.block_consensus == false,
      "topics" => topics,
      "transactionHash" => to_string(log.transaction_hash),
      "transactionIndex" => log.transaction_index,
      "transactionLogIndex" => log.index,
      "type" => "mined"
    }
  end

  defp cast_block("0x" <> hexadecimal_digits = input) do
    case Integer.parse(hexadecimal_digits, 16) do
      {integer, ""} -> {:ok, integer}
      _ -> {:error, input <> " is not a valid block number"}
    end
  end

  defp cast_block(integer) when is_integer(integer), do: {:ok, integer}
  defp cast_block(_), do: {:error, "invalid block number"}

  defp address_or_topic_params(filter_options) do
    address_param = Map.get(filter_options, "address")
    topics_param = Map.get(filter_options, "topics")

    with {:ok, address} <- validate_address(address_param),
         {:ok, topics} <- validate_topics(topics_param) do
      address_and_topics(address, topics)
    end
  end

  defp address_and_topics(nil, nil), do: {:error, "Must supply one of address and topics"}
  defp address_and_topics(address, nil), do: {:ok, %{address_hash: address}}
  defp address_and_topics(nil, topics), do: {:ok, topics}
  defp address_and_topics(address, topics), do: {:ok, Map.put(topics, :address_hash, address)}

  defp validate_address(nil), do: {:ok, nil}

  defp validate_address(address) do
    case Address.cast(address) do
      {:ok, address} -> {:ok, address}
      :error -> {:error, "invalid address"}
    end
  end

  defp validate_topics(nil), do: {:ok, nil}
  defp validate_topics([]), do: []

  defp validate_topics(topics) when is_list(topics) do
    topics
    |> Enum.filter(&(!is_nil(&1)))
    |> Stream.with_index()
    |> Enum.reduce({:ok, %{}}, fn {topic, index}, {:ok, acc} ->
      case cast_topics(topic) do
        {:ok, data} ->
          with_filter = Map.put(acc, String.to_existing_atom("#{@index_to_word[index]}_topic"), data)

          {:ok, add_operator(with_filter, index)}

        :error ->
          {:error, "invalid topics"}
      end
    end)
  end

  defp add_operator(filters, 0), do: filters

  defp add_operator(filters, index) do
    Map.put(filters, String.to_existing_atom("topic#{index - 1}_#{index}_opr"), "and")
  end

  defp cast_topics(topics) when is_list(topics) do
    case EctoType.cast({:array, Data}, topics) do
      {:ok, data} -> {:ok, Enum.map(data, &to_string/1)}
      :error -> :error
    end
  end

  defp cast_topics(topic) do
    case Data.cast(topic) do
      {:ok, data} -> {:ok, to_string(data)}
      :error -> :error
    end
  end

  defp logs_blocks_filter(filter_options) do
    with {:filter, %{"blockHash" => block_hash_param}} <- {:filter, filter_options},
         {:block_hash, {:ok, block_hash}} <- {:block_hash, Hash.Full.cast(block_hash_param)},
         {:block, %{number: number}} <- {:block, Repo.replica().get(Block, block_hash)} do
      {:ok, number, number}
    else
      {:filter, filters} ->
        from_block = Map.get(filters, "fromBlock", "latest")
        to_block = Map.get(filters, "toBlock", "latest")

        max_block_number =
          if from_block == "latest" || to_block == "latest" do
            max_consensus_block_number()
          end

        pending_block_number =
          if from_block == "pending" || to_block == "pending" do
            max_non_consensus_block_number(max_block_number)
          end

        if is_nil(pending_block_number) && from_block == "pending" && to_block == "pending" do
          {:error, :empty}
        else
          to_block_numbers(from_block, to_block, max_block_number, pending_block_number)
        end

      {:block, _} ->
        {:error, "Invalid Block Hash"}

      {:block_hash, _} ->
        {:error, "Invalid Block Hash"}
    end
  end

  defp paging_options(%{
         "paging_options" => %{
           "logIndex" => log_index,
           "transactionIndex" => transaction_index,
           "blockNumber" => block_number
         }
       })
       when is_integer(transaction_index) do
    with {:ok, parsed_block_number} <- to_number(block_number, "invalid block number"),
         {:ok, parsed_log_index} <- to_number(log_index, "invalid log index") do
      {:ok,
       %{
         log_index: parsed_log_index,
         transaction_index: transaction_index,
         block_number: parsed_block_number
       }}
    end
  end

  defp paging_options(_), do: {:ok, nil}

  defp to_block_numbers(from_block, to_block, max_block_number, pending_block_number) do
    actual_pending_block_number = pending_block_number || max_block_number

    with {:ok, from} <-
           to_block_number(from_block, max_block_number, actual_pending_block_number),
         {:ok, to} <- to_block_number(to_block, max_block_number, actual_pending_block_number) do
      {:ok, from, to}
    end
  end

  defp to_block_number(integer, _, _) when is_integer(integer), do: {:ok, integer}
  defp to_block_number("latest", max_block_number, _), do: {:ok, max_block_number || 0}
  defp to_block_number("earliest", _, _), do: {:ok, 0}
  defp to_block_number("pending", max_block_number, nil), do: {:ok, max_block_number || 0}
  defp to_block_number("pending", _, pending), do: {:ok, pending}

  defp to_block_number("0x" <> number, _, _) do
    case Integer.parse(number, 16) do
      {integer, ""} -> {:ok, integer}
      _ -> {:error, "invalid block number"}
    end
  end

  defp to_block_number(number, _, _) when is_bitstring(number) do
    case Integer.parse(number, 16) do
      {integer, ""} -> {:ok, integer}
      _ -> {:error, "invalid block number"}
    end
  end

  defp to_block_number(_, _, _), do: {:error, "invalid block number"}

  defp to_number(number, error_message) when is_bitstring(number) do
    case Integer.parse(number, 16) do
      {integer, ""} -> {:ok, integer}
      _ -> {:error, error_message}
    end
  end

  defp to_number(_, error_message), do: {:error, error_message}

  defp max_non_consensus_block_number(max) do
    case RPC.max_non_consensus_block_number(max) do
      {:ok, number} -> number
      _ -> nil
    end
  end

  defp max_consensus_block_number do
    case Chain.max_consensus_block_number() do
      {:ok, number} -> number
      _ -> nil
    end
  end

  defp format_success(result, id) do
    %{result: result, id: id}
  end

  defp format_error(message, id) do
    %{error: message, id: id}
  end

  defp do_eth_request(%{"jsonrpc" => rpc_version}) when rpc_version != "2.0" do
    {:error, "invalid rpc version"}
  end

  defp do_eth_request(%{"jsonrpc" => "2.0", "method" => method, "params" => params})
       when is_list(params) do
    with {:ok, action} <- get_action(method),
         {:correct_arity, true} <-
           {:correct_arity, :erlang.function_exported(__MODULE__, action, Enum.count(params))} do
      apply(__MODULE__, action, params)
    else
      {:correct_arity, _} ->
        {:error, "Incorrect number of params."}

      _ ->
        {:error, "Action not found."}
    end
  end

  defp do_eth_request(%{"params" => _params, "method" => _}) do
    {:error, "Invalid params. Params must be a list."}
  end

  defp do_eth_request(_) do
    {:error, "Method, params, and jsonrpc, are all required parameters."}
  end

  defp get_action(action) do
    case Map.get(@methods, action) do
      %{action: action} ->
        {:ok, action}

      _ ->
        :error
    end
  end

  defp block_param("latest"), do: {:ok, :latest}
  defp block_param("earliest"), do: {:ok, :earliest}
  defp block_param("pending"), do: {:ok, :pending}

  defp block_param(string_integer) when is_bitstring(string_integer) do
    case Integer.parse(string_integer) do
      {integer, ""} -> {:ok, integer}
      _ -> :error
    end
  end

  defp block_param(nil), do: {:ok, :latest}
  defp block_param(_), do: :error

  def encode_quantity(binary) when is_binary(binary) do
    hex_binary = Base.encode16(binary, case: :lower)

    result = String.replace_leading(hex_binary, "0", "")

    final_result = if result == "", do: "0", else: result

    "0x#{final_result}"
  end

  def encode_quantity(value) when is_integer(value) do
    value
    |> :binary.encode_unsigned()
    |> encode_quantity()
  end

  def encode_quantity(value) when is_nil(value) do
    nil
  end

  def methods, do: @methods

  ###### Tolar Hashnet methods ######
  def tol_get_block_by_hash({"block_hash", block_hash}) do
    TolarHashnet.tol_get_block_by_hash(block_hash)
  end

  def tol_get_block_by_index({"block_index", block_index}) do
    TolarHashnet.tol_get_block_by_index(block_index)
  end

  def tol_get_latest_block() do
    TolarHashnet.tol_get_latest_block()
  end

  def tol_get_block_count() do
    TolarHashnet.tol_get_block_count()
  end

  def tol_get_transaction({"transaction_hash", tx_hash}) do
    TolarHashnet.tol_get_transaction(tx_hash)
  end
end
