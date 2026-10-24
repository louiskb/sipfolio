require "test_helper"

# Devise sign up, sign in and sign out through the real forms (no sign_in helper).
class DeviseAuthTest < ActionDispatch::IntegrationTest
  test "a visitor can sign up and gets a profile" do
    assert_difference -> { User.count } => 1, -> { Profile.count } => 1 do
      post user_registration_path, params: {
        user: {
          first_name: "Carol",
          username: "carol_mixes",
          email: "carol@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_response :redirect
    follow_redirect!

    assert_response :success
    assert_equal "carol_mixes", User.find_by!(email: "carol@example.com").username
  end

  test "sign up is rejected with invalid data" do
    assert_no_difference -> { User.count } do
      post user_registration_path, params: {
        user: { first_name: "", username: "x", email: "bad", password: "1", password_confirmation: "2" }
      }
    end

    assert_response :unprocessable_content
  end

  test "an existing user can sign in and sign out" do
    post user_session_path, params: { user: { email: users(:one).email, password: "password123" } }

    assert_redirected_to cocktails_path
    follow_redirect!

    assert_response :success
    assert_match users(:one).username, response.body

    delete destroy_user_session_path

    assert_response :redirect
    get cocktails_path

    assert_redirected_to new_user_session_path
  end

  test "sign in fails with the wrong password" do
    post user_session_path, params: { user: { email: users(:one).email, password: "wrong-password" } }

    assert_response :unprocessable_content
    get cocktails_path

    assert_redirected_to new_user_session_path
  end
end
