defmodule Harbor.PromptNotifier do
  @moduledoc """
  Delivers completion notifications for Skipper runs.

  Delivery is best-effort so an email provider failure cannot change the
  outcome of the completed Gust run.
  """

  require Logger

  import Swoosh.Email

  alias Gust.Flows
  alias Harbor.Mailer
  alias Harbor.Prompts
  alias Harbor.Prompts.Prompt

  @terminal_statuses [:succeeded, :failed]

  @doc """
  Delivers an email when the run is terminal and its prompt has an address.

  Returns `:ok` when no notification was requested or the run is not finished.
  Provider and lookup failures are returned after being logged.
  """
  def deliver_run_finished(run_id) when is_integer(run_id) do
    run = Flows.get_run!(run_id)
    prompt = Prompts.get_prompt_by_gust_run_id(run_id)

    case prompt do
      %Prompt{notification_email: email} = prompt
      when is_binary(email) and email != "" and run.status in @terminal_statuses ->
        prompt
        |> completion_email(run.status)
        |> Mailer.deliver()
        |> log_delivery_error(run_id)

      _other ->
        :ok
    end
  rescue
    error ->
      Logger.error(
        "Skipper completion email failed for run #{run_id}: #{Exception.message(error)}"
      )

      {:error, error}
  catch
    kind, reason ->
      Logger.error(
        "Skipper completion email failed for run #{run_id}: #{inspect({kind, reason})}"
      )

      {:error, {kind, reason}}
  end

  @doc """
  Builds the completion email for a terminal prompt run.
  """
  def completion_email(%Prompt{} = prompt, status) when status in @terminal_statuses do
    result_url = result_url(prompt)
    {subject, heading, message} = email_copy(status)

    new()
    |> from(Application.fetch_env!(:harbor, :notification_from))
    |> to(prompt.notification_email)
    |> subject(subject)
    |> text_body(text_body(heading, message, result_url))
    |> html_body(html_body(heading, message, result_url))
    |> put_provider_option(:idempotency_key, "skipper-run-#{prompt.gust_run_id}-#{status}")
    |> put_provider_option(:tags, [
      %{name: "workflow", value: "skipper"},
      %{name: "status", value: to_string(status)}
    ])
  end

  defp email_copy(:succeeded) do
    {
      "Your Skipper answer is ready",
      "Your fused answer is ready",
      "Skipper finished comparing the model responses and preparing your final answer."
    }
  end

  defp email_copy(:failed) do
    {
      "Skipper could not finish your answer",
      "Your Skipper run did not finish",
      "Skipper could not complete this fusion. You can return to Harbor and try it again."
    }
  end

  defp text_body(heading, message, result_url) do
    """
    #{heading}

    #{message}

    Open your Skipper result: #{result_url}

    This notification was requested from Harbor.
    """
  end

  defp html_body(heading, message, result_url) do
    escaped_url = result_url |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()

    """
    <!doctype html>
    <html>
      <body style="font-family: sans-serif; color: #172033; line-height: 1.5;">
        <h1 style="font-size: 22px;">#{heading}</h1>
        <p>#{message}</p>
        <p style="margin: 24px 0;">
          <a href="#{escaped_url}" style="background: #172033; border-radius: 8px; color: #ffffff; display: inline-block; padding: 10px 16px; text-decoration: none;">
            Open result
          </a>
        </p>
        <p style="color: #667085; font-size: 13px;">This notification was requested from Harbor.</p>
      </body>
    </html>
    """
  end

  defp result_url(prompt) do
    HarborWeb.Endpoint.url()
    |> String.trim_trailing("/")
    |> Kernel.<>("/skipper/#{prompt.id}")
  end

  defp log_delivery_error({:error, reason} = result, run_id) do
    Logger.error("Skipper completion email failed for run #{run_id}: #{inspect(reason)}")
    result
  end

  defp log_delivery_error(result, _run_id), do: result
end
