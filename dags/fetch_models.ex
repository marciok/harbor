defmodule FetchModels do
  require Logger
  use Gust.DSL, schedule: "*/5 * * * *"

  @minimum_context_window 128_000
  @minimum_output_tokens 8_000

  task :get_budget, save: true do
    get_model_provider!("/credits")
  end

  task :fetch, save: true do
    %{"data" => models} = get_model_provider!("/models")
    models = filter_models(models)

    models
    |> Enum.sort_by(fn %{"owned_by" => provider, "type" => "language"} -> provider end)
    |> Enum.map(fn %{"id" => slug, "name" => name, "owned_by" => owner} ->
      %{slug: slug, name: name, owner: owner}
    end)
  end

  def filter_models(models) do
    providers = Application.get_env(:harbor, :model_providers)

    Enum.filter(models, fn
      %{
        "context_window" => context_window,
        "max_tokens" => max_tokens,
        "owned_by" => provider,
        "type" => "language"
      }
      when is_integer(context_window) and is_integer(max_tokens) ->
        provider in providers and
          context_window >= @minimum_context_window and
          max_tokens >= @minimum_output_tokens

      _model ->
        false
    end)
  end

  defp get_model_provider!(path) do
    %{"token" => token, "host" => host} =
      Gust.Flows.get_secret_by_name("VERCEL_API").value |> Jason.decode!()

    %Req.Response{status: 200, body: body} =
      Req.get!("#{host}#{path}", auth: {:bearer, token})

    body
  end
end
