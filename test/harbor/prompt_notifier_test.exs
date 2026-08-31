defmodule Harbor.PromptNotifierTest do
  use Harbor.DataCase, async: true

  import Harbor.SkipperFixtures
  import Swoosh.TestAssertions

  alias Gust.Flows
  alias Harbor.PromptNotifier
  alias Harbor.Prompts

  test "sends the result email after a successful run" do
    %{prompt: prompt, run: run} = skipper_fixture()

    {:ok, prompt} =
      Prompts.set_notification_email(prompt.browser_session_id, prompt.id, %{
        "notification_email" => "sailor@example.com"
      })

    {:ok, run} = Flows.update_run_status(run, :succeeded)

    assert {:ok, %{}} = PromptNotifier.deliver_run_finished(run.id)

    assert_email_sent(fn email ->
      assert email.to == [{"", "sailor@example.com"}]
      assert email.from == {"Skipper", "notifications@harbor.local"}
      assert email.subject == "Your Skipper answer is ready"
      assert email.text_body =~ "/skipper/#{prompt.id}"
      assert email.html_body =~ "Open result"
      assert email.provider_options.idempotency_key == "skipper-run-#{run.id}-succeeded"
      true
    end)
  end

  test "sends a failure email so the user is not left waiting" do
    %{prompt: prompt, run: run} = skipper_fixture()

    {:ok, _prompt} =
      Prompts.set_notification_email(prompt.browser_session_id, prompt.id, %{
        "notification_email" => "sailor@example.com"
      })

    {:ok, run} = Flows.update_run_status(run, :failed)

    assert {:ok, %{}} = PromptNotifier.deliver_run_finished(run.id)

    assert_email_sent(
      to: "sailor@example.com",
      subject: "Skipper could not finish your answer"
    )
  end

  test "does not send when no notification was requested" do
    %{run: run} = skipper_fixture()
    {:ok, run} = Flows.update_run_status(run, :succeeded)

    assert :ok = PromptNotifier.deliver_run_finished(run.id)
    refute_email_sent()
  end

  test "does not send before the run finishes" do
    %{prompt: prompt, run: run} = skipper_fixture()

    {:ok, _prompt} =
      Prompts.set_notification_email(prompt.browser_session_id, prompt.id, %{
        "notification_email" => "sailor@example.com"
      })

    assert :ok = PromptNotifier.deliver_run_finished(run.id)
    refute_email_sent()
  end
end
