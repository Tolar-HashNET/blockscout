defmodule Explorer.EthRPC.TolarHashnet do
  @moduledoc """
  JsonRPC methods handling for Tolar hashnet
  """
  alias Explorer.Chain
  alias Explorer.Chain.{Address, Block, Data, Hash, Transaction, Gas}

  @typep tolar_formatted_address_hash :: String.t()
  @typep unprefixed_hash :: String.t()
  @typep error :: String.t()
  @typep topic :: String.t() | nil

  @typep tol_block_response :: %{
           required(:block_hash) => unprefixed_hash(),
           required(:previous_block_hash) => unprefixed_hash(),
           required(:block_index) => EthereumJSONRPC.block_number(),
           required(:confirmation_timestamp) => non_neg_integer(),
           required(:transaction_hashes) => [unprefixed_hash()]
         }

  @typep transaction_response :: %{
           required(:transaction_hash) => unprefixed_hash(),
           required(:block_hash) => unprefixed_hash(),
           required(:transaction_index) => Transaction.transaction_index(),
           required(:sender_address) => tolar_formatted_address_hash,
           required(:receiver_address) => tolar_formatted_address_hash,
           required(:value) => String.t(),
           required(:gas) => Gas.t(),
           required(:gas_price) => String.t(),
           required(:nonce) => String.t(),
           required(:data) => Data.t(),
           required(:gas_used) => Gas.t() | nil,
           required(:confirmation_timestamp) => non_neg_integer(),
           required(:excepted) => boolean(),
           required(:exception) => String.t() | nil,
           required(:new_address) => tolar_formatted_address_hash,
           network_id: nil,
           output: nil,
           gas_refunded: nil
         }

  @typep transaction_receipt_response :: %{
           required(:hash) => unprefixed_hash(),
           required(:block_hash) => unprefixed_hash(),
           required(:transaction_index) => Transaction.transaction_index(),
           required(:sender_address) => tolar_formatted_address_hash(),
           required(:receiver_address) => tolar_formatted_address_hash(),
           required(:new_address) => tolar_formatted_address_hash(),
           required(:gas_used) => Gas.t() | nil,
           required(:excepted) => boolean(),
           required(:block_number) => EthereumJSONRPC.block_number(),
           required(:logs) => [log()]
         }

  @typep past_events_response :: %{
           required(:address) => tolar_formatted_address_hash,
           required(:topic) => topic(),
           required(:topic_arg_0) => topic(),
           required(:topic_arg_1) => topic(),
           required(:topic_arg_2) => topic(),
           required(:data) => Data.t(),
           required(:transaction_hash) => unprefixed_hash(),
           required(:block_hash) => unprefixed_hash(),
           required(:block_index) => EthereumJSONRPC.block_number()
         }

  @typep log :: %{
           address: tolar_formatted_address_hash(),
           topics: [String.t()],
           data: String.t()
         }

  @spec tol_get_block_by_hash(String.t()) :: {:ok, tol_block_response()} | {:error, error()}
  def tol_get_block_by_hash(block_hash) when is_binary(block_hash) do
    with normalized_hash <- prefix_hash(block_hash),
         {:ok, parsed_hash} <- validate_full_hash(normalized_hash),
         %Block{} = block <- Chain.fetch_block_by_hash(parsed_hash, [:transactions]) do
      {:ok, build_block_response(block)}
    else
      :error ->
        {:error, "Invalid block hash"}

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
    with normalized_hash <- prefix_hash(transaction_hash),
         {:ok, parsed_tx_hash} <- validate_full_hash(normalized_hash),
         %Transaction{} = transaction <- Chain.fetch_transaction_by_hash(parsed_tx_hash) do
      {:ok, build_transaction_response(transaction)}
    else
      :error ->
        {:error, "Invalid transaction hash"}

      _ ->
        {:error, "Transaction not found"}
    end
  end

  @spec tol_get_transaction_receipt(String.t()) :: {:ok, transaction_receipt_response()} | {:error, error()}
  def tol_get_transaction_receipt(transaction_hash) do
    with normalized_hash <- prefix_hash(transaction_hash),
         {:ok, tx_hash} <- validate_full_hash(normalized_hash),
         %Transaction{} = transaction <-
           Chain.fetch_transaction_by_hash(tx_hash, [:block, :from_address, :to_address, :logs, :internal_transactions]) do
      {:ok, build_transaction_receipt_response(transaction)}
    else
      :error ->
        {:error, "Invalid transaction hash"}

      _ ->
        {:error, "Transaction not found"}
    end
  end

  @transaction_associations %{
    from_address: :required,
    to_address: :required,
    block: :required
  }

  @spec tol_get_transaction_list([String.t()], non_neg_integer(), non_neg_integer()) ::
          {:ok, [transaction_response()]} | {:error, error()}
  def tol_get_transaction_list(addresses, limit, skip) do
    with eth_addresses <- tolar_addresses_to_eth(addresses),
         [%Transaction{} | _] = transactions <-
           Chain.fetch_transactions_for_addresses(eth_addresses,
             limit: limit,
             skip: skip,
             necessity_by_association: @transaction_associations
           ) do
      {:ok, Enum.map(transactions, &build_transaction_response/1)}
    else
      _ ->
        {:error, "Transactions not found"}
    end
  end

  @spec tol_get_past_events(tolar_formatted_address_hash(), topic()) ::
          {:ok, %{past_events: past_events_response()}} | {:error, error()}
  def tol_get_past_events(address, topic) when is_binary(topic) and topic != "" do
    {:ok, eth_address} = tolar_address_to_eth(address)
    formatted_topic = if String.starts_with?(topic, "0x"), do: topic, else: "0x" <> topic

    case Chain.tol_address_to_logs(eth_address, topic: formatted_topic) do
      [] ->
        {:error, "Address not found"}

      logs ->
        {:ok, %{past_events: build_full_log_response(logs)}}
    end
  end

  def tol_get_past_events(address, _) do
    {:ok, eth_address} = tolar_address_to_eth(address)

    case Chain.tol_address_to_logs(eth_address) do
      [] ->
        {:error, "Address not found"}

      logs ->
        {:ok, %{past_events: build_full_log_response(logs)}}
    end
  end

  @spec tol_get_blockchain_info() ::
          {:ok,
           %{
             confirmed_blocks_count: non_neg_integer(),
             total_blocks_count: non_neg_integer(),
             last_confirmed_block_hash: Hash.Address.t()
           }}
  def tol_get_blockchain_info() do
    {:ok, blockchain_info()}
  end

  @tolar_address_prefix "54"

  @spec eth_address_to_tolar(Hash.Address.t()) :: tolar_formatted_address_hash()
  def eth_address_to_tolar(%Hash{} = hash) do
    address = hash |> to_string() |> String.trim_leading("0x")

    <<_b::binary-size(56), checksum::binary>> =
      hash.bytes
      |> ExKeccak.hash_256()
      |> ExKeccak.hash_256()
      |> Base.encode16(case: :lower)

    @tolar_address_prefix <> address <> checksum
  end

  @spec tolar_address_to_eth(tolar_formatted_address_hash()) :: {:ok, Hash.Address.t()} | {:error, :invalid_format}
  def tolar_address_to_eth("54" <> <<address::binary-size(40), _checksum::binary>>) do
    case Chain.string_to_address_hash("0x" <> address) do
      :error ->
        {:error, :invalid_format}

      {:ok, _} = success ->
        success
    end
  end

  def tolar_address_to_eth(_), do: {:error, :invalid_format}

  def tolar_addresses_to_eth(addresses) when is_list(addresses) do
    Enum.reduce(addresses, [], fn address, acc ->
      case tolar_address_to_eth(address) do
        {:ok, hash} ->
          [hash | acc]

        _ ->
          acc
      end
    end)
  end

  @spec unprefixed_hash(Hash.t()) :: unprefixed_hash()
  def unprefixed_hash(%Hash{} = hash) do
    [_, unprefixed] = Hash.to_iodata(hash)

    IO.iodata_to_binary(unprefixed)
  end

  defp build_block_response(block) do
    transaction_hashes = Enum.map(block.transactions, &unprefixed_hash(&1.hash))

    %{
      block_hash: unprefixed_hash(block.hash),
      previous_block_hash: unprefixed_hash(block.parent_hash),
      block_index: block.number,
      confirmation_timestamp: DateTime.to_unix(block.timestamp, :millisecond),
      transaction_hashes: transaction_hashes
    }
  end

  defp build_transaction_response(transaction) do
    {excepted, exception} = exception(transaction)

    %{
      transaction_hash: unprefixed_hash(transaction.hash),
      block_hash: unprefixed_hash(transaction.block_hash),
      transaction_index: transaction.index,
      sender_address: safe_eth_to_tolar(transaction.from_address),
      receiver_address: safe_eth_to_tolar(transaction.to_address),
      value: Decimal.to_string(transaction.value.value),
      gas: transaction.gas,
      gas_price: Decimal.to_string(transaction.gas_price.value),
      nonce: Integer.to_string(transaction.nonce),
      data: transaction.input,
      gas_used: transaction.gas_used,
      excepted: excepted,
      exception: exception,
      new_address: maybe_convert_to_tolar_hash(transaction.created_contract_address_hash),
      confirmation_timestamp: DateTime.to_unix(transaction.block.timestamp, :millisecond),
      network_id: nil,
      output: nil,
      gas_refunded: nil
    }
  end

  defp build_transaction_receipt_response(transaction) do
    {excepted, _} = exception(transaction)

    %{
      hash: unprefixed_hash(transaction.hash),
      block_hash: unprefixed_hash(transaction.block_hash),
      block_number: transaction.block_number,
      transaction_index: transaction.index,
      sender_address: safe_eth_to_tolar(transaction.from_address),
      receiver_address: safe_eth_to_tolar(transaction.to_address),
      new_address: maybe_convert_to_tolar_hash(transaction.created_contract_address_hash),
      gas_used: transaction.gas_used,
      excepted: excepted,
      logs: build_logs(transaction)
    }
  end

  defp build_logs(transaction) do
    Enum.map(transaction.logs, fn log ->
      topics =
        [log.first_topic, log.second_topic, log.third_topic, log.fourth_topic]
        |> Enum.map(&unprefixed_binary/1)
        |> Enum.reject(&is_nil/1)

      %{
        address: eth_address_to_tolar(log.address_hash),
        topics: topics,
        data: unprefixed_data(log.data)
      }
    end)
  end

  defp build_full_log_response(logs) do
    Enum.map(logs, fn log ->
      %{
        address: eth_address_to_tolar(log.address_hash),
        topic: unprefixed_binary(log.first_topic),
        topic_arg_0: unprefixed_binary(log.second_topic),
        topic_arg_1: unprefixed_binary(log.third_topic),
        topic_arg_2: unprefixed_binary(log.fourth_topic),
        data: unprefixed_data(log.data),
        transaction_hash: unprefixed_hash(log.transaction_hash),
        block_hash: unprefixed_hash(log.block_hash),
        block_index: log.block_number
      }
    end)
  end

  @zero_address "54000000000000000000000000000000000000000023199e2b"

  def zero_address(), do: @zero_address

  defp blockchain_info() do
    %{
      confirmed_blocks_count: Chain.fetch_count_consensus_blocks(),
      total_blocks_count: Chain.block_count(),
      last_confirmed_block_hash: Chain.fetch_latest_block_hash()
    }
  end

  defp maybe_convert_to_tolar_hash(nil), do: @zero_address
  defp maybe_convert_to_tolar_hash(%Hash{} = hash), do: eth_address_to_tolar(hash)

  defp validate_full_hash(transaction_hash) do
    Hash.Full.cast(transaction_hash)
  end

  defp safe_eth_to_tolar(nil), do: @zero_address

  defp safe_eth_to_tolar(%Address{hash: hash}), do: eth_address_to_tolar(hash)

  defp prefix_hash("0x" <> tx_hash), do: "0x" <> tx_hash

  defp prefix_hash(tx_hash), do: "0x" <> tx_hash

  defp unprefixed_binary(nil), do: nil

  defp unprefixed_binary("0x" <> unprefixed), do: unprefixed

  defp unprefixed_data(%Data{} = data) do
    [_, unprefixed] = Explorer.Chain.Data.to_iodata(data)

    IO.iodata_to_binary(unprefixed)
  end

  defp safe_bool(term) when is_boolean(term), do: term

  defp safe_bool(_), do: false

  @errors_to_codes %{
    "Unknown" => 1,
    "BadRLP" => 2,
    "InvalidFormat" => 3,
    "OutOfGasIntrinsic" => 4,
    "InvalidSignature" => 5,
    "InvalidNonce" => 6,
    "NotEnoughCash" => 7,
    "OutOfGasBase" => 8,
    "BlockGasLimitReached" => 9,
    "BadInstruction" => 10,
    "BadJumpDestination" => 11,
    "OutOfGas" => 12,
    "OutOfStack" => 13,
    "StackUnderflow" => 14,
    "RevertInstruction" => 15,
    "InvalidZeroSignatureFormat" => 16,
    "AddressAlreadyUsed" => 17
  }

  @spec exception(Transaction.t()) :: {boolean(), non_neg_integer()}
  def exception(transaction) do
    case transaction.status do
      :error ->
        exception = Map.get(@errors_to_codes, transaction.error, 1)

        {true, exception}

      _ ->
        if safe_bool(transaction.has_error_in_internal_txs) do
          excepted_internal_transaction =
            Enum.find(transaction.internal_transactions, &(&1.error != "" and not is_nil(&1.error)))

          {true, Map.get(@errors_to_codes, excepted_internal_transaction.error, 1)}
        else
          {false, 0}
        end
    end
  end

  def errors_to_codes, do: @errors_to_codes
end
