require "test_helper"

class CocktailsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:one)
    @cocktail = cocktails(:one)
  end

  test "index requires sign in" do
    get cocktails_path

    assert_redirected_to new_user_session_path
  end

  test "creates a cocktail with nested doses (existing and new ingredient) and tags" do
    sign_in @owner

    assert_difference -> { Cocktail.count } => 1, -> { Dose.count } => 2, -> { Ingredient.count } => 1,
                      -> { Tag.count } => 2 do
      post cocktails_path, params: {
        cocktail: {
          name: "Elderflower Collins",
          about: "Floral and light.",
          description: "Build over ice, top with soda.",
          doses_attributes: {
            "0" => { amount: "45", ingredient_id: ingredients(:gin).id, _destroy: "false" },
            "1" => { amount: "15", ingredient_id: "", _destroy: "false",
                     ingredient_attributes: { name: "Elderflower Liqueur" } }
          },
          tags_attributes: {
            "0" => { name: "floral", _destroy: "false" },
            "1" => { name: "long", _destroy: "false" }
          }
        }
      }
    end

    cocktail = Cocktail.find_by!(name: "Elderflower Collins")

    assert_redirected_to cocktail_path(cocktail)
    assert_equal @owner, cocktail.user
    assert_equal ["Elderflower Liqueur", "Gin"], cocktail.ingredients.map(&:name).sort
    assert_equal [15.0, 45.0], cocktail.doses.map(&:amount).sort
  end

  test "edits a cocktail: changes a dose, removes a dose, adds a tag" do
    sign_in @owner
    vodka_dose = doses(:one_vodka)
    lime_dose = doses(:one_lime)

    get edit_cocktail_path(@cocktail)

    assert_response :success

    patch cocktail_path(@cocktail), params: {
      cocktail: {
        name: "Moscow Mule Deluxe",
        doses_attributes: {
          "0" => { id: vodka_dose.id, amount: "60", ingredient_id: vodka_dose.ingredient_id },
          "1" => { id: lime_dose.id, _destroy: "1" }
        },
        tags_attributes: { "0" => { name: "ginger" } }
      }
    }

    assert_redirected_to cocktail_path(@cocktail)
    @cocktail.reload

    assert_equal "Moscow Mule Deluxe", @cocktail.name
    assert_equal [60.0], @cocktail.doses.map(&:amount)
    assert_equal %w[ginger refreshing], @cocktail.tags.map(&:name).sort
  end

  test "destroys a cocktail with its doses" do
    sign_in @owner
    @cocktail.favorites.destroy_all
    @cocktail.user_reviews.destroy_all

    assert_difference -> { Cocktail.count } => -1, -> { Dose.count } => -2 do
      delete cocktail_path(@cocktail)
    end

    assert_redirected_to cocktails_path
  end

  # ApplicationController has no rescue_from for Pundit, so a refusal surfaces as the raised error.
  # Each request signs in again: Devise's sign_in only applies to the next request, and a raised
  # error means no session cookie comes back.
  test "Pundit blocks editing, updating and destroying someone else's cocktail" do
    intruder = users(:two)

    sign_in intruder
    assert_raises(Pundit::NotAuthorizedError) { get edit_cocktail_path(@cocktail) }

    sign_in intruder
    assert_raises(Pundit::NotAuthorizedError) do
      patch cocktail_path(@cocktail), params: { cocktail: { name: "Hijacked" } }
    end

    sign_in intruder
    assert_raises(Pundit::NotAuthorizedError) { delete cocktail_path(@cocktail) }

    sign_in intruder
    assert_raises(Pundit::NotAuthorizedError) { get sipsense_revise_cocktail_path(@cocktail) }

    assert_equal "Moscow Mule", @cocktail.reload.name
    assert Cocktail.exists?(@cocktail.id)
  end

  test "create_with_ai saves the cocktail the AI service returns" do
    sign_in @owner
    ai_cocktail = cocktails(:two)
    fake_service = Object.new
    fake_service.define_singleton_method(:create_from_prompt) { |_prompt| ai_cocktail }

    with_stubbed_ai_service(fake_service) do
      post create_with_ai_cocktails_path, params: { cocktail: { prompt: "something with gin" } }
    end

    assert_redirected_to cocktail_path(ai_cocktail)
  end

  test "create_with_ai re-renders the form when the AI call raises" do
    sign_in @owner
    fake_service = Object.new
    fake_service.define_singleton_method(:create_from_prompt) { |_prompt| raise "provider down" }

    with_stubbed_ai_service(fake_service) do
      post create_with_ai_cocktails_path, params: { cocktail: { prompt: "something with gin" } }
    end

    assert_response :unprocessable_content
  end

  private

  # Swaps CocktailAiService.new for the duration of the block, so no request ever reaches the AI provider.
  def with_stubbed_ai_service(fake_service)
    CocktailAiService.define_singleton_method(:new) { |*_args, **_kwargs| fake_service }
    yield
  ensure
    CocktailAiService.singleton_class.send(:remove_method, :new)
  end
end
