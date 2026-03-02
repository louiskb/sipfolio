# Pundit Authorization Rules

## Pattern
Every controller action must be authorized via Pundit. The application enforces this with:
```ruby
after_action :verify_authorized, except: :index, unless: :skip_pundit?
after_action :verify_policy_scoped, only: :index, unless: :skip_pundit?
```

## Adding a new action
1. Call `authorize @resource` (or `authorize Resource, :action?`) in the controller action
2. Add the corresponding `action?` method to `app/policies/<resource>_policy.rb`
3. For index actions, use `policy_scope(Resource)` in the controller instead of `Resource.all`

## Policy structure
```ruby
class CocktailPolicy < ApplicationPolicy
  def show?
    true  # public
  end

  def create?
    user.present?
  end

  def update?
    record.user == user
  end

  def destroy?
    record.user == user || user.admin?
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
```

## Common mistakes
- Forgetting `authorize` in a new action → raises `Pundit::AuthorizationNotPerformedError`
- Using `Resource.all` in index instead of `policy_scope(Resource)` → raises `Pundit::PolicyScopingNotPerformedError`
- Policies live in `app/policies/`, named `<model>_policy.rb`
