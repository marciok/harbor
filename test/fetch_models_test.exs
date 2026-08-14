Code.require_file("../dags/fetch_models.ex", __DIR__)

defmodule FetchModelsTest do
  use ExUnit.Case, async: false

  setup do
    previous_providers = Application.get_env(:harbor, :model_providers)
    Application.put_env(:harbor, :model_providers, ["supported"])

    on_exit(fn ->
      Application.put_env(:harbor, :model_providers, previous_providers)
    end)
  end

  test "keeps supported language models that meet both token limits" do
    eligible_model = model()

    assert FetchModels.filter_models([eligible_model]) == [eligible_model]
  end

  test "filters models below either token limit" do
    models = [
      model(%{"id" => "small-context", "context_window" => 127_999}),
      model(%{"id" => "small-output", "max_tokens" => 7_999})
    ]

    assert FetchModels.filter_models(models) == []
  end

  test "filters unsupported, non-language, and incomplete models" do
    models = [
      model(%{"id" => "unsupported", "owned_by" => "other"}),
      model(%{"id" => "image", "type" => "image"}),
      model(%{"id" => "missing-context"}) |> Map.delete("context_window"),
      model(%{"id" => "missing-output"}) |> Map.delete("max_tokens")
    ]

    assert FetchModels.filter_models(models) == []
  end

  defp model(overrides \\ %{}) do
    Map.merge(
      %{
        "context_window" => 128_000,
        "id" => "supported/model",
        "max_tokens" => 8_000,
        "name" => "Supported model",
        "owned_by" => "supported",
        "type" => "language"
      },
      overrides
    )
  end
end
