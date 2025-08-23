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

    messages = [ system_message ] + conversation_history + [ { role: "user", content: message } ]

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

  # Generate comprehensive course structure from prompt and document context
  def self.generate_course_structure(prompt, context_chunks = [])
    context = context_chunks.map(&:content).join("\n\n")

    Rails.logger.info "Generating course structure with #{context_chunks.length} chunks of context"

    system_prompt = build_course_structure_system_prompt
    user_prompt = build_course_structure_prompt(prompt, context)

    response = client.chat(
      parameters: {
        model: "gpt-4",
        messages: [
          {
            role: "system",
            content: system_prompt
          },
          {
            role: "user",
            content: user_prompt
          }
        ],
        temperature: 0.7,
        max_tokens: 2000
      }
    )

    content = response.dig("choices", 0, "message", "content")
    JSON.parse(content)
  rescue JSON::ParserError => e
    Rails.logger.error "OpenAI Course Structure JSON Parse Error: #{e.message}"
    Rails.logger.error "Raw response: #{content}"
    {}
  rescue => e
    Rails.logger.error "OpenAI Course Structure Error: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    {}
  end

  # Generate detailed educational content from a prompt
  def self.generate_content(prompt, system_message = nil)
    Rails.logger.info "Generating detailed content using OpenAI (#{prompt.length} characters)"

    messages = []

    if system_message
      messages << {
        role: "system",
        content: system_message
      }
    end

    messages << {
      role: "user",
      content: prompt
    }

    response = client.chat(
      parameters: {
        model: "gpt-4",
        messages: messages,
        temperature: 0.7,
        max_tokens: 1500
      }
    )

    {
      'choices' => [
        {
          'message' => {
            'content' => response.dig("choices", 0, "message", "content")
          }
        }
      ]
    }
  rescue => e
    Rails.logger.error "OpenAI Content Generation Error: #{e.message}"
    Rails.logger.error e.backtrace.first(3).join("\n")
    nil
  end

  # Generate meaningful conversation title based on chat content
  def self.generate_conversation_title(conversation)
    return nil unless conversation.chat_messages.exists?

    # Get first few user messages to understand the conversation context
    user_messages = conversation.chat_messages
                              .where(message_type: 'user_prompt')
                              .limit(3)
                              .pluck(:content)
                              .join(' ')

        # Get first few AI responses to understand the context better
    ai_messages = conversation.chat_messages
                            .where(message_type: ['ai_overview', 'ai_detailed'])
                            .limit(2)
                            .pluck(:content)
                            .join(' ')

    return nil if user_messages.blank?

    Rails.logger.info "Generating title for conversation #{conversation.id} with #{user_messages.length} characters of content"

    system_prompt = <<~PROMPT
      You are a helpful assistant that creates concise, descriptive titles for conversations.
      Based on the conversation content provided, generate a short, meaningful title (3-6 words maximum) that captures the main topic or purpose.

      Rules:
      - Keep it under 50 characters
      - Use title case (capitalize first letter of each word)
      - Be descriptive but concise
      - Focus on the main topic, not implementation details
      - Remove any document references (like @filename)

      Examples of good titles:
      - "Employee Onboarding Process"
      - "API Integration Guide"
      - "Security Best Practices"
      - "Database Migration Steps"
    PROMPT

    user_prompt = <<~PROMPT
      Based on this conversation content, generate a concise title:

      User messages: #{user_messages.truncate(800)}

      #{ai_messages.present? ? "AI responses: #{ai_messages.truncate(400)}" : ""}

      Generate only the title, nothing else.
    PROMPT

    response = client.chat(
      parameters: {
        model: "gpt-3.5-turbo",
        messages: [
          {
            role: "system",
            content: system_prompt
          },
          {
            role: "user",
            content: user_prompt
          }
        ],
        temperature: 0.3,
        max_tokens: 20
      }
    )

    title = response.dig("choices", 0, "message", "content")&.strip

    # Clean up the title
    if title.present?
      title = title.gsub(/^["']|["']$/, '') # Remove surrounding quotes
      title = title.gsub(/@\w+/, '').strip # Remove document references
      title = title.truncate(50, omission: '...')
    end

    Rails.logger.info "Generated title for conversation #{conversation.id}: '#{title}'"
    title
  rescue => e
    Rails.logger.error "OpenAI Title Generation Error: #{e.message}"
    Rails.logger.error e.backtrace.first(3).join("\n")
    nil
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

  def self.build_course_structure_system_prompt
    <<~PROMPT
      You are an AI assistant specialized in creating comprehensive onboarding course structures. Your role is to analyze user requests and document content to generate well-organized, educational course outlines.

      Return your response as a valid JSON object with this exact structure:
      {
        "title": "Course Title",
        "description": "Brief course description",
        "objectives": ["Learning objective 1", "Learning objective 2", "Learning objective 3"],
        "duration_estimate": "2-3 hours",
        "difficulty_level": "Beginner|Intermediate|Advanced",
        "modules": [
          {
            "order": 1,
            "title": "Module Title",
            "description": "Module description",
            "duration": "30 minutes",
            "topics": [
              {
                "title": "Topic Title",
                "content_overview": "What this topic covers",
                "key_points": ["Key point 1", "Key point 2"],
                "activities": ["Activity or exercise suggestion"]
              }
            ]
          }
        ],
        "assessment_suggestions": [
          {
            "type": "quiz|assignment|project",
            "title": "Assessment Title",
            "description": "Assessment description"
          }
        ]
      }

      Guidelines:
      - Create 3-5 modules per course
      - Each module should have 2-4 topics
      - Base content on provided document context when available
      - Make courses practical and actionable
      - Include realistic time estimates
      - Suggest relevant assessments
    PROMPT
  end

  def self.build_course_structure_prompt(user_prompt, context)
    <<~PROMPT
      User Request: #{user_prompt}

      #{context.present? ? "Referenced Document Content:\n#{context}" : "No specific documents referenced."}

      Please create a comprehensive course structure based on the user's request. If document content is provided, incorporate relevant information from those documents into the course structure. The course should be educational, well-organized, and practical for onboarding new team members.

      Focus on creating actionable learning modules that build upon each other logically. Include specific topics, key learning points, and suggested activities or exercises where appropriate.
    PROMPT
  end
end
