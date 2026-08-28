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
      model(%{"id" => "supported/small-context", "context_length" => 127_999}),
      model(%{
        "id" => "supported/small-output",
        "top_provider" => %{"max_completion_tokens" => 7_999}
      })
    ]

    assert FetchModels.filter_models(models) == []
  end

  test "filters unsupported, non-language, and incomplete models" do
    models = [
      model(%{"id" => "other/unsupported"}),
      model(%{
        "id" => "supported/image",
        "architecture" => %{"output_modalities" => ["image"]}
      }),
      model(%{"id" => "supported/missing-context"}) |> Map.delete("context_length"),
      model(%{"id" => "supported/missing-output"}) |> Map.delete("top_provider")
    ]

    assert FetchModels.filter_models(models) == []
  end

  test "recognizes OpenRouter author slugs for the supported providers" do
    Application.put_env(
      :harbor,
      :model_providers,
      ~w(alibaba meta mistral xai zai)
    )

    models =
      for owner <- ~w(qwen meta-llama mistralai x-ai z-ai) do
        model(%{"id" => "#{owner}/model"})
      end

    assert FetchModels.filter_models(models) == models
  end

  defp model(overrides \\ %{}) do
    Map.merge(
      %{
        "architecture" => %{"output_modalities" => ["text"]},
        "context_length" => 128_000,
        "id" => "supported/model",
        "name" => "Supported model",
        "top_provider" => %{"max_completion_tokens" => 8_000}
      },
      overrides
    )
  end
end
