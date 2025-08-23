class Admin::CourseGeneratorController < ApplicationController
  before_action :require_admin
  before_action :load_documents

  def index
    # Load current conversation and messages
    current_user_id = session[:user_id]
    session_id = session.id.to_s
    
    # Try to find by session conversation_id first, then by session_id
    @current_conversation = if session[:conversation_id]
      Conversation.find_by(id: session[:conversation_id], user_id: current_user_id)
    else
      Conversation.find_by(user_id: current_user_id, session_id: session_id)
    end
    
    @chat_messages = @current_conversation&.chat_messages&.chronological || []
    @conversations = Conversation.where(user_id: current_user_id).recent.limit(10)
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

    # Find or create conversation for this session
    conversation = find_or_create_conversation(@prompt)

    # Save user message
    conversation.chat_messages.create!(
      message_type: 'user_prompt',
      content: @prompt,
      user_prompt: @prompt
    )

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

    # Start background job with conversation ID
    GenerateCourseJob.perform_later(@prompt, mentioned_document_ids, session.id.to_s, conversation.id)

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

  def new_conversation
    Rails.logger.info "Starting new conversation"
    
    # Clear only the conversation-related session data, keep user authentication
    session.delete(:conversation_id)
    
    current_user_id = session[:user_id]
    @conversations = Conversation.where(user_id: current_user_id).recent.limit(10)
    
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update("chat-messages", partial: "welcome_message"),
          turbo_stream.update("conversation-list", partial: "conversation_list", locals: { conversations: @conversations })
        ]
      end
      format.html { redirect_to admin_course_generator_index_path }
    end
  end

  def switch_conversation
    conversation_id = params[:conversation_id]
    current_user_id = session[:user_id]
    
    @conversation = Conversation.find_by(id: conversation_id, user_id: current_user_id)
    
    if @conversation
      # Update session to point to this conversation
      session[:conversation_id] = @conversation.id
      
      @chat_messages = @conversation.chat_messages.chronological
      @conversations = Conversation.where(user_id: current_user_id).recent.limit(10)
      
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.update("chat-messages", partial: "conversation_history", locals: { chat_messages: @chat_messages }),
            turbo_stream.update("conversation-list", partial: "conversation_list", locals: { conversations: @conversations })
          ]
        end
      end
    else
      head :not_found
    end
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

    def find_or_create_conversation(prompt)
    # Look for existing conversation in this session
    current_user_id = session[:user_id]
    session_id = session.id.to_s

    conversation = Conversation.find_by(
      user_id: current_user_id,
      session_id: session_id
    )

    unless conversation
      # Create new conversation
      title = prompt.strip.truncate(50, omission: '...')
      title = title.gsub(/@\w+/, '').strip # Remove document references
      title = title.present? ? title : "Course Generation #{Time.current.strftime('%m/%d %H:%M')}"

      conversation = Conversation.create!(
        user_id: current_user_id,
        session_id: session_id,
        title: title
      )

      Rails.logger.info "Created new conversation: #{conversation.id} - '#{conversation.title}'"
    end

    conversation
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
