require "test_helper"

class UserReviewPolicyTest < ActiveSupport::TestCase
  def setup
    @review = user_reviews(:one) # written by users(:one)
  end

  def test_scope
    # UserReviewPolicy::Scope does not define #resolve yet (the generated one is commented out).
    assert_raises(NoMethodError) { UserReviewPolicy::Scope.new(users(:one), UserReview).resolve }
  end

  def test_show
    assert_not UserReviewPolicy.new(users(:one), @review).show?
  end

  def test_create
    assert_predicate UserReviewPolicy.new(users(:two), UserReview.new), :create?
  end

  def test_update
    assert_predicate UserReviewPolicy.new(users(:one), @review), :update?
    assert_not UserReviewPolicy.new(users(:two), @review).update?
  end

  def test_destroy
    assert_predicate UserReviewPolicy.new(users(:one), @review), :destroy?
    assert_not UserReviewPolicy.new(users(:two), @review).destroy?
  end
end
