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

    @chat_messages = if @current_conversation
      @current_conversation.chat_messages.where.not(message_type: 'ai_detailed').chronological
    else
      []
    end
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
    Rails.logger.info "Course structure generation requested"

    # Find conversation - prioritize explicit conversation_id parameter, then session
    current_user_id = session[:user_id]
    session_id = session.id.to_s

    conversation = if params[:conversation_id].present?
      # Use specific conversation ID from button parameter
      Conversation.find_by(id: params[:conversation_id], user_id: current_user_id)
    elsif session[:conversation_id]
      # Fall back to session conversation
      Conversation.find_by(id: session[:conversation_id], user_id: current_user_id)
    else
      # Last resort: find by session_id
      Conversation.find_by(user_id: current_user_id, session_id: session_id)
    end

    Rails.logger.info "Using conversation #{conversation&.id} for course generation (from #{params[:conversation_id].present? ? 'parameter' : 'session'})"

    unless conversation
      Rails.logger.error "No conversation found for course generation"
      redirect_to admin_course_generator_index_path, alert: "No conversation found. Please start a new conversation."
      return
    end

    # Extract all document references from conversation messages
    mentioned_document_ids = []
    conversation.chat_messages.where(message_type: 'user_prompt').each do |message|
      mentioned_document_ids += extract_document_mentions(message.content)
    end
    mentioned_document_ids = mentioned_document_ids.uniq

    Rails.logger.info "Found #{mentioned_document_ids.length} referenced documents for structure generation"

    # Create Course record immediately and link to conversation
    course_title = generate_course_title(conversation)
    course_prompt = extract_course_prompt(conversation)

    course = Course.create!(
      title: course_title,
      prompt: course_prompt,
      admin_id: current_user_id,
      conversation: conversation
    )

    Rails.logger.info "Created course #{course.id} linked to conversation #{conversation.id}"

    # Start structure generation job with course ID and conversation context
    GenerateDetailedCourseJob.perform_later(session_id, mentioned_document_ids, course.id, conversation.id)

            # For now, just redirect to the structure page with loading message
    redirect_to show_structure_admin_course_generator_index_path(course_id: course.id),
                notice: "Course structure generation started. Please wait while we create your course structure..."
  end

  def generate_full_course
    Rails.logger.info "Full course generation requested"

    @course = Course.find(params[:id])
    unless @course
      redirect_to admin_course_generator_index_path, alert: "Course not found."
      return
    end

    # Start full course content generation job
    GenerateFullCourseJob.perform_later(@course.id)

    redirect_to show_full_course_admin_course_generator_path(@course.id),
                notice: "Full course content generation started. Please wait while we create detailed content and quizzes..."
  end

  def show_full_course
    @course = Course.find(params[:id])
    @course_modules = @course.course_modules.includes(:course_steps).ordered

    unless @course
      redirect_to admin_course_generator_index_path, alert: "Course not found."
      return
    end
  end

    def show_structure
    @session_id = params[:session_id]
    @course_id = params[:course_id]

    @conversation = Conversation.joins(:chat_messages)
                                .where(session_id: @session_id)
                                .order(updated_at: :desc)
                                .first

    @course = nil
    @course_modules = []
    @loading = true

    # Try to find course by ID first, or find the latest course associated with the conversation
    if @course_id
      @course = Course.includes(course_modules: :course_steps).find_by(id: @course_id)
    elsif @conversation
      # Find the latest course created from this conversation using the proper relationship
      @course = @conversation.courses.includes(course_modules: :course_steps)
                              .order(created_at: :desc)
                              .first
    end

    if @course
      @course_modules = @course.course_modules.ordered
      @loading = false
      Rails.logger.info "Loaded course #{@course.id} with #{@course_modules.count} modules"
    else
      # Fallback to checking conversation messages for JSON structure
      if @conversation
        structure_message = @conversation.chat_messages
                                       .where(message_type: 'ai_detailed')
                                       .order(created_at: :desc)
                                       .first

        if structure_message
          begin
            # Try to parse as JSON first
            @course_structure = JSON.parse(structure_message.content)
            @loading = false
          rescue JSON::ParserError
            # Fallback to original text format
            @course_structure = structure_message.content
            @loading = false
          end
        end
      end
    end
  end

  def new_conversation
    Rails.logger.info "Creating new conversation"

    current_user_id = session[:user_id]
    session_id = session.id.to_s

    # Create a new conversation immediately
    @conversation = Conversation.create!(
      user_id: current_user_id,
      session_id: session_id,
      title: "New Conversation #{Time.current.strftime('%m/%d %H:%M')}"
    )

    # Set the new conversation as current
    session[:conversation_id] = @conversation.id

    # Reload conversations list for sidebar
    @conversations = Conversation.where(user_id: current_user_id).recent.limit(10)

    Rails.logger.info "Created conversation #{@conversation.id}: '#{@conversation.title}'"

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update("chat-messages", partial: "welcome_message", locals: { conversation: @conversation }),
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

      @chat_messages = @conversation.chat_messages.where.not(message_type: 'ai_detailed').chronological
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
    # Use same logic as index action to find current conversation
    current_user_id = session[:user_id]
    session_id = session.id.to_s

    # Try to find by session conversation_id first, then by session_id
    conversation = if session[:conversation_id]
      Conversation.find_by(id: session[:conversation_id], user_id: current_user_id)
    else
      Conversation.find_by(user_id: current_user_id, session_id: session_id)
    end

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

      # Set the new conversation as current
      session[:conversation_id] = conversation.id

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

  def generate_course_title(conversation)
    # Use conversation title or generate from first prompt
    if conversation.title && !conversation.title.include?("Course Generation")
      return conversation.title
    end

    # Get first user prompt from conversation
    first_prompt = conversation.chat_messages.where(message_type: 'user_prompt').first&.content
    if first_prompt
      # Clean up prompt for title (remove document mentions, truncate)
      title = first_prompt.gsub(/@\w+/, '').strip.truncate(50, omission: '...')
      return title.present? ? title : "Course from Conversation"
    end

    "Course from Conversation"
  end

  def extract_course_prompt(conversation)
    # Combine all user prompts to form the course prompt
    prompts = conversation.chat_messages.where(message_type: 'user_prompt').pluck(:content)
    prompts.join("\n\n").presence || "Generate a course structure"
  end

  def step_content
    step = CourseStep.find(params[:id])
    course_module = step.course_module

    render json: {
      id: step.id,
      title: step.title,
      step_type: step.step_type,
      content: step.content,
      detailed_content: step.detailed_content,
      duration_minutes: step.duration_minutes,
      module_title: course_module.title,
      content_generated: step.content_generated?,
      icon: step.icon
    }
  end
end
