defmodule Harbor.OpenRouter.SSE do
  @moduledoc false

  defstruct buffer: "", content: "", raw: ""

  @type t :: %__MODULE__{
          buffer: String.t(),
          content: String.t(),
          raw: String.t()
        }

  @spec new() :: t()
  def new, do: %__MODULE__{}

  @spec consume(t(), String.t(), (String.t() -> any())) :: t()
  def consume(%__MODULE__{} = state, chunk, on_delta)
      when is_binary(chunk) and is_function(on_delta, 1) do
    [pending | events] =
      ~r/\r?\n\r?\n/
      |> Regex.split(state.buffer <> chunk)
      |> Enum.reverse()

    state = %{state | buffer: pending}

    events
    |> Enum.reverse()
    |> Enum.reduce(state, &consume_event(&2, &1, on_delta))
  end

  @spec finish(t(), (String.t() -> any())) :: t()
  def finish(%__MODULE__{buffer: buffer} = state, on_delta) when is_function(on_delta, 1) do
    state
    |> Map.put(:buffer, "")
    |> consume_event(buffer, on_delta)
  end

  @spec append_raw(t(), String.t()) :: t()
  def append_raw(%__MODULE__{} = state, chunk) when is_binary(chunk) do
    %{state | raw: state.raw <> chunk}
  end

  defp consume_event(state, event, on_delta) do
    case event_data(event) do
      nil ->
        state

      "[DONE]" ->
        state

      data ->
        data
        |> Jason.decode!()
        |> consume_payload(state, on_delta)
    end
  end

  defp event_data(event) do
    data =
      event
      |> String.split(~r/\r?\n/)
      |> Enum.flat_map(fn
        "data:" <> data -> [String.trim_leading(data)]
        _other -> []
      end)
      |> Enum.join("\n")
      |> String.trim()

    if data == "", do: nil, else: data
  end

  defp consume_payload(%{"error" => error}, _state, _on_delta) do
    raise "OpenRouter stream failed: #{format_error(error)}"
  end

  defp consume_payload(payload, state, on_delta) do
    case get_in(payload, ["choices", Access.at(0), "delta", "content"]) do
      delta when is_binary(delta) and delta != "" ->
        on_delta.(delta)
        %{state | content: state.content <> delta}

      _other ->
        state
    end
  end

  defp format_error(%{"message" => message}) when is_binary(message), do: message
  defp format_error(error), do: inspect(error)
end
