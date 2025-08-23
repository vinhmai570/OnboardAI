require "openai"

# Support both OpenAI and Azure OpenAI via ENV configuration.
#
# For OpenAI (default):
#   OPENAI_API_KEY, OPEN_AI_BASE_URL=https://api.openai.com/v1
#
# For Azure OpenAI via APIM or direct endpoint:
#   OPEN_AI_PROVIDER=azure
#   OPENAI_API_KEY=...            (Azure API key)
#   AZURE_OPENAI_ENDPOINT=https://<resource|apim-host>
#   AZURE_OPENAI_DEPLOYMENT=<deployment_name>
#   AZURE_OPENAI_API_VERSION=2024-02-15-preview (or your version)

OpenAI.configure do |config|
  if ENV["OPEN_AI_PROVIDER"] == "azure"
    endpoint = ENV.fetch("AZURE_OPENAI_ENDPOINT")
    deployment = ENV.fetch("AZURE_OPENAI_DEPLOYMENT", "gpt-4.1")
    config.uri_base = File.join(endpoint, "openai", "deployments", deployment)
    config.api_version = ENV.fetch("AZURE_OPENAI_API_VERSION", "2024-02-15-preview")
  else
    config.uri_base = ENV.fetch("OPEN_AI_BASE_URL", "https://api.openai.com/v1")
  end
  config.api_type = ENV.fetch("OPEN_AI_PROVIDER", "azure")
  config.log_errors = true
  config.access_token = ENV.fetch("OPENAI_API_KEY", nil)
end
