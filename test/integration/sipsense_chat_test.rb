require "test_helper"

# SipSense chat: controllers enqueue ChatResponseJob; the job streams the answer through
# ruby_llm's acts_as_chat persistence. The provider is faked with WebMock.
class SipsenseChatTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  COMPLETIONS_URL = "https://models.inference.ai.azure.com/chat/completions".freeze

  setup { sign_in users(:one) }

  test "starting a chat creates it and enqueues the AI response" do
    assert_difference -> { Chat.count } => 1 do
      assert_enqueued_with(job: ChatResponseJob) do
        post chats_path, params: { chat: { prompt: "Suggest a mezcal cocktail", model: "" } }
      end
    end

    assert_redirected_to chat_path(Chat.last)
  end

  test "sending a message enqueues the AI response as a turbo stream" do
    chat = Chat.create!

    assert_enqueued_with(job: ChatResponseJob, args: [chat.id, "And a gin one?"]) do
      post chat_messages_path(chat), params: { message: { content: "And a gin one?" } }, as: :turbo_stream
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
  end

  test "ChatResponseJob persists the user message and the streamed assistant reply" do
    chat = Chat.create!
    stub_streamed_answer(["Try a ", "Oaxaca Old Fashioned."])

    assert_difference -> { chat.messages.count } => 2 do
      ChatResponseJob.perform_now(chat.id, "Suggest a mezcal cocktail")
    end

    user_message, assistant_message = chat.messages.order(:id).last(2)

    assert_equal "user", user_message.role
    assert_equal "Suggest a mezcal cocktail", user_message.content
    assert_equal "assistant", assistant_message.role
    assert_equal "Try a Oaxaca Old Fashioned.", assistant_message.content
  end

  private

  def stub_streamed_answer(pieces)
    events = pieces.map do |piece|
      chunk = {
        id: "chatcmpl-test", object: "chat.completion.chunk", created: Time.now.to_i, model: "gpt-4.1-nano",
        choices: [{ index: 0, delta: { role: "assistant", content: piece }, finish_reason: nil }]
      }
      "data: #{chunk.to_json}\n\n"
    end
    stub_request(:post, COMPLETIONS_URL).to_return(
      status: 200, body: "#{events.join}data: [DONE]\n\n", headers: { "Content-Type" => "text/event-stream" }
    )
  end
end
