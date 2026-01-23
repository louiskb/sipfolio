class CocktailPolicy < ApplicationPolicy
  # NOTE: Up to Pundit v2.3.1, the inheritance was declared as
  # `Scope < Scope` rather than `Scope < ApplicationPolicy::Scope`.
  # In most cases the behavior will be identical, but if updating existing
  # code, beware of possible changes to the ancestors:
  # https://gist.github.com/Burgestrand/4b4bc22f31c8a95c425fc0e30d7ef1f5

  def create_with_ai?
    true
  end

  def show?
    true
  end

  def create?
    true
  end

  def update?
    return true if user.admin?  # admin can edit any cocktails.
    record.user == user
    # record: the cocktail passed to the `authorize` method in controller. record.user is the cocktail's (that's passed in earlier) user.
    # user: the `current_user` signed in with Devise.
    # record.user == user, checks whether the cocktail's user (the cocktail that was passed in earlier) is the same as the current_user.
  end

  def destroy?
    return true if user.admin? # admin can destroy any cocktails.
    record.user == user
  end

  class Scope < Scope
    # NOTE: Be explicit about which records you allow access to!
    def resolve
      scope.all # If users can see all cocktails.
      # scope.where(user: user) # If users can only see their cocktails.
      # scope.where("name LIKE 't%'") # If users can only see cocktails starting with `t`.
      # user.admin? ? scope.all : scope.where(user: user) # (ternary operator - shorthand way of writing a simple if-else statement in Ruby and many other programming languages (condition ? expression_if_true : expression_if_false). Ternary operators make the code more concise when you have simple conditional assignments or returns.) # If admin can see all cocktails but users can only see their cocktails.
    end
  end
end
