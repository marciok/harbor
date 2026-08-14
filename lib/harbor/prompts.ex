defmodule Harbor.Prompts do
  @moduledoc """
  Manages prompts owned by browser sessions.
  """

  import Ecto.Query

  alias Harbor.Prompts.Prompt
  alias Harbor.Repo

  @doc """
  Lists a browser session's prompts from newest to oldest.

  ## Options

    * `:limit` - limits the number of returned prompts
  """
  def list_prompts(browser_session_id, opts \\ []) do
    Prompt
    |> where(browser_session_id: ^browser_session_id)
    |> order_by(desc: :inserted_at)
    |> maybe_limit(Keyword.get(opts, :limit))
    |> Repo.all()
  end

  @doc """
  Creates a prompt for a browser session and Gust run.

  Ownership and the Gust run identifier are supplied separately so they cannot
  be overridden by form parameters.
  """
  def create_prompt(browser_session_id, gust_run_id, attrs)
      when is_integer(gust_run_id) and is_map(attrs) do
    %Prompt{browser_session_id: browser_session_id, gust_run_id: gust_run_id}
    |> Prompt.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a prompt owned by a browser session.
  """
  def get_prompt!(browser_session_id, id) do
    Repo.get_by!(Prompt, id: id, browser_session_id: browser_session_id)
  end

  @doc """
  Gets a prompt when it belongs to the browser session or is public.
  """
  def get_accessible_prompt(browser_session_id, id) do
    Prompt
    |> where(
      [prompt],
      prompt.id == ^id and
        (prompt.browser_session_id == ^browser_session_id or prompt.public)
    )
    |> Repo.one()
  end

  @doc """
  Changes whether an owned prompt can be viewed by anyone with its URL.
  """
  def set_public(browser_session_id, id, public) when is_boolean(public) do
    browser_session_id
    |> get_prompt!(id)
    |> Ecto.Changeset.change(public: public)
    |> Repo.update()
  end

  defp maybe_limit(query, nil), do: query
  defp maybe_limit(query, limit), do: limit(query, ^limit)
end
