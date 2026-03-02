---
name: feature
description: >
  Sipfolio-specific feature implementation. Follows the global /feature skill structure
  with Sipfolio/Rails-specific conventions layered on top.
---

Follow the global /feature skill approach for: $ARGUMENTS

## Sipfolio-Specific Conventions
Apply these on top of the global feature planning process:

### Rails Layer Order
1. `rails generate migration AddXxxToYyyy` → `rails db:migrate`
2. Add model validations + associations in `app/models/`
3. Add Pundit policy method in `app/policies/<model>_policy.rb`
4. Add controller action with `authorize` call
5. Add route in `config/routes.rb`
6. Build view/partial in `app/views/`
7. Write test in `test/models/` or `test/system/`

### Must-Follow Rules
- `authorize @resource` (or `authorize Resource, :action?`) in every controller action
- `policy_scope(Resource)` on all index actions — never `Resource.all`
- `simple_form_for` for all forms — not plain `form_for`
- Bootstrap 5 classes only — no inline styles
- Turbo Frames for partial page updates, Turbo Streams for multi-element server push
- Service objects in `app/services/` if business logic spans more than one model or is complex
- Cloudinary via ActiveStorage for all image uploads

### Verification Steps (Sipfolio)
After each layer, suggest:
- `rails console` — check DB state, test model methods
- `rails test test/models/<model>_test.rb` — run model tests
- Visit the relevant route in browser at `http://localhost:3000`
- `rails test test/system/` — run system tests
