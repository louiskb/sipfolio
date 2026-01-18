module ApplicationHelper
  def nav_link_class(path = "#")
    current_page?(path) ? "nav-link active fs-5" : "nav-link fs-5"
  end

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
end
