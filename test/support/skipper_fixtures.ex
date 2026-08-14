defmodule Harbor.SkipperFixtures do
  @moduledoc false

  alias Gust.Flows
  alias Harbor.BrowserSessions
  alias Harbor.Prompts

  def skipper_fixture(attrs \\ %{}) do
    {:ok, browser_session} = BrowserSessions.create_browser_session()

    dag_name = "skipper_test_#{System.unique_integer([:positive, :monotonic])}"
    {:ok, dag} = Flows.create_dag(%{name: dag_name})

    {:ok, run} =
      Flows.create_run(%{
        dag_id: dag.id,
        params:
          Map.get(attrs, :run_params, %{
            synthesizer: %{
              name: "GPT Test",
              owner: "openai",
              slug: "openai/gpt-test"
            },
            panel: [
              %{
                name: "GPT Test",
                owner: "openai",
                slug: "openai/gpt-test"
              }
            ]
          }),
        status: Map.get(attrs, :run_status, :running)
      })

    {:ok, prompt} =
      Prompts.create_prompt(browser_session.id, run.id, %{
        content: Map.get(attrs, :content, "Compare the available approaches")
      })

    %{browser_session: browser_session, dag: dag, prompt: prompt, run: run}
  end

  def response_task_fixture(run, attrs \\ %{}) do
    attrs =
      Map.merge(
        %{
          map_index: 0,
          params: %{
            "name" => "GPT Test",
            "owner" => "openai"
          },
          result: %{"content" => "A panel response"},
          status: :succeeded
        },
        attrs
      )

    task_fixture(run, "get_responses", attrs)
  end

  def analysis_task_fixture(run, attrs \\ %{}) do
    attrs =
      Map.merge(
        %{
          result: %{
            "analysis" => %{
              "consensus" => ["The panel agrees on the main approach"]
            }
          },
          status: :succeeded
        },
        attrs
      )

    task_fixture(run, "judge_analysis", attrs)
  end

  def synthesize_task_fixture(run, attrs \\ %{}) do
    attrs =
      Map.merge(
        %{
          result: %{"answer" => "The fused recommendation"},
          status: :succeeded
        },
        attrs
      )

    task_fixture(run, "synthesize", attrs)
  end

  defp task_fixture(run, name, attrs) do
    attrs =
      Map.merge(
        %{
          error: %{},
          name: name,
          params: %{},
          result: %{},
          run_id: run.id,
          status: :created
        },
        attrs
      )

    {:ok, task} = Flows.create_task(attrs)
    task
  end
end
