class GenerateCourseJob < ApplicationJob
  queue_as :default

  def perform(prompt, mentioned_document_ids, session_id, conversation_id = nil)
    Rails.logger.info "Starting streaming course generation for prompt: '#{prompt}'"
    @conversation = Conversation.find_by(id: conversation_id) if conversation_id

    begin
      # Get referenced documents and their chunks
      referenced_documents = Document.where(id: mentioned_document_ids).includes(:document_chunks)
      context_chunks = referenced_documents.flat_map(&:document_chunks).select { |chunk| chunk.embedding.present? }

      Rails.logger.info "Found #{context_chunks.length} chunks from #{referenced_documents.length} documents"

      # Remove loading message first
      broadcast_remove_loading

      # Stream the course generation process
      stream_course_generation(prompt, context_chunks, referenced_documents)

    rescue => e
      Rails.logger.error "Course generation streaming error: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")

      # Remove loading and show error
      broadcast_remove_loading
      broadcast_error_message("An error occurred while generating the course. Please try again.")
    end
  end

  private

    def stream_course_generation(prompt, context_chunks, referenced_documents)
    Rails.logger.info "🚀 Starting ChatGPT-style streaming for: #{prompt}"

    # Start streaming response with AI thinking
    broadcast_start_streaming

    # Generate simple course overview in text format
    overview_response = generate_simple_overview(prompt, context_chunks)

    if overview_response.present?
      # Save AI response to chat history
      save_ai_response(overview_response, 'ai_overview')

      # Stream the response line by line
      stream_text_response(overview_response)

      # Add generate detailed course button at the end
      broadcast_generate_button
    else
      broadcast_error_message("Failed to generate course overview. Please try again.")
    end
  end

  def generate_simple_overview(prompt, context_chunks)
    context = context_chunks.map(&:content).join("\n\n")[0..2000] # Limit context

        system_prompt = <<~PROMPT
      You are a helpful AI assistant that creates course overviews. Provide a well-structured response in **Markdown format**.

      Structure your response using proper Markdown formatting:
      - Use **## headings** for main sections
      - Use **bold text** for emphasis
      - Use bullet points (-) for lists
      - Use numbered lists (1.) when appropriate
      - Keep it conversational and helpful

      Example structure:
      ## Course Overview
      Brief description of the course...

      ## Learning Objectives
      - First objective
      - Second objective
      - Third objective

      ## Duration
      Estimated time to complete...

      ## Key Topics
      - Topic 1
      - Topic 2
      - Topic 3
    PROMPT

    user_prompt = if context.present?
      "Create a course overview for: #{prompt}\n\nBased on this context from documents:\n#{context}"
    else
      "Create a course overview for: #{prompt}"
    end

    call_openai_streaming(system_prompt, user_prompt)
  end

  def stream_text_response(text)
    Rails.logger.info "📝 Streaming response line by line (#{text.length} characters)"

    # Split into lines and sentences for natural streaming
    lines = text.split(/\n/).reject(&:blank?)

    lines.each do |line|
      clean_line = line.strip
      next if clean_line.empty?

      # Stream each line as it comes
      broadcast_line(clean_line)

      # Natural pause between lines
      sleep(0.1)
    end

    # Add generate button
    sleep(0.5)
    broadcast_generate_button
  end

  def split_into_markdown_blocks(text)
    # Split by double newlines (paragraph breaks) and headers
    blocks = text.split(/(?=\n##)|(?=\n\n)/).reject(&:blank?)

    # Further split large blocks by single sentences if they're too long
    final_blocks = []
    blocks.each do |block|
      block = block.strip
      if block.length > 300 && !block.start_with?('##') && !block.include?("\n-") && !block.include?("\n*")
        # Split long paragraphs by sentences
        sentences = block.split(/(?<=[.!?])\s+/).reject(&:blank?)
        final_blocks.concat(sentences)
      else
        final_blocks << block
      end
    end

    final_blocks
  end

    def stream_course_title_and_overview(prompt, context_chunks)
    Rails.logger.info "📋 Streaming title and overview"

    # Generate just the title and overview first
    system_prompt = build_title_overview_prompt
    user_prompt = "Create a course title and description for: #{prompt}"

    response = call_openai_streaming(system_prompt, user_prompt)

    if response.present?
      # Test JSON parsing before broadcasting
      begin
        parsed = JSON.parse(response)
        if parsed.is_a?(Hash) && parsed["title"].present?
          broadcast_course_section("title_overview", response)
          Rails.logger.info "✅ Successfully streamed title and overview"
        else
          Rails.logger.warn "⚠️ Invalid title/overview structure: #{response}"
          broadcast_course_section("title_overview", { title: "Generated Course", description: "Course created from your prompt" }.to_json)
        end
      rescue JSON::ParserError => e
        Rails.logger.error "❌ JSON parsing error for title/overview: #{e.message}"
        broadcast_course_section("title_overview", { title: "Generated Course", description: "Course created from your prompt" }.to_json)
      end
    else
      Rails.logger.error "❌ No response from OpenAI for title/overview"
    end
  end

    def stream_course_objectives(prompt, context_chunks)
    Rails.logger.info "🎯 Streaming learning objectives"

    # Generate learning objectives
    system_prompt = build_objectives_prompt
    context = context_chunks.map(&:content).join("\n\n")[0..2000] # Limit context
    user_prompt = "Create learning objectives for course: #{prompt}\n\nContext: #{context}"

    response = call_openai_streaming(system_prompt, user_prompt)

    if response.present?
      begin
        parsed = JSON.parse(response)
        if parsed.is_a?(Hash) && parsed["objectives"]&.is_a?(Array)
          broadcast_course_section("objectives", response)
          Rails.logger.info "✅ Successfully streamed objectives"
        else
          Rails.logger.warn "⚠️ Invalid objectives structure: #{response}"
          fallback_objectives = { objectives: [ "Understand the basics", "Apply key concepts", "Complete practical exercises" ] }.to_json
          broadcast_course_section("objectives", fallback_objectives)
        end
      rescue JSON::ParserError => e
        Rails.logger.error "❌ JSON parsing error for objectives: #{e.message}"
        fallback_objectives = { objectives: [ "Understand the basics", "Apply key concepts", "Complete practical exercises" ] }.to_json
        broadcast_course_section("objectives", fallback_objectives)
      end
    else
      Rails.logger.error "❌ No response from OpenAI for objectives"
    end
  end

    def stream_course_modules(prompt, context_chunks)
    Rails.logger.info "📚 Streaming course modules"

    # Generate course modules
    system_prompt = build_modules_prompt
    context = context_chunks.map(&:content).join("\n\n")[0..3000] # Limit context
    user_prompt = "Create course modules for: #{prompt}\n\nContext: #{context}"

    response = call_openai_streaming(system_prompt, user_prompt)

    if response.present?
      begin
        parsed = JSON.parse(response)
        if parsed.is_a?(Hash) && parsed["modules"]&.is_a?(Array)
          broadcast_course_section("modules", response)
          Rails.logger.info "✅ Successfully streamed modules"
        else
          Rails.logger.warn "⚠️ Invalid modules structure: #{response}"
          fallback_modules = {
            modules: [
              { order: 1, title: "Introduction", description: "Getting started with the course", duration: "30 minutes", topics: [ "Overview", "Setup" ] },
              { order: 2, title: "Core Concepts", description: "Learn the fundamentals", duration: "1 hour", topics: [ "Key principles", "Best practices" ] },
              { order: 3, title: "Practical Application", description: "Apply what you've learned", duration: "45 minutes", topics: [ "Hands-on exercises", "Real examples" ] }
            ]
          }.to_json
          broadcast_course_section("modules", fallback_modules)
        end
      rescue JSON::ParserError => e
        Rails.logger.error "❌ JSON parsing error for modules: #{e.message}"
        fallback_modules = {
          modules: [
            { order: 1, title: "Introduction", description: "Getting started with the course", duration: "30 minutes", topics: [ "Overview", "Setup" ] },
            { order: 2, title: "Core Concepts", description: "Learn the fundamentals", duration: "1 hour", topics: [ "Key principles", "Best practices" ] },
            { order: 3, title: "Practical Application", description: "Apply what you've learned", duration: "45 minutes", topics: [ "Hands-on exercises", "Real examples" ] }
          ]
        }.to_json
        broadcast_course_section("modules", fallback_modules)
      end
    else
      Rails.logger.error "❌ No response from OpenAI for modules"
    end
  end

    def stream_course_assessments(prompt, context_chunks)
    Rails.logger.info "📝 Streaming assessments"

    # Generate assessments
    system_prompt = build_assessments_prompt
    user_prompt = "Create assessment suggestions for course: #{prompt}"

    response = call_openai_streaming(system_prompt, user_prompt)

    if response.present?
      begin
        parsed = JSON.parse(response)
        if parsed.is_a?(Hash) && parsed["assessments"]&.is_a?(Array)
          broadcast_course_section("assessments", response)
          Rails.logger.info "✅ Successfully streamed assessments"
        else
          Rails.logger.warn "⚠️ Invalid assessments structure: #{response}"
          fallback_assessments = {
            assessments: [
              { type: "quiz", title: "Knowledge Check", description: "Test your understanding of key concepts" },
              { type: "assignment", title: "Practical Exercise", description: "Apply what you've learned in a real scenario" },
              { type: "project", title: "Final Project", description: "Demonstrate your mastery of the course material" }
            ]
          }.to_json
          broadcast_course_section("assessments", fallback_assessments)
        end
      rescue JSON::ParserError => e
        Rails.logger.error "❌ JSON parsing error for assessments: #{e.message}"
        fallback_assessments = {
          assessments: [
            { type: "quiz", title: "Knowledge Check", description: "Test your understanding of key concepts" },
            { type: "assignment", title: "Practical Exercise", description: "Apply what you've learned in a real scenario" },
            { type: "project", title: "Final Project", description: "Demonstrate your mastery of the course material" }
          ]
        }.to_json
        broadcast_course_section("assessments", fallback_assessments)
      end
    else
      Rails.logger.error "❌ No response from OpenAI for assessments"
    end
  end

  def stream_referenced_documents(referenced_documents, chunks_used)
    documents_data = {
      documents: referenced_documents.map { |doc| { id: doc.id, title: doc.title } },
      chunks_used: chunks_used
    }

    broadcast_course_section("referenced_docs", documents_data)
  end

    def call_openai_streaming(system_prompt, user_prompt)
    client = OpenaiService.client

    Rails.logger.info "🤖 Making OpenAI call for streaming generation"

    response = client.chat(
      parameters: {
        model: "gpt-4",
        messages: [
          { role: "system", content: system_prompt },
          { role: "user", content: user_prompt }
        ],
        temperature: 0.7,
        max_tokens: 800 # Smaller for streaming parts
      }
    )

    content = response.dig("choices", 0, "message", "content")
    Rails.logger.info "📥 OpenAI response: #{content&.truncate(200)}"
    content
  rescue => e
    Rails.logger.error "❌ OpenAI streaming call error: #{e.message}"
    Rails.logger.error e.backtrace.first(3).join("\n")
    nil
  end

  # Turbo Stream broadcast methods
  def broadcast_remove_loading
    Turbo::StreamsChannel.broadcast_remove_to(
      "course_generator",
      target: "loading-message"
    )
  end

  def broadcast_start_streaming
    Turbo::StreamsChannel.broadcast_append_to(
      "course_generator",
      target: "chat-messages",
      partial: "admin/course_generator/chatgpt_streaming_start"
    )
  end

  def broadcast_line(line_content)
    Turbo::StreamsChannel.broadcast_append_to(
      "course_generator",
      target: "streaming-text-content",
      partial: "admin/course_generator/simple_line",
      locals: { line: line_content }
    )
  end

  def broadcast_generate_button
    Turbo::StreamsChannel.broadcast_replace_to(
      "course_generator",
      target: "generate-button-container",
      partial: "admin/course_generator/generate_detailed_button"
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

    Rails.logger.info "Saved AI response to conversation #{@conversation.id} (#{message_type})"
  end

  # Prompt building methods
  def build_title_overview_prompt
    <<~PROMPT
      You are an AI assistant that creates course titles and descriptions.
      Return your response as a JSON object with this structure:
      {
        "title": "Course Title Here",
        "description": "Brief course description",
        "duration_estimate": "X hours/days/weeks",
        "difficulty_level": "Beginner|Intermediate|Advanced"
      }

      Be concise but descriptive.
    PROMPT
  end

  def build_objectives_prompt
    <<~PROMPT
      You are an AI assistant that creates learning objectives.
      Return your response as a JSON object with this structure:
      {
        "objectives": [
          "Learning objective 1",
          "Learning objective 2",
          "Learning objective 3"
        ]
      }

      Create 3-5 specific, measurable learning objectives.
    PROMPT
  end

  def build_modules_prompt
    <<~PROMPT
      You are an AI assistant that creates course modules.
      Return your response as a JSON object with this structure:
      {
        "modules": [
          {
            "order": 1,
            "title": "Module Title",
            "description": "Module description",
            "duration": "X minutes/hours",
            "topics": ["Topic 1", "Topic 2", "Topic 3"]
          }
        ]
      }

      Create 3-4 modules with logical progression.
    PROMPT
  end

  def build_assessments_prompt
    <<~PROMPT
      You are an AI assistant that creates course assessments.
      Return your response as a JSON object with this structure:
      {
        "assessments": [
          {
            "type": "quiz|assignment|project",
            "title": "Assessment Title",
            "description": "Assessment description"
          }
        ]
      }

      Create 2-3 diverse assessment suggestions.
    PROMPT
  end
end
