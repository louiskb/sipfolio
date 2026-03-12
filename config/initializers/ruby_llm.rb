RubyLLM.configure do |config|
  config.openai_api_key = ENV.fetch('GITHUB_TOKEN', nil) || ENV.fetch('OPENAI_API_KEY', nil) # Add `Rails.application.credentials.dig(:openai_api_key)` if using Rails credentials. FYI Run `rails credentials:edit` to open and decrypt YAML file where you'd add and edit credentials e.g. `openai_api_key: your-api-key-here`. It's decrypted at runtime using a master key `config/master.key`, which is never committed to Git. Rails credentials work well in development without needing a `.env` file.
  config.openai_api_base = "https://models.inference.ai.azure.com"
  # config.default_model = "gpt-5-nano"

  # Use the new association-based acts_as API (recommended)
  config.use_new_acts_as = true
end
