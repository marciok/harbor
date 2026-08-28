defmodule Harbor.SkipperStream do
  @moduledoc false

  @pubsub Harbor.PubSub
  @topic_prefix "skipper:run"

  @type stream_kind :: :source | :synthesis

  @spec subscribe(pos_integer()) :: :ok | {:error, term()}
  def subscribe(run_id) do
    Phoenix.PubSub.subscribe(@pubsub, topic(run_id))
  end

  @spec broadcast_started(pos_integer(), stream_kind(), pos_integer()) :: :ok | {:error, term()}
  def broadcast_started(run_id, kind, task_id) do
    broadcast(run_id, kind, task_id, :started, "")
  end

  @spec broadcast_delta(pos_integer(), stream_kind(), pos_integer(), String.t()) ::
          :ok | {:error, term()}
  def broadcast_delta(run_id, kind, task_id, delta) do
    broadcast(run_id, kind, task_id, :delta, delta)
  end

  @spec broadcast_finished(pos_integer(), stream_kind(), pos_integer(), String.t()) ::
          :ok | {:error, term()}
  def broadcast_finished(run_id, kind, task_id, content) do
    broadcast(run_id, kind, task_id, :finished, content)
  end

  defp broadcast(run_id, kind, task_id, event, content) do
    Phoenix.PubSub.broadcast(
      @pubsub,
      topic(run_id),
      {:skipper_stream,
       %{
         run_id: run_id,
         kind: kind,
         task_id: task_id,
         event: event,
         content: content
       }}
    )
  end

  defp topic(run_id), do: "#{@topic_prefix}:#{run_id}"
end
