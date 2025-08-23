if Rails.env.development?
  HttpLog.configure do |config|
    # Log all HTTP requests to external services in development
    config.enabled = true

    # Log request and response details
    config.log_request = true
    config.log_response = true
    config.log_data = true
    config.log_headers = false # Set to true if you need headers (be careful with API keys)
    config.log_benchmark = true

    # Configure log level and format
    config.severity = Logger::INFO
    config.prefix = "[HTTP]"
    config.prefix_data_lines = true
    config.prefix_response_lines = true
    config.prefix_line_numbers = false

    # Only log external requests (not Rails internal)
    config.url_whitelist_pattern = /.*/
    config.url_blacklist_pattern = %r{^https?://(127\.0\.0\.1|localhost)}

    # Compact logging for better readability
    config.compact_log = true
  end
end
