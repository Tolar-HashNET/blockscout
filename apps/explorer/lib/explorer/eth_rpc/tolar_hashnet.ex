defmodule Explorer.EthRPC.TolarHashnet do
  @moduledoc """
  JsonRPC methods handling for Tolar hashnet
  """
  alias Explorer.Chain
  alias Explorer.Chain.Cache.Block, as: BlockCache
  alias Explorer.Chain.{Block, Data, Hash, Transaction, Wei, Gas}

  @typep tolar_formatted_address_hash :: String.t()

  @typep tol_block_response :: %{
           required(:block_hash) => Hash.t(),
           required(:previous_block_hash) => Hash.t(),
           required(:block_index) => EthereumJSONRPC.block_number(),
           required(:confirmation_timestamp) => non_neg_integer(),
           required(:transaction_hashes) => [Hash.t()]
         }

  @typep transaction_response :: %{
           required(:transaction_hash) => Hash.t(),
           required(:block_hash) => Hash.t(),
           required(:transaction_index) => Transaction.transaction_index(),
           required(:sender_address) => tolar_formatted_address_hash,
           required(:receiver_address) => tolar_formatted_address_hash,
           required(:value) => Wei.t(),
           required(:gas) => Gas.t(),
           required(:gas_price) => Wei.t(),
           required(:nonce) => non_neg_integer(),
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
           required(:hash) => Hash.t(),
           required(:block_hash) => Hash.t(),
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
           required(:transaction_hash) => Hash.t(),
           required(:block_hash) => Hash.t(),
           required(:block_index) => EthereumJSONRPC.block_number()
         }

  @typep log :: %{
           address: tolar_formatted_address_hash(),
           topics: [String.t()],
           data: String.t()
         }

  @typep error :: String.t()

  @typep topic :: String.t() | nil

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
    with {:ok, _} <- validate_full_hash(transaction_hash),
         %Transaction{} = transaction <- Chain.fetch_transaction_by_hash(transaction_hash) do
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
    with {:ok, _} <- validate_full_hash(transaction_hash),
         %Transaction{} = transaction <-
           Chain.fetch_transaction_by_hash(transaction_hash, [:block, :from_address, :to_address, :logs]) do
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
  def tol_get_past_events(address, topic) when is_binary(topic) do
    {:ok, eth_address} = tolar_address_to_eth(address)
    formatted_topic = if String.starts_with?(topic, "0x"), do: topic, else: "0x" <> topic

    case Chain.tol_address_to_logs(eth_address, topic: formatted_topic) do
      [] ->
        {:error, "Address not found"}

      logs ->
        {:ok, %{past_events: build_full_log_response(logs)}}
    end
  end

  def tol_get_past_events(address, nil) do
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
      sender_address: eth_address_to_tolar(transaction.from_address.hash),
      receiver_address: eth_address_to_tolar(transaction.to_address.hash),
      value: transaction.value,
      gas: transaction.gas,
      gas_price: transaction.gas_price,
      nonce: transaction.nonce,
      data: transaction.input,
      gas_used: transaction.gas_used,
      exception: transaction.error,
      excepted: transaction.has_error_in_internal_txs,
      new_address: maybe_convert_to_tolar_hash(transaction.created_contract_address_hash),
      confirmation_timestamp: DateTime.to_unix(transaction.block.timestamp, :millisecond),
      network_id: nil,
      output: nil,
      gas_refunded: nil
    }
  end

  defp build_transaction_receipt_response(transaction) do
    %{
      hash: transaction.hash,
      block_hash: transaction.block_hash,
      block_number: transaction.block_number,
      transaction_index: transaction.index,
      sender_address: eth_address_to_tolar(transaction.from_address.hash),
      receiver_address: eth_address_to_tolar(transaction.to_address.hash),
      new_address: maybe_convert_to_tolar_hash(transaction.created_contract_address_hash),
      gas_used: transaction.gas_used,
      excepted: transaction.has_error_in_internal_txs,
      logs: build_logs(transaction)
    }
  end

  defp build_logs(transaction) do
    Enum.map(transaction.logs, fn log ->
      %{
        address: eth_address_to_tolar(log.address_hash),
        topics: Enum.reject([log.first_topic, log.second_topic, log.third_topic, log.fourth_topic], &is_nil/1),
        data: log.data |> Explorer.Chain.Data.to_iodata() |> IO.iodata_to_binary()
      }
    end)
  end

  defp build_full_log_response(logs) do
    Enum.map(logs, fn log ->
      %{
        address: eth_address_to_tolar(log.address_hash),
        topic: log.first_topic,
        topic_arg_0: log.second_topic,
        topic_arg_1: log.third_topic,
        topic_arg_2: log.fourth_topic,
        data: log.data |> Explorer.Chain.Data.to_iodata() |> IO.iodata_to_binary(),
        transaction_hash: log.transaction_hash,
        block_hash: log.block_hash,
        block_index: log.block_number
      }
    end)
  end

  @zero_address "54000000000000000000000000000000000000000023199e2b"

  defp blockchain_info() do
    %{
      confirmed_blocks_count: BlockCache.estimated_count(),
      total_blocks_count: Chain.block_count(),
      last_confirmed_block_hash: Chain.fetch_latest_block_hash()
    }
  end

  defp maybe_convert_to_tolar_hash(nil), do: @zero_address
  defp maybe_convert_to_tolar_hash(%Hash{} = hash), do: eth_address_to_tolar(hash)

  defp validate_full_hash(transaction_hash) do
    Explorer.Chain.Hash.Full.cast(transaction_hash)
  end
end
