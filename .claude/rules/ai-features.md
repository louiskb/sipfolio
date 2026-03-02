# AI Features (SipSense) Rules

## Overview
Sipfolio uses `ruby_llm` + `ruby_llm-schema` gems for AI-powered cocktail generation and revision.
Service object: `app/services/cocktail_ai_service.rb`

## Routes
- `GET  /cocktails/sipsense_mix`       → form for AI cocktail generation
- `POST /cocktails/create_with_ai`     → creates cocktail from prompt
- `GET  /cocktails/:id/sipsense_revise` → revision form
- `PATCH /cocktails/:id/revise_with_ai` → applies AI revision

## Pattern
All AI logic lives in `CocktailAiService`, not in the controller:
```ruby
service = CocktailAiService.new(current_user)
@cocktail = service.create_from_prompt(params[:prompt])
```

## Authorization
AI actions require Pundit authorization:
```ruby
authorize Cocktail, :create_with_ai?
```
The policy method must exist in `app/policies/cocktail_policy.rb`.

## Error handling
Wrap AI calls in `begin/rescue` — network and API errors are common:
```ruby
begin
  @cocktail = service.create_from_prompt(params[:prompt])
rescue => e
  redirect_to cocktails_path, alert: "AI generation failed: #{e.message}"
end
```

## Models used
The `Model` resource (`app/models/model.rb`) tracks available AI models with a `refresh` action.
The `ToolCall` model logs raw AI tool calls for debugging.
