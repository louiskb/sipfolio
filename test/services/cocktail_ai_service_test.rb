require "test_helper"

# Covers the mapping from a SipSense Mix schema answer onto Cocktail / Dose / Ingredient / Tag records.
#
# The AI provider is faked at the HTTP layer (WebMock), so the real ruby_llm code parses the
# response. That way this test notices if a ruby_llm upgrade changes where the structured answer
# lives (e.g. `Message#content` vs `Message#parsed`).
class CocktailAiServiceTest < ActiveSupport::TestCase
  COMPLETIONS_URL = "https://models.inference.ai.azure.com/chat/completions".freeze

  setup do
    @user = users(:one)
  end

  test "create_from_prompt builds and saves a cocktail with doses, ingredients and tags" do
    stub_ai_answer(
      name: "Midnight Basil Smash",
      about: "Herbal and bright.",
      description: "Muddle basil, add gin and lime, shake hard and double strain.",
      ingredients: [
        { ingredient_name: "gin", amount: 50.0 },
        { ingredient_name: "fresh basil syrup", amount: 15.5 }
      ],
      tags: %w[Herbal Citrus]
    )

    cocktail = nil
    assert_difference -> { Cocktail.count } => 1, -> { Dose.count } => 2, -> { Ingredient.count } => 1 do
      cocktail = CocktailAiService.new(@user).create_from_prompt("something herbal with gin")
    end

    assert_predicate cocktail, :persisted?
    assert_equal "Midnight Basil Smash", cocktail.name
    assert_equal "Herbal and bright.", cocktail.about
    assert_equal @user, cocktail.user
    assert cocktail.ai_generated
    assert_includes Cocktail::COCKTAIL_IMAGES, cocktail.img_url
    assert_equal({ "Fresh Basil Syrup" => 15.5, "Gin" => 50.0 },
                 cocktail.doses.to_h { |dose| [dose.ingredient.name, dose.amount] })
    assert_equal ingredients(:gin), cocktail.doses.find { |d| d.ingredient.name == "Gin" }.ingredient
    assert_equal %w[citrus herbal], cocktail.tags.map(&:name).sort
  end

  test "create_from_prompt returns an unsaved cocktail when the answer breaks the dose limit" do
    stub_ai_answer(
      name: "Kitchen Sink",
      about: "Everything.",
      description: "Pour it all in.",
      ingredients: (1..6).map { |i| { ingredient_name: "spirit #{i}", amount: 10 } },
      tags: ["strong"]
    )

    cocktail = nil
    assert_no_difference -> { Cocktail.count } do
      cocktail = CocktailAiService.new(@user).create_from_prompt("everything")
    end

    assert_not cocktail.persisted?
    assert_includes cocktail.errors[:doses], "maximum 5 ingredients are allowed"
  end

  test "revise_cocktail replaces doses and tags with the new answer" do
    cocktail = cocktails(:one)
    stub_ai_answer(
      name: "Moscow Mule Royale",
      about: "Spicier.",
      description: "Build over ice, top with ginger beer and a dash of bitters.",
      ingredients: [{ ingredient_name: "vodka", amount: 50 }],
      tags: %w[spicy]
    )

    revised = CocktailAiService.new(@user).revise_cocktail(cocktail, "make it spicier")

    assert_predicate revised, :persisted?
    cocktail.reload

    assert_equal "Moscow Mule Royale", cocktail.name
    assert_equal [["Vodka", 50.0]], cocktail.doses.map { |dose| [dose.ingredient.name, dose.amount] }
    assert_equal %w[spicy], cocktail.tags.map(&:name)
  end

  private

  # Fakes an OpenAI-compatible chat completion whose message content is the JSON schema answer.
  def stub_ai_answer(answer)
    body = {
      id: "chatcmpl-test",
      object: "chat.completion",
      created: Time.now.to_i,
      model: "gpt-4o",
      choices: [
        { index: 0, finish_reason: "stop", message: { role: "assistant", content: answer.to_json } }
      ],
      usage: { prompt_tokens: 10, completion_tokens: 20, total_tokens: 30 }
    }
    stub_request(:post, COMPLETIONS_URL).to_return(
      status: 200, body: body.to_json, headers: { "Content-Type" => "application/json" }
    )
  end
end
