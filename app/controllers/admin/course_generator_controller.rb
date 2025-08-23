class Admin::CourseGeneratorController < ApplicationController
  before_action :require_admin
  before_action :load_documents

  def index
  end

        def generate
    Rails.logger.info "Course generation request received"

    @prompt = params[:prompt]&.strip
    mentioned_document_ids = extract_document_mentions(@prompt)

    if @prompt.blank?
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.append("chat-messages",
            partial: "error_message",
            locals: { message: "Please provide a prompt for course generation." })
        end
      end
      return
    end

    Rails.logger.info "Generating course with prompt: '#{@prompt}' and #{mentioned_document_ids.length} referenced documents"

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.append("chat-messages", partial: "simple_user_message", locals: { prompt: @prompt }),
          turbo_stream.append("chat-messages", partial: "simple_loading_message"),
          turbo_stream.update("course-prompt", ""),
          turbo_stream.update("referenced-docs", "")
        ]
      end
    end

    # Start background job after rendering response
    GenerateCourseJob.perform_later(@prompt, mentioned_document_ids, session.id.to_s)

  rescue => e
    Rails.logger.error "Course generation error: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")

        respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.append("chat-messages",
          partial: "simple_error_message",
          locals: { message: "An error occurred while generating the course. Please try again." })
      end
    end
  end

  def generate_detailed
    Rails.logger.info "Detailed course generation requested"

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.append("chat-messages",
          partial: "simple_loading_message")
      end
    end

    # Start detailed generation job
    GenerateDetailedCourseJob.perform_later(session.id.to_s)
  end

  def search_documents
    query = params[:query]&.strip&.downcase

    if query.blank?
      render json: []
      return
    end

    documents = Document.where("LOWER(title) LIKE ?", "%#{query}%")
                       .limit(10)
                       .select(:id, :title)

    render json: documents.map { |doc| { id: doc.id, title: doc.title } }
  end

    private

  def load_documents
    @documents = Document.includes(:user).order(:title)
  end

  def extract_document_mentions(text)
    return [] unless text.present?

    # Extract @filename patterns from the text
    filenames = text.scan(/@([a-z0-9_.-]+)/i).flatten
    Rails.logger.info "Extracted filename mentions: #{filenames}"

    # Find document IDs based on filenames
    document_ids = []
    filenames.each do |filename|
      @documents.each do |doc|
        sanitized_filename = helpers.sanitize_filename_for_mention(doc.title)
        if sanitized_filename.downcase == filename.downcase
          document_ids << doc.id
          Rails.logger.info "Matched filename '#{filename}' to document ID #{doc.id} (#{doc.title})"
        end
      end
    end

    document_ids.uniq
  end
end
