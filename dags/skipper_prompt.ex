defmodule SkipperPrompt do
  use Gust.DSL
  alias Gust.Flows

  @analysis_fields ~w(consensus contradictions partial_coverage unique_insights blind_spots)

  task :get_models, downstream: [:get_responses], ctx: %{run_id: run_id}, save: true do
    run = Flows.get_run!(run_id)
    Map.fetch!(run.params, "panel")
  end

  task :get_prompt,
    downstream: [:get_responses],
    ctx: %{run_id: run_id},
    save: true do
    run = Flows.get_run!(run_id)
    %{"prompt" => prompt} = run.params

    %{prompt: prompt}
  end

  task :get_responses,
    downstream: [:judge_analysis],
    map_over: :get_models,
    ctx: %{params: params, run_id: run_id},
    save: true do
    prompt = prompt_from_task(run_id)
    model = params

    content =
      chat_completion(model["slug"], [
        %{role: "user", content: prompt}
      ])

    %{model: model, content: content}
  end

  task :judge_analysis,
    downstream: [:synthesize],
    ctx: %{run_id: run_id},
    save: true do
    prompt = prompt_from_task(run_id)
    responses = panel_responses(run_id)
    run = Flows.get_run!(run_id)

    analysis = input_chat_completion(run.params["synthesizer"]["slug"], prompt, responses)

    %{analysis: analysis}
  end

  task :synthesize, ctx: %{run_id: run_id}, save: true do
    prompt = prompt_from_task(run_id)
    %{"analysis" => analysis} = Flows.get_task_by_name_run("judge_analysis", run_id).result
    responses = panel_responses(run_id)
    run = Flows.get_run!(run_id)

    answer =
      chat_completion(run.params["synthesizer"]["slug"], [
        %{role: "system", content: synthesize_system_prompt()},
        %{role: "user", content: synthesize_user_prompt(prompt, responses, analysis)}
      ])

    %{answer: answer}
  end

  defp panel_responses(run_id) do
    Flows.get_tasks_by_name("get_responses", run_id)
    |> Enum.map(& &1.result)
    |> Enum.filter(fn
      %{"content" => content} -> is_binary(content) and content != ""
      _ -> false
    end)
  end

  defp chat_completion(model, messages) do
    "/chat/completions"
    |> vercel_post!(%{model: model, messages: messages})
    |> get_in(["choices", Access.at(0), "message", "content"]) || ""
  end

  defp input_chat_completion(model, prompt, responses) do
    text = analysis_text_format()

    "/responses"
    |> vercel_post!(%{
      model: model,
      input: [
        %{role: "developer", content: judge_system_prompt()},
        %{role: "user", content: judge_user_prompt(prompt, responses)}
      ],
      text: text
    })
    |> extract_response_text()
    |> Jason.decode!()
  end

  defp analysis_text_format do
    properties =
      Map.new(@analysis_fields, fn field ->
        {field, %{type: "array", items: %{type: "string"}}}
      end)

    %{
      format: %{
        type: "json_schema",
        name: "fusion_judgement",
        strict: true,
        schema: %{
          type: "object",
          properties: properties,
          required: @analysis_fields,
          additionalProperties: false
        }
      }
    }
  end

  defp vercel_post!(path, payload) do
    %{"token" => token, "host" => host} =
      Flows.get_secret_by_name("VERCEL_API").value
      |> Jason.decode!()

    case Req.post(String.trim_trailing(host, "/") <> path,
           json: payload,
           auth: {:bearer, token},
           receive_timeout: 120_000
         ) do
      {:ok, %Req.Response{status: 200, body: response_body}} ->
        response_body

      {:ok, %Req.Response{status: status, body: response_body}} ->
        raise "LLM request failed with status #{status}: #{inspect(response_body)}"

      {:error, error} ->
        raise "LLM request failed: #{Exception.message(error)}"
    end
  end

  defp extract_response_text(response) do
    response["output"]
    |> Enum.find(&(&1["type"] == "message"))
    |> get_in(["content", Access.at(0), "text"])
  end

  defp prompt_from_task(run_id) do
    %{"prompt" => prompt} = Flows.get_task_by_name_run("get_prompt", run_id).result
    prompt
  end

  defp judge_user_prompt(prompt, responses) do
    panel = format_panel_responses(responses)

    """
    Question:
    #{prompt}

    Panel responses:
    #{panel}
    """
  end

  defp synthesize_system_prompt, do: Application.get_env(:harbor, :synthesize_system_prompt)
  defp judge_system_prompt, do: Application.get_env(:harbor, :judge_system_prompt)

  defp synthesize_user_prompt(prompt, responses, analysis) do
    panel = format_panel_responses(responses)

    """
    Question:
    #{prompt}

    Judge's structured analysis (JSON):
    #{Jason.encode!(analysis)}

    Panel responses:
    #{panel}
    """
  end

  defp format_panel_responses(responses) do
    responses
    |> Enum.with_index(1)
    |> Enum.map_join("\n\n", fn {%{"model" => model, "content" => content}, i} ->
      "### Response #{i} (#{model["id"]})\n#{content}"
    end)
  end
end
