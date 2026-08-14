defmodule HarborWeb.ModelProviderTest do
  use ExUnit.Case, async: true

  alias HarborWeb.ModelProvider

  @providers [
    {"alibaba", "Alibaba", "alibaba"},
    {"anthropic", "Anthropic", "anthropic"},
    {"deepseek", "DeepSeek", "deepseek"},
    {"google", "Google", "google-gemini"},
    {"meta", "Meta", "meta"},
    {"mistral", "Mistral AI", "mistral"},
    {"moonshotai", "Kimi", "kimi"},
    {"openai", "OpenAI", "openai"},
    {"xai", "xAI", "xai"},
    {"zai", "Z.ai", "zai"}
  ]

  test "returns display metadata for supported providers" do
    for {owner, name, icon_name} <- @providers do
      assert ModelProvider.name(owner) == name

      assert ModelProvider.icon_path(owner) ==
               "/images/model-providers/#{icon_name}.svg"
    end
  end

  test "returns nil for unsupported providers" do
    assert ModelProvider.name("unknown") == nil
    assert ModelProvider.icon_path("unknown") == nil
  end
end
