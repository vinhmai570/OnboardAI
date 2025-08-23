require 'openai'

if ENV['OPENAI_ACCESS_TOKEN'].present?
  OpenAI.configure do |config|
    config.access_token = ENV['OPENAI_ACCESS_TOKEN']
    config.organization_id = ENV['OPENAI_ORGANIZATION_ID'] if ENV['OPENAI_ORGANIZATION_ID'].present?
    config.log_errors = Rails.env.development? # Optional
  end
else
  Rails.logger.warn "OPENAI_ACCESS_TOKEN not configured. OpenAI features will be disabled."
end
