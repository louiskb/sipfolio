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

Ruby 3.3.5 · Rails 8.1.4 (`load_defaults 8.1`) · PostgreSQL · Devise 5 · Pundit · Hotwire
(Turbo + Stimulus) · Bootstrap 5.3 (sassc-rails + sprockets, **not** cssbundling or Propshaft) ·
importmap · simple_form · Active Storage → Cloudinary · ruby_llm 2.1 (schemas via `schematist`) ·
redcarpet · Puma 8 · Minitest + WebMock. (No hosting — see "Deployment".)

Rails was upgraded 7.1 → 7.2 → 8.0 → 8.1 on `chore/rails-8.1` (2026-10-24). The Rails 8
`app:update` templates assume Propshaft, so `config.assets.quiet` (development) and
`config.assets.compile = false` (production) were restored by hand for sprockets — keep them
if you run `app:update` again.

### Bringing an existing database up to date (ruby_llm 1.9 → 2.1)

ruby_llm upgrades go one release at a time, and its 2.1 guide requires deleting the 2.0
upgrade migrations once every database has run them. So a database still on the old schema
(e.g. a development DB created before the upgrade) needs **two** stops:

```bash
pg_dump rails_mister_cocktail_development > ~/sipfolio-dev-before-ruby_llm-2.sql  # backup first
git switch --detach 8e87f9a          # last commit with the 2.0 migrations (ruby_llm 2.0)
bundle install && bin/rails db:migrate && bin/rails ruby_llm:load_models
git switch master                    # or the branch that contains the upgrade
bundle install && bin/rails db:migrate && bin/rails ruby_llm:load_models
```

The 2.0 migrations are irreversible; the backup is the way back. A brand-new database just
uses `bin/rails db:prepare` (it loads `db/schema.rb`).

## Commands

```bash
bin/rails server                              # dev server (bin/dev does the same: sprockets, no jsbundling)
bin/rails console
bin/rails db:migrate
bin/rails ruby_llm:load_models                # fill ruby_llm_models from the packaged registry (no network)
bin/rails db:seed                             # NEEDS env vars — see "Seeding" below
bin/rails test                                # whole suite (green — see "Testing")
bin/rails test test/models/                   # one directory
bin/rails test test/models/cocktail_test.rb   # one file
bin/rails test test/models/cocktail_test.rb:7 # one test, by line number
bundle exec rubocop                           # ~144 offenses on a clean tree today
bundle exec rubocop -a app/models/cocktail.rb # autocorrect one file
bundle exec bundler-audit check --update      # gem advisories (clean as of 2026-10-24)
bundle exec brakeman --no-pager               # static security scan (0 warnings as of 2026-10-24)
bin/importmap audit                           # JS pin advisories
bin/rails zeitwerk:check
```

## Architecture

### Two distinct AI subsystems — don't confuse them

**1. SipSense Mix / Revise — structured cocktail generation (synchronous)**

`CocktailsController` → `CocktailAiService` → `RubyLLM.chat.with_schema(CocktailSchema)`.
The schema (`app/schemas/cocktail_schema.rb`, a `Schematist::Schema` — `RubyLLM::Schema` is
gone in ruby_llm 2.x) forces JSON back with `name`, `about`, `description`, an `ingredients`
array of `{ingredient_name, amount}`, and a `tags` array. In ruby_llm 2.x the Hash is
`response.parsed`; `response.content` is the raw JSON **string**. The service then maps the
parsed Hash onto real records: `Ingredient.find_or_create_by(name: …titleize)`,
`cocktail.doses.build`, `cocktail.tags.build`, sets `ai_generated = true`, picks a random
`img_url` from `Cocktail::COCKTAIL_IMAGES`, and saves everything in one transaction.
Revision destroys the existing doses/tags and rebuilds them from the new response.

Routes: `GET /cocktails/sipsense_mix`, `POST /cocktails/create_with_ai`,
`GET /cocktails/:id/sipsense_revise`, `PATCH /cocktails/:id/revise_with_ai`.

The AI must respect the model's own limits (max 5 doses, max 10 tags) or `save` fails
validation — the prompts in `CocktailAiService` encode those limits, so if you change
`max_doses_limit` / `max_tags_limit` in `Cocktail`, change the prompt text too.

**2. SipSense chat — streaming conversation (asynchronous)**

`Chat` (`acts_as_chat`) and `Message` (`acts_as_message`) are the app's **ruby_llm
persistence models** — this is an LLM chatbot, **not** user-to-user messaging, and it has no
`user_id` at all. Since ruby_llm 2.0 the model registry, tool calls, usage and batches are
**owned by ruby_llm** (`ruby_llm_models`, `ruby_llm_tool_calls`, `ruby_llm_usages`,
`ruby_llm_batches`, plus 2.1's MCP/provider-file tables). There are no app `Model` or
`ToolCall` classes any more: read them through `RubyLLM.models`, `message.tool_calls`
(a Hash keyed by call id — iterate `each_value`), `message.tokens` and `chat.cost`.

Flow: `MessagesController#create` → `ChatResponseJob.perform_later` → `chat.ask(content)`
with a block → each chunk calls `Message#broadcast_append_chunk` → `broadcast_append_to
"chat_#{chat_id}"` → the view subscribes with `turbo_stream_from "chat_#{@chat.id}"`.
`Message` also has a blanket `broadcasts_to ->(m) { "chat_#{m.chat_id}" }`.
`MAX_USER_MESSAGES = 5` caps user turns per chat. `Message#to_partial_path` is overridden to
`messages/message`: ruby_llm (1.16+) otherwise picks a partial per role (`messages/_user`,
`_assistant` …) that this app doesn't have.

Active Job uses the **default `:async` adapter** (in-process, lost on restart) — no Sidekiq,
no Solid Queue. Action Cable is `async` in dev and `redis` in production (`REDIS_URL`).

### Provider configuration

`config/initializers/ruby_llm.rb` points ruby_llm at **Azure AI inference**
(`https://models.inference.ai.azure.com`) and reads the key from `GITHUB_TOKEN`
(falling back to `OPENAI_API_KEY`). It also sets `openai_protocol = :chat_completions`
(ruby_llm 2.x defaults OpenAI to the Responses API, which that endpoint never served) and
`default_model = "gpt-4.1-nano"` (ruby_llm 1.16 moved its own default to gpt-5.4; SipSense
chat has no model picker, so this is the model every chat uses). `CocktailAiService`
hardcodes `model: "gpt-4o"` in its constructor default; `ChatsController` takes the model
from the form instead (the picker is commented out, so it is always blank).
`RubyLLM.models.refresh` (via `POST /models/refresh`) repopulates `ruby_llm_models`;
`ModelsController` reads `RubyLLM.models`, and `/models/:id` takes dotted ids plus a
`?provider=` param.

**As of 2026-10-24 that Azure endpoint no longer resolves** (`models.inference.ai.azure.com`
is NXDOMAIN on public DNS), so SipSense Mix shows "AI encountered an error" and chat replies
never arrive. This predates the Rails 8.1 upgrade (master uses the same URL). GitHub Models
now lives at `https://models.github.ai/inference` with publisher-prefixed model ids
(`openai/gpt-4o`); moving there is an open decision, not done.

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

Devise 5 note: the copied `devise/shared/_error_messages` partial uses `data-turbo-temporary`
(not `data-turbo-cache="false"`), and `config.responder.error_status` is
`:unprocessable_content`.

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
| `GITHUB_TOKEN` | Azure AI inference key for all ruby_llm calls (endpoint currently dead — see "Provider configuration") |
| `CLOUDINARY_URL` | Active Storage `:cloudinary` service (dev **and** production) |
| `REDIS_URL` | Action Cable adapter in production — **unused now**, no production exists |
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

**Current state: `bin/rails test` is green — 40 runs, 173 assertions, 0 failures, 0 errors**
(was 10 runs, 10 errors before the 2026-10-24 safety net). It is a small smoke suite, not
full coverage:

- `test/integration/pages_render_test.rb` — public pages and every main signed-in page render.
- `test/integration/devise_auth_test.rb` — sign up, sign in, sign out through the real forms.
- `test/integration/sipsense_chat_test.rb` — chat/message creation enqueue `ChatResponseJob`;
  the job persists the user message and a streamed assistant reply.
- `test/controllers/cocktails_controller_test.rb` — create/edit/destroy with nested doses and
  tags, Pundit refusals on someone else's cocktail (raised `Pundit::NotAuthorizedError`: there
  is no `rescue_from`), `create_with_ai` success and failure with a stubbed service.
- `test/services/cocktail_ai_service_test.rb` — schema answer → Cocktail/Dose/Ingredient/Tag.
- `test/models/cocktail_test.rb`, `test/policies/*` — validations (5-dose / 10-tag limits) and
  both policies. The other model/controller files are still empty generated stubs.

**No network in tests.** `webmock` blocks every real request (`test_helper.rb`), and ruby_llm
gets a dummy key so a real `GITHUB_TOKEN` from `.env` never reaches a test. AI answers are faked
at the HTTP layer (`stub_request` on `…/chat/completions`), so the real ruby_llm parsing runs.
`test/fixtures/ruby_llm_models.yml` (model class `RubyLLM::ActiveRecord::Model`) must list
every model id the app asks for (`gpt-4o`, `gpt-4.1-nano`) or ruby_llm raises
`ModelNotFoundError`. Fixture users sign in with `password123`. Integration tests include
`Devise::Test::IntegrationHelpers`; `sign_in` only applies to the next request, so sign in again
after a request that raises.

Bugs the smoke tests step around (found 2026-10-24, present on master too, not fixed):
- `CocktailsController#create` re-rendering `new` after a validation error 500s:
  `@hero_banner` is never set there, and `_new_banner` calls `.sample` on it.
- The edit page 500s (`nil is not a valid asset source`) for a cocktail with no `photo` and
  no `img_url` — i.e. any cocktail created by hand without an upload.
  `cocktail_background_image` calls `asset_path(nil)`.
- `chats/_chat` assumes every chat has a first message; an empty chat breaks `/chats`.

Layout: `test/models/`, `test/controllers/` (`ActionDispatch::IntegrationTest`),
`test/integration/`, `test/services/`, `test/policies/`, `test/channels/`. `test/system/` is
empty — despite `capybara` + `selenium-webdriver` being installed, there are no system tests.
Tests run parallelised (`parallelize(workers: :number_of_processors)`, from 50 tests up).

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

**There is no deployment. This app is local-only as of 2026-09-22.**

It used to run on Heroku at `sipfolio.rocks`. That app was destroyed (along with its
`heroku-postgresql:essential-0` and `heroku-redis:mini` add-ons) to stop the monthly
charge, and `apps:destroy` removed the `heroku` git remote — `origin` (GitHub) is the
only remote now. A final database dump lives outside the repo at
`~/code/louiskb/sipfolio-archive/sipfolio-db-2026-09-22.dump`.

Vestiges of that setup still sit in the tree and are **not** wired to anything:

- `Procfile` (`release: rails db:migrate`) — Heroku-only, inert.
- `Dockerfile` / `.dockerignore` — Rails 7.1 scaffold defaults, never used to deploy.
- `sipfolio.rocks.crt` / `.csr` / `.key` — TLS material for the old custom domain.
  Gitignored (`*.crt`/`*.csr`/`*.key`) and mode 600, so they have never been committed.
  Defunct: the domain is frozen at the registrar until late 2027.

Cloudinary is unaffected — uploaded images live in that account, not on Heroku, and
`CLOUDINARY_URL` is still required in development for Active Storage to work.

If this is ever redeployed, note that `REDIS_URL` was only needed for the production
Action Cable adapter (`config/cable.yml`); development uses the `async` adapter.

## Detailed rules

`.claude/rules/pundit.md`, `hotwire.md` and `ai-features.md` carry longer patterns. Note that
`pundit.md` describes the after_actions as living in `ApplicationController` and `hotwire.md`
leads with Turbo Frames — read both as the **target** convention; the "Authorization" and
"Hotwire" sections above describe what the code actually does today.
