class GenerateFullCourseJob < ApplicationJob
  queue_as :default

  def perform(course_id)
    Rails.logger.info "Starting full course content generation for course: #{course_id}"

    @course = Course.find(course_id)
    @course_modules = @course.course_modules.includes(:course_steps).ordered

    begin
            # Generate detailed content for each module and its steps
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

    <<~PROMPT
      Generate detailed educational content for a course module with the following context:

      Course: #{course_context[:course_title]}
      Module: #{course_context[:module_title]}
      Description: #{course_context[:module_description]}
      Duration: #{course_context[:module_duration]} minutes

      Steps in this module:
      #{course_context[:steps].map.with_index { |step, i| "#{i+1}. #{step[:title]} (#{step[:type]}, #{step[:duration]}min)" }.join("\n")}

      Please generate:
      1. A comprehensive module overview (2-3 paragraphs)
      2. Learning objectives for this module (3-5 bullet points)
      3. Key concepts that will be covered
      4. Prerequisites or prior knowledge needed
      5. How this module fits into the overall course structure

      Format the response in clear, educational markdown format. Make it engaging and informative for adult learners.
      The content should be detailed enough to guide both instructors and self-directed learners.
    PROMPT
  end

  def build_step_content_prompt(step)
    module_context = step.course_module
    course_context = module_context.course

    <<~PROMPT
      Generate detailed educational content for a specific learning step with the following context:

      Course: #{course_context.title}
      Module: #{module_context.title}
      Step: #{step.title}
      Type: #{step.step_type}
      Duration: #{step.duration_minutes} minutes
      Current Content: #{step.content}

      Based on the step type "#{step.step_type}", please generate appropriate detailed content:

      #{step_type_instructions(step.step_type)}

      Format the response in clear, educational markdown format. Include:
      - Clear explanations with examples
      - Practical applications where relevant
      - Interactive elements if appropriate for the step type
      - Clear action items or takeaways

      Make the content engaging and suitable for adult learners in a professional development context.
    PROMPT
  end

  def step_type_instructions(step_type)
    case step_type
    when 'lesson'
      <<~INSTRUCTIONS
        For a LESSON step, provide:
        1. Core concept explanation with clear definitions
        2. Real-world examples and use cases
        3. Step-by-step breakdown of key processes
        4. Common misconceptions to avoid
        5. Visual elements description (diagrams, charts, etc.)
      INSTRUCTIONS
    when 'exercise'
      <<~INSTRUCTIONS
        For an EXERCISE step, provide:
        1. Clear instructions for the practical activity
        2. Expected outcomes and success criteria
        3. Tools or resources needed
        4. Step-by-step guidance
        5. Troubleshooting tips for common issues
        6. Self-assessment questions
      INSTRUCTIONS
    when 'reading'
      <<~INSTRUCTIONS
        For a READING step, provide:
        1. Curated content or article-style material
        2. Key points to focus on while reading
        3. Discussion questions for reflection
        4. Connections to other course concepts
        5. Additional recommended resources
      INSTRUCTIONS
    when 'video'
      <<~INSTRUCTIONS
        For a VIDEO step, provide:
        1. Video concept outline and key topics covered
        2. Timestamps for important sections
        3. Note-taking template or guide
        4. Follow-up questions after watching
        5. Related resources and further reading
      INSTRUCTIONS
    when 'assessment'
      <<~INSTRUCTIONS
        For an ASSESSMENT step, provide:
        1. Assessment instructions and format
        2. Evaluation criteria or rubric
        3. Sample questions or examples
        4. Preparation tips and study guide
        5. How results connect to learning objectives
      INSTRUCTIONS
    else
      "Provide comprehensive educational content appropriate for this step type, including explanations, examples, and practical guidance."
    end
  end

  def build_module_quiz_prompt(course_module)
    steps_content = course_module.course_steps.ordered.map { |step|
      "- #{step.title} (#{step.step_type}): #{step.content}"
    }.join("\n")

    <<~PROMPT
      Create a comprehensive quiz for the following course module:

      Module: #{course_module.title}
      Description: #{course_module.description}
      Duration: #{course_module.duration_minutes} minutes

      Steps covered in this module:
      #{steps_content}

      Generate a combo quiz that includes:

      1. **Multiple Choice Questions (5 questions)**
         - Test key concepts and understanding
         - Include 4 options each with clear distractors
         - Mark correct answers with explanation

      2. **True/False Questions (3 questions)**
         - Focus on common misconceptions
         - Provide detailed explanations for each answer

      3. **Short Answer Questions (2 questions)**
         - Test practical application of concepts
         - Provide sample answers and evaluation criteria

      4. **Scenario-Based Question (1 question)**
         - Present a realistic workplace scenario
         - Test ability to apply module concepts
         - Include detailed solution approach

      Format the quiz in clear markdown with:
      - Question numbers and clear formatting
      - Answer choices for multiple choice/true-false
      - Correct answers and explanations at the end
      - Estimated time: 15 minutes total

      Make questions challenging but fair, focusing on practical application rather than memorization.
      Ensure questions cover all major topics from the module steps.
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
              <span class="text-sm text-green-800">Generating detailed module content...</span>
            </div>
            <div class="flex items-center space-x-3">
              <div class="animate-pulse bg-blue-300 rounded-full h-3 w-3"></div>
              <span class="text-sm text-blue-800">Creating interactive step content...</span>
            </div>
            <div class="flex items-center space-x-3">
              <div class="animate-pulse bg-red-300 rounded-full h-3 w-3 delay-200"></div>
              <span class="text-sm text-red-800">Building comprehensive quizzes...</span>
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
          <p class="text-green-700 mb-6">Your complete course with detailed content and interactive quizzes is ready.</p>

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
