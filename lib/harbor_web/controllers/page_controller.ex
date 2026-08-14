defmodule HarborWeb.PageController do
  use HarborWeb, :controller

  def home(conn, _params) do
    render(conn, :home, page_title: "Model orchestration")
  end
end
