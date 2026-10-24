ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"

# No real network in tests: every AI (ruby_llm) or Cloudinary call must be stubbed.
# Localhost stays allowed for Capybara/system tests.
WebMock.disable_net_connect!(allow_localhost: true)

# Never let a real AI key (GITHUB_TOKEN from .env) reach the test run. ruby_llm still needs
# *a* key to build a chat, so give it a dummy one.
RubyLLM.configure { |config| config.openai_api_key = "test-key" }

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

module ActionDispatch
  class IntegrationTest
    include Devise::Test::IntegrationHelpers
  end
end
