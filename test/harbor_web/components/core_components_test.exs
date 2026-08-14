defmodule HarborWeb.CoreComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias HarborWeb.CoreComponents

  test "task_status renders a badge and spinner for a running task" do
    document =
      render_component(&CoreComponents.task_status/1,
        id: "analysis-status",
        task: %{status: :running}
      )
      |> LazyHTML.from_fragment()

    assert document
           |> LazyHTML.filter("#analysis-status[data-status=running]")
           |> Enum.count() == 1

    assert document
           |> LazyHTML.filter(".loading-spinner")
           |> Enum.count() == 1
  end

  test "task_status renders nothing without a task" do
    document =
      render_component(&CoreComponents.task_status/1, id: "analysis-status", task: nil)
      |> LazyHTML.from_fragment()

    assert document
           |> LazyHTML.filter("*")
           |> Enum.empty?()
  end

  test "stage_empty renders the requested icon" do
    document =
      render_component(&CoreComponents.stage_empty/1,
        id: "analysis-empty",
        icon: "hero-magnifying-glass"
      )
      |> LazyHTML.from_fragment()

    assert document
           |> LazyHTML.query("#analysis-empty .hero-magnifying-glass")
           |> Enum.count() == 1
  end

  test "panel_model can render in its selected state" do
    document =
      render_component(&CoreComponents.panel_model/1,
        id: "selected-model",
        model: %{"name" => "GPT Test", "owner" => "openai"},
        selected: true
      )
      |> LazyHTML.from_fragment()

    assert document
           |> LazyHTML.filter("#selected-model.skipper-panel-model--selected")
           |> Enum.count() == 1
  end

  test "model_picker renders the selected model and provider logo" do
    selected_model = %{
      "name" => "GPT Test",
      "owner" => "openai",
      id: "openai/gpt-test"
    }

    document =
      render_component(&CoreComponents.model_picker/1,
        id: "model-picker",
        models: [selected_model],
        event: "select_model",
        label: "Select a model",
        selected_model: selected_model
      )
      |> LazyHTML.from_fragment()

    assert document
           |> LazyHTML.query("#model-picker-button img[src='/images/model-providers/openai.svg']")
           |> Enum.count() == 1

    assert document
           |> LazyHTML.query("[id='model-picker-option-openai/gpt-test'] .hero-check")
           |> Enum.count() == 1
  end

  test "model_picker renders its add variant" do
    model = %{"name" => "GPT Test", "owner" => "openai", id: "openai/gpt-test"}

    document =
      render_component(&CoreComponents.model_picker/1,
        id: "add-model",
        models: [model],
        event: "add_model",
        label: "Add model",
        variant: :add,
        close_on_select: false
      )
      |> LazyHTML.from_fragment()

    assert document
           |> LazyHTML.query("#add-model-button .hero-plus")
           |> Enum.count() == 1

    assert document
           |> LazyHTML.query(
             "[id='add-model-option-openai/gpt-test'] img[src='/images/model-providers/openai.svg']"
           )
           |> Enum.count() == 1
  end
end
