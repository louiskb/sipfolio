require "test_helper"

class CocktailPolicyTest < ActiveSupport::TestCase
  def setup
    @owner = users(:one)
    @other = users(:two)
    @cocktail = cocktails(:one)
  end

  def test_scope
    assert_equal Cocktail.count, CocktailPolicy::Scope.new(@other, Cocktail).resolve.count
  end

  def test_show
    assert_predicate CocktailPolicy.new(@other, @cocktail), :show?
  end

  def test_create
    assert_predicate CocktailPolicy.new(@other, Cocktail.new), :create?
    assert_predicate CocktailPolicy.new(@other, Cocktail), :create_with_ai?
  end

  def test_update
    assert_predicate CocktailPolicy.new(@owner, @cocktail), :update?
    assert_not CocktailPolicy.new(@other, @cocktail).update?
    assert_not CocktailPolicy.new(@other, @cocktail).revise_with_ai?

    @other.admin = true

    assert_predicate CocktailPolicy.new(@other, @cocktail), :update?
  end

  def test_destroy
    assert_predicate CocktailPolicy.new(@owner, @cocktail), :destroy?
    assert_not CocktailPolicy.new(@other, @cocktail).destroy?
  end
end
