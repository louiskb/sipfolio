module ApplicationHelper
  # Makes the class attribute value dynamic (adding and removing `active` class) depending on the current page.
  def nav_link_class(path = "#")
    current_page?(path) ? "nav-link active fs-5" : "nav-link fs-5"
  end

  # Renders markdown into HTML with settings for the `redcarpet` gem that parses markdown into HTML.
  def render_markdown(text)
    return "" if text.blank?

    markdown = Redcarpet::Markdown.new(
      Redcarpet::Render::HTML.new(
        filter_html: true,
        hard_wrap: true
      ),
      autolink: true,
      tables: true,
      fenced_code_blocks: true
    )

    markdown.render(text)
  end

  # Checks whether the cocktail image is either (1) uploaded by the user (via Active Storage) or (2) pre-selected by SipSense Mix AI (pre-saved cocktail images in the `assets/images` path).
  def cocktail_background_image(cocktail)
    if cocktail.photo.attached?
      url_for(cocktail.photo)
    else
      asset_path(cocktail.img_url)
    end
  end
  
end
