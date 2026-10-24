require "test_helper"

class CocktailTest < ActiveSupport::TestCase
  def build_cocktail(**attrs)
    Cocktail.new({ name: "Test Sour", about: "Tart.", description: "Shake it.", user: users(:one) }.merge(attrs))
  end

  test "fixture cocktail is valid" do
    assert_predicate cocktails(:one), :valid?
  end

  test "requires name, about and description" do
    cocktail = Cocktail.new(user: users(:one))

    assert_not cocktail.valid?
    assert_includes cocktail.errors[:name], "can't be blank"
    assert_includes cocktail.errors[:about], "can't be blank"
    assert_includes cocktail.errors[:description], "can't be blank"
  end

  test "name must be unique" do
    cocktail = build_cocktail(name: cocktails(:one).name)

    assert_not cocktail.valid?
    assert_includes cocktail.errors[:name], "has already been taken"
  end

  test "img_url must come from the shipped image list" do
    assert_predicate build_cocktail(img_url: "cocktail-3.jpg"), :valid?
    assert_not build_cocktail(img_url: "not-an-image.jpg").valid?
  end

  test "allows up to 5 doses" do
    cocktail = build_cocktail
    5.times { |i| cocktail.doses.build(amount: 10, ingredient: Ingredient.new(name: "Ingredient #{i}")) }

    assert_predicate cocktail, :valid?
  end

  test "rejects more than 5 doses" do
    cocktail = build_cocktail
    6.times { |i| cocktail.doses.build(amount: 10, ingredient: Ingredient.new(name: "Ingredient #{i}")) }

    assert_not cocktail.valid?
    assert_includes cocktail.errors[:doses], "maximum 5 ingredients are allowed"
  end

  test "allows up to 10 tags" do
    cocktail = build_cocktail
    10.times { |i| cocktail.tags.build(name: "tag#{i}") }

    assert_predicate cocktail, :valid?
  end

  test "rejects more than 10 tags" do
    cocktail = build_cocktail
    11.times { |i| cocktail.tags.build(name: "tag#{i}") }

    assert_not cocktail.valid?
    assert_includes cocktail.errors[:tags], "maximum 10 tags are allowed"
  end

  test "destroying a cocktail destroys its doses and tags but keeps ingredients" do
    cocktail = cocktails(:one)
    cocktail.favorites.destroy_all
    cocktail.user_reviews.destroy_all

    assert_difference -> { Dose.count } => -2, -> { Tag.count } => -1, -> { Ingredient.count } => 0 do
      cocktail.destroy
    end
  end
end
