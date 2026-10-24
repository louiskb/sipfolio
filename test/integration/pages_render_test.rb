require "test_helper"

# Smoke test: every public page and the main signed-in pages render without errors.
class PagesRenderTest < ActionDispatch::IntegrationTest
  test "public pages render" do
    [root_path, new_user_session_path, new_user_registration_path, new_user_password_path].each do |path|
      get path

      assert_response :success, "expected #{path} to render"
    end
  end

  test "signed-in pages redirect to sign in when signed out" do
    [cocktails_path, journal_path, user_profile_path, chats_path, profiles_path].each do |path|
      get path

      assert_redirected_to new_user_session_path, "expected #{path} to require sign in"
    end
  end

  test "main signed-in pages render" do
    sign_in users(:one)
    cocktail = cocktails(:one)
    chat = Chat.create!
    # Real chats always get a first message from ChatResponseJob; chats/_chat assumes one exists.
    chat.messages.create!(role: "user", content: "What goes well with mezcal?")

    paths = [
      root_path,
      cocktails_path,
      cocktail_path(cocktail),
      new_cocktail_path,
      edit_cocktail_path(cocktail),
      sipsense_mix_cocktails_path,
      sipsense_revise_cocktail_path(cocktail),
      new_cocktail_user_review_path(cocktail),
      new_ingredient_path,
      journal_path,
      user_profile_path,
      profiles_path,
      profile_path(profiles(:two)),
      chats_path,
      new_chat_path,
      chat_path(chat),
      models_path,
      edit_user_registration_path
    ]

    paths.each do |path|
      get path

      assert_response :success, "expected #{path} to render"
    end
  end

  test "cocktail show lists its ingredients and tags" do
    sign_in users(:two)

    get cocktail_path(cocktails(:one))

    assert_response :success
    assert_match "Moscow Mule", response.body
    assert_match "Vodka", response.body
    assert_match "refreshing", response.body
  end
end
