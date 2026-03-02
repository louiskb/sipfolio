# Sipfolio - Claude Code Instructions

## Project Overview
Sipfolio is a social cocktail app (Rails 7.1) where users create, rate, and discover cocktail recipes. It has AI-powered features (SipSense) for generating and revising cocktails.

## Tech Stack
- **Ruby**: 3.3.5
- **Rails**: 7.1.5
- **Database**: PostgreSQL
- **Auth**: Devise
- **Authorization**: Pundit (verify_authorized / verify_policy_scoped enforced in controllers)
- **Frontend**: Hotwire (Turbo + Stimulus), Bootstrap 5.3, importmap
- **Images**: Cloudinary
- **Forms**: Simple Form
- **Tests**: Minitest + Capybara (system tests)
- **Deployment**: Heroku (`release: rails db:migrate` in Procfile)

## Common Commands
```bash
rails server              # Start dev server
rails console             # Open Rails console
rails db:migrate          # Run pending migrations
rails db:seed             # Seed with Faker data
rails test                # Run all tests
rails test test/models/   # Run model tests only
rails test test/system/   # Run system tests
bundle exec rails ...     # Prefix if needed
```

## Key Architecture
- **Controllers**: `app/controllers/` — use Pundit `authorize` on every action
- **Policies**: `app/policies/` — authorization logic lives here
- **Services**: `app/services/` — business logic (e.g., `CocktailAiService`)
- **Models**: `app/models/` — ActiveRecord, concerns in `models/concerns/`
- **Views**: `app/views/` — ERB templates, Turbo Frames for SPA behaviour
- **Channels**: `app/channels/` — ActionCable for chat

## Conventions
- Always add `authorize` calls in controllers (Pundit pattern already enforced)
- Service objects in `app/services/` for complex business logic
- Use `simple_form_for` for forms
- Bootstrap 5 classes for styling; avoid inline styles
- Cloudinary for all image uploads (ActiveStorage + Cloudinary)
- Use Turbo Frames/Streams for partial page updates instead of full page reloads

## Models (key relationships)
- `User` has many `Cocktail`, `Follow`, `Favorite`, `UserReview`, `Message`
- `Cocktail` has many `Dose` (ingredients+quantities), `Tag`, `UserReview`, `Favorite`
- `Profile` — per-user profile with `Achievement` and `Badge` associations
- `Chat` + `Message` — real-time chat via ActionCable

## Environment / Secrets
- `.env` is gitignored — credentials go there
- Rails credentials: `rails credentials:edit`
- Never hardcode API keys; use `ENV['KEY']` or credentials

## Testing Approach
- Model tests: `test/models/`
- Controller/integration tests: `test/integration/` or `test/controllers/`
- System tests (Capybara): `test/system/`
- Fixtures: `test/fixtures/`
- Factories: uses Faker for seed data (no FactoryBot)

## Linting
- RuboCop: `bundle exec rubocop` — auto-corrects on every file edit via hook
- Config: `.rubocop.yml` — max line length 120, Rails + Minitest extensions enabled

## Detailed Rules
See `.claude/rules/` for in-depth guidance on:
- `pundit.md` — authorization patterns and common mistakes
- `hotwire.md` — Turbo Frames/Streams and Stimulus patterns
- `ai-features.md` — SipSense AI routes, service object, and error handling
