class GenerateDetailedCourseJob < ApplicationJob
  queue_as :default

  def perform(session_id)
    Rails.logger.info "Starting detailed course generation for session: #{session_id}"

    # Find the latest conversation for this session
    @conversation = Conversation.joins(:chat_messages)
                                .where(session_id: session_id)
                                .order(updated_at: :desc)
                                .first

    begin
      # Generate detailed course structure with modules, assessments, etc.
      detailed_content = generate_detailed_course_structure

      # Save AI response to chat history
      save_ai_response(detailed_content, 'ai_detailed')

      # Remove any existing loading message
      broadcast_remove_loading

      # Stream the detailed content line by line
      stream_detailed_content(detailed_content)

    rescue => e
      Rails.logger.error "Detailed course generation error: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")

      # Show error message
      broadcast_error_message("Failed to generate detailed course content. Please try again.")
    end
  end

  private

  def generate_detailed_course_structure
    system_prompt = <<~PROMPT
      You are an AI course designer. Create a detailed, structured course plan with specific modules, lessons, and assessments.

      Provide your response in markdown format with:
      ## Module 1: [Title]
      ### Lesson 1.1: [Lesson Title]
      - Learning outcomes
      - Key concepts
      - Activities
      - Resources needed

      ### Assessment 1.1
      - Quiz questions
      - Practical exercises
      - Success criteria

      Continue for 3-4 modules with multiple lessons each.
      Include estimated time for each component.
      Be specific and actionable.
    PROMPT

    user_prompt = "Create a comprehensive detailed course structure for the onboarding course we discussed. Break it down into specific modules, lessons, activities, and assessments."

    client = OpenaiService.client

    response = client.chat(
      parameters: {
        model: "gpt-4",
        messages: [
          { role: "system", content: system_prompt },
          { role: "user", content: user_prompt }
        ],
        temperature: 0.7,
        max_tokens: 2000
      }
    )

    response.dig("choices", 0, "message", "content")
  rescue => e
    Rails.logger.error "OpenAI detailed course generation error: #{e.message}"
    "Failed to generate detailed course structure. Please try again."
  end

  def stream_detailed_content(text)
    Rails.logger.info "📚 Streaming detailed course content (#{text.length} characters)"

    # Add a header to indicate this is detailed content
    broadcast_detailed_header

    # Split into lines and stream
    lines = text.split(/\n/).reject(&:blank?)

    lines.each do |line|
      clean_line = line.strip
      next if clean_line.empty?

      broadcast_detailed_line(clean_line)
      sleep(0.2) # Slightly faster for detailed content
    end
  end

  # Turbo Stream broadcast methods
  def broadcast_remove_loading
    Turbo::StreamsChannel.broadcast_remove_to(
      "course_generator",
      target: "loading-message"
    )
  end

  def broadcast_detailed_header
    Turbo::StreamsChannel.broadcast_append_to(
      "course_generator",
      target: "chat-messages",
      partial: "admin/course_generator/detailed_header"
    )
  end

  def broadcast_detailed_line(line_content)
    Turbo::StreamsChannel.broadcast_append_to(
      "course_generator",
      target: "detailed-content",
      partial: "admin/course_generator/detailed_line",
      locals: { line: line_content }
    )
  end

  def broadcast_error_message(message)
    Turbo::StreamsChannel.broadcast_append_to(
      "course_generator",
      target: "chat-messages",
      partial: "admin/course_generator/simple_error_message",
      locals: { message: message }
    )
  end

  def save_ai_response(content, message_type)
    return unless @conversation

    @conversation.chat_messages.create!(
      message_type: message_type,
      content: content,
      ai_response: content
    )

    # Update conversation timestamp
    @conversation.touch

    Rails.logger.info "Saved AI detailed response to conversation #{@conversation.id}"
  end
end
