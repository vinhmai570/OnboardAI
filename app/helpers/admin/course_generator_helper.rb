module Admin::CourseGeneratorHelper
  def render_markdown(text)
    return "" if text.blank?

    renderer = Redcarpet::Render::HTML.new(
      filter_html: true,
      no_links: false,
      no_images: false,
      hard_wrap: true
    )

    markdown = Redcarpet::Markdown.new(renderer,
      autolink: true,
      tables: true,
      fenced_code_blocks: true,
      strikethrough: true
    )

    markdown.render(text).html_safe
  end

  def sanitize_filename_for_mention(title)
    # Convert title to a mention-friendly filename format
    title.strip
         .downcase
         .gsub(/[^a-z0-9\s\-_\.]/, '') # Keep only alphanumeric, spaces, hyphens, underscores, dots
         .gsub(/\s+/, '_') # Replace spaces with underscores
         .gsub(/_{2,}/, '_') # Replace multiple underscores with single
         .gsub(/^_+|_+$/, '') # Remove leading/trailing underscores
  end
end
