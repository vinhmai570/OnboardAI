class GenerateDetailedCourseJob < ApplicationJob
  queue_as :default

  def perform(session_id, mentioned_document_ids = [], course_id = nil)
    Rails.logger.info "Starting course structure generation for session: #{session_id}"
    Rails.logger.info "Using #{mentioned_document_ids.length} referenced documents"

    @session_id = session_id
    # Find the latest conversation for this session
    @conversation = Conversation.joins(:chat_messages)
                                .where(session_id: session_id)
                                .order(updated_at: :desc)
                                .first

    begin
      # Get referenced documents and their chunks
      referenced_documents = Document.where(id: mentioned_document_ids).includes(:document_chunks)
      context_chunks = referenced_documents.flat_map(&:document_chunks).select { |chunk| chunk.embedding.present? }

      Rails.logger.info "Found #{context_chunks.length} chunks from #{referenced_documents.length} documents for structure generation"

      # Generate course structure JSON using document context
      json_response = generate_course_structure_list(context_chunks, referenced_documents)

      if json_response
        # Parse and store the structured course data
        course_structure = parse_and_store_course_structure(json_response, course_id)

        if course_structure
          Rails.logger.info "Successfully created course structure with ID: #{course_structure[:course_id]}"

          # Save JSON response to chat history (but don't display in chat)
          save_ai_response(json_response, 'ai_detailed')

          # Broadcast completion to structure page
          broadcast_structure_completion(course_structure[:course_id])
        else
          broadcast_structure_error("Failed to parse course structure. Please try again.")
        end
      else
        broadcast_structure_error("Failed to generate course structure. Please try again.")
      end

    rescue => e
      Rails.logger.error "Course structure generation error: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")

      # Show error message on structure page
      broadcast_structure_error("Failed to generate course structure. Please try again.")
    end
  end

  private

  def generate_course_structure_list(context_chunks, referenced_documents)
    context = context_chunks.map(&:content).join("\n\n")[0..3000] # Limit context for structure

    system_prompt = <<~PROMPT
      You are an AI course designer. Create a clear, well-organized course structure based on the provided documents and context.

      IMPORTANT: Return ONLY valid JSON in the following format (no markdown, no explanation, just pure JSON):

      {
        "title": "Course Title Here",
        "overview": "Brief description of the course and its purpose based on the documents.",
        "learning_objectives": [
          "Objective 1 based on document content",
          "Objective 2",
          "Objective 3"
        ],
        "modules": [
          {
            "id": 1,
            "title": "Module Title",
            "duration_hours": 2,
            "description": "Brief module description",
            "steps": [
              {
                "id": 1,
                "title": "Step Title",
                "content": "Step content description",
                "type": "lesson",
                "duration_minutes": 30,
                "resources": ["Resource 1", "Resource 2"]
              },
              {
                "id": 2,
                "title": "Assessment Title",
                "content": "Assessment description",
                "type": "assessment",
                "duration_minutes": 15,
                "questions": ["Question 1", "Question 2"]
              }
            ]
          }
        ],
        "total_duration_hours": 6,
        "referenced_documents": #{referenced_documents.map(&:title).to_json},
        "created_at": "#{Time.current.iso8601}"
      }

      Base your structure on the provided documents and context. Include 3-4 modules with 3-5 steps each.
      Step types can be: "lesson", "exercise", "assessment", "reading".
    PROMPT

    user_prompt = if context.present?
      "Create a structured course based on the following context from documents:\n\n#{context}"
    else
      "Create a structured onboarding course with modules and steps."
    end

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
    Rails.logger.error "OpenAI course structure generation error: #{e.message}"
    nil
  end

  def parse_and_store_course_structure(json_response, course_id = nil)
    begin
      # Parse JSON response
      structure_data = JSON.parse(json_response)

      # Use existing course or create new one (fallback for backward compatibility)
      if course_id
        course = Course.find(course_id)
        Rails.logger.info "Using existing course #{course.id}: '#{course.title}'"

        # Update course with structured data
        course.update!(structure: structure_data)
      else
        # Fallback: Create new course (for backward compatibility)
        current_user = @conversation&.user
        return nil unless current_user

        course = Course.create!(
          title: structure_data['title'] || 'Generated Course',
          prompt: "Generated from conversation #{@conversation.id}",
          structure: structure_data,
          admin: current_user,
          conversation: @conversation
        )
        Rails.logger.info "Created new course #{course.id}: '#{course.title}'"
      end

      # Create CourseModule and CourseStep records from JSON data
      structure_data['modules']&.each_with_index do |module_data, module_index|
        course_module = course.course_modules.create!(
          title: module_data['title'],
          description: module_data['description'],
          duration_hours: module_data['duration_hours'] || 1,
          order_position: module_index + 1
        )

        Rails.logger.info "Created module #{course_module.id}: '#{course_module.title}'"

        # Create steps for this module
        module_data['steps']&.each_with_index do |step_data, step_index|
          course_step = course_module.course_steps.create!(
            title: step_data['title'],
            content: step_data['content'],
            step_type: step_data['type'] || 'lesson',
            duration_minutes: step_data['duration_minutes'] || 30,
            resources: step_data['resources'] || [],
            order_position: step_index + 1
          )

          Rails.logger.info "Created step #{course_step.id}: '#{course_step.title}'"
        end
      end

      # Also create individual steps from modules for backward compatibility with existing system
      step_order = 1
      course.course_modules.includes(:course_steps).each do |course_module|
        course_module.course_steps.each do |course_step|
          Step.create!(
            course: course,
            order: step_order,
            content: "#{course_step.title}\n\n#{course_step.content}",
            quiz_questions: []
          )
          step_order += 1
        end
      end

      {
        course_id: course.id,
        structure: structure_data
      }

    rescue JSON::ParserError => e
      Rails.logger.error "JSON parsing error: #{e.message}"
      Rails.logger.error "Response was: #{json_response}"
      nil
    rescue => e
      Rails.logger.error "Course creation error: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      nil
    end
  end

  # Turbo Stream broadcast methods for structure page
  def broadcast_structure_completion(course_id = nil)
    if course_id
      # Redirect to the structured course view
      Turbo::StreamsChannel.broadcast_replace_to(
        "course_generator_#{@session_id}",
        target: "structure-loading",
        html: "<script>window.location.href = '/admin/course_generator/show_structure?session_id=#{@session_id}&course_id=#{course_id}';</script>"
      )
    else
      Turbo::StreamsChannel.broadcast_replace_to(
        "course_generator_#{@session_id}",
        target: "structure-loading",
        html: "<script>window.location.reload();</script>"
      )
    end
  end

  def broadcast_structure_error(message)
    Turbo::StreamsChannel.broadcast_replace_to(
      "course_generator_#{@session_id}",
      target: "structure-loading",
      html: %{
        <div class="text-center py-12">
          <div class="text-red-600 text-6xl mb-4">⚠️</div>
          <h2 class="text-xl font-semibold text-gray-900 mb-2">Generation Failed</h2>
          <p class="text-gray-600 mb-6">#{message}</p>
          <button onclick="window.location.reload()"
                  class="inline-flex items-center px-4 py-2 bg-blue-600 text-white text-sm font-medium rounded-lg hover:bg-blue-700">
            🔄 Try Again
          </button>
        </div>
      }
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
