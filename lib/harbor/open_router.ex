defmodule Harbor.OpenRouter do
  @moduledoc false

  alias Gust.Flows
  alias Harbor.OpenRouter.SSE

  @receive_timeout 120_000

  @spec chat_completion!(String.t(), list(map()), (String.t() -> any())) :: String.t()
  def chat_completion!(model, messages, on_delta) when is_function(on_delta, 1) do
    %{"token" => token, "host" => host} =
      Flows.get_secret_by_name("OPENROUTER_API").value
      |> Jason.decode!()

    url = String.trim_trailing(host, "/") <> "/chat/completions"

    into = fn {:data, data}, {request, response} ->
      stream = stream_state(response.body)

      stream =
        if response.status == 200 do
          SSE.consume(stream, data, on_delta)
        else
          SSE.append_raw(stream, data)
        end

      {:cont, {request, %{response | body: stream}}}
    end

    case Req.post(url,
           json: %{model: model, messages: messages, stream: true},
           auth: {:bearer, token},
           headers: [{"accept", "text/event-stream"}],
           receive_timeout: @receive_timeout,
           retry: false,
           into: into
         ) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        body
        |> stream_state()
        |> SSE.finish(on_delta)
        |> Map.fetch!(:content)

      {:ok, %Req.Response{status: status, body: body}} ->
        raise "LLM request failed with status #{status}: #{format_error_body(body)}"

      {:error, error} ->
        raise "LLM request failed: #{Exception.message(error)}"
    end
  end

  defp stream_state(%SSE{} = state), do: state
  defp stream_state(_body), do: SSE.new()

  defp format_error_body(%SSE{raw: raw}) do
    case Jason.decode(raw) do
      {:ok, body} -> inspect(body)
      {:error, _error} -> inspect(raw)
    end
  end

  defp format_error_body(body), do: inspect(body)
end
