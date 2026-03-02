# Hotwire (Turbo + Stimulus) Rules

## Stack
- **Turbo Drive**: handles full page navigations (active by default)
- **Turbo Frames**: partial page updates — wrap sections in `<turbo-frame id="...">` tags
- **Turbo Streams**: server-push updates to multiple DOM elements at once
- **Stimulus**: light JS controllers for behaviour, no heavy framework

## Turbo Frames
Use for forms, modals, and inline updates:
```erb
<%# Wrap the target area %>
<turbo-frame id="cocktail_<%= @cocktail.id %>">
  <%= render @cocktail %>
</turbo-frame>

<%# Link that loads into a frame %>
<%= link_to "Edit", edit_cocktail_path(@cocktail), data: { turbo_frame: "cocktail_#{@cocktail.id}" } %>
```

## Turbo Streams (controller responses)
```ruby
# In controller
respond_to do |format|
  format.turbo_stream { render turbo_stream: turbo_stream.replace("cocktail_#{@cocktail.id}", partial: "cocktail") }
  format.html { redirect_to @cocktail }
end
```

Or use a stream template: `app/views/cocktails/create.turbo_stream.erb`
```erb
<%= turbo_stream.prepend "cocktails", partial: "cocktail", locals: { cocktail: @cocktail } %>
```

## Stimulus
- Controllers live in `app/javascript/controllers/`
- Naming: `hello_controller.js` → `data-controller="hello"`
- Register via `app/javascript/controllers/index.js` (auto-imports with stimulus-rails)

```js
// app/javascript/controllers/example_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "output"]

  connect() { /* runs when controller connects to DOM */ }
  disconnect() { /* runs when controller disconnects */ }
}
```

## Rules
- Prefer Turbo Frames/Streams over full page reloads for form submissions
- Don't write vanilla fetch/XHR — let Turbo handle it
- Use `data-turbo-confirm` for destructive actions
- For real-time: use ActionCable channels + Turbo Streams (already wired via `app/channels/`)
- Avoid `data-turbo="false"` except for file download links
