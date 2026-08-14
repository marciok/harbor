defmodule Harbor.PromptsFixtures do
  @moduledoc false

  def unique_gust_run_id do
    1_000_000_000 + System.unique_integer([:positive, :monotonic])
  end
end
