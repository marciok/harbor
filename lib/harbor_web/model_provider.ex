defmodule HarborWeb.ModelProvider do
  @icon_base_path "/images/model-providers"

  @provider_names %{
    "alibaba" => "Alibaba",
    "anthropic" => "Anthropic",
    "deepseek" => "DeepSeek",
    "google" => "Google",
    "meta" => "Meta",
    "mistral" => "Mistral AI",
    "moonshotai" => "Kimi",
    "openai" => "OpenAI",
    "xai" => "xAI",
    "zai" => "Z.ai"
  }

  @icon_names %{
    "google" => "google-gemini",
    "moonshotai" => "kimi"
  }

  def icon_path(owner) when is_map_key(@provider_names, owner) do
    icon_name = Map.get(@icon_names, owner, owner)
    "#{@icon_base_path}/#{icon_name}.svg"
  end

  def icon_path(_owner), do: nil

  def name(owner), do: Map.get(@provider_names, owner)
end
