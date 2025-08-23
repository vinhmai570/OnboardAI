class OpenaiService
  def self.client
    @client ||= OpenAI::Client.new
  end

  def self.azure_embedding_client
    @azure_embedding_client ||= begin
        Rails.logger.info "🔧 Configuring Azure OpenAI client for embeddings"
        Rails.logger.info "   Endpoint: #{ENV['AZURE_OPENAI_ENDPOINT']}"
        Rails.logger.info "   Deployment: #{ENV['AZURE_OPENAI_EMBEDDINGS_DEPLOYMENT']}"
        ::OpenAI::Client.new(
          access_token: ENV.fetch("OPENAI_API_KEY"),
          uri_base: File.join(ENV.fetch("AZURE_OPENAI_ENDPOINT"), "openai", "deployments", ENV.fetch("AZURE_OPENAI_EMBEDDINGS_DEPLOYMENT", "text-embedding-3-small")),
          api_version: "2023-12-01-preview"
        )
    end
  end

  # Generate embeddings for text using Azure OpenAI
  def self.generate_embedding(text)
    return nil if text.blank?

    Rails.logger.info "Generating embedding for text (#{text.length} characters) using Azure OpenAI"

    # Truncate text if too long (OpenAI has token limits)
    truncated_text = text.length > 8000 ? text[0..8000] : text

    embedding_client = azure_embedding_client

    response = embedding_client.embeddings(
      parameters: {
        model: "text-embedding-3-small",
        input: truncated_text
      }
    )

    embedding = response.dig("data", 0, "embedding")

    if embedding && embedding.is_a?(Array)
      Rails.logger.info "✅ Successfully generated embedding with #{embedding.length} dimensions via Azure OpenAI"
      embedding
    else
      Rails.logger.error "❌ Invalid embedding response format from Azure OpenAI"
      nil
    end
  rescue => e
    Rails.logger.error "❌ Azure OpenAI Embedding Error: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    nil
  end

  # Generate course task list from prompt and document context
  def self.generate_task_list(prompt, context_chunks = [])
    context = context_chunks.map(&:content).join("\n\n")

    full_prompt = build_task_list_prompt(prompt, context)

    response = client.chat(
      parameters: {
        model: "gpt-4",
        messages: [
          {
            role: "system",
            content: "You are an AI assistant that creates structured onboarding task lists. Return your response as a JSON array of task objects with 'title' and 'description' fields."
          },
          {
            role: "user",
            content: full_prompt
          }
        ],
        temperature: 0.7
      }
    )

    content = response.dig("choices", 0, "message", "content")
    JSON.parse(content)
  rescue JSON::ParserError => e
    Rails.logger.error "OpenAI Task List JSON Parse Error: #{e.message}"
    []
  rescue => e
    Rails.logger.error "OpenAI Task List Error: #{e.message}"
    []
  end

  # Generate detailed course content from task list
  def self.generate_course_details(task_list, context_chunks = [])
    context = context_chunks.map(&:content).join("\n\n")

    full_prompt = build_course_details_prompt(task_list, context)

    response = client.chat(
      parameters: {
        model: "gpt-4",
        messages: [
          {
            role: "system",
            content: "You are an AI assistant that creates detailed educational content. Return your response as a JSON object with course steps."
          },
          {
            role: "user",
            content: full_prompt
          }
        ],
        temperature: 0.7
      }
    )

    content = response.dig("choices", 0, "message", "content")
    JSON.parse(content)
  rescue JSON::ParserError => e
    Rails.logger.error "OpenAI Course Details JSON Parse Error: #{e.message}"
    {}
  rescue => e
    Rails.logger.error "OpenAI Course Details Error: #{e.message}"
    {}
  end

  # Generate chat response with document context
  def self.chat_response(message, context_chunks = [], conversation_history = [])
    context = context_chunks.map(&:content).join("\n\n")

    system_message = {
      role: "system",
      content: build_chat_system_prompt(context)
    }

    messages = [system_message] + conversation_history + [{ role: "user", content: message }]

    response = client.chat(
      parameters: {
        model: "gpt-3.5-turbo",
        messages: messages,
        temperature: 0.7,
        max_tokens: 500
      }
    )

    response.dig("choices", 0, "message", "content")
  rescue => e
    Rails.logger.error "OpenAI Chat Error: #{e.message}"
    "I'm sorry, I'm having trouble processing your request right now. Please try again later."
  end

  private

  def self.build_task_list_prompt(user_prompt, context)
    <<~PROMPT
      Based on the following user request and relevant document context, create a structured list of onboarding tasks.

      User Request: #{user_prompt}

      Document Context:
      #{context}

      Please create a JSON array of tasks, where each task has:
      - title: A clear, concise title for the task
      - description: A brief description of what needs to be accomplished

      Focus on creating practical, actionable tasks that build upon each other logically.
    PROMPT
  end

  def self.build_course_details_prompt(task_list, context)
    tasks_json = task_list.to_json

    <<~PROMPT
      Based on the following task list and document context, create detailed course content with quizzes.

      Task List: #{tasks_json}

      Document Context:
      #{context}

      Please create a JSON object with the following structure:
      {
        "steps": [
          {
            "order": 1,
            "title": "Step Title",
            "content": "Detailed educational content in markdown format",
            "quiz_questions": [
              {
                "question": "Question text?",
                "options": ["Option A", "Option B", "Option C", "Option D"],
                "correct_answer": 0,
                "explanation": "Why this is the correct answer"
              }
            ]
          }
        ]
      }

      Make the content educational, engaging, and practical. Include code examples where appropriate.
    PROMPT
  end

  def self.build_chat_system_prompt(context)
    <<~PROMPT
      You are a helpful AI assistant for an onboarding platform. You help users learn and complete their onboarding tasks.

      You have access to the following relevant documentation:
      #{context}

      Use this context to provide accurate, helpful answers. If a question is outside the scope of the provided context, let the user know and offer to help with topics covered in their onboarding materials.

      Be friendly, encouraging, and focus on helping users learn effectively.
    PROMPT
  end
end
