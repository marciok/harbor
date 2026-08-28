defmodule Harbor.OpenRouter.SSETest do
  use ExUnit.Case, async: true

  alias Harbor.OpenRouter.SSE

  test "decodes content deltas across arbitrary HTTP chunks" do
    on_delta = fn delta -> send(self(), {:delta, delta}) end

    state =
      SSE.new()
      |> SSE.consume("data: {\"choices\":[{\"delta\":{\"content\":\"Hel", on_delta)
      |> SSE.consume("lo\"}}]}\n\ndata: {\"choices\":[{\"delta\":", on_delta)
      |> SSE.consume("{\"content\":\" world\"}}]}\n\ndata: [DONE]\n\n", on_delta)
      |> SSE.finish(on_delta)

    assert state.content == "Hello world"
    assert_receive {:delta, "Hello"}
    assert_receive {:delta, " world"}
    refute_receive {:delta, _other}
  end

  test "supports CRLF events, comments, and a final event without a blank line" do
    on_delta = fn delta -> send(self(), {:delta, delta}) end

    state =
      SSE.new()
      |> SSE.consume(": keep-alive\r\n\r\ndata: {\"choices\":[{\"delta\":{}}]}\r\n\r\n", on_delta)
      |> SSE.consume("data: {\"choices\":[{\"delta\":{\"content\":\"Done\"}}]}", on_delta)
      |> SSE.finish(on_delta)

    assert state.content == "Done"
    assert_receive {:delta, "Done"}
    refute_receive {:delta, _other}
  end

  test "raises when OpenRouter sends an error event" do
    assert_raise RuntimeError, "OpenRouter stream failed: Provider unavailable", fn ->
      SSE.consume(
        SSE.new(),
        "data: {\"error\":{\"message\":\"Provider unavailable\"}}\n\n",
        fn _delta -> :ok end
      )
    end
  end
end
