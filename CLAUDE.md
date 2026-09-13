# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Sipfolio is a social cocktail app: users create, rate, favourite and discover cocktail
recipes, and two separate AI features ("SipSense") generate recipes and answer questions.

**Naming quirk:** the app started life as the Le Wagon "mister cocktail" challenge, so the
Rails module is `RailsMisterCocktail` and the databases are `rails_mister_cocktail_development`
/ `_test` / `_production` — not `sipfolio_*`. The Le Wagon `spec/` submodule was removed in
9701f6c; there is no `spec/` directory.

## Tech Stack

Ruby 3.3.5 · Rails 7.1.5 · PostgreSQL · Devise · Pundit · Hotwire (Turbo + Stimulus) ·
Bootstrap 5.3 (sassc-rails + sprockets, **not** cssbundling) · importmap · simple_form ·
Active Storage → Cloudinary · ruby_llm + ruby_llm-schema · redcarpet · Minitest · Heroku.

## Commands

```bash
bin/rails server                              # dev server (no bin/dev — sprockets, not jsbundling)
bin/rails console
bin/rails db:migrate
bin/rails db:seed                             # NEEDS env vars — see "Seeding" below
bin/rails test                                # whole suite (currently red — see "Testing")
bin/rails test test/models/                   # one directory
bin/rails test test/models/cocktail_test.rb   # one file
bin/rails test test/models/cocktail_test.rb:7 # one test, by line number
bundle exec rubocop                           # ~145 offenses on a clean tree today
bundle exec rubocop -a app/models/cocktail.rb # autocorrect one file
```

## Architecture

### Two distinct AI subsystems — don't confuse them

**1. SipSense Mix / Revise — structured cocktail generation (synchronous)**

`CocktailsController` → `CocktailAiService` → `RubyLLM.chat.with_schema(CocktailSchema)`.
The schema (`app/schemas/cocktail_schema.rb`) forces JSON back with `name`, `about`,
`description`, an `ingredients` array of `{ingredient_name, amount}`, and a `tags` array.
The service then maps that onto real records: `Ingredient.find_or_create_by(name: …titleize)`,
`cocktail.doses.build`, `cocktail.tags.build`, sets `ai_generated = true`, picks a random
`img_url` from `Cocktail::COCKTAIL_IMAGES`, and saves everything in one transaction.
Revision destroys the existing doses/tags and rebuilds them from the new response.

Routes: `GET /cocktails/sipsense_mix`, `POST /cocktails/create_with_ai`,
`GET /cocktails/:id/sipsense_revise`, `PATCH /cocktails/:id/revise_with_ai`.

The AI must respect the model's own limits (max 5 doses, max 10 tags) or `save` fails
validation — the prompts in `CocktailAiService` encode those limits, so if you change
`max_doses_limit` / `max_tags_limit` in `Cocktail`, change the prompt text too.

**2. SipSense chat — streaming conversation (asynchronous)**

`Chat`, `Message`, `Model` and `ToolCall` are **ruby_llm persistence models**
(`acts_as_chat`, `acts_as_message`, `acts_as_model`, `acts_as_tool_call`) — this is an
LLM chatbot, **not** user-to-user messaging, and it has no `user_id` at all.

Flow: `MessagesController#create` → `ChatResponseJob.perform_later` → `chat.ask(content)`
with a block → each chunk calls `Message#broadcast_append_chunk` → `broadcast_append_to
"chat_#{chat_id}"` → the view subscribes with `turbo_stream_from "chat_#{@chat.id}"`.
`Message` also has a blanket `broadcasts_to ->(m) { "chat_#{m.chat_id}" }`.
`MAX_USER_MESSAGES = 5` caps user turns per chat.

Active Job uses the **default `:async` adapter** (in-process, lost on restart) — no Sidekiq,
no Solid Queue. Action Cable is `async` in dev and `redis` in production (`REDIS_URL`).

### Provider configuration

`config/initializers/ruby_llm.rb` points ruby_llm at **Azure AI inference**
(`https://models.inference.ai.azure.com`) and reads the key from `GITHUB_TOKEN`
(falling back to `OPENAI_API_KEY`). `CocktailAiService` hardcodes `model: "gpt-4o"` in its
constructor default; `ChatsController` takes the model from the form instead.
`Model.refresh!` (via `POST /models/refresh`) repopulates the models table.

### Authorization — Pundit is opt-in, not global

`ApplicationController` runs `before_action :authenticate_user!` and includes
`Pundit::Authorization`, but the `verify_authorized` / `verify_policy_scoped` after_actions
are **deliberately commented out** there (see the note in the file: not every controller has
an index). They are enabled per-controller instead.

| Controller | Pundit |
|---|---|
| `CocktailsController` | `verify_authorized` + `verify_policy_scoped`, `authorize` on every action |
| `UserReviewsController` | `verify_authorized`, `authorize` on every action |
| Chats, Messages, Models, Profiles, Doses, Tags, Favorites, Ingredients | **none** |

Only two policies exist: `CocktailPolicy` and `UserReviewPolicy`. Both use
`return true if user.admin?` then `record.user == user`. `CocktailPolicy::Scope#resolve`
returns `scope.all`. `skip_pundit?` exempts Devise controllers and `PagesController`.

**When adding to an unprotected controller, adding Pundit is a deliberate change** — it means
writing a new policy class and enabling the after_action. Don't silently half-apply it
(an `authorize` call with no policy raises `Pundit::NotDefinedError`).

### Cocktail images have two independent paths

- `img_url` — a filename string from `Cocktail::COCKTAIL_IMAGES` (`cocktail-1.jpg` …
  `cocktail-26.jpg`), files that ship in `app/assets/images/`. Validated by `inclusion`.
  This is what the AI picks.
- `photo` — a real `has_one_attached` upload going to Cloudinary.

`ApplicationHelper#cocktail_background_image(cocktail)` picks between them (attachment wins).
Use that helper rather than reaching for either field directly.

### Hotwire, as actually used

There are **no Turbo Frames in this codebase**. The only Turbo usage beyond Drive is the
chat: `turbo_stream_from`, model broadcasts, and one stream template
(`app/views/messages/create.turbo_stream.erb`). Everything else is plain redirects and
`render …, status: :unprocessable_content`.

Stimulus controllers (`app/javascript/controllers/`, eager-loaded via importmap):
`file_preview`, `img_preview`, `form_field_vis`, `tag_field_vis`, `load_button`, `hello`.

### Other pieces worth knowing

- `Cocktail` uses `accepts_nested_attributes_for :doses` (with nested `:ingredient`) and
  `:tags`. `CocktailsController#new` pre-builds 5 doses + 10 tags for the form.
- `Ingredient` has a `before_destroy` guard that `throw :abort`s if any dose uses it.
- `User` `after_create :create_profile`; `Profile` carries `Point`, `Badge`, `Achievement`.
- `ApplicationHelper#render_markdown` (redcarpet) renders assistant messages; always paired
  with `sanitize` in the view.

## Conventions

- `simple_form_for` + `f.input` / `f.button :submit` for all forms.
- Double quotes; 2-space indent; 120-char max line.
- Bootstrap 5 utility classes for styling. (Chat views still carry inline `style=` attributes
  — legacy, don't copy the pattern into new views.)
- Complex multi-model logic goes in `app/services/`, not controllers.
- `ENV.fetch("KEY", nil)` over `ENV["KEY"]` in app code.
- RuboCop autocorrects every `.rb` edit via the `PostToolUse` hook
  (`.claude/hooks/rubocop-fix.sh`). `.rubocop.yml` excludes `db/`, `config/`, `bin/`, `test/`
  and disables many Style cops (`FrozenStringLiteralComment`, `StringLiterals`,
  `Documentation`, `Metrics/AbcSize`…).

## Environment

`.env` is gitignored (`dotenv-rails` loads it in dev/test). Keys in use:

| Key | Purpose |
|---|---|
| `GITHUB_TOKEN` | Azure AI inference key for all ruby_llm calls |
| `CLOUDINARY_URL` | Active Storage `:cloudinary` service (dev **and** production) |
| `REDIS_URL` | Action Cable adapter in production |
| `ADMIN_EMAIL` / `ADMIN_PASSWORD` / `ADMIN_USERNAME` | seeds only |
| `USER_1_EMAIL` / `USER_1_PASSWORD` / `USER_1_USERNAME` | seeds only |
| `USER_PASSWORDS` | password for the 22 Faker users in seeds |

Note Active Storage is `:cloudinary` in development too, so image uploads need
`CLOUDINARY_URL` locally.

### Seeding

`db/seeds.rb` calls `destroy_all` across Favorite → UserReview → Dose → Tag → Cocktail →
Ingredient → User before creating anything, and reads the seven `ENV` keys above with
`ENV["…"]` (no default). Missing keys produce users with blank passwords/emails that fail
validation, so check `.env` first.

## Testing

**Current state: `bin/rails test` is red — 10 runs, 0 assertions, 10 errors.** Every test file
is an empty generated stub, and `test/fixtures/users.yml` still contains the scaffold's
`one: {}` / `two: {}`, so `fixtures :all` violates the unique index on `users.email`
(`PG::UniqueViolation … Key (email)=() already exists`). Fixing that fixture is the
prerequisite for any test work here.

Layout: `test/models/`, `test/controllers/` (`ActionDispatch::IntegrationTest`),
`test/policies/`, `test/channels/`. `test/system/` and `test/integration/` exist but are
empty — despite `capybara` + `selenium-webdriver` being installed, there are no system tests.
Tests run parallelised (`parallelize(workers: :number_of_processors)`).

## Known landmines

Real bugs already in `master` — don't mistake them for intended behaviour, and don't
"fix" them silently as a side effect of unrelated work:

- **`Follow` is broken.** The table has `follower_id` / `followed_id`, but the model declares
  `belongs_to :following` (looks for `following_id`) and `User` declares
  `has_many :passive_follows, foreign_key: "follow_id"`. `Follow` also validates a
  `followed_id` its own association never sets.
- **`User#follow`, `#unfollow`, `#following?` are defined after `private`** — they're
  unreachable from outside the model.
- **Shallow-route destroys read the wrong param.** `DosesController#destroy` and
  `TagsController#destroy` call `Cocktail.find(params[:cocktail_id])`, but `shallow: true`
  means those routes are `/doses/:id` and `/tags/:id` with no `cocktail_id`.
- **Routes without controllers.** `resources :follows`, `:achievements`, `:badges` and
  `:points` are nested under `profiles` but no such controllers exist.
- **Unroutable actions.** `TagsController#index`, `IngredientsController#index`,
  `UserReviewsController#edit`/`#update` have no matching route.
- Several controllers pass `content: :unprocessable_content` to `render` where
  `status:` was meant.

## Deployment

Heroku (`heroku` remote on `master`). `Procfile` is `release: rails db:migrate` only — there
is no `web:` line, so Heroku falls back to its default Rails web command.

## Detailed rules

`.claude/rules/pundit.md`, `hotwire.md` and `ai-features.md` carry longer patterns. Note that
`pundit.md` describes the after_actions as living in `ApplicationController` and `hotwire.md`
leads with Turbo Frames — read both as the **target** convention; the "Authorization" and
"Hotwire" sections above describe what the code actually does today.
