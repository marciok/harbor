defmodule FetchModels do
  require Logger

  @minimum_context_window 128_000
  @minimum_output_tokens 8_000
  @provider_aliases %{
    "meta-llama" => "meta",
    "mistralai" => "mistral",
    "qwen" => "alibaba",
    "x-ai" => "xai",
    "z-ai" => "zai"
  }

  task :get_budget, save: true do
    %{"data" => key} = get_openrouter!("/key")
    %{balance: key["limit_remaining"]}
  end

  task :fetch, downstream: [:test_model], save: true do
    %{"data" => models} = get_openrouter!("/models")
    models = filter_models(models)

    models
    |> Enum.sort_by(fn %{"id" => slug} -> owner_from_slug(slug) end)
    |> Enum.map(fn %{"id" => slug, "name" => name} ->
      %{slug: slug, name: name, owner: owner_from_slug(slug)}
    end)
  end

  def filter_models(models) do
    providers = Application.get_env(:harbor, :model_providers)

    Enum.filter(models, fn
      %{
        "architecture" => %{"output_modalities" => output_modalities},
        "context_length" => context_window,
        "id" => slug,
        "top_provider" => %{"max_completion_tokens" => max_tokens}
      }
      when is_binary(slug) and is_list(output_modalities) and is_integer(context_window) and
             is_integer(max_tokens) ->
        owner_from_slug(slug) in providers and
          "text" in output_modalities and
          context_window >= @minimum_context_window and
          max_tokens >= @minimum_output_tokens

      _model ->
        false
    end)
  end

  defp get_openrouter!(path) do
    %{"token" => token, "host" => host} =
      Gust.Flows.get_secret_by_name("OPENROUTER_API").value |> Jason.decode!()

    %Req.Response{status: 200, body: body} =
      Req.get!(String.trim_trailing(host, "/") <> path, auth: {:bearer, token})

    body
  end

  defp owner_from_slug(slug) do
    case String.split(slug, "/", parts: 2) do
      [owner, _model] -> Map.get(@provider_aliases, owner, owner)
      _invalid_slug -> nil
    end
  end
end
