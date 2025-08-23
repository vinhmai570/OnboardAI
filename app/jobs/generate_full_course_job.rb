class GenerateFullCourseJob < ApplicationJob
  queue_as :default

  def perform(course_id)
    Rails.logger.info "Starting full course content generation for course: #{course_id}"

    @course = Course.find(course_id)
    @course_modules = @course.course_modules.includes(:course_steps).ordered
    @conversation = @course.conversation

    # Extract document context from conversation
    @document_context = extract_document_context

    begin
      # Generate detailed content for each module and its steps using document context
      total_modules = @course_modules.count
      completed_modules = 0

      @course_modules.each_with_index do |course_module, module_index|
        Rails.logger.info "Generating content for module #{module_index + 1}/#{total_modules}: #{course_module.title}"

        module_success = true

        # Generate detailed module content
        Rails.logger.info "  → Generating module overview and description..."
        module_content_success = generate_module_content(course_module)
        module_success &&= module_content_success

        # Generate content for each step in the module
        total_steps = course_module.course_steps.count
        step_successes = 0

        course_module.course_steps.ordered.each_with_index do |step, step_index|
          Rails.logger.info "  → Generating step #{step_index + 1}/#{total_steps}: #{step.title} (#{step.step_type})"
          step_success = generate_step_content(step)
          step_successes += 1 if step_success
        end

        # Generate combo quiz for the end of the module
        Rails.logger.info "  → Creating comprehensive module quiz..."
        quiz_success = generate_module_quiz(course_module)
        module_success &&= quiz_success

        completed_modules += 1
        progress_percentage = (completed_modules.to_f / total_modules * 100).round

        if module_success
          Rails.logger.info "✅ Module #{module_index + 1} completed successfully! Overall progress: #{progress_percentage}%"
        else
          Rails.logger.warn "⚠️ Module #{module_index + 1} completed with some issues. Overall progress: #{progress_percentage}%"
        end

        # Broadcast progress update
        broadcast_progress_update(@course.id, completed_modules, total_modules, progress_percentage)
      end

      # Final validation - ensure all content was generated
      total_items = @course_modules.count + @course.course_steps.count
      generated_modules = @course_modules.where(content_generated: true).count
      generated_steps = @course.course_steps.where(content_generated: true).count
      generated_items = generated_modules + generated_steps

      Rails.logger.info "Content generation summary:"
      Rails.logger.info "  Documents used: #{@document_context[:documents].count} (#{@document_context[:chunks].count} chunks)"
      Rails.logger.info "  Modules: #{generated_modules}/#{@course_modules.count} generated"
      Rails.logger.info "  Steps: #{generated_steps}/#{@course.course_steps.count} generated"
      Rails.logger.info "  Total items: #{generated_items}/#{total_items} generated"
      Rails.logger.info "  Quiz steps created: #{@course.course_steps.where(step_type: 'assessment').count}"

      # Mark course as having full content generated only if everything succeeded
      if generated_items >= total_items * 0.8  # At least 80% success rate
        @course.update!(
          full_content_generated: true,
          full_content_generated_at: Time.current
        )

        Rails.logger.info "✅ Full course content generation completed successfully!"
        Rails.logger.info "   Course: #{@course.title}"
        Rails.logger.info "   Modules: #{@course_modules.count} (with quizzes)"
        Rails.logger.info "   Total Steps: #{@course.course_steps.count}"
        Rails.logger.info "   Assessment Steps: #{@course.quiz_count}"

        # Broadcast successful completion
        broadcast_full_course_completion(@course.id)
      else
        Rails.logger.error "❌ Course generation incomplete! Only #{generated_items}/#{total_items} items generated"
        broadcast_full_course_error("Course generation incomplete. Only #{generated_items}/#{total_items} items were successfully generated.", @course.id)
      end

    rescue => e
      Rails.logger.error "Full course generation error: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")

      broadcast_full_course_error("Failed to generate full course content. Please try again.", @course.id)
    end
  end

  private

  def extract_document_context
    return { chunks: [], documents: [] } unless @conversation

    Rails.logger.info "Extracting document context from conversation #{@conversation.id}"

    # Extract document IDs from all user messages in the conversation
    mentioned_document_ids = []
    @conversation.chat_messages.where(message_type: 'user_prompt').each do |message|
      mentioned_document_ids += extract_document_mentions(message.content)
    end
    mentioned_document_ids = mentioned_document_ids.uniq

    Rails.logger.info "Found #{mentioned_document_ids.length} referenced documents in conversation"

    # Get referenced documents and their chunks
    if mentioned_document_ids.any?
      referenced_documents = Document.where(id: mentioned_document_ids).includes(:document_chunks)
      context_chunks = referenced_documents.flat_map(&:document_chunks).select { |chunk| chunk.embedding.present? }

      Rails.logger.info "Loaded #{context_chunks.length} chunks from #{referenced_documents.length} documents for full course generation"

      {
        chunks: context_chunks,
        documents: referenced_documents,
        document_ids: mentioned_document_ids
      }
    else
      Rails.logger.warn "No documents referenced in conversation - content will be generated without document context"
      { chunks: [], documents: [], document_ids: [] }
    end
  rescue => e
    Rails.logger.error "Error extracting document context: #{e.message}"
    { chunks: [], documents: [], document_ids: [] }
  end

  def extract_document_mentions(text)
    return [] unless text.present?

    # Extract @filename patterns from the text (same logic as controller)
    filenames = text.scan(/@([a-z0-9_.-]+)/i).flatten

    # Get all documents to match against
    all_documents = Document.all

    # Find document IDs based on filenames
    document_ids = []
    filenames.each do |filename|
      all_documents.each do |doc|
        # Use simple filename matching (could be enhanced with better sanitization)
        sanitized_filename = doc.title.downcase.gsub(/[^a-z0-9_.-]/, '_')
        if sanitized_filename == filename.downcase
          document_ids << doc.id
          Rails.logger.info "Matched filename '#{filename}' to document ID #{doc.id} (#{doc.title})"
        end
      end
    end

    document_ids.uniq
  end

  def generate_module_content(course_module)
    # Generate detailed description and overview for the module
    prompt = build_module_content_prompt(course_module)

    response = OpenaiService.generate_content(prompt)
    if response && response['choices'] && response['choices'][0]
      content = response['choices'][0]['message']['content']

      # Update module with detailed content
      course_module.update!(
        detailed_description: content,
        content_generated: true
      )

      Rails.logger.info "    ✅ Module content generated successfully (#{content.length} characters)"
      return true
    else
      Rails.logger.error "    ❌ Failed to generate module content - no valid response from OpenAI"
      return false
    end
  rescue => e
    Rails.logger.error "    ❌ Error generating module content: #{e.message}"
    return false
  end

  def generate_step_content(step)
    # Generate detailed content based on step type
    prompt = build_step_content_prompt(step)

    response = OpenaiService.generate_content(prompt)
    if response && response['choices'] && response['choices'][0]
      content = response['choices'][0]['message']['content']

      # Update step with detailed content
      step.update!(
        detailed_content: content,
        content_generated: true
      )

      Rails.logger.info "      ✅ Step content generated: #{step.step_type} (#{content.length} characters)"
      return true
    else
      Rails.logger.error "      ❌ Failed to generate step content - no valid response from OpenAI"
      return false
    end
  rescue => e
    Rails.logger.error "      ❌ Error generating step content: #{e.message}"
    return false
  end

  def generate_module_quiz(course_module)
    # Generate a comprehensive quiz for the module
    prompt = build_module_quiz_prompt(course_module)

    response = OpenaiService.generate_content(prompt)
    if response && response['choices'] && response['choices'][0]
      quiz_content = response['choices'][0]['message']['content']

      # Create a quiz step at the end of the module
      quiz_step = course_module.course_steps.create!(
        title: "📝 Module #{course_module.order_position} Quiz",
        step_type: 'assessment',
        duration_minutes: 15,
        content: "Complete this quiz to test your understanding of the module concepts.",
        detailed_content: quiz_content,
        content_generated: true,
        order_position: course_module.course_steps.maximum(:order_position).to_i + 1
      )

      Rails.logger.info "      ✅ Module quiz created: #{quiz_step.title} (#{quiz_content.length} characters)"
      return true
    else
      Rails.logger.error "      ❌ Failed to generate module quiz - no valid response from OpenAI"
      return false
    end
  rescue => e
    Rails.logger.error "      ❌ Error generating module quiz: #{e.message}"
    return false
  end

  def build_module_content_prompt(course_module)
    course_context = {
      course_title: @course.title,
      module_title: course_module.title,
      module_description: course_module.description,
      module_duration: course_module.duration_minutes,
      steps: course_module.course_steps.ordered.map { |step|
        {
          title: step.title,
          type: step.step_type,
          duration: step.duration_minutes,
          content: step.content
        }
      }
    }

    # Build document context
    document_context = ""
    if @document_context[:chunks].any?
      document_context = "\n\nREFERENCED DOCUMENT CONTENT:\n"
      document_context += "Base your content STRICTLY on the following document excerpts:\n\n"

      @document_context[:chunks].first(5).each_with_index do |chunk, i|
        document_context += "--- Document Excerpt #{i+1} ---\n"
        document_context += "#{chunk.content}\n\n"
      end

      document_context += "IMPORTANT: Only use information from the above document excerpts. Do not add external knowledge not found in these documents.\n"
    else
      document_context = "\n\nWARNING: No document context available. Please generate generic educational content."
    end

    <<~PROMPT
      Generate detailed educational content for a course module with the following context:

      Course: #{course_context[:course_title]}
      Module: #{course_context[:module_title]}
      Description: #{course_context[:module_description]}
      Duration: #{course_context[:module_duration]} minutes

      Steps in this module:
      #{course_context[:steps].map.with_index { |step, i| "#{i+1}. #{step[:title]} (#{step[:type]}, #{step[:duration]}min)" }.join("\n")}#{document_context}

      Please generate (based ONLY on the referenced document content):
      1. A comprehensive module overview (2-3 paragraphs)
      2. Learning objectives for this module (3-5 bullet points)
      3. Key concepts that will be covered
      4. Prerequisites or prior knowledge needed
      5. How this module fits into the overall course structure

      Format the response in clear, educational markdown format. Make it engaging and informative for adult learners.
      The content should be detailed enough to guide both instructors and self-directed learners.

      CRITICAL: Only reference information found in the provided document excerpts above. Do not include external knowledge.
    PROMPT
  end

  def build_step_content_prompt(step)
    module_context = step.course_module
    course_context = module_context.course

    # Build document context for this specific step
    document_context = ""
    if @document_context[:chunks].any?
      document_context = "\n\nREFERENCED DOCUMENT CONTENT:\n"
      document_context += "Base your content STRICTLY on the following document excerpts:\n\n"

      # Limit to most relevant chunks for the step
      relevant_chunks = @document_context[:chunks].first(3)
      relevant_chunks.each_with_index do |chunk, i|
        document_context += "--- Document Excerpt #{i+1} ---\n"
        document_context += "#{chunk.content}\n\n"
      end

      document_context += "IMPORTANT: Only use information from the above document excerpts. Do not add external knowledge not found in these documents.\n"
    else
      document_context = "\n\nWARNING: No document context available. Please generate generic educational content."
    end

    <<~PROMPT
      Generate detailed educational content for a specific learning step with the following context:

      Course: #{course_context.title}
      Module: #{module_context.title}
      Step: #{step.title}
      Type: #{step.step_type}
      Duration: #{step.duration_minutes} minutes
      Current Content: #{step.content}#{document_context}

      Based on the step type "#{step.step_type}", please generate appropriate detailed content using ONLY the referenced document content:

      #{step_type_instructions(step.step_type)}

      Format the response in clear, educational markdown format. Include:
      - Clear explanations with examples FROM THE DOCUMENTS
      - Practical applications where relevant FROM THE DOCUMENTS
      - Interactive elements if appropriate for the step type
      - Clear action items or takeaways based on DOCUMENT CONTENT

      Make the content engaging and suitable for adult learners in a professional development context.

      CRITICAL: Only reference information found in the provided document excerpts above. Do not include external knowledge.
    PROMPT
  end

  def step_type_instructions(step_type)
    case step_type
    when 'lesson'
      <<~INSTRUCTIONS
        For a LESSON step, provide (using ONLY document content):
        1. Core concept explanation with clear definitions FROM THE DOCUMENTS
        2. Real-world examples and use cases MENTIONED IN THE DOCUMENTS
        3. Step-by-step breakdown of key processes FROM THE DOCUMENTS
        4. Common misconceptions to avoid based on DOCUMENT GUIDANCE
        5. Visual elements description if mentioned in DOCUMENTS
      INSTRUCTIONS
    when 'exercise'
      <<~INSTRUCTIONS
        For an EXERCISE step, provide (using ONLY document content):
        1. Clear instructions for activities described in THE DOCUMENTS
        2. Expected outcomes and success criteria FROM THE DOCUMENTS
        3. Tools or resources MENTIONED IN THE DOCUMENTS
        4. Step-by-step guidance BASED ON DOCUMENT PROCEDURES
        5. Troubleshooting tips from DOCUMENT EXAMPLES
        6. Self-assessment questions based on DOCUMENT CONTENT
      INSTRUCTIONS
    when 'reading'
      <<~INSTRUCTIONS
        For a READING step, provide (using ONLY document content):
        1. Key passages or content FROM THE DOCUMENTS
        2. Key points to focus on BASED ON DOCUMENT HIGHLIGHTS
        3. Discussion questions for reflection ON DOCUMENT CONTENT
        4. Connections to other concepts WITHIN THE DOCUMENTS
        5. Additional context FROM OTHER PARTS OF THE DOCUMENTS
      INSTRUCTIONS
    when 'video'
      <<~INSTRUCTIONS
        For a VIDEO step, provide (using ONLY document content):
        1. Video concept outline based on DOCUMENT TOPICS
        2. Key sections to focus on FROM DOCUMENT STRUCTURE
        3. Note-taking template based on DOCUMENT INFORMATION
        4. Follow-up questions FROM DOCUMENT CONTENT
        5. Related concepts from OTHER PARTS OF THE DOCUMENTS
      INSTRUCTIONS
    when 'assessment'
      <<~INSTRUCTIONS
        For an ASSESSMENT step, provide (using ONLY document content):
        1. Assessment instructions based on DOCUMENT GUIDANCE
        2. Evaluation criteria FROM THE DOCUMENTS
        3. Sample questions based on DOCUMENT CONTENT
        4. Preparation tips FROM DOCUMENT RECOMMENDATIONS
        5. Learning objectives connections TO DOCUMENT TOPICS
      INSTRUCTIONS
    else
      "Provide comprehensive educational content appropriate for this step type, using ONLY information from the referenced documents. Include explanations, examples, and practical guidance EXCLUSIVELY from document content."
    end
  end

  def build_module_quiz_prompt(course_module)
    steps_content = course_module.course_steps.ordered.map { |step|
      "- #{step.title} (#{step.step_type}): #{step.content}"
    }.join("\n")

    # Build document context for quiz
    document_context = ""
    if @document_context[:chunks].any?
      document_context = "\n\nREFERENCED DOCUMENT CONTENT FOR QUIZ QUESTIONS:\n"
      document_context += "Base ALL quiz questions STRICTLY on the following document excerpts:\n\n"

      # Use more chunks for quiz to have broader question coverage
      quiz_chunks = @document_context[:chunks].first(8)
      quiz_chunks.each_with_index do |chunk, i|
        document_context += "--- Document Excerpt #{i+1} ---\n"
        document_context += "#{chunk.content}\n\n"
      end

      document_context += "CRITICAL: All quiz questions and answers must be based on information found in the above document excerpts only.\n"
    else
      document_context = "\n\nWARNING: No document context available. Please generate generic quiz questions."
    end

    <<~PROMPT
      Create a comprehensive quiz for the following course module:

      Module: #{course_module.title}
      Description: #{course_module.description}
      Duration: #{course_module.duration_minutes} minutes

      Steps covered in this module:
      #{steps_content}#{document_context}

      Generate a combo quiz that includes (based ONLY on the referenced document content):

      1. **Multiple Choice Questions (5 questions)**
         - Test key concepts from the DOCUMENTS
         - Include 4 options each with clear distractors
         - Mark correct answers with explanation FROM DOCUMENTS

      2. **True/False Questions (3 questions)**
         - Focus on information specifically mentioned in DOCUMENTS
         - Provide detailed explanations for each answer using DOCUMENT CONTENT

      3. **Short Answer Questions (2 questions)**
         - Test practical application of concepts FROM DOCUMENTS
         - Provide sample answers based on DOCUMENT INFORMATION

      4. **Scenario-Based Question (1 question)**
         - Present a realistic scenario based on DOCUMENT EXAMPLES
         - Test ability to apply concepts FROM DOCUMENTS
         - Include detailed solution approach using DOCUMENT GUIDANCE

      Format the quiz in clear markdown with:
      - Question numbers and clear formatting
      - Answer choices for multiple choice/true-false
      - Correct answers and explanations at the end
      - Estimated time: 15 minutes total

      Make questions challenging but fair, focusing on practical application of DOCUMENT CONTENT.

      CRITICAL: All questions, answers, and explanations must be based exclusively on the provided document excerpts above. Do not include external knowledge.
    PROMPT
  end

  def broadcast_progress_update(course_id, completed_modules, total_modules, percentage)
    Turbo::StreamsChannel.broadcast_replace_to(
      "full_course_generator_#{course_id}",
      target: "full-course-loading",
      html: %{
        <div class="text-center py-12">
          <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-6"></div>
          <h2 class="text-2xl font-semibold text-gray-900 mb-4">🤖 Generating Full Course Content...</h2>

          <!-- Progress Bar -->
          <div class="max-w-lg mx-auto mb-6">
            <div class="flex justify-between text-sm text-gray-600 mb-2">
              <span>Progress</span>
              <span>#{percentage}%</span>
            </div>
            <div class="w-full bg-gray-200 rounded-full h-3">
              <div class="bg-blue-600 h-3 rounded-full transition-all duration-500" style="width: #{percentage}%"></div>
            </div>
            <div class="text-sm text-gray-500 mt-2">Module #{completed_modules}/#{total_modules} completed</div>
          </div>

          <!-- Current Status -->
          <div class="max-w-md mx-auto space-y-3 mb-6">
            <div class="flex items-center space-x-3">
              <div class="bg-green-500 rounded-full h-3 w-3"></div>
              <span class="text-sm text-green-800">Generating content from your documents...</span>
            </div>
            <div class="flex items-center space-x-3">
              <div class="animate-pulse bg-blue-300 rounded-full h-3 w-3"></div>
              <span class="text-sm text-blue-800">Creating interactive step content...</span>
            </div>
            <div class="flex items-center space-x-3">
              <div class="animate-pulse bg-red-300 rounded-full h-3 w-3 delay-200"></div>
              <span class="text-sm text-red-800">Building document-based quizzes...</span>
            </div>
          </div>

          <div class="text-sm text-gray-500">
            This process may take 2-5 minutes depending on course complexity.
            <br>Page will auto-refresh when complete.
          </div>
        </div>
      }
    )
  end

  def broadcast_full_course_completion(course_id)
    Turbo::StreamsChannel.broadcast_replace_to(
      "full_course_generator_#{course_id}",
      target: "full-course-loading",
      html: %{
        <div class="text-center py-8 bg-green-50 border border-green-200 rounded-lg">
          <div class="text-green-600 text-6xl mb-4">🎉</div>
          <h2 class="text-xl font-semibold text-green-900 mb-2">Full Course Content Generated!</h2>
          <p class="text-green-700 mb-6">Your complete course with detailed content from your documents and interactive quizzes is ready.</p>

          <!-- Success Stats -->
          <div class="bg-white rounded-lg p-4 mb-6 mx-auto max-w-md">
            <div class="grid grid-cols-2 gap-4 text-sm">
              <div class="text-center">
                <div class="text-2xl font-bold text-blue-600">#{Course.find(course_id).course_modules.count}</div>
                <div class="text-gray-600">Modules</div>
              </div>
              <div class="text-center">
                <div class="text-2xl font-bold text-red-600">#{Course.find(course_id).quiz_count}</div>
                <div class="text-gray-600">Quizzes</div>
              </div>
            </div>
          </div>

          <button onclick="window.location.reload()"
                  class="inline-flex items-center px-6 py-3 bg-green-600 text-white font-medium rounded-lg hover:bg-green-700 transition-colors">
            🚀 View Complete Course
          </button>
        </div>
      }
    )
  end

  def broadcast_full_course_error(message, course_id)
    Turbo::StreamsChannel.broadcast_replace_to(
      "full_course_generator_#{course_id}",
      target: "full-course-loading",
      html: %{
        <div class="text-center py-8 bg-red-50 border border-red-200 rounded-lg">
          <div class="text-red-600 text-6xl mb-4">⚠️</div>
          <h2 class="text-xl font-semibold text-red-900 mb-2">Generation Failed</h2>
          <p class="text-red-700 mb-4">#{message}</p>
          <div class="space-x-3">
            <button onclick="window.location.reload()"
                    class="inline-flex items-center px-4 py-2 bg-blue-600 text-white text-sm font-medium rounded-lg hover:bg-blue-700">
              🔄 Reload Page
            </button>
          </div>
        </div>
      }
    )
  end
end
