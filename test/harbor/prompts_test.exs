defmodule Harbor.PromptsTest do
  use Harbor.DataCase, async: true

  alias Harbor.BrowserSessions
  alias Harbor.Prompts
  alias Harbor.Prompts.Prompt

  setup do
    {:ok, browser_session} = BrowserSessions.create_browser_session()
    %{browser_session: browser_session}
  end

  test "builds a form changeset from prompt content" do
    assert %{valid?: true} = Prompt.form_changeset(%Prompt{}, %{"content" => "A question"})

    changeset = Prompt.form_changeset(%Prompt{}, %{"content" => "   "})

    refute changeset.valid?
    assert "can't be blank" in errors_on(changeset).content
  end

  test "creates a prompt for a browser session and Gust run", %{
    browser_session: browser_session
  } do
    gust_run_id = System.unique_integer([:positive])

    assert {:ok, %Prompt{} = prompt} =
             Prompts.create_prompt(browser_session.id, gust_run_id, %{
               content: "Compare the options"
             })

    assert prompt.content == "Compare the options"
    assert prompt.gust_run_id == gust_run_id
    assert prompt.browser_session_id == browser_session.id
    refute prompt.public
  end

  test "requires non-blank content", %{browser_session: browser_session} do
    assert {:error, changeset} =
             Prompts.create_prompt(browser_session.id, System.unique_integer([:positive]), %{
               content: "   "
             })

    assert "can't be blank" in errors_on(changeset).content
  end

  test "requires a unique Gust run", %{browser_session: browser_session} do
    gust_run_id = System.unique_integer([:positive])

    assert {:ok, _prompt} =
             Prompts.create_prompt(browser_session.id, gust_run_id, %{content: "First prompt"})

    assert {:error, changeset} =
             Prompts.create_prompt(browser_session.id, gust_run_id, %{content: "Second prompt"})

    assert "has already been taken" in errors_on(changeset).gust_run_id
  end

  test "lists only prompts owned by the browser session", %{
    browser_session: browser_session
  } do
    {:ok, other_browser_session} = BrowserSessions.create_browser_session()

    assert {:ok, owned_prompt} =
             Prompts.create_prompt(browser_session.id, System.unique_integer([:positive]), %{
               content: "Owned prompt"
             })

    assert {:ok, _other_prompt} =
             Prompts.create_prompt(
               other_browser_session.id,
               System.unique_integer([:positive]),
               %{
                 content: "Another browser's prompt"
               }
             )

    assert [prompt] = Prompts.list_prompts(browser_session.id)
    assert prompt.id == owned_prompt.id
  end

  test "limits prompts and lists them from newest to oldest", %{
    browser_session: browser_session
  } do
    prompts =
      for number <- 1..11 do
        assert {:ok, prompt} =
                 Prompts.create_prompt(
                   browser_session.id,
                   System.unique_integer([:positive]),
                   %{content: "Prompt #{number}"}
                 )

        prompt
      end

    listed_prompts = Prompts.list_prompts(browser_session.id, limit: 10)

    expected_ids =
      prompts
      |> Enum.reverse()
      |> Enum.take(10)
      |> Enum.map(& &1.id)

    assert length(listed_prompts) == 10
    assert Enum.map(listed_prompts, & &1.id) == expected_ids
  end

  test "gets only prompts owned by the browser session", %{browser_session: browser_session} do
    {:ok, other_browser_session} = BrowserSessions.create_browser_session()

    assert {:ok, prompt} =
             Prompts.create_prompt(browser_session.id, System.unique_integer([:positive]), %{
               content: "Private prompt"
             })

    assert Prompts.get_prompt!(browser_session.id, prompt.id).id == prompt.id

    assert_raise Ecto.NoResultsError, fn ->
      Prompts.get_prompt!(other_browser_session.id, prompt.id)
    end
  end

  test "allows anyone to get a public prompt while only its owner can change sharing", %{
    browser_session: browser_session
  } do
    {:ok, other_browser_session} = BrowserSessions.create_browser_session()

    {:ok, prompt} =
      Prompts.create_prompt(browser_session.id, System.unique_integer([:positive]), %{
        content: "Shareable prompt"
      })

    assert_raise Ecto.NoResultsError, fn ->
      Prompts.get_accessible_prompt!(other_browser_session.id, prompt.id)
    end

    assert {:ok, public_prompt} = Prompts.set_public(browser_session.id, prompt.id, true)
    assert public_prompt.public
    assert Prompts.get_accessible_prompt!(other_browser_session.id, prompt.id).id == prompt.id

    assert_raise Ecto.NoResultsError, fn ->
      Prompts.set_public(other_browser_session.id, prompt.id, false)
    end
  end
end
